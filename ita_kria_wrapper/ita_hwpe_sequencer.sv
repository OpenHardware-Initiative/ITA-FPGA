// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Gemini AI, based on user-provided testbench
// Version: 6.0 (Corrected, Cycle-Accurate Sequencer)

`include "hci_helpers.svh"

import ita_package::*;
import ita_hwpe_package::*;

module ita_sequencer #(
    // Parameters
    parameter int M_TILE_LEN = 64,
    parameter int SEQUENCE_LEN = 64,
    parameter int PROJECTION_SPACE = 64,
    parameter int EMBEDDING_SIZE = 64,
    parameter int FEEDFORWARD_SIZE = 64,
    parameter activation_e ACTIVATION = Identity,
    parameter int SINGLE_ATTENTION = 0,
    parameter int N_CONTEXT = 8,
    parameter int ID = 0,
    parameter int INTER_TILE_DELAY_CYCLES = 5
) (
    input  logic clk_i,
    input  logic rst_ni,
    // Control Interface
    input  logic      start_i,
    input  step_e     step_i,
    output logic      done_o,
    // HWPE Status
    input  logic      hwpe_busy_i,
    // Peripheral Bus Master Interface
    output logic                   periph_req_o,
    input  logic                   periph_gnt_i,
    output logic [31:0]            periph_add_o,
    output logic                   periph_wen_o,
    output logic [3:0]             periph_be_o,
    output logic [31:0]            periph_data_o,
    // Pre-calculated Parameters
    input logic [N_STATES-1:0][31:0] BASE_PTR_INPUT,
    input logic [N_STATES-1:0][31:0] BASE_PTR_WEIGHT0,
    input logic [N_STATES-1:0][31:0] BASE_PTR_WEIGHT1,
    input logic [N_STATES-1:0][31:0] BASE_PTR_BIAS,
    input logic [N_STATES-1:0][31:0] BASE_PTR_OUTPUT,
    input logic [3:0]                N_TILES_SEQUENCE_DIM,
    input logic [3:0]                N_TILES_EMBEDDING_DIM,
    input logic [3:0]                N_TILES_PROJECTION_DIM,
    input logic [3:0]                N_TILES_FEEDFORWARD_DIM,
    input logic [31:0]       N_TILES_OUTER_X [N_STATES-1:0],
    input logic [31:0]       N_TILES_OUTER_Y [N_STATES-1:0],
    input logic [31:0]      N_TILES_INNER_DIM [N_STATES-1:0],
    // RQS Constants
    input  logic [31:0] rqs_eps_mult0_i,
    input  logic [31:0] rqs_eps_mult1_i,
    input  logic [31:0] rqs_rshift0_i,
    input  logic [31:0] rqs_rshift1_i,
    input  logic [31:0] rqs_add0_i,
    input  logic [31:0] rqs_add1_i,
    // Activation Constants
    input  logic [31:0] activation_gelu_const_i,
    input  logic [31:0] activation_rqs_const_i
);

    localparam unsigned ITA_REG_OFFSET = 32'h20;
    localparam int N_ELEMENTS_PER_TILE = M_TILE_LEN * M_TILE_LEN;
    localparam int PROGRAM_STEPS = 16;

    typedef enum logic [4:0] {
        S_IDLE,
        S_CHECK_BUSY,
        S_INTER_TILE_DELAY,
        S_PROG_REQ,
        S_PROG_WAIT_GNT,
        S_PROG_ACK,
        S_TRIGGER_REQ,
        S_TRIGGER_WAIT_GNT,
        S_TRIGGER_ACK,
        S_UPDATE_TILE_COUNTERS,
        S_FINISH_STEP
    } seq_state_t;

    // --- State registers ---
    seq_state_t           current_state, next_state;
    // REVISED: Replaced tile_x/y_cnt with a single outer_tile_cnt
    logic [15:0]          outer_tile_cnt, outer_tile_cnt_next;
    logic [7:0]           tile_inner_cnt, tile_inner_cnt_next;
    logic [4:0]           reg_prog_cnt, reg_prog_cnt_next;
    logic [N_CONTEXT-1:0] ita_reg_cnt, ita_reg_cnt_next;
    logic                 is_first_tile_ever_r, is_first_tile_ever_r_next;
    logic [$clog2(INTER_TILE_DELAY_CYCLES)-1:0] delay_cnt, delay_cnt_next;


    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            current_state        <= S_IDLE;
            outer_tile_cnt       <= '0; // REVISED
            tile_inner_cnt       <= '0;
            reg_prog_cnt         <= '0;
            is_first_tile_ever_r <= 1'b1;
            ita_reg_cnt          <= '0;
        end else begin
            current_state        <= next_state;
            outer_tile_cnt       <= outer_tile_cnt_next; // REVISED
            tile_inner_cnt       <= tile_inner_cnt_next;
            reg_prog_cnt         <= reg_prog_cnt_next;
            is_first_tile_ever_r <= is_first_tile_ever_r_next;
            ita_reg_cnt          <= ita_reg_cnt_next;
        end
    end

    always_comb begin
        // --- Local variables ---
        logic [31:0] input_ptr, weight_ptr0, weight_ptr1, bias_ptr, output_ptr;
        logic [31:0] ctrl_engine_val, ctrl_stream_val;
        logic        weight_ptr_en, bias_ptr_en, ita_reg_en;
        logic        is_last_tile_in_step;
        logic [31:0] tiles_reg_val;
        logic do_write;

        // REVISED: Derive current X and Y from the flattened outer_tile_cnt
        int unsigned current_tile_y;
        int unsigned current_tile_x;
        int unsigned total_outer_tiles;

        // --- Default assignments ---
        next_state                = current_state;
        outer_tile_cnt_next       = outer_tile_cnt; // REVISED
        tile_inner_cnt_next       = tile_inner_cnt;
        reg_prog_cnt_next         = reg_prog_cnt;
        is_first_tile_ever_r_next = is_first_tile_ever_r;
        ita_reg_cnt_next          = ita_reg_cnt;
        done_o                    = 1'b0;
        periph_req_o              = 1'b0;
        periph_add_o              = '0;
        periph_wen_o              = 1'b1;
        periph_be_o               = 4'hf;
        periph_data_o             = '0;

        // --- Calculation Stage ---
        begin
            int unsigned current_tile;
            layer_e      layer_type;
            activation_e activation_function;
            logic is_last;

            // REVISED: Calculation of X, Y, and total outer tiles
            // Avoid division by zero if a dimension is 0 (should not happen in practice)
            if (N_TILES_OUTER_X[step_i] > 0) begin
                current_tile_y = outer_tile_cnt / N_TILES_OUTER_X[step_i];
                current_tile_x = outer_tile_cnt % N_TILES_OUTER_X[step_i];
            end else begin
                current_tile_y = 0;
                current_tile_x = 0;
            end
            total_outer_tiles = N_TILES_OUTER_Y[step_i] * N_TILES_OUTER_X[step_i];

            // Pointer calculations now use the derived X and Y values
            input_ptr = BASE_PTR_INPUT[step_i] + (current_tile_y * N_TILES_INNER_DIM[step_i] + tile_inner_cnt) * N_ELEMENTS_PER_TILE;
            output_ptr = BASE_PTR_OUTPUT[step_i] + (outer_tile_cnt) * N_ELEMENTS_PER_TILE;
            if (step_i == V) bias_ptr = BASE_PTR_BIAS[step_i] + current_tile_y * M_TILE_LEN * 3;
            else             bias_ptr = BASE_PTR_BIAS[step_i] + current_tile_x * M_TILE_LEN * 3;
            
            // The absolute tile index now depends on the flattened outer counter
            current_tile = outer_tile_cnt * N_TILES_INNER_DIM[step_i] + tile_inner_cnt;
            
            // REVISED: Simpler termination condition check
            is_last_tile_in_step = (outer_tile_cnt == total_outer_tiles - 1) &&
                                   (tile_inner_cnt == N_TILES_INNER_DIM[step_i] - 1);
            
            // ... (The rest of the pointer/control value logic is largely the same, using current_tile_x/y where needed) ...
            weight_ptr0 = BASE_PTR_WEIGHT0[step_i] + (current_tile % (N_TILES_OUTER_X[step_i] * N_TILES_INNER_DIM[step_i])) * N_ELEMENTS_PER_TILE;
            if (is_last_tile_in_step) begin
                weight_ptr1 = BASE_PTR_WEIGHT1[step_i];
                if (step_i == AV) weight_ptr1 = BASE_PTR_WEIGHT0[QK];
            end else begin
                int unsigned next_tile_idx = (current_tile + 1) % (N_TILES_OUTER_X[step_i] * N_TILES_INNER_DIM[step_i]);
                weight_ptr1 = BASE_PTR_WEIGHT0[step_i] + next_tile_idx * N_ELEMENTS_PER_TILE;
            end

            // Control value logic (unchanged, as it depends on absolute tile index)
            is_last = 1'b0;
            ctrl_stream_val = 32'h0;
            weight_ptr_en = 1'b0;
            bias_ptr_en = 1'b0;
            if (SINGLE_ATTENTION == 1) layer_type = Linear;
            else                       layer_type = Attention;
            activation_function = Identity;
            ctrl_engine_val = layer_type | (activation_function << 2);
            ita_reg_en = (SINGLE_ATTENTION == 1) ? 1'b1 : (ita_reg_cnt < N_CONTEXT);
            case (step_i)
                Q:      begin ctrl_stream_val = (current_tile == 0) ? 32'h3 : 32'h2; weight_ptr_en = 1'b1; bias_ptr_en = 1'b1; end
                K:      begin ctrl_stream_val = 32'h2; weight_ptr_en = 1'b1; bias_ptr_en = 1'b1; end
                V:      begin ctrl_stream_val = 32'hA; weight_ptr_en = 1'b1; bias_ptr_en = 1'b1; end
                QK, AV: begin if (SINGLE_ATTENTION == 1) ctrl_engine_val = SingleAttention | (Identity << 2); ctrl_stream_val = 32'h6; weight_ptr_en = 1'b1; bias_ptr_en = 1'b0; end
                OW:     begin is_last = is_last_tile_in_step; ctrl_stream_val = is_last ? 32'h0 : 32'h2; weight_ptr_en = !is_last; bias_ptr_en = 1'b1; end
                F1:     begin if (SINGLE_ATTENTION == 1) ctrl_engine_val = Linear | (ACTIVATION << 2); else ctrl_engine_val = Feedforward | (ACTIVATION << 2); ctrl_stream_val = (current_tile == 0) ? 32'h3 : 32'h2; weight_ptr_en = 1'b1; bias_ptr_en = 1'b1; end
                F2:     begin if (SINGLE_ATTENTION == 1) ctrl_engine_val = Linear | (Identity << 2); else ctrl_engine_val = Feedforward | (Identity << 2); is_last = is_last_tile_in_step; ctrl_stream_val = is_last ? 32'h0 : 32'h2; weight_ptr_en = !is_last; bias_ptr_en = 1'b1; end
                default: ;
            endcase
            ctrl_stream_val[4] = ((tile_inner_cnt + 1) % N_TILES_INNER_DIM[step_i] == 0) ? 1'b0 : 1'b1;
            tiles_reg_val = N_TILES_SEQUENCE_DIM | N_TILES_EMBEDDING_DIM << 4 | N_TILES_PROJECTION_DIM << 8 | N_TILES_FEEDFORWARD_DIM << 12;
        end

        // --- FSM State Logic ---
        case (current_state)
            S_IDLE: begin
                if (start_i) begin
                    next_state = S_CHECK_BUSY;
                    outer_tile_cnt_next = '0; // REVISED
                    tile_inner_cnt_next = '0;
                    reg_prog_cnt_next = '0;
                    is_first_tile_ever_r_next = 1'b1;
                    if (step_i == F1) ita_reg_cnt_next = '0;
                end
            end

            S_CHECK_BUSY: begin
                if (!hwpe_busy_i || is_first_tile_ever_r) begin
                    // Instead of going straight to programming, go to the delay state
                    next_state = S_INTER_TILE_DELAY;
                    delay_cnt_next = '0;
                end
            end
        
            S_INTER_TILE_DELAY: begin
                // The first tile (is_first_tile_ever_r) skips the delay entirely
                if (delay_cnt == INTER_TILE_DELAY_CYCLES - 1 || is_first_tile_ever_r) begin
                    next_state = S_PROG_REQ;
                    reg_prog_cnt_next = '0; 
                end else begin
                    delay_cnt_next = delay_cnt + 1;
                end
            end 

            // REVISED: Implemented a robust 3-state peripheral write handshake
            S_PROG_REQ: begin
                do_write = 1'b1;
                // REVISED: case statement is re-indexed starting from 0, soft-clear (0x14) is removed.
                case (reg_prog_cnt)
                    0:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_INPUT_PTR;   periph_data_o=input_ptr;   end
                    1:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_WEIGHT_PTR0; periph_data_o=weight_ptr0; end
                    2:  if (weight_ptr_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_WEIGHT_PTR1; periph_data_o=weight_ptr1; end else do_write=1'b0;
                    3:  if (bias_ptr_en)   begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_BIAS_PTR;    periph_data_o=bias_ptr;    end else do_write=1'b0;
                    4:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_OUTPUT_PTR;  periph_data_o=output_ptr;  end
                    5:  if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_TILES; periph_data_o = tiles_reg_val; end else do_write=1'b0;
                    6:  if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_EPS_MULT0; periph_data_o=rqs_eps_mult0_i; end else do_write=1'b0;
                    7:  if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_EPS_MULT1; periph_data_o=rqs_eps_mult1_i; end else do_write=1'b0;
                    8:  if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_RIGHT_SHIFT0; periph_data_o=rqs_rshift0_i; end else do_write=1'b0;
                    9:  if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_RIGHT_SHIFT1; periph_data_o=rqs_rshift1_i; end else do_write=1'b0;
                    10: if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_ADD0; periph_data_o=rqs_add0_i; end else do_write=1'b0;
                    11: if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_ADD1; periph_data_o=rqs_add1_i; end else do_write=1'b0;
                    12: if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_GELU_B_C; periph_data_o=activation_gelu_const_i; end else do_write=1'b0;
                    13: if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_ACTIVATION_REQUANT; periph_data_o=activation_rqs_const_i; end else do_write=1'b0;
                    14: begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_CTRL_ENGINE; periph_data_o=ctrl_engine_val; end
                    15: begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_CTRL_STREAM; periph_data_o=ctrl_stream_val; end
                    default: do_write = 1'b0; // Should not happen
                endcase

                if (do_write) begin
                    periph_req_o = 1'b1;
                    periph_wen_o = 1'b0; // This is a write
                    next_state = S_PROG_WAIT_GNT;
                end else begin
                    // Skip this write, move to the next register immediately
                    reg_prog_cnt_next = reg_prog_cnt + 1;
                    if (reg_prog_cnt == PROGRAM_STEPS - 1) begin
                        next_state = S_TRIGGER_REQ; // All programming (including skips) is done
                    end
                end
            end

            S_PROG_WAIT_GNT: begin
                // Hold the request and configuration until granted
                periph_req_o  = 1'b1;
                periph_wen_o  = 1'b0;
                // Re-calculate address and data to avoid latches
                case (reg_prog_cnt)
                    0:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_INPUT_PTR;   periph_data_o=input_ptr;   end
                    1:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_WEIGHT_PTR0; periph_data_o=weight_ptr0; end
                    2:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_WEIGHT_PTR1; periph_data_o=weight_ptr1; end
                    3:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_BIAS_PTR;    periph_data_o=bias_ptr;    end
                    4:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_OUTPUT_PTR;  periph_data_o=output_ptr;  end
                    5:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_TILES; periph_data_o = tiles_reg_val; end
                    6:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_EPS_MULT0; periph_data_o=rqs_eps_mult0_i; end
                    7:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_EPS_MULT1; periph_data_o=rqs_eps_mult1_i; end
                    8:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_RIGHT_SHIFT0; periph_data_o=rqs_rshift0_i; end
                    9:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_RIGHT_SHIFT1; periph_data_o=rqs_rshift1_i; end
                    10: begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_ADD0; periph_data_o=rqs_add0_i; end
                    11: begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_ADD1; periph_data_o=rqs_add1_i; end
                    12: begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_GELU_B_C; periph_data_o=activation_gelu_const_i; end
                    13: begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_ACTIVATION_REQUANT; periph_data_o=activation_rqs_const_i; end
                    14: begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_CTRL_ENGINE; periph_data_o=ctrl_engine_val; end
                    15: begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_CTRL_STREAM; periph_data_o=ctrl_stream_val; end
                endcase
                if (periph_gnt_i) begin
                    next_state = S_PROG_ACK;
                end
            end

            S_PROG_ACK: begin
                periph_req_o = 1'b0; // De-assert request
                reg_prog_cnt_next = reg_prog_cnt + 1;
                if (reg_prog_cnt == PROGRAM_STEPS - 1) begin
                    next_state = S_TRIGGER_REQ; // Last write is done, go to trigger
                end else begin
                    next_state = S_PROG_REQ; // Go to next programming step
                end
            end

            // 3-state handshake for the trigger write
            S_TRIGGER_REQ: begin
                periph_req_o  = 1'b1;
                periph_wen_o  = 1'b0;
                periph_add_o  = 32'h00;
                periph_data_o = 32'h00;
                next_state = S_TRIGGER_WAIT_GNT;
            end

            S_TRIGGER_WAIT_GNT: begin
                periph_req_o  = 1'b1;
                periph_wen_o  = 1'b0;
                periph_add_o  = 32'h00;
                periph_data_o = 32'h00;
                if (periph_gnt_i) begin
                    next_state = S_TRIGGER_ACK;
                end
            end

            S_TRIGGER_ACK: begin
                periph_req_o = 1'b0;
                is_first_tile_ever_r_next = 1'b0; // The first trigger has been sent
                if (is_last_tile_in_step) begin
                    next_state = S_FINISH_STEP;
                end else begin
                    next_state = S_UPDATE_TILE_COUNTERS;
                end
            end

            S_UPDATE_TILE_COUNTERS: begin
                next_state = S_CHECK_BUSY;
                if (ita_reg_en) ita_reg_cnt_next = ita_reg_cnt + 1;

                // REVISED: Simplified counter update logic
                if (tile_inner_cnt == N_TILES_INNER_DIM[step_i] - 1) begin
                    tile_inner_cnt_next = 0;
                    outer_tile_cnt_next = outer_tile_cnt + 1; // Innermost loop wraps, increment outer loop
                end else begin
                    tile_inner_cnt_next = tile_inner_cnt + 1; // Innermost loop increments
                end
            end

            S_FINISH_STEP: begin
                done_o = 1'b1;
                next_state = S_IDLE;
            end
            default: ;
        endcase
    end
endmodule
