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

module ita_sequencer_hardcoded_k_step #(
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
    output logic [31:0]            periph_data_o
);
    typedef enum logic [4:0] {
        S_IDLE,
        S_CHECK_BUSY,
        S_WAIT_CYCLE,
        S_WRITE_REQ_0,
        S_WRITE_REQ_1,
        S_WRITE_REQ_2,
        S_WRITE_REQ_3,
        S_WRITE_REQ_4,
        S_WRITE_REQ_5,
        S_WRITE_WAIT_GNT,
        S_WRITE_ACK,
        S_SEND_TRIGGER,
        S_FINISH_STEP,
        S_CHOOSE_STATE,
        S_WAIT_5,
        S_WRITE_REQS
    } seq_state_t;

    seq_state_t  current_state, next_state;
    logic [7:0]  write_step_cnt, write_step_cnt_next, tile_cnt, next_tile_cnt;
    logic [$clog2(INTER_TILE_DELAY_CYCLES):0] delay_cnt, delay_cnt_next;
    logic [31:0] prev_data;
    localparam int unsigned WAIT5_CYCLES = 500; // 5us wait / 1ns period
    logic [$clog2(WAIT5_CYCLES)-1:0] wait5_cnt, wait5_cnt_n;

    // FSM state registers
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            current_state  <= S_IDLE;
            write_step_cnt <= '0;
            delay_cnt      <= '0;
            tile_cnt       <= '0;
            wait5_cnt      <= '0; //counter
        end else begin
            current_state  <= next_state;
            write_step_cnt <= write_step_cnt_next;
            delay_cnt      <= delay_cnt_next;
            tile_cnt       <= next_tile_cnt;
            wait5_cnt      <= wait5_cnt_n; //counter
        end
    end

    // Combinational logic for FSM and outputs
    always_comb begin
        next_state          = current_state;
        write_step_cnt_next = write_step_cnt;
        delay_cnt_next      = delay_cnt;
        next_tile_cnt       = tile_cnt;
        wait5_cnt_n         = wait5_cnt; //counter
        done_o              = 1'b0;
        periph_req_o        = 1'b0;
        periph_add_o        = '0;
        periph_wen_o        = 1'b1; // Default to read
        periph_be_o         = 4'hf;
        periph_data_o       = '0;

        case (current_state)
            S_IDLE: begin
                if (start_i) begin
                    next_state = S_WRITE_REQ_0;
                    periph_req_o = 1'b1;
                    periph_wen_o = 1'b0;
                    periph_add_o = 32'd20; 
                    periph_data_o = 32'h0;
                    periph_be_o  = 4'hF;
                end
            end

            S_CHECK_BUSY: begin
                write_step_cnt_next = 0;
                if (!hwpe_busy_i) begin
                    periph_req_o = 1'b1;
                    periph_wen_o = 1'b0;
                    periph_add_o = 32'd00; 
                    periph_data_o = 32'h0;
                    periph_be_o  = 4'hF;
                    next_state = S_CHOOSE_STATE;
                end
            end
            
            S_CHOOSE_STATE: begin
                    periph_req_o = 1'b0;
                    periph_wen_o = 1'b1;
                    periph_add_o = 32'd00; 
                    periph_data_o = 32'h0;
                    periph_be_o  = 4'hF;
                    next_state = S_WAIT_5;
            end  

            S_WAIT_5: begin
                if (wait5_cnt == WAIT5_CYCLES-1) begin
                wait5_cnt_n = '0;            // clear for next time
                next_state  = S_WRITE_REQS;  // proceed after full 5us
                end else begin
                    wait5_cnt_n = wait5_cnt + 1'b1;
                    next_state  = S_WAIT_5;      // keep waiting
                end
            end

            S_WRITE_REQS: begin
                case (tile_cnt)
                    0: next_state = S_WRITE_REQ_0;
                    1: next_state = S_WRITE_REQ_1;
                    2: next_state = S_WRITE_REQ_2;
                    3: next_state = S_WRITE_REQ_3;
                    4: next_state = S_WRITE_REQ_4;
                    5: next_state = S_WRITE_REQ_5;
                    default: next_state = S_FINISH_STEP; // All tiles done
                endcase
            end          

            S_WAIT_CYCLE: begin
                case (tile_cnt)
                    0: next_state = S_WRITE_REQ_0;
                    1: next_state = S_WRITE_REQ_1;
                    2: next_state = S_WRITE_REQ_2;
                    3: next_state = S_WRITE_REQ_3;
                    4: next_state = S_WRITE_REQ_4;
                    5: next_state = S_WRITE_REQ_5;
                    default: next_state = S_FINISH_STEP; // All tiles done
                endcase

                periph_req_o = 1'b0;
                periph_wen_o = 1'b1;
                periph_data_o = prev_data; 
                periph_data_o = 32'h0;
                periph_be_o  = 4'hF;
                @(posedge clk_i);
                
            end
            S_SEND_TRIGGER: begin
                periph_req_o = 1'b1;
                periph_wen_o = 1'b0;
                periph_add_o = 32'h00; 
                periph_data_o = 32'h0;
                periph_be_o  = 4'hF;
                case (tile_cnt)
                    0: next_state = S_WRITE_REQ_0;
                    1: next_state = S_WRITE_REQ_1;
                    2: next_state = S_WRITE_REQ_2;
                    3: next_state = S_WRITE_REQ_3;
                    4: next_state = S_WRITE_REQ_4;
                    5: next_state = S_WRITE_REQ_5;
                    default: next_state = S_FINISH_STEP; // All tiles done
                endcase
            end

            S_WRITE_REQ_0: begin
                periph_req_o = 1'b1;
                periph_wen_o = 1'b0; 
                case (write_step_cnt)
                    0:   begin periph_add_o = 32'd32; periph_data_o = 32'h2000; end // INPUT_PTR
                    1:   begin periph_add_o = 32'd36; periph_data_o = 32'ha000; end // WEIGHT_PTR0
                    2:   begin periph_add_o = 32'd40; periph_data_o = 32'hb000; end // WEIGHT_PTR1
                    3:   begin periph_add_o = 32'd44; periph_data_o = 32'h1c240; end // BIAS_PTR
                    4:   begin periph_add_o = 32'd48; periph_data_o = 32'h31cc0; end // OUTPUT_PTR
                    5:   begin periph_add_o = 32'd84; periph_data_o = 32'h00000; end // TILES
                    6:   begin periph_add_o = 32'd88; periph_data_o = 32'h00012; end // EPS_MULT0
                endcase

                prev_data = periph_data_o;
                
                if (write_step_cnt == 6) begin
                   
                    next_state = S_CHECK_BUSY;
                    next_tile_cnt = tile_cnt + 1;
                end else begin
                    next_state = S_WAIT_CYCLE;
                    write_step_cnt_next = write_step_cnt + 1;
                end
            end

            
            S_WRITE_REQ_1: begin
                periph_req_o = 1'b1;
                periph_wen_o = 1'b0; 
                case (write_step_cnt)
                    0:   begin periph_add_o = 32'd32; periph_data_o = 32'h3000; end // INPUT_PTR
                    1:   begin periph_add_o = 32'd36; periph_data_o = 32'hb000; end // WEIGHT_PTR0
                    2:   begin periph_add_o = 32'd40; periph_data_o = 32'hc000; end // WEIGHT_PTR1
                    3:   begin periph_add_o = 32'd44; periph_data_o = 32'h1c240; end // BIAS_PTR
                    4:   begin periph_add_o = 32'd48; periph_data_o = 32'h31cc0; end // OUTPUT_PTR
                    5:   begin periph_add_o = 32'd84; periph_data_o = 32'h00000; end // TILES
                    6:   begin periph_add_o = 32'd88; periph_data_o = 32'h00002; end // EPS_MULT0

                endcase

                prev_data = periph_data_o;

                if (write_step_cnt == 6) begin
                    next_state = S_CHECK_BUSY;
                    next_tile_cnt = tile_cnt + 1;
                end else begin
                    next_state = S_WAIT_CYCLE;
                    write_step_cnt_next = write_step_cnt + 1;
                end
            end

            S_WRITE_REQ_2: begin
                periph_req_o = 1'b1;
                periph_wen_o = 1'b0; 
                case (write_step_cnt)
                    0:   begin periph_add_o = 32'd32; periph_data_o = 32'h2000; end // INPUT_PTR
                    1:   begin periph_add_o = 32'd36; periph_data_o = 32'hc000; end // WEIGHT_PTR0
                    2:   begin periph_add_o = 32'd40; periph_data_o = 32'hd000; end // WEIGHT_PTR1
                    3:   begin periph_add_o = 32'd44; periph_data_o = 32'h1c300; end // BIAS_PTR
                    4:   begin periph_add_o = 32'd48; periph_data_o = 32'h32cc0; end // OUTPUT_PTR
                    5:   begin periph_add_o = 32'd84; periph_data_o = 32'h00000; end // TILES
                    6:   begin periph_add_o = 32'd88; periph_data_o = 32'h00012; end // EPS_MULT0
                endcase

                prev_data = periph_data_o;

                if (write_step_cnt == 6) begin
                    next_state = S_CHECK_BUSY;
                    next_tile_cnt = tile_cnt + 1;
                end else begin
                    next_state = S_WAIT_CYCLE;
                    write_step_cnt_next = write_step_cnt + 1;
                end
            end

            S_WRITE_REQ_3: begin
                periph_req_o = 1'b1;
                periph_wen_o = 1'b0; 
                case (write_step_cnt)
                    0:   begin periph_add_o = 32'd32; periph_data_o = 32'h3000; end // INPUT_PTR
                    1:   begin periph_add_o = 32'd36; periph_data_o = 32'hd000; end // WEIGHT_PTR0
                    2:   begin periph_add_o = 32'd40; periph_data_o = 32'he000; end // WEIGHT_PTR1
                    3:   begin periph_add_o = 32'd44; periph_data_o = 32'h1c300; end // BIAS_PTR
                    4:   begin periph_add_o = 32'd48; periph_data_o = 32'h32cc0; end // OUTPUT_PTR
                    5:   begin periph_add_o = 32'd84; periph_data_o = 32'h00000; end // TILES
                    6:   begin periph_add_o = 32'd88; periph_data_o = 32'h00002; end // EPS_MULT0
                endcase

                prev_data = periph_data_o;

                if (write_step_cnt == 6) begin
                    next_state = S_CHECK_BUSY;
                    next_tile_cnt = tile_cnt + 1;
                end else begin
                    next_state = S_WAIT_CYCLE;
                    write_step_cnt_next = write_step_cnt + 1;
                end
            end

            S_WRITE_REQ_4: begin
                periph_req_o = 1'b1;
                periph_wen_o = 1'b0; 
                case (write_step_cnt)
                    0:   begin periph_add_o = 32'd32; periph_data_o = 32'h2000; end // INPUT_PTR
                    1:   begin periph_add_o = 32'd36; periph_data_o = 32'he000; end // WEIGHT_PTR0
                    2:   begin periph_add_o = 32'd40; periph_data_o = 32'hf000; end // WEIGHT_PTR1
                    3:   begin periph_add_o = 32'd44; periph_data_o = 32'h1c3c0; end // BIAS_PTR
                    4:   begin periph_add_o = 32'd48; periph_data_o = 32'h33cc0; end // OUTPUT_PTR
                    5:   begin periph_add_o = 32'd84; periph_data_o = 32'h00000; end // TILES
                    6:   begin periph_add_o = 32'd88; periph_data_o = 32'h00012; end // EPS_MULT0
                endcase

                prev_data = periph_data_o;

                if (write_step_cnt == 6) begin
                    next_state = S_CHECK_BUSY;
                    next_tile_cnt = tile_cnt + 1;
                end else begin
                    next_state = S_WAIT_CYCLE;
                    write_step_cnt_next = write_step_cnt + 1;
                end
            end

            S_WRITE_REQ_5: begin
                periph_req_o = 1'b1;
                periph_wen_o = 1'b0; 
                case (write_step_cnt)
                    0:   begin periph_add_o = 32'd32; periph_data_o = 32'h3000; end // INPUT_PTR
                    1:   begin periph_add_o = 32'd36; periph_data_o = 32'hf000; end // WEIGHT_PTR0
                    2:   begin periph_add_o = 32'd40; periph_data_o = 32'h2000; end // WEIGHT_PTR1
                    3:   begin periph_add_o = 32'd44; periph_data_o = 32'h1c3c0; end // BIAS_PTR
                    4:   begin periph_add_o = 32'd48; periph_data_o = 32'h33cc0; end // OUTPUT_PTR
                    5:   begin periph_add_o = 32'd84; periph_data_o = 32'h00000; end // TILES
                    6:   begin periph_add_o = 32'd88; periph_data_o = 32'h00002; end // EPS_MULT0
                endcase

                prev_data = periph_data_o;

                if (write_step_cnt == 6) begin
                    next_state = S_CHECK_BUSY;
                    next_tile_cnt = tile_cnt + 1;
                end else begin
                    next_state = S_WAIT_CYCLE;
                    write_step_cnt_next = write_step_cnt + 1;
                end
                
            end
            
            S_FINISH_STEP: begin
                done_o = 1'b1;
                next_state = S_IDLE;
            end
        endcase
    end
endmodule