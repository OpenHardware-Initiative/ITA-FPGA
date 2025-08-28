// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Gemini AI, based on user-provided testbench
// Version: 8.1 (Fully Expanded Hardcoded Sequencer for Debugging Step Q)
//
// PURPOSE:
// This is a special-purpose, temporary module for debugging Step Q ONLY.
// It replaces all dynamic pointer and control calculations with a pre-computed,
// hardcoded sequence of peripheral writes. This is used to verify that the FSM's
// timing and the HWPE core's response are correct, by eliminating the
// dynamic calculations as a potential source of error.
//
// THIS MODULE IS NOT SCALABLE, PARAMETRIC, OR SUITABLE FOR SYNTHESIS IN A FINAL DESIGN.

`include "hci_helpers.svh"

import ita_package::*;
import ita_hwpe_package::*;

module ita_sequencer_hardcoded_q_step #(
    parameter int INTER_TILE_DELAY_CYCLES = 5
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic start_i,
    // step_i is ignored, this module only does Step Q
    input  step_e     step_i,
    output logic      done_o,
    input  logic      hwpe_busy_i,
    output logic                   periph_req_o,
    input  logic                   periph_gnt_i,
    output logic [31:0]            periph_add_o,
    output logic                   periph_wen_o,
    output logic [3:0]             periph_be_o,
    output logic [31:0]            periph_data_o,
    // Constants are still needed for the hardcoded values
    input  logic [31:0] rqs_eps_mult0_i,
    input  logic [31:0] rqs_eps_mult1_i,
    input  logic [31:0] rqs_rshift0_i,
    input  logic [31:0] rqs_rshift1_i,
    input  logic [31:0] rqs_add0_i,
    input  logic [31:0] rqs_add1_i,
    input  logic [31:0] activation_gelu_const_i,
    input  logic [31:0] activation_rqs_const_i
);

    logic is_start_of_new_tile; 
    logic [31:0] tiles_reg_val;
    

    // Each of the 6 tiles has 16 programming writes and 1 trigger write
    localparam int WRITES_PER_TILE = 17;
    localparam int TOTAL_WRITES = 6 * WRITES_PER_TILE; // 102 total writes

    typedef enum logic [3:0] {
        S_IDLE,
        S_CHECK_BUSY,
        S_INTER_TILE_DELAY,
        S_WRITE_REQ,
        S_WRITE_WAIT_GNT,
        S_WRITE_ACK,
        S_FINISH_STEP
    } seq_state_t;

    seq_state_t  current_state, next_state;
    logic [7:0]  write_step_cnt, write_step_cnt_next; // Counter for all 102 writes
    logic [$clog2(INTER_TILE_DELAY_CYCLES):0] delay_cnt, delay_cnt_next;

    // FSM state registers
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            current_state  <= S_IDLE;
            write_step_cnt <= '0;
            delay_cnt      <= '0;
        end else begin
            current_state  <= next_state;
            write_step_cnt <= write_step_cnt_next;
            delay_cnt      <= delay_cnt_next;
        end
    end

    // Combinational logic for FSM and outputs
    always_comb begin

        
        next_state          = current_state;
        write_step_cnt_next = write_step_cnt;
        delay_cnt_next      = delay_cnt;
        done_o              = 1'b0;
        periph_req_o        = 1'b0;
        periph_add_o        = '0;
        periph_wen_o        = 1'b1; // Default to read
        periph_be_o         = 4'hF;
        periph_data_o       = '0;
        
        // This logic determines if we are at the start of a new tile's programming sequence.
        // This occurs after the trigger write of the previous tile.
        is_start_of_new_tile = (write_step_cnt != 0) && (write_step_cnt % WRITES_PER_TILE == 0);
        
        // A single, constant value for the ITA_REG_TILES register
        tiles_reg_val = 32'h00004321; // F=4, P=3, E=2, S=1

        case (current_state)
            S_IDLE: begin
                if (start_i) begin
                    // The first tile does not wait for busy
                    next_state = S_WRITE_REQ;
                end
            end

            S_CHECK_BUSY: begin
                if (!hwpe_busy_i) begin
                    next_state = S_INTER_TILE_DELAY;
                    delay_cnt_next = '0;
                end
            end

            S_INTER_TILE_DELAY: begin
                if (delay_cnt == INTER_TILE_DELAY_CYCLES - 1) begin
                    next_state = S_WRITE_REQ;
                end else begin
                    delay_cnt_next = delay_cnt + 1;
                end
            end

            S_WRITE_REQ: begin
                periph_req_o = 1'b1;
                periph_wen_o = 1'b0; // All operations are writes
                next_state = S_WRITE_WAIT_GNT;
                
                // Giant hardcoded lookup for address and data
                case (write_step_cnt)
                    // --- TILE 0 (y=0, x=0, i=0) ---
                    0:   begin periph_add_o = 32'h20; periph_data_o = 32'h00000; end // INPUT_PTR
                    1:   begin periph_add_o = 32'h24; periph_data_o = 32'h08000; end // WEIGHT_PTR0
                    2:   begin periph_add_o = 32'h28; periph_data_o = 32'h09000; end // WEIGHT_PTR1
                    3:   begin periph_add_o = 32'h2C; periph_data_o = 32'h2E000; end // BIAS_PTR
                    4:   begin periph_add_o = 32'h30; periph_data_o = 32'h3C000; end // OUTPUT_PTR
                    5:   begin periph_add_o = 32'h34; periph_data_o = tiles_reg_val; end // TILES
                    6:   begin periph_add_o = 32'h38; periph_data_o = rqs_eps_mult0_i; end // EPS_MULT0
                    7:   begin periph_add_o = 32'h3C; periph_data_o = rqs_eps_mult1_i; end // EPS_MULT1
                    8:   begin periph_add_o = 32'h40; periph_data_o = rqs_rshift0_i; end // RIGHT_SHIFT0
                    9:   begin periph_add_o = 32'h44; periph_data_o = rqs_rshift1_i; end // RIGHT_SHIFT1
                    10:  begin periph_add_o = 32'h48; periph_data_o = rqs_add0_i; end // ADD0
                    11:  begin periph_add_o = 32'h4C; periph_data_o = rqs_add1_i; end // ADD1
                    12:  begin periph_add_o = 32'h50; periph_data_o = activation_gelu_const_i; end // GELU_B_C
                    13:  begin periph_add_o = 32'h54; periph_data_o = activation_rqs_const_i; end // ACTIVATION_REQUANT
                    14:  begin periph_add_o = 32'h60; periph_data_o = 32'h0; end // CTRL_ENGINE
                    15:  begin periph_add_o = 32'h64; periph_data_o = 32'h3; end // CTRL_STREAM
                    16:  begin periph_add_o = 32'h00; periph_data_o = 32'h0; end // TRIGGER
                    // --- TILE 1 (y=0, x=0, i=1) ---
                    17:  begin periph_add_o = 32'h20; periph_data_o = 32'h01000; end // INPUT_PTR
                    18:  begin periph_add_o = 32'h24; periph_data_o = 32'h09000; end // WEIGHT_PTR0
                    19:  begin periph_add_o = 32'h28; periph_data_o = 32'h0A000; end // WEIGHT_PTR1
                    20:  begin periph_add_o = 32'h2C; periph_data_o = 32'h2E000; end // BIAS_PTR
                    21:  begin periph_add_o = 32'h30; periph_data_o = 32'h3C000; end // OUTPUT_PTR
                    22:  begin periph_add_o = 32'h34; periph_data_o = tiles_reg_val; end // TILES
                    23:  begin periph_add_o = 32'h38; periph_data_o = rqs_eps_mult0_i; end // EPS_MULT0
                    24:  begin periph_add_o = 32'h3C; periph_data_o = rqs_eps_mult1_i; end // EPS_MULT1
                    25:  begin periph_add_o = 32'h40; periph_data_o = rqs_rshift0_i; end // RIGHT_SHIFT0
                    26:  begin periph_add_o = 32'h44; periph_data_o = rqs_rshift1_i; end // RIGHT_SHIFT1
                    27:  begin periph_add_o = 32'h48; periph_data_o = rqs_add0_i; end // ADD0
                    28:  begin periph_add_o = 32'h4C; periph_data_o = rqs_add1_i; end // ADD1
                    29:  begin periph_add_o = 32'h50; periph_data_o = activation_gelu_const_i; end // GELU_B_C
                    30:  begin periph_add_o = 32'h54; periph_data_o = activation_rqs_const_i; end // ACTIVATION_REQUANT
                    31:  begin periph_add_o = 32'h60; periph_data_o = 32'h0; end // CTRL_ENGINE
                    32:  begin periph_add_o = 32'h64; periph_data_o = 32'h12; end// CTRL_STREAM
                    33:  begin periph_add_o = 32'h00; periph_data_o = 32'h0; end // TRIGGER
                    // --- TILE 2 (y=0, x=1, i=0) ---
                    34:  begin periph_add_o = 32'h20; periph_data_o = 32'h00000; end // INPUT_PTR
                    35:  begin periph_add_o = 32'h24; periph_data_o = 32'h0A000; end // WEIGHT_PTR0
                    36:  begin periph_add_o = 32'h28; periph_data_o = 32'h0B000; end // WEIGHT_PTR1
                    37:  begin periph_add_o = 32'h2C; periph_data_o = 32'h2E0C0; end // BIAS_PTR
                    38:  begin periph_add_o = 32'h30; periph_data_o = 32'h3D000; end // OUTPUT_PTR
                    39:  begin periph_add_o = 32'h34; periph_data_o = tiles_reg_val; end // TILES
                    40:  begin periph_add_o = 32'h38; periph_data_o = rqs_eps_mult0_i; end // EPS_MULT0
                    41:  begin periph_add_o = 32'h3C; periph_data_o = rqs_eps_mult1_i; end // EPS_MULT1
                    42:  begin periph_add_o = 32'h40; periph_data_o = rqs_rshift0_i; end // RIGHT_SHIFT0
                    43:  begin periph_add_o = 32'h44; periph_data_o = rqs_rshift1_i; end // RIGHT_SHIFT1
                    44:  begin periph_add_o = 32'h48; periph_data_o = rqs_add0_i; end // ADD0
                    45:  begin periph_add_o = 32'h4C; periph_data_o = rqs_add1_i; end // ADD1
                    46:  begin periph_add_o = 32'h50; periph_data_o = activation_gelu_const_i; end // GELU_B_C
                    47:  begin periph_add_o = 32'h54; periph_data_o = activation_rqs_const_i; end // ACTIVATION_REQUANT
                    48:  begin periph_add_o = 32'h60; periph_data_o = 32'h0; end // CTRL_ENGINE
                    49:  begin periph_add_o = 32'h64; periph_data_o = 32'h2; end // CTRL_STREAM
                    50:  begin periph_add_o = 32'h00; periph_data_o = 32'h0; end // TRIGGER
                    // --- TILE 3 (y=0, x=1, i=1) ---
                    51:  begin periph_add_o = 32'h20; periph_data_o = 32'h01000; end // INPUT_PTR
                    52:  begin periph_add_o = 32'h24; periph_data_o = 32'h0B000; end // WEIGHT_PTR0
                    53:  begin periph_add_o = 32'h28; periph_data_o = 32'h0C000; end // WEIGHT_PTR1
                    54:  begin periph_add_o = 32'h2C; periph_data_o = 32'h2E0C0; end // BIAS_PTR
                    55:  begin periph_add_o = 32'h30; periph_data_o = 32'h3D000; end // OUTPUT_PTR
                    56:  begin periph_add_o = 32'h34; periph_data_o = tiles_reg_val; end // TILES
                    57:  begin periph_add_o = 32'h38; periph_data_o = rqs_eps_mult0_i; end // EPS_MULT0
                    58:  begin periph_add_o = 32'h3C; periph_data_o = rqs_eps_mult1_i; end // EPS_MULT1
                    59:  begin periph_add_o = 32'h40; periph_data_o = rqs_rshift0_i; end // RIGHT_SHIFT0
                    60:  begin periph_add_o = 32'h44; periph_data_o = rqs_rshift1_i; end // RIGHT_SHIFT1
                    61:  begin periph_add_o = 32'h48; periph_data_o = rqs_add0_i; end // ADD0
                    62:  begin periph_add_o = 32'h4C; periph_data_o = rqs_add1_i; end // ADD1
                    63:  begin periph_add_o = 32'h50; periph_data_o = activation_gelu_const_i; end // GELU_B_C
                    64:  begin periph_add_o = 32'h54; periph_data_o = activation_rqs_const_i; end // ACTIVATION_REQUANT
                    65:  begin periph_add_o = 32'h60; periph_data_o = 32'h0; end // CTRL_ENGINE
                    66:  begin periph_add_o = 32'h64; periph_data_o = 32'h12; end// CTRL_STREAM
                    67:  begin periph_add_o = 32'h00; periph_data_o = 32'h0; end // TRIGGER
                    // --- TILE 4 (y=0, x=2, i=0) ---
                    68:  begin periph_add_o = 32'h20; periph_data_o = 32'h00000; end // INPUT_PTR
                    69:  begin periph_add_o = 32'h24; periph_data_o = 32'h0C000; end // WEIGHT_PTR0
                    70:  begin periph_add_o = 32'h28; periph_data_o = 32'h0D000; end // WEIGHT_PTR1
                    71:  begin periph_add_o = 32'h2C; periph_data_o = 32'h2E180; end // BIAS_PTR
                    72:  begin periph_add_o = 32'h30; periph_data_o = 32'h3E000; end // OUTPUT_PTR
                    73:  begin periph_add_o = 32'h34; periph_data_o = tiles_reg_val; end // TILES
                    74:  begin periph_add_o = 32'h38; periph_data_o = rqs_eps_mult0_i; end // EPS_MULT0
                    75:  begin periph_add_o = 32'h3C; periph_data_o = rqs_eps_mult1_i; end // EPS_MULT1
                    76:  begin periph_add_o = 32'h40; periph_data_o = rqs_rshift0_i; end // RIGHT_SHIFT0
                    77:  begin periph_add_o = 32'h44; periph_data_o = rqs_rshift1_i; end // RIGHT_SHIFT1
                    78:  begin periph_add_o = 32'h48; periph_data_o = rqs_add0_i; end // ADD0
                    79:  begin periph_add_o = 32'h4C; periph_data_o = rqs_add1_i; end // ADD1
                    80:  begin periph_add_o = 32'h50; periph_data_o = activation_gelu_const_i; end // GELU_B_C
                    81:  begin periph_add_o = 32'h54; periph_data_o = activation_rqs_const_i; end // ACTIVATION_REQUANT
                    82:  begin periph_add_o = 32'h60; periph_data_o = 32'h0; end // CTRL_ENGINE
                    83:  begin periph_add_o = 32'h64; periph_data_o = 32'h2; end // CTRL_STREAM
                    84:  begin periph_add_o = 32'h00; periph_data_o = 32'h0; end // TRIGGER
                    // --- TILE 5 (y=0, x=2, i=1) ---
                    85:  begin periph_add_o = 32'h20; periph_data_o = 32'h01000; end // INPUT_PTR
                    86:  begin periph_add_o = 32'h24; periph_data_o = 32'h0D000; end // WEIGHT_PTR0
                    87:  begin periph_add_o = 32'h28; periph_data_o = 32'h0E000; end // WEIGHT_PTR1
                    88:  begin periph_add_o = 32'h2C; periph_data_o = 32'h2E180; end // BIAS_PTR
                    89:  begin periph_add_o = 32'h30; periph_data_o = 32'h3E000; end // OUTPUT_PTR
                    90:  begin periph_add_o = 32'h34; periph_data_o = tiles_reg_val; end // TILES
                    91:  begin periph_add_o = 32'h38; periph_data_o = rqs_eps_mult0_i; end // EPS_MULT0
                    92:  begin periph_add_o = 32'h3C; periph_data_o = rqs_eps_mult1_i; end // EPS_MULT1
                    93:  begin periph_add_o = 32'h40; periph_data_o = rqs_rshift0_i; end // RIGHT_SHIFT0
                    94:  begin periph_add_o = 32'h44; periph_data_o = rqs_rshift1_i; end // RIGHT_SHIFT1
                    95:  begin periph_add_o = 32'h48; periph_data_o = rqs_add0_i; end // ADD0
                    96:  begin periph_add_o = 32'h4C; periph_data_o = rqs_add1_i; end // ADD1
                    97:  begin periph_add_o = 32'h50; periph_data_o = activation_gelu_const_i; end // GELU_B_C
                    98:  begin periph_add_o = 32'h54; periph_data_o = activation_rqs_const_i; end // ACTIVATION_REQUANT
                    99:  begin periph_add_o = 32'h60; periph_data_o = 32'h0; end // CTRL_ENGINE
                    100: begin periph_add_o = 32'h64; periph_data_o = 32'h12; end// CTRL_STREAM
                    101: begin periph_add_o = 32'h00; periph_data_o = 32'h0; end // TRIGGER
                endcase
            end

            S_WRITE_WAIT_GNT: begin
                periph_req_o = 1'b1;
                periph_wen_o = 1'b0;
                // Re-drive address and data to prevent latches. This must be identical to the case statement above.
                case (write_step_cnt)
                    // --- TILE 0 (y=0, x=0, i=0) ---
                    0:   begin periph_add_o = 32'h20; periph_data_o = 32'h00000; end // INPUT_PTR
                    1:   begin periph_add_o = 32'h24; periph_data_o = 32'h08000; end // WEIGHT_PTR0
                    2:   begin periph_add_o = 32'h28; periph_data_o = 32'h09000; end // WEIGHT_PTR1
                    3:   begin periph_add_o = 32'h2C; periph_data_o = 32'h2E000; end // BIAS_PTR
                    4:   begin periph_add_o = 32'h30; periph_data_o = 32'h3C000; end // OUTPUT_PTR
                    5:   begin periph_add_o = 32'h34; periph_data_o = tiles_reg_val; end // TILES
                    6:   begin periph_add_o = 32'h38; periph_data_o = rqs_eps_mult0_i; end // EPS_MULT0
                    7:   begin periph_add_o = 32'h3C; periph_data_o = rqs_eps_mult1_i; end // EPS_MULT1
                    8:   begin periph_add_o = 32'h40; periph_data_o = rqs_rshift0_i; end // RIGHT_SHIFT0
                    9:   begin periph_add_o = 32'h44; periph_data_o = rqs_rshift1_i; end // RIGHT_SHIFT1
                    10:  begin periph_add_o = 32'h48; periph_data_o = rqs_add0_i; end // ADD0
                    11:  begin periph_add_o = 32'h4C; periph_data_o = rqs_add1_i; end // ADD1
                    12:  begin periph_add_o = 32'h50; periph_data_o = activation_gelu_const_i; end // GELU_B_C
                    13:  begin periph_add_o = 32'h54; periph_data_o = activation_rqs_const_i; end // ACTIVATION_REQUANT
                    14:  begin periph_add_o = 32'h60; periph_data_o = 32'h0; end // CTRL_ENGINE
                    15:  begin periph_add_o = 32'h64; periph_data_o = 32'h3; end // CTRL_STREAM
                    16:  begin periph_add_o = 32'h00; periph_data_o = 32'h0; end // TRIGGER
                    // --- TILE 1 (y=0, x=0, i=1) ---
                    17:  begin periph_add_o = 32'h20; periph_data_o = 32'h01000; end // INPUT_PTR
                    18:  begin periph_add_o = 32'h24; periph_data_o = 32'h09000; end // WEIGHT_PTR0
                    19:  begin periph_add_o = 32'h28; periph_data_o = 32'h0A000; end // WEIGHT_PTR1
                    20:  begin periph_add_o = 32'h2C; periph_data_o = 32'h2E000; end // BIAS_PTR
                    21:  begin periph_add_o = 32'h30; periph_data_o = 32'h3C000; end // OUTPUT_PTR
                    22:  begin periph_add_o = 32'h34; periph_data_o = tiles_reg_val; end // TILES
                    23:  begin periph_add_o = 32'h38; periph_data_o = rqs_eps_mult0_i; end // EPS_MULT0
                    24:  begin periph_add_o = 32'h3C; periph_data_o = rqs_eps_mult1_i; end // EPS_MULT1
                    25:  begin periph_add_o = 32'h40; periph_data_o = rqs_rshift0_i; end // RIGHT_SHIFT0
                    26:  begin periph_add_o = 32'h44; periph_data_o = rqs_rshift1_i; end // RIGHT_SHIFT1
                    27:  begin periph_add_o = 32'h48; periph_data_o = rqs_add0_i; end // ADD0
                    28:  begin periph_add_o = 32'h4C; periph_data_o = rqs_add1_i; end // ADD1
                    29:  begin periph_add_o = 32'h50; periph_data_o = activation_gelu_const_i; end // GELU_B_C
                    30:  begin periph_add_o = 32'h54; periph_data_o = activation_rqs_const_i; end // ACTIVATION_REQUANT
                    31:  begin periph_add_o = 32'h60; periph_data_o = 32'h0; end // CTRL_ENGINE
                    32:  begin periph_add_o = 32'h64; periph_data_o = 32'h12; end// CTRL_STREAM
                    33:  begin periph_add_o = 32'h00; periph_data_o = 32'h0; end // TRIGGER
                    // --- TILE 2 (y=0, x=1, i=0) ---
                    34:  begin periph_add_o = 32'h20; periph_data_o = 32'h00000; end // INPUT_PTR
                    35:  begin periph_add_o = 32'h24; periph_data_o = 32'h0A000; end // WEIGHT_PTR0
                    36:  begin periph_add_o = 32'h28; periph_data_o = 32'h0B000; end // WEIGHT_PTR1
                    37:  begin periph_add_o = 32'h2C; periph_data_o = 32'h2E0C0; end // BIAS_PTR
                    38:  begin periph_add_o = 32'h30; periph_data_o = 32'h3D000; end // OUTPUT_PTR
                    39:  begin periph_add_o = 32'h34; periph_data_o = tiles_reg_val; end // TILES
                    40:  begin periph_add_o = 32'h38; periph_data_o = rqs_eps_mult0_i; end // EPS_MULT0
                    41:  begin periph_add_o = 32'h3C; periph_data_o = rqs_eps_mult1_i; end // EPS_MULT1
                    42:  begin periph_add_o = 32'h40; periph_data_o = rqs_rshift0_i; end // RIGHT_SHIFT0
                    43:  begin periph_add_o = 32'h44; periph_data_o = rqs_rshift1_i; end // RIGHT_SHIFT1
                    44:  begin periph_add_o = 32'h48; periph_data_o = rqs_add0_i; end // ADD0
                    45:  begin periph_add_o = 32'h4C; periph_data_o = rqs_add1_i; end // ADD1
                    46:  begin periph_add_o = 32'h50; periph_data_o = activation_gelu_const_i; end // GELU_B_C
                    47:  begin periph_add_o = 32'h54; periph_data_o = activation_rqs_const_i; end // ACTIVATION_REQUANT
                    48:  begin periph_add_o = 32'h60; periph_data_o = 32'h0; end // CTRL_ENGINE
                    49:  begin periph_add_o = 32'h64; periph_data_o = 32'h2; end // CTRL_STREAM
                    50:  begin periph_add_o = 32'h00; periph_data_o = 32'h0; end // TRIGGER
                    // --- TILE 3 (y=0, x=1, i=1) ---
                    51:  begin periph_add_o = 32'h20; periph_data_o = 32'h01000; end // INPUT_PTR
                    52:  begin periph_add_o = 32'h24; periph_data_o = 32'h0B000; end // WEIGHT_PTR0
                    53:  begin periph_add_o = 32'h28; periph_data_o = 32'h0C000; end // WEIGHT_PTR1
                    54:  begin periph_add_o = 32'h2C; periph_data_o = 32'h2E0C0; end // BIAS_PTR
                    55:  begin periph_add_o = 32'h30; periph_data_o = 32'h3D000; end // OUTPUT_PTR
                    56:  begin periph_add_o = 32'h34; periph_data_o = tiles_reg_val; end // TILES
                    57:  begin periph_add_o = 32'h38; periph_data_o = rqs_eps_mult0_i; end // EPS_MULT0
                    58:  begin periph_add_o = 32'h3C; periph_data_o = rqs_eps_mult1_i; end // EPS_MULT1
                    59:  begin periph_add_o = 32'h40; periph_data_o = rqs_rshift0_i; end // RIGHT_SHIFT0
                    60:  begin periph_add_o = 32'h44; periph_data_o = rqs_rshift1_i; end // RIGHT_SHIFT1
                    61:  begin periph_add_o = 32'h48; periph_data_o = rqs_add0_i; end // ADD0
                    62:  begin periph_add_o = 32'h4C; periph_data_o = rqs_add1_i; end // ADD1
                    63:  begin periph_add_o = 32'h50; periph_data_o = activation_gelu_const_i; end // GELU_B_C
                    64:  begin periph_add_o = 32'h54; periph_data_o = activation_rqs_const_i; end // ACTIVATION_REQUANT
                    65:  begin periph_add_o = 32'h60; periph_data_o = 32'h0; end // CTRL_ENGINE
                    66:  begin periph_add_o = 32'h64; periph_data_o = 32'h12; end// CTRL_STREAM
                    67:  begin periph_add_o = 32'h00; periph_data_o = 32'h0; end // TRIGGER
                    // --- TILE 4 (y=0, x=2, i=0) ---
                    68:  begin periph_add_o = 32'h20; periph_data_o = 32'h00000; end // INPUT_PTR
                    69:  begin periph_add_o = 32'h24; periph_data_o = 32'h0C000; end // WEIGHT_PTR0
                    70:  begin periph_add_o = 32'h28; periph_data_o = 32'h0D000; end // WEIGHT_PTR1
                    71:  begin periph_add_o = 32'h2C; periph_data_o = 32'h2E180; end // BIAS_PTR
                    72:  begin periph_add_o = 32'h30; periph_data_o = 32'h3E000; end // OUTPUT_PTR
                    73:  begin periph_add_o = 32'h34; periph_data_o = tiles_reg_val; end // TILES
                    74:  begin periph_add_o = 32'h38; periph_data_o = rqs_eps_mult0_i; end // EPS_MULT0
                    75:  begin periph_add_o = 32'h3C; periph_data_o = rqs_eps_mult1_i; end // EPS_MULT1
                    76:  begin periph_add_o = 32'h40; periph_data_o = rqs_rshift0_i; end // RIGHT_SHIFT0
                    77:  begin periph_add_o = 32'h44; periph_data_o = rqs_rshift1_i; end // RIGHT_SHIFT1
                    78:  begin periph_add_o = 32'h48; periph_data_o = rqs_add0_i; end // ADD0
                    79:  begin periph_add_o = 32'h4C; periph_data_o = rqs_add1_i; end // ADD1
                    80:  begin periph_add_o = 32'h50; periph_data_o = activation_gelu_const_i; end // GELU_B_C
                    81:  begin periph_add_o = 32'h54; periph_data_o = activation_rqs_const_i; end // ACTIVATION_REQUANT
                    82:  begin periph_add_o = 32'h60; periph_data_o = 32'h0; end // CTRL_ENGINE
                    83:  begin periph_add_o = 32'h64; periph_data_o = 32'h2; end // CTRL_STREAM
                    84:  begin periph_add_o = 32'h00; periph_data_o = 32'h0; end // TRIGGER
                    // --- TILE 5 (y=0, x=2, i=1) ---
                    85:  begin periph_add_o = 32'h20; periph_data_o = 32'h01000; end // INPUT_PTR
                    86:  begin periph_add_o = 32'h24; periph_data_o = 32'h0D000; end // WEIGHT_PTR0
                    87:  begin periph_add_o = 32'h28; periph_data_o = 32'h0E000; end // WEIGHT_PTR1
                    88:  begin periph_add_o = 32'h2C; periph_data_o = 32'h2E180; end // BIAS_PTR
                    89:  begin periph_add_o = 32'h30; periph_data_o = 32'h3E000; end // OUTPUT_PTR
                    90:  begin periph_add_o = 32'h34; periph_data_o = tiles_reg_val; end // TILES
                    91:  begin periph_add_o = 32'h38; periph_data_o = rqs_eps_mult0_i; end // EPS_MULT0
                    92:  begin periph_add_o = 32'h3C; periph_data_o = rqs_eps_mult1_i; end // EPS_MULT1
                    93:  begin periph_add_o = 32'h40; periph_data_o = rqs_rshift0_i; end // RIGHT_SHIFT0
                    94:  begin periph_add_o = 32'h44; periph_data_o = rqs_rshift1_i; end // RIGHT_SHIFT1
                    95:  begin periph_add_o = 32'h48; periph_data_o = rqs_add0_i; end // ADD0
                    96:  begin periph_add_o = 32'h4C; periph_data_o = rqs_add1_i; end // ADD1
                    97:  begin periph_add_o = 32'h50; periph_data_o = activation_gelu_const_i; end // GELU_B_C
                    98:  begin periph_add_o = 32'h54; periph_data_o = activation_rqs_const_i; end // ACTIVATION_REQUANT
                    99:  begin periph_add_o = 32'h60; periph_data_o = 32'h0; end // CTRL_ENGINE
                    100: begin periph_add_o = 32'h64; periph_data_o = 32'h12; end// CTRL_STREAM
                    101: begin periph_add_o = 32'h00; periph_data_o = 32'h0; end // TRIGGER
                endcase
                if (periph_gnt_i) begin
                    next_state = S_WRITE_ACK;
                end
            end

            S_WRITE_ACK: begin
                periph_req_o = 1'b0;
                write_step_cnt_next = write_step_cnt + 1;
                if (write_step_cnt == TOTAL_WRITES - 1) begin
                    // After the final trigger, wait for busy one last time before finishing
                    next_state = S_CHECK_BUSY;
                end else if (is_start_of_new_tile) begin
                    // A tile just finished triggering, now wait for busy before next one
                    next_state = S_CHECK_BUSY;
                end else begin
                    // Continue with the writes for the current tile
                    next_state = S_WRITE_REQ;
                end
            end

            S_FINISH_STEP: begin
                done_o = 1'b1;
                next_state = S_IDLE;
            end
        endcase
    end
endmodule