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
    output logic               periph_req_o,
    input  logic               periph_gnt_i,
    output logic [31:0]        periph_add_o,
    output logic               periph_wen_o,
    output logic [3:0]         periph_be_o,
    output logic [31:0]        periph_data_o,
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
    input logic [31:0]     N_TILES_OUTER_X [N_STATES-1:0],
    input logic [31:0]     N_TILES_OUTER_Y [N_STATES-1:0],
    input logic [31:0]   N_TILES_INNER_DIM [N_STATES-1:0],
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

    // FSM States re-architected for pipelined operation
    typedef enum logic [4:0] {
        S_IDLE,
        S_LATCH_AND_PROG,      // Latch values for next tile and start programming
        S_PROG_REQ,
        S_PROG_WAIT_GNT,
        S_PROG_ACK,
        S_WAIT_BUSY,           // Wait for current tile to finish
        S_DELAY,               // Wait for stabilization period
        S_TRIGGER_REQ,
        S_TRIGGER_WAIT_GNT,
        S_TRIGGER_ACK,
        S_WAIT_FINAL_BUSY,     // Special wait state for the very last tile
        S_FINISH_STEP
    } seq_state_t;

    // --- State registers ---
    seq_state_t  current_state, next_state;
    step_e       step_r, step_r_next; 
    logic [15:0] outer_tile_cnt, outer_tile_cnt_next;
    logic [7:0]  tile_inner_cnt, tile_inner_cnt_next;
    logic [4:0]  reg_prog_cnt, reg_prog_cnt_next;
    logic [7:0]  ita_reg_cnt, ita_reg_cnt_next;
    logic        is_first_tile_ever_r, is_first_tile_ever_r_next;
    logic [$clog2(INTER_TILE_DELAY_CYCLES)-1:0] delay_cnt, delay_cnt_next;

    // Latched values for stable programming
    logic [31:0] input_ptr_latched, weight_ptr0_latched, weight_ptr1_latched, bias_ptr_latched, output_ptr_latched;
    logic [31:0] ctrl_engine_val_latched, ctrl_stream_val_latched, tiles_reg_val_latched;
    logic        weight_ptr_en_latched, bias_ptr_en_latched, ita_reg_en_latched;

    // Local variables for calculation
    logic [31:0] input_ptr, weight_ptr0, weight_ptr1, bias_ptr, output_ptr;
    logic [31:0] ctrl_engine_val, ctrl_stream_val, tiles_reg_val;
    logic        weight_ptr_en, bias_ptr_en, ita_reg_en;
    logic        is_last_tile_in_step;
    logic        do_write;

    // Combinational block for calculating pointers and control values
    // This logic is driven by the current state of the counters and the registered step `step_r`.
    always_comb begin
        int unsigned current_tile_y;
        int unsigned current_tile_x;
        int unsigned total_outer_tiles;
        int unsigned current_tile;
        layer_e      layer_type;
        activation_e activation_function;
        logic        is_last, is_first_tile_of_step;

        // Default to no-op
        input_ptr = '0; weight_ptr0 = '0; weight_ptr1 = '0; bias_ptr = '0; output_ptr = '0;
        ctrl_engine_val = '0; ctrl_stream_val = '0; tiles_reg_val = '0;
        weight_ptr_en = 1'b0; bias_ptr_en = 1'b0; ita_reg_en = 1'b0;
        is_last_tile_in_step = 1'b0;

        // --- Calculation Stage (Combinatorial) ---
        // This logic is identical to your original code, but uses 'step_r' for stability.
        begin
            if (N_TILES_OUTER_X[step_r] > 0) begin
                current_tile_y = outer_tile_cnt / N_TILES_OUTER_X[step_r];
                current_tile_x = outer_tile_cnt % N_TILES_OUTER_X[step_r];
            end else begin
                current_tile_y = 0; current_tile_x = 0;
            end
            total_outer_tiles = N_TILES_OUTER_Y[step_r] * N_TILES_OUTER_X[step_r];
            current_tile = outer_tile_cnt * N_TILES_INNER_DIM[step_r] + tile_inner_cnt;
            is_first_tile_of_step = (outer_tile_cnt == 0 && tile_inner_cnt == 0);
            is_last_tile_in_step = (outer_tile_cnt == total_outer_tiles - 1) &&
                                   (tile_inner_cnt == N_TILES_INNER_DIM[step_r] - 1);

            input_ptr = BASE_PTR_INPUT[step_r] + (current_tile_y * N_TILES_INNER_DIM[step_r] + tile_inner_cnt) * N_ELEMENTS_PER_TILE;
            output_ptr = BASE_PTR_OUTPUT[step_r] + outer_tile_cnt * N_ELEMENTS_PER_TILE;
            if (step_r == V)
                bias_ptr = BASE_PTR_BIAS[step_r] + current_tile_y * M_TILE_LEN * 3;
            else
                bias_ptr = BASE_PTR_BIAS[step_r] + current_tile_x * M_TILE_LEN * 3;
            weight_ptr0 = BASE_PTR_WEIGHT0[step_r] + (current_tile % (N_TILES_OUTER_X[step_r] * N_TILES_INNER_DIM[step_r])) * N_ELEMENTS_PER_TILE;
            if (is_last_tile_in_step) begin
                weight_ptr1 = BASE_PTR_WEIGHT1[step_r];
                if (step_r == AV) weight_ptr1 = BASE_PTR_WEIGHT0[QK];
            end else begin
                int unsigned next_tile_idx = (current_tile + 1) % (N_TILES_OUTER_X[step_r] * N_TILES_INNER_DIM[step_r]);
                weight_ptr1 = BASE_PTR_WEIGHT0[step_r] + next_tile_idx * N_ELEMENTS_PER_TILE;
            end

            is_last = 1'b0;
            ctrl_stream_val = 32'h0;
            weight_ptr_en = 1'b0;
            bias_ptr_en = 1'b0;
            if (SINGLE_ATTENTION == 1) layer_type = Linear; else layer_type = Attention;
            activation_function = Identity;
            ctrl_engine_val = layer_type | (activation_function << 2);
            ita_reg_en = (SINGLE_ATTENTION == 1) ? 1'b1 : (ita_reg_cnt < N_CONTEXT);
            case (step_r)
                Q: begin
                    if (is_first_tile_of_step) ctrl_stream_val = 32'h0003; else ctrl_stream_val = 32'h0002;
                    weight_ptr_en = 1'b1; bias_ptr_en = 1'b1;
                end
                K: begin
                    ctrl_stream_val = 32'h0002; weight_ptr_en = 1'b1; bias_ptr_en = 1'b1;
                end
                V: begin
                    ctrl_stream_val = 32'h000A; weight_ptr_en = 1'b1; bias_ptr_en = 1'b1;
                end
                QK, AV: begin
                    if (SINGLE_ATTENTION == 1) ctrl_engine_val = SingleAttention | (Identity << 2);
                    ctrl_stream_val = 32'h0006; weight_ptr_en = 1'b1; bias_ptr_en = 1'b0;
                end
                OW: begin
                    is_last = is_last_tile_in_step;
                    ctrl_stream_val = is_last ? 32'h0000 : 32'h0002;
                    weight_ptr_en = !is_last; bias_ptr_en = 1'b1;
                end
                F1: begin
                    if (SINGLE_ATTENTION == 1) ctrl_engine_val = Linear | (ACTIVATION << 2);
                    else ctrl_engine_val = Feedforward | (ACTIVATION << 2);
                    ctrl_stream_val = is_first_tile_of_step ? 32'h0003 : 32'h0002;
                    weight_ptr_en = 1'b1; bias_ptr_en = 1'b1;
                end
                F2: begin
                    if (SINGLE_ATTENTION == 1) ctrl_engine_val = Linear | (Identity << 2);
                    else ctrl_engine_val = Feedforward | (Identity << 2);
                    is_last = is_last_tile_in_step;
                    ctrl_stream_val = is_last ? 32'h0000 : 32'h0002;
                    weight_ptr_en = !is_last; bias_ptr_en = 1'b1;
                end
                default: ;
            endcase
            if ((tile_inner_cnt + 1) == N_TILES_INNER_DIM[step_r]) ctrl_stream_val[4] = 1'b0;
            else ctrl_stream_val[4] = 1'b1;
            tiles_reg_val = N_TILES_SEQUENCE_DIM | (N_TILES_EMBEDDING_DIM << 4) |
                            (N_TILES_PROJECTION_DIM << 8) | (N_TILES_FEEDFORWARD_DIM << 12);
        end
    end

    // Sequential block for state registers
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            current_state        <= S_IDLE;
            step_r               <= Q;
            outer_tile_cnt       <= '0;
            tile_inner_cnt       <= '0;
            reg_prog_cnt         <= '0;
            is_first_tile_ever_r <= 1'b1;
            ita_reg_cnt          <= '0;
            delay_cnt            <= '0;
        end else begin
            current_state        <= next_state;
            step_r               <= step_r_next;
            outer_tile_cnt       <= outer_tile_cnt_next;
            tile_inner_cnt       <= tile_inner_cnt_next;
            reg_prog_cnt         <= reg_prog_cnt_next;
            is_first_tile_ever_r <= is_first_tile_ever_r_next;
            ita_reg_cnt          <= ita_reg_cnt_next;
            delay_cnt            <= delay_cnt_next;
        end
    end

    // Sequential block for the latched programming values
    // These are only updated when the FSM enters the S_LATCH_AND_PROG state
    always_ff @(posedge clk_i) begin
        if (next_state == S_LATCH_AND_PROG) begin
            input_ptr_latched         <= input_ptr;
            weight_ptr0_latched       <= weight_ptr0;
            weight_ptr1_latched       <= weight_ptr1;
            bias_ptr_latched          <= bias_ptr;
            output_ptr_latched        <= output_ptr;
            ctrl_engine_val_latched   <= ctrl_engine_val;
            ctrl_stream_val_latched   <= ctrl_stream_val;
            tiles_reg_val_latched     <= tiles_reg_val;
            weight_ptr_en_latched     <= weight_ptr_en;
            bias_ptr_en_latched       <= bias_ptr_en;
            ita_reg_en_latched        <= ita_reg_en;
        end
    end
    
    // Main FSM logic block
    always_comb begin
        // --- Default assignments ---
        next_state                = current_state;
        step_r_next               = step_r;
        outer_tile_cnt_next       = outer_tile_cnt;
        tile_inner_cnt_next       = tile_inner_cnt;
        reg_prog_cnt_next         = reg_prog_cnt;
        is_first_tile_ever_r_next = is_first_tile_ever_r;
        ita_reg_cnt_next          = ita_reg_cnt;
        delay_cnt_next            = delay_cnt;
        done_o                    = 1'b0;
        periph_req_o              = 1'b0;
        periph_add_o              = '0;
        periph_wen_o              = 1'b1;
        periph_be_o               = 4'h0;
        periph_data_o             = '0;
        do_write                  = 1'b0;

        // --- Pipelined FSM Logic ---
        case (current_state)
            S_IDLE: begin
                if (start_i) begin
                    step_r_next               = step_i;
                    outer_tile_cnt_next       = '0;
                    tile_inner_cnt_next       = '0;
                    reg_prog_cnt_next         = '0;
                    is_first_tile_ever_r_next = 1'b1;
                    if (step_i == F1) ita_reg_cnt_next = '0;
                    next_state = S_LATCH_AND_PROG;
                end
            end

            S_LATCH_AND_PROG: begin
                // The always_ff block for latched values triggers on this state transition.
                // We can now proceed to program the latched values.
                reg_prog_cnt_next = '0;
                next_state = S_PROG_REQ;
            end

            S_PROG_REQ: begin
                do_write = 1'b1;
                case (reg_prog_cnt)
                    0:  begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_INPUT_PTR;   periph_data_o = input_ptr_latched; end
                    1:  begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_WEIGHT_PTR0; periph_data_o = weight_ptr0_latched; end
                    2:  if (weight_ptr_en_latched) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_WEIGHT_PTR1; periph_data_o=weight_ptr1_latched; end else do_write=1'b0;
                    3:  if (bias_ptr_en_latched)   begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_BIAS_PTR;    periph_data_o=bias_ptr_latched;    end else do_write=1'b0;
                    4:  begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_OUTPUT_PTR;  periph_data_o = output_ptr_latched;  end
                    5:  if (ita_reg_en_latched) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_TILES;         periph_data_o=tiles_reg_val_latched;       end else do_write=1'b0;
                    6:  if (ita_reg_en_latched) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_EPS_MULT0;   periph_data_o=rqs_eps_mult0_i;             end else do_write=1'b0;
                    7:  if (ita_reg_en_latched) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_EPS_MULT1;   periph_data_o=rqs_eps_mult1_i;             end else do_write=1'b0;
                    8:  if (ita_reg_en_latched) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_RIGHT_SHIFT0; periph_data_o=rqs_rshift0_i;                 end else do_write=1'b0;
                    9:  if (ita_reg_en_latched) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_RIGHT_SHIFT1; periph_data_o=rqs_rshift1_i;                 end else do_write=1'b0;
                    10: if (ita_reg_en_latched) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_ADD0;         periph_data_o=rqs_add0_i;                      end else do_write=1'b0;
                    11: if (ita_reg_en_latched) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_ADD1;         periph_data_o=rqs_add1_i;                      end else do_write=1'b0;
                    12: if (ita_reg_en_latched) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_GELU_B_C;    periph_data_o=activation_gelu_const_i;     end else do_write=1'b0;
                    13: if (ita_reg_en_latched) begin periph_add_o=ITA_REG_OFFSET + 4*ITA_REG_ACTIVATION_REQUANT; periph_data_o=activation_rqs_const_i; end else do_write=1'b0;
                    14: begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_CTRL_ENGINE; periph_data_o = ctrl_engine_val_latched; end
                    15: begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_CTRL_STREAM; periph_data_o = ctrl_stream_val_latched; end
                    default: do_write = 1'b0;
                endcase

                if (do_write) begin
                    periph_req_o = 1'b1;
                    periph_wen_o = 1'b0;
                    next_state = S_PROG_WAIT_GNT;
                end else begin
                    if (reg_prog_cnt == PROGRAM_STEPS - 1) begin
                        next_state = is_first_tile_ever_r ? S_TRIGGER_REQ : S_WAIT_BUSY;
                    end else begin
                        reg_prog_cnt_next = reg_prog_cnt + 1;
                    end
                end
            end

            S_PROG_WAIT_GNT: begin
                periph_req_o = 1'b1; periph_wen_o = 1'b0;
                case (reg_prog_cnt) // Hold outputs stable while waiting for grant
                    0:  begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_INPUT_PTR;   periph_data_o = input_ptr_latched; end
                    1:  begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_WEIGHT_PTR0; periph_data_o = weight_ptr0_latched; end
                    2:  begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_WEIGHT_PTR1; periph_data_o = weight_ptr1_latched; end
                    3:  begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_BIAS_PTR;    periph_data_o = bias_ptr_latched; end
                    4:  begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_OUTPUT_PTR;  periph_data_o = output_ptr_latched; end
                    5:  begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_TILES;         periph_data_o = tiles_reg_val_latched; end
                    6:  begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_EPS_MULT0;   periph_data_o = rqs_eps_mult0_i; end
                    7:  begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_EPS_MULT1;   periph_data_o = rqs_eps_mult1_i; end
                    8:  begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_RIGHT_SHIFT0; periph_data_o = rqs_rshift0_i; end
                    9:  begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_RIGHT_SHIFT1; periph_data_o = rqs_rshift1_i; end
                    10: begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_ADD0;         periph_data_o = rqs_add0_i; end
                    11: begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_ADD1;         periph_data_o = rqs_add1_i; end
                    12: begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_GELU_B_C;    periph_data_o = activation_gelu_const_i; end
                    13: begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_ACTIVATION_REQUANT; periph_data_o = activation_rqs_const_i; end
                    14: begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_CTRL_ENGINE; periph_data_o = ctrl_engine_val_latched; end
                    15: begin periph_add_o = ITA_REG_OFFSET + 4*ITA_REG_CTRL_STREAM; periph_data_o = ctrl_stream_val_latched; end
                endcase
                if (periph_gnt_i) begin
                    next_state = S_PROG_ACK;
                end
            end

            S_PROG_ACK: begin
                if (reg_prog_cnt == PROGRAM_STEPS - 1) begin
                    // Always go to wait/delay path, but handle first tile specially in S_WAIT_BUSY
                    next_state = is_first_tile_ever_r ? S_TRIGGER_REQ : S_WAIT_BUSY;
                end else begin
                    reg_prog_cnt_next = reg_prog_cnt + 1;
                    next_state = S_PROG_REQ;
                end
            end
            
            S_WAIT_BUSY: begin
                // For first tile, hwpe_busy_i will be 0, so skip immediately to delay
                // For subsequent tiles, wait for previous tile to complete
                if (!hwpe_busy_i || is_first_tile_ever_r) begin
                    delay_cnt_next = '0;
                    next_state = S_DELAY;
                end
            end
            
            S_DELAY: begin
                // Always wait 5 cycles before triggering
                if (delay_cnt == INTER_TILE_DELAY_CYCLES - 1) begin
                    next_state = S_TRIGGER_REQ;
                end else begin
                    delay_cnt_next = delay_cnt + 1;
                end
            end
    
            S_TRIGGER_REQ: begin
                periph_req_o  = 1'b1;
                periph_wen_o  = 1'b0;
                periph_add_o  = 32'h00;
                periph_data_o = 32'h00; // Trigger with 0, as per testbench
                next_state    = S_TRIGGER_WAIT_GNT;
            end

            S_TRIGGER_WAIT_GNT: begin
                periph_req_o  = 1'b1; periph_wen_o  = 1'b0;
                periph_add_o  = 32'h00; periph_data_o = 32'h00;
                if (periph_gnt_i) begin
                    next_state = S_TRIGGER_ACK;
                end
            end

            S_TRIGGER_ACK: begin
                is_first_tile_ever_r_next = 1'b0;
                if (is_last_tile_in_step) begin
                    next_state = S_WAIT_FINAL_BUSY;
                end else begin
                    // Update counters for the next tile...
                    if (tile_inner_cnt == N_TILES_INNER_DIM[step_r] - 1) begin
                        tile_inner_cnt_next = 0;
                        outer_tile_cnt_next = outer_tile_cnt + 1;
                    end else begin
                        tile_inner_cnt_next = tile_inner_cnt + 1;
                    end
                    if (ita_reg_en_latched) ita_reg_cnt_next = ita_reg_cnt + 1;
                    // ...and immediately start programming it.
                    next_state = S_LATCH_AND_PROG;
                end
            end

            S_WAIT_FINAL_BUSY: begin
                if (!hwpe_busy_i) begin
                    next_state = S_FINISH_STEP;
                end
            end

            S_FINISH_STEP: begin
                done_o = 1'b1;
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase

        periph_be_o = (periph_req_o && !periph_wen_o) ? 4'hF : 4'h0;
    end
endmodule