// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Gemini AI, based on user-provided testbench

`include "hci_helpers.svh"

import ita_package::*;
import ita_hwpe_package::*;

/*
 * =================================================================================
 * == ITA Sequencer Module (Complete 1-to-1 Implementation)                     ==
 * =================================================================================
 *
 * This module is a low-level FSM that acts as a hardware replacement for the
 * testbench's procedural tasks. It receives a command to execute a specific
 * computation step and then performs the multi-cycle sequence of programming
 * the HWPE's registers and triggering its execution, exactly replicating the
 * testbench's control flow.
 *
 */
module ita_sequencer #(
    // Parameters defining the problem size, identical to the testbench
    parameter int M_TILE_LEN = 64,
    parameter int SEQUENCE_LEN = 64,
    parameter int PROJECTION_SPACE = 64,
    parameter int EMBEDDING_SIZE = 64,
    parameter int FEEDFORWARD_SIZE = 64,
    parameter activation_e ACTIVATION = Identity,
    parameter int SINGLE_ATTENTION = 0,
    parameter int N_CONTEXT = 8, // From ita_hwpe_package
    parameter int ID = 0 // Core ID for peripheral transactions
) (
    input  logic clk_i,
    input  logic rst_ni,

    // --- Control Interface from Main FSM ---
    input  logic      start_i,        // Pulse to begin sequencing for the given step
    input  step_e     step_i,         // Which step to execute (Q, K, V, etc.)
    output logic      done_o,         // Asserted for one cycle when the step is fully complete

    // --- HWPE Status Input ---
    input  logic      hwpe_busy_i,    // The 'busy' signal from the HWPE

    // --- Peripheral Bus Master Interface (to program the HWPE) ---
    output logic                   periph_req_o,
    input  logic                   periph_gnt_i,
    output logic [31:0]            periph_add_o,
    output logic                   periph_wen_o,
    output logic [3:0]             periph_be_o,
    output logic [31:0]            periph_data_o,

    // --- Pre-calculated Parameters from Top Wrapper ---
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

    // --- Requantization (RQS) Constant Inputs ---
    input  logic [31:0] rqs_eps_mult0_i,
    input  logic [31:0] rqs_eps_mult1_i,
    input  logic [31:0] rqs_rshift0_i,
    input  logic [31:0] rqs_rshift1_i,
    input  logic [31:0] rqs_add0_i,
    input  logic [31:0] rqs_add1_i,

    // --- Activation Constant Inputs ---
    input  logic [31:0] activation_gelu_const_i,
    input  logic [31:0] activation_rqs_const_i
);

    localparam unsigned ITA_REG_OFFSET = 32'h20;
    localparam int N_ELEMENTS_PER_TILE = M_TILE_LEN * M_TILE_LEN;
    localparam int PROGRAM_STEPS = 16;

    // FSM to control the sequencing of register writes and triggers
    typedef enum logic [3:0] {
        S_IDLE,
        S_CHECK_BUSY,
        S_POST_BUSY_DELAY,
        S_CALC,
        S_PROG_REG,
        S_WAIT_GNT,
        S_POST_PROGRAM_DELAY,
        S_TRIGGER,
        S_CHECK_DONE,
        S_FINISH_STEP
    } seq_state_t;

    // Current-state registers
    seq_state_t           current_state;
    logic [7:0]           tile_y_cnt, tile_x_cnt, tile_inner_cnt;
    logic [4:0]           reg_prog_cnt; // Needs to count up to PROGRAM_STEPS
    logic [4:0]           reg_prog_cnt;
    logic [N_CONTEXT-1:0] ita_reg_cnt;
    logic                 is_first_tile_ever_r;
    logic [2:0]           delay_cnt;

    // Next-state logic variables
    seq_state_t           next_state;
    logic [7:0]           tile_y_cnt_next, tile_x_cnt_next, tile_inner_cnt_next;
    logic [4:0]           reg_prog_cnt_next;
    logic [N_CONTEXT-1:0] ita_reg_cnt_next;
    logic                 is_first_tile_ever_r_next;
    logic [2:0]           delay_cnt_next;



    // --- Combinational Logic for Pointer and Control Value Calculation ---
    logic [31:0] input_ptr, weight_ptr0, weight_ptr1, bias_ptr, output_ptr;
    logic [31:0] ctrl_engine_val, ctrl_stream_val;
    logic        weight_ptr_en, bias_ptr_en, ita_reg_en;
    logic [31:0] ita_reg_tiles_val;
    logic [5:0][31:0] ita_reg_rqs_val = '0;
    logic [31:0]      ita_reg_gelu_b_c_val = '0;
    logic [31:0]      ita_reg_activation_rqs_val = '0;

    logic is_last_tile_in_step;
    logic is_last;
    int unsigned current_tile;
    int unsigned output_tile;
    int unsigned next_tile_idx;
    layer_e layer_type;
    activation_e activation_function;
    int unsigned current_tile_idx;

    // Replicate `ita_ptrs_compute`
    always_comb begin
        input_ptr = BASE_PTR_INPUT[step_i] + (tile_y_cnt * N_TILES_INNER_DIM[step_i] + tile_inner_cnt) * N_ELEMENTS_PER_TILE;
        output_ptr = BASE_PTR_OUTPUT[step_i] + (tile_y_cnt * N_TILES_OUTER_X[step_i] + tile_x_cnt) * N_ELEMENTS_PER_TILE;

        if (step_i == V) begin
            bias_ptr = BASE_PTR_BIAS[step_i] + tile_y_cnt * M_TILE_LEN * 3;
        end else begin
            bias_ptr = BASE_PTR_BIAS[step_i] + tile_x_cnt * M_TILE_LEN * 3;
        end

        output_tile = tile_y_cnt * N_TILES_OUTER_X[step_i] + tile_x_cnt;
        current_tile = output_tile * N_TILES_INNER_DIM[step_i] + tile_inner_cnt;

        weight_ptr0 = BASE_PTR_WEIGHT0[step_i] + (current_tile % (N_TILES_OUTER_X[step_i] * N_TILES_INNER_DIM[step_i])) * N_ELEMENTS_PER_TILE;

        is_last_tile_in_step = (tile_y_cnt == N_TILES_OUTER_Y[step_i] - 1) &&
                               (tile_x_cnt == N_TILES_OUTER_X[step_i] - 1) &&
                               (tile_inner_cnt == N_TILES_INNER_DIM[step_i] - 1);

        if (is_last_tile_in_step) begin
            weight_ptr1 = BASE_PTR_WEIGHT1[step_i];
            if (step_i == AV) begin
                weight_ptr1 = BASE_PTR_WEIGHT0[QK];
            end
        end else begin
            next_tile_idx = (current_tile + 1) % (N_TILES_OUTER_X[step_i] * N_TILES_INNER_DIM[step_i]);
            weight_ptr1 = BASE_PTR_WEIGHT0[step_i] + next_tile_idx * N_ELEMENTS_PER_TILE;
        end
    end

    // Replicate `ctrl_val_compute`
    always_comb begin
        ctrl_stream_val = 32'h0;
        weight_ptr_en = 1'b0;
        bias_ptr_en = 1'b0;

        if (SINGLE_ATTENTION == 1) layer_type = Linear;
        else                       layer_type = Attention;

        activation_function = Identity;
        ctrl_engine_val = layer_type | (activation_function << 2);

        current_tile_idx = (tile_y_cnt * N_TILES_OUTER_X[step_i] + tile_x_cnt) * N_TILES_INNER_DIM[step_i] + tile_inner_cnt;

        case (step_i)
            Q: begin
                ctrl_stream_val = (current_tile_idx == 0) ? 32'h3 : 32'h2;
                weight_ptr_en = 1'b1; bias_ptr_en = 1'b1;
            end
            K: begin
                ctrl_stream_val = 32'h2;
                weight_ptr_en = 1'b1; bias_ptr_en = 1'b1;
            end
            V: begin
                ctrl_stream_val = 32'hA;
                weight_ptr_en = 1'b1; bias_ptr_en = 1'b1;
            end
            QK, AV: begin
                if (SINGLE_ATTENTION == 1) ctrl_engine_val = SingleAttention | (Identity << 2);
                ctrl_stream_val = 32'h6;
                weight_ptr_en = 1'b1; bias_ptr_en = 1'b0;
            end
            OW: begin
                is_last = (current_tile_idx == (N_TILES_OUTER_X[OW]*N_TILES_OUTER_Y[OW]*N_TILES_INNER_DIM[OW])-1);
                ctrl_stream_val = is_last ? 32'h0 : 32'h2;
                weight_ptr_en = !is_last; bias_ptr_en = 1'b1;
            end
            F1: begin
                if (SINGLE_ATTENTION == 1) ctrl_engine_val = Linear | (ACTIVATION << 2);
                else                       ctrl_engine_val = Feedforward | (ACTIVATION << 2);
                ctrl_stream_val = (current_tile_idx == 0) ? 32'h3 : 32'h2;
                weight_ptr_en = 1'b1; bias_ptr_en = 1'b1;
            end
            F2: begin
                if (SINGLE_ATTENTION == 1) ctrl_engine_val = Linear | (Identity << 2);
                else                       ctrl_engine_val = Feedforward | (Identity << 2);
                is_last = (current_tile_idx == (N_TILES_OUTER_X[F2]*N_TILES_OUTER_Y[F2]*N_TILES_INNER_DIM[F2])-1);
                ctrl_stream_val = is_last ? 32'h0 : 32'h2;
                weight_ptr_en = !is_last; bias_ptr_en = 1'b1;
            end
            default: ;
        endcase
        ctrl_stream_val[4] = ((current_tile + 1) % N_TILES_INNER_DIM[step_i] == 0) ? 1'b0 : 1'b1;
    end

    assign ita_reg_en = (SINGLE_ATTENTION == 1) ? 1'b1 : (ita_reg_cnt < N_CONTEXT);

    // --- FSM Sequential Logic ---
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            current_state        <= S_IDLE;
            tile_y_cnt           <= '0;
            tile_x_cnt           <= '0;
            tile_inner_cnt       <= '0;
            reg_prog_cnt         <= '0;
            is_first_tile_ever_r <= 1'b1;
            ita_reg_cnt          <= '0;
            delay_cnt            <= '0;
        end else begin
            current_state        <= next_state;
            tile_y_cnt           <= tile_y_cnt_next;
            tile_x_cnt           <= tile_x_cnt_next;
            tile_inner_cnt       <= tile_inner_cnt_next;
            reg_prog_cnt         <= reg_prog_cnt_next;
            is_first_tile_ever_r <= is_first_tile_ever_r_next;
            ita_reg_cnt          <= ita_reg_cnt_next;
            delay_cnt            <= delay_cnt_next;
        end
    end

    // --- FSM Combinational Logic ---
    always_comb begin
        // Default assignments
        next_state = current_state;
        tile_y_cnt_next = tile_y_cnt;
        tile_x_cnt_next = tile_x_cnt;
        tile_inner_cnt_next = tile_inner_cnt;
        reg_prog_cnt_next = reg_prog_cnt;
        is_first_tile_ever_r_next = is_first_tile_ever_r;
        ita_reg_cnt_next = ita_reg_cnt;
        delay_cnt_next = delay_cnt;

        done_o = 1'b0;
        periph_req_o = 1'b0;
        periph_add_o = '0;
        periph_wen_o = 1'b1; // Default to read
        periph_be_o = '0;
        periph_data_o = '0;

        case (current_state)
            S_IDLE: begin
                if (start_i) begin
                    next_state = S_CHECK_BUSY;
                    tile_y_cnt_next = '0;
                    tile_x_cnt_next = '0;
                    tile_inner_cnt_next = '0;
                    reg_prog_cnt_next = '0;
                    is_first_tile_ever_r_next = (step_i == Q);
                    if (step_i == F1) ita_reg_cnt_next = '0;
                end
            end

            S_CHECK_BUSY: begin
                if (!hwpe_busy_i || is_first_tile_ever_r) begin
                    next_state = S_POST_BUSY_DELAY;
                    delay_cnt_next = 3'b0;
                end
            end

            S_POST_BUSY_DELAY: begin
                if (is_first_tile_ever_r) begin
                    next_state = S_CALC;
                end else if (delay_cnt == 4) begin
                    next_state = S_CALC;
                end else begin
                    delay_cnt_next = delay_cnt + 1;
                end
            end

            S_CALC: begin
                next_state = S_PROG_REG;
            end

            S_PROG_REG: begin
                periph_req_o = 1'b1;
                periph_wen_o = 1'b0;
                periph_be_o  = 4'hF;

                case (reg_prog_cnt)
                    // Pointers
                    0:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_INPUT_PTR;   periph_data_o=input_ptr;   end
                    1:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_WEIGHT_PTR0; periph_data_o=weight_ptr0; end
                    2:  if (weight_ptr_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_WEIGHT_PTR1; periph_data_o=weight_ptr1; end else periph_req_o=1'b0;
                    3:  if (bias_ptr_en)   begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_BIAS_PTR;    periph_data_o=bias_ptr;    end else periph_req_o=1'b0;
                    4:  begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_OUTPUT_PTR;  periph_data_o=output_ptr;  end
                    // Tile Dims and other regs
                    // NOTE: The register map values (e.g., ITA_REG_TILES=6) are now taken from your package file
                    5:  if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_TILES; periph_data_o = N_TILES_SEQUENCE_DIM | N_TILES_EMBEDDING_DIM << 4 | N_TILES_PROJECTION_DIM << 8 | N_TILES_FEEDFORWARD_DIM << 12; end else periph_req_o=1'b0;
                    6:  if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_EPS_MULT0; periph_data_o=rqs_eps_mult0_i; end else periph_req_o=1'b0;
                    7:  if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_EPS_MULT1; periph_data_o=rqs_eps_mult1_i; end else periph_req_o=1'b0;
                    // 8: Case for EPS_MULT2 REMOVED
                    8:  if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_RIGHT_SHIFT0; periph_data_o=rqs_rshift0_i; end else periph_req_o=1'b0;
                    9:  if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_RIGHT_SHIFT1; periph_data_o=rqs_rshift1_i; end else periph_req_o=1'b0;
                    // 11: Case for RIGHT_SHIFT2 REMOVED
                    10: if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_ADD0; periph_data_o=rqs_add0_i; end else periph_req_o=1'b0;
                    11: if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_ADD1; periph_data_o=rqs_add1_i; end else periph_req_o=1'b0;
                    // 14, 15, 16: Cases for ADD2, ADD3, ADD4 REMOVED
                    12: if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_GELU_B_C; periph_data_o=activation_gelu_const_i; end else periph_req_o=1'b0;
                    13: if (ita_reg_en) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_ACTIVATION_REQUANT; periph_data_o=activation_rqs_const_i; end else periph_req_o=1'b0;
                    // Control Registers
                    14: begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_CTRL_ENGINE; periph_data_o=ctrl_engine_val; end
                    15: begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_CTRL_STREAM; periph_data_o=ctrl_stream_val; end
                    default: periph_req_o = 1'b0;
                endcase

                if (periph_gnt_i || !periph_req_o) begin
                    if (reg_prog_cnt == PROGRAM_STEPS - 1) begin
                        next_state = S_POST_PROGRAM_DELAY;
                    end else begin
                        next_state = S_WAIT_GNT;
                    end
                end
            end

            S_WAIT_GNT: begin
                next_state = S_PROG_REG;
                reg_prog_cnt_next = reg_prog_cnt + 1;
            end

            S_POST_PROGRAM_DELAY: begin
                next_state = S_TRIGGER;
            end

            S_TRIGGER: begin
                periph_req_o = 1'b1;
                periph_wen_o = 1'b0;
                periph_be_o  = 4'hF;
                periph_add_o = 32'h00;
                periph_data_o= 32'h00;
                if (periph_gnt_i) begin
                    next_state = S_CHECK_DONE;
                    is_first_tile_ever_r_next = 1'b0;
                end
            end

            S_CHECK_DONE: begin
                if (is_last_tile_in_step) begin
                    if (!hwpe_busy_i) begin
                        next_state = S_FINISH_STEP;
                    end
                end else begin
                    next_state = S_CHECK_BUSY;
                    reg_prog_cnt_next = '0;
                    if (ita_reg_en) ita_reg_cnt_next = ita_reg_cnt + 1;
                    if (tile_inner_cnt == N_TILES_INNER_DIM[step_i] - 1) begin
                        tile_inner_cnt_next = '0;
                        if (tile_x_cnt == N_TILES_OUTER_X[step_i] - 1) begin
                            tile_x_cnt_next = '0;
                            tile_y_cnt_next = tile_y_cnt + 1;
                        end else begin
                            tile_x_cnt_next = tile_x_cnt + 1;
                        end
                    end else begin
                        tile_inner_cnt_next = tile_inner_cnt + 1;
                    end
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