`include "hci_helpers.svh"

import ita_hwpe_package::*;
import hwpe_ctrl_package::*;
import hwpe_stream_package::*;
import hci_package::*;
import ita_package::*;

/*
 * This module wraps the ITA HWPE (ita_hwpe_wrap) and the URAM memory
 * controller (uram_memory_controller). It handles the internal TCDM
 * connection between them, exposing a clean interface that matches
 * the peripheral and control signals used in the provided testbench.
 */
module ITA_FPGA_WRAPPER #(
    // Parameters for ita_hwpe_wrap
    parameter int unsigned AccDataWidth = 1024,
    parameter int unsigned IdWidth      = 8,
    parameter int unsigned MemDataWidth = 32,
    parameter int unsigned MP = (AccDataWidth / MemDataWidth),
    
    // AXI parameters
    parameter integer C_S_AXIS_TDATA_WIDTH = 32,
    parameter integer C_M_AXIS_TDATA_WIDTH = 32,

    // Parameters for uram_memory_controller
    parameter int TOTAL_WORDS = 277888, // Default size from TB
    parameter string MEM_INIT_FILES [MP-1:0] = '{default:"none"},
    
    // Data Parameters
    parameter int M_TILE_LEN = 64,
    parameter int SEQUENCE_LEN = 64,
    parameter int PROJECTION_SPACE = 192,
    parameter int EMBEDDING_SIZE = 128,
    parameter int FEEDFORWARD_SIZE = 256,
    parameter activation_e ACTIVATION = Relu,
    parameter int SINGLE_ATTENTION = 0,
    parameter int N_CONTEXT = 8
) (
    // Global signals
    input  logic clk_i,
    input  logic rst_ni,
    input  logic test_mode_i,

    // Events from HWPE
    output logic [N_CORES-1:0][1:0] evt_o,
    output logic                    busy_o,
    
    // --- FSM Control Interface from CPU/System ---
    input  logic start_load_attn_wb_i, // Pulse to load Attention weights/biases
    input  logic start_load_ffn_wb_i,  // Pulse to load FFN weights/biases
    input  logic start_attn_i,         // Pulse to load ATTN inputs (Q,K,V) and run
    input  logic start_ffn_i,          // Pulse to load FFN input and run
    
    // --- FSM Status Outputs to CPU/System ---
    output logic attn_wb_done_o,       // Asserted when ATTN WB load is complete
    output logic ffn_wb_done_o,        // Asserted when FFN WB load is complete
    output logic attn_done_o,          // Asserted when Attention block is done
    output logic ffn_done_o,           // Asserted when FFN block is done
    output logic accelerator_idle_o,   // Asserted when FSM is in IDLE
    
    // SLAVE AXI STREAM Signals -> Wrapper (for loading data into URAM)
    input  logic [C_S_AXIS_TDATA_WIDTH-1:0] s_axis_tdata,
    input  logic s_axis_tvalid,
    output logic s_axis_tready,
    
    // MASTER AXI STREAM Signals <- Wrapper (for reading results from URAM)
    output logic [C_M_AXIS_TDATA_WIDTH-1:0] m_axis_tdata,
    output logic m_axis_tvalid,
    input  logic m_axis_tready,

    // RQS and activation constants (PROGRAMMING THE ACCELERATOR)

    input  logic [31:0] activation_gelu_const_i,
    input  logic [31:0] activation_rqs_const_i,

    input  logic [31:0] rqs_eps_mult0_i,
    input  logic [31:0] rqs_eps_mult1_i,
    input  logic [31:0] rqs_eps_mult2_i,
    input  logic [31:0] rqs_rshift0_i,
    input  logic [31:0] rqs_rshift1_i,
    input  logic [31:0] rqs_rshift2_i,
    input  logic [31:0] rqs_add0_i,
    input  logic [31:0] rqs_add1_i,
    input  logic [31:0] rqs_add2_i,
    input  logic [31:0] rqs_add3_i,
    input  logic [31:0] rqs_add4_i
);
    
    // --- FSM State Definition  ---
    typedef enum logic [5:0] {
        S_IDLE,
        // Attention WB Loading
        S_WAIT_ATTN_WB_DATA,
        S_SETUP_ATTN_WB,
        // FFN WB Loading
        S_WAIT_FFN_WB_DATA,
        S_SETUP_FFN_WB,
        // Attention Path States
        S_WAIT_ATTN_DATA,
        S_SETUP_ATTN,
        S_START_Q, S_WAIT_Q_DONE,
        S_START_K, S_WAIT_K_DONE,
        S_START_V, S_WAIT_V_DONE,
        S_START_QK, S_WAIT_QK_DONE,
        S_START_AV, S_WAIT_AV_DONE,
        S_START_OW, S_WAIT_OW_DONE,
        S_WAIT_ATTN_READ_READY,
        S_DONE_ATTN,
        // FFN Path States
        S_WAIT_FFN_DATA,
        S_SETUP_FFN,
        S_START_F1, S_WAIT_F1_DONE,
        S_START_F2, S_WAIT_F2_DONE,
        S_WAIT_FFN_READ_READY,
        S_DONE_FFN
    } state_t;
    
    state_t current_state, next_state; // FSM state registers
    step_e  current_step_r, next_step; // Sub-state for RUN states (Q, K, V, etc.)

    logic [2:0] delay_cnt, delay_cnt_next; // Counter for the inter-step delay
    
    // --- Sequencer Control & Status Wires ---
    logic q_start, k_start, v_start, qk_start, av_start, ow_start, f1_start, f2_start ; // To start the ita_sequencer for a specific step
    logic q_done, k_done, v_done, qk_done, av_done, ow_done, f1_done, f2_done;  // From ita_sequencer, indicates one step is complete

    // --- Internal Peripheral Bus to program the HWPE ---
    logic periph_req_seq;
    logic periph_gnt_seq;
    logic [31:0] periph_add_seq;
    logic periph_wen_seq;
    logic [3:0] periph_be_seq;
    logic [31:0] periph_data_seq;
    logic [31:0] periph_r_data_seq;
    logic periph_r_valid_seq;
    logic [IdWidth-1:0] periph_r_id_seq;
    
    // --- DMA Address Generator Control & Status ---
    logic        dma_ag_start;         // Pulse to start the address generator.
    logic [31:0] dma_ag_base_addr;     // Internal wire to select the base address
    logic [31:0] dma_ag_len;           // Number of addresses to generate for the current transfer.
    logic        dma_ag_done;          // Pulse from the address generator when the transfer is complete.
    logic [31:0] uram_addr;            // Address bus to the memory controller.
    logic        uram_addr_valid;      // Valid signal for the address bus.
    logic        uram_addr_ready;      // Ready signal for the address bus.
    logic        transfer_in_progress; // A latch to prevent re-triggering a DMA transfer mid-operation.

    // --- Parameter and Pointer Calculation (from Testbench) ---
    // This logic remains unchanged as it defines the accelerator's geometry.
    localparam int N_TILES_SEQUENCE_DIM    = SEQUENCE_LEN / M_TILE_LEN;
    localparam int N_TILES_EMBEDDING_DIM   = EMBEDDING_SIZE / M_TILE_LEN;
    localparam int N_TILES_PROJECTION_DIM  = PROJECTION_SPACE / M_TILE_LEN;
    localparam int N_TILES_FEEDFORWARD_DIM = FEEDFORWARD_SIZE / M_TILE_LEN;
    localparam int N_ELEMENTS_PER_TILE     = M_TILE_LEN * M_TILE_LEN;
    localparam int ID = 0;
    
    /*// --- Tile Dimensions ---
    logic [31:0] N_TILES_OUTER_X [N_STATES-1:0];
    logic [31:0] N_TILES_OUTER_Y [N_STATES-1:0];
    logic [31:0] N_TILES_INNER_DIM [N_STATES-1:0];
    
    // Use explicit array literals to define the content with a guaranteed order.
    // This is the most robust method to prevent the circular shift issue.
    // Index mapping: 0=Idle, 1=Q, 2=K, 3=V, 4=QK, 5=AV, 6=OW, 7=F1, 8=F2
    localparam logic [31:0] OUTER_X_VALUES [0:N_STATES-1] = '{
        32'hX,                      // [0] Idle
        N_TILES_PROJECTION_DIM,     // [1] Q
        N_TILES_PROJECTION_DIM,     // [2] K
        N_TILES_SEQUENCE_DIM,       // [3] V
        N_TILES_SEQUENCE_DIM,       // [4] QK
        N_TILES_PROJECTION_DIM,     // [5] AV
        N_TILES_EMBEDDING_DIM,      // [6] OW
        N_TILES_FEEDFORWARD_DIM,    // [7] F1
        N_TILES_EMBEDDING_DIM       // [8] F2
    };
    
    localparam logic [31:0] OUTER_Y_VALUES [0:N_STATES-1] = '{
        32'hX,                      // [0] Idle
        N_TILES_SEQUENCE_DIM,       // [1] Q
        N_TILES_SEQUENCE_DIM,       // [2] K
        N_TILES_PROJECTION_DIM,     // [3] V
        1,                          // [4] QK
        1,                          // [5] AV
        N_TILES_SEQUENCE_DIM,       // [6] OW
        N_TILES_SEQUENCE_DIM,       // [7] F1
        N_TILES_SEQUENCE_DIM        // [8] F2
    };
    
    localparam logic [31:0] INNER_DIM_VALUES [0:N_STATES-1] = '{
        32'hX,                      // [0] Idle
        N_TILES_EMBEDDING_DIM,      // [1] Q
        N_TILES_EMBEDDING_DIM,      // [2] K
        N_TILES_EMBEDDING_DIM,      // [3] V
        N_TILES_PROJECTION_DIM,     // [4] QK
        N_TILES_SEQUENCE_DIM,       // [5] AV
        N_TILES_PROJECTION_DIM,     // [6] OW
        N_TILES_EMBEDDING_DIM,      // [7] F1
        N_TILES_FEEDFORWARD_DIM     // [8] F2
    };
    
    // Use a generate block to perform a direct, 1-to-1 mapping to the output signals.
    generate
        genvar i;
        for (i = 0; i < N_STATES; i=i+1) begin : map_tile_dims
            assign N_TILES_OUTER_X[i]   = OUTER_X_VALUES[i];
            assign N_TILES_OUTER_Y[i]   = OUTER_Y_VALUES[i];
            assign N_TILES_INNER_DIM[i] = INNER_DIM_VALUES[i];
        end
    endgenerate*/
    
    // 1. Declare the golden arrays as 'logic' (unpacked array of nets)
    logic [31:0] GOLDEN_OUTER_X     [0:N_STATES-1];
    logic [31:0] GOLDEN_OUTER_Y     [0:N_STATES-1];
    logic [31:0] GOLDEN_INNER_DIM   [0:N_STATES-1];

    // 2. Assign the constant array literal to the nets
    // Index mapping: 0=Idle, 1=Q, 2=K, 3=V, 4=QK, 5=AV, 6=OW, 7=F1, 8=F2
    assign GOLDEN_OUTER_X   = '{ 32'hX, 3, 3, 1, 1, 3, 2, 4, 2 };
    assign GOLDEN_OUTER_Y   = '{ 32'hX, 1, 1, 3, 1, 1, 1, 1, 1 };
    assign GOLDEN_INNER_DIM = '{ 32'hX, 2, 2, 2, 3, 1, 3, 2, 4 };
    
    
    // --- Base Pointers (Assignments are identical to the procedural testbench) ---
    logic [31:0] BASE_PTR [0:22];
    logic [N_STATES-1:0][31:0] BASE_PTR_INPUT;
    logic [N_STATES-1:0][31:0] BASE_PTR_WEIGHT0;
    logic [N_STATES-1:0][31:0] BASE_PTR_WEIGHT1;
    logic [N_STATES-1:0][31:0] BASE_PTR_BIAS;
    logic [N_STATES-1:0][31:0] BASE_PTR_OUTPUT;
    
    assign BASE_PTR[0]  = 0;
    assign BASE_PTR[1]  = BASE_PTR[0]  + SEQUENCE_LEN * EMBEDDING_SIZE;
    assign BASE_PTR[2]  = BASE_PTR[1]  + SEQUENCE_LEN * EMBEDDING_SIZE;
    assign BASE_PTR[3]  = BASE_PTR[2]  + PROJECTION_SPACE * EMBEDDING_SIZE;
    assign BASE_PTR[4]  = BASE_PTR[3]  + PROJECTION_SPACE * EMBEDDING_SIZE;
    assign BASE_PTR[5]  = BASE_PTR[4]  + PROJECTION_SPACE * EMBEDDING_SIZE;
    assign BASE_PTR[6]  = BASE_PTR[5]  + PROJECTION_SPACE * EMBEDDING_SIZE;
    assign BASE_PTR[7]  = BASE_PTR[6]  + PROJECTION_SPACE * 3;
    assign BASE_PTR[8]  = BASE_PTR[7]  + PROJECTION_SPACE * 3;
    assign BASE_PTR[9]  = BASE_PTR[8]  + PROJECTION_SPACE * 3;
    assign BASE_PTR[10] = BASE_PTR[9]  + EMBEDDING_SIZE * 3;
    assign BASE_PTR[11] = BASE_PTR[10] + SEQUENCE_LEN * EMBEDDING_SIZE;
    assign BASE_PTR[12] = BASE_PTR[11] + EMBEDDING_SIZE * FEEDFORWARD_SIZE;
    assign BASE_PTR[13] = BASE_PTR[12] + FEEDFORWARD_SIZE * EMBEDDING_SIZE;
    assign BASE_PTR[14] = BASE_PTR[13] + FEEDFORWARD_SIZE * 3;
    assign BASE_PTR[15] = BASE_PTR[14] + EMBEDDING_SIZE * 3;
    assign BASE_PTR[16] = BASE_PTR[15] + SEQUENCE_LEN * PROJECTION_SPACE;
    assign BASE_PTR[17] = BASE_PTR[16] + SEQUENCE_LEN * PROJECTION_SPACE;
    assign BASE_PTR[18] = BASE_PTR[17] + SEQUENCE_LEN * PROJECTION_SPACE;
    assign BASE_PTR[19] = BASE_PTR[18] + SEQUENCE_LEN * SEQUENCE_LEN;
    assign BASE_PTR[20] = BASE_PTR[19] + SEQUENCE_LEN * PROJECTION_SPACE;
    assign BASE_PTR[21] = BASE_PTR[20] + SEQUENCE_LEN * EMBEDDING_SIZE;
    assign BASE_PTR[22] = BASE_PTR[21] + SEQUENCE_LEN * FEEDFORWARD_SIZE;
    
    assign BASE_PTR_INPUT[Q]   = BASE_PTR[0];
    assign BASE_PTR_INPUT[K]   = BASE_PTR[1];
    assign BASE_PTR_INPUT[V]   = BASE_PTR[4];
    assign BASE_PTR_INPUT[QK]  = BASE_PTR[15];
    assign BASE_PTR_INPUT[AV]  = BASE_PTR[18];
    assign BASE_PTR_INPUT[OW]  = BASE_PTR[19];
    assign BASE_PTR_INPUT[F1]  = BASE_PTR[10];
    assign BASE_PTR_INPUT[F2]  = BASE_PTR[21];
    
    assign BASE_PTR_WEIGHT0[Q]  = BASE_PTR[2];
    assign BASE_PTR_WEIGHT0[K]  = BASE_PTR[3];
    assign BASE_PTR_WEIGHT0[V]  = BASE_PTR[1];
    assign BASE_PTR_WEIGHT0[QK] = BASE_PTR[16];
    assign BASE_PTR_WEIGHT0[AV] = BASE_PTR[17];
    assign BASE_PTR_WEIGHT0[OW] = BASE_PTR[5];
    assign BASE_PTR_WEIGHT0[F1] = BASE_PTR[11];
    assign BASE_PTR_WEIGHT0[F2] = BASE_PTR[12];
    
    assign BASE_PTR_WEIGHT1[1] = BASE_PTR_WEIGHT0[2]; // Corresponds to i=0 in TB (Q -> K)
    assign BASE_PTR_WEIGHT1[2] = BASE_PTR_WEIGHT0[3]; // Corresponds to i=1 in TB (K -> V)
    assign BASE_PTR_WEIGHT1[3] = BASE_PTR_WEIGHT0[4]; // Corresponds to i=2 in TB (V -> QK)
    assign BASE_PTR_WEIGHT1[4] = BASE_PTR_WEIGHT0[5]; // Corresponds to i=3 in TB (QK -> AV)
    assign BASE_PTR_WEIGHT1[5] = BASE_PTR_WEIGHT0[6]; // Corresponds to i=4 in TB (AV -> OW)
    assign BASE_PTR_WEIGHT1[7] = BASE_PTR_WEIGHT0[F2]; // Special case for F1
    
    assign BASE_PTR_BIAS[Q]  = BASE_PTR[6];
    assign BASE_PTR_BIAS[K]  = BASE_PTR[7];
    assign BASE_PTR_BIAS[V]  = BASE_PTR[8];
    assign BASE_PTR_BIAS[OW] = BASE_PTR[9];
    assign BASE_PTR_BIAS[F1] = BASE_PTR[13];
    assign BASE_PTR_BIAS[F2] = BASE_PTR[14];
    
    assign BASE_PTR_OUTPUT[Q]  = BASE_PTR[15];
    assign BASE_PTR_OUTPUT[K]  = BASE_PTR[16];
    assign BASE_PTR_OUTPUT[V]  = BASE_PTR[17];
    assign BASE_PTR_OUTPUT[QK] = BASE_PTR[18];
    assign BASE_PTR_OUTPUT[AV] = BASE_PTR[19];
    assign BASE_PTR_OUTPUT[OW] = BASE_PTR[20];
    assign BASE_PTR_OUTPUT[F1] = BASE_PTR[21];
    assign BASE_PTR_OUTPUT[F2] = BASE_PTR[22];
    

    logic [31:0] BASE_PTR [0:22];
    logic [N_STATES-1:0][31:0] BASE_PTR_INPUT;
    logic [N_STATES-1:0][31:0] BASE_PTR_WEIGHT0;
    logic [N_STATES-1:0][31:0] BASE_PTR_WEIGHT1;
    logic [N_STATES-1:0][31:0] BASE_PTR_BIAS;
    logic [N_STATES-1:0][31:0] BASE_PTR_OUTPUT;
    logic [31:0] WB_TOTAL_BYTES;
    logic [31:0] WB_LOAD_WORDS;

    // Attention Layer
    localparam int ATTN_W_LOAD_WORDS  = (H * 4 * EMBEDDING_SIZE * PROJECTION_SPACE) / (C_S_AXIS_TDATA_WIDTH / 8);
    localparam int ATTN_B_LOAD_WORDS  = (H * (9 * PROJECTION_SPACE + 3 * EMBEDDING_SIZE)) / (C_S_AXIS_TDATA_WIDTH / 8);
    localparam int ATTN_WB_LOAD_WORDS = ATTN_W_LOAD_WORDS + ATTN_B_LOAD_WORDS;
    localparam int ATTN_LOAD_WORDS    = (SEQUENCE_LEN * EMBEDDING_SIZE) / (C_S_AXIS_TDATA_WIDTH / 4);
    localparam int ATTN_OUTPUT_WORDS  = (SEQUENCE_LEN * EMBEDDING_SIZE) / (C_M_AXIS_TDATA_WIDTH / 8);

    // FFN Layer
    localparam int FFN_W_LOAD_WORDS   = (2 * EMBEDDING_SIZE * FEEDFORWARD_SIZE) / (C_S_AXIS_TDATA_WIDTH / 8);
    localparam int FFN_B_LOAD_WORDS   = (3 * FEEDFORWARD_SIZE + 3 * EMBEDDING_SIZE) / (C_S_AXIS_TDATA_WIDTH / 8);
    localparam int FFN_WB_LOAD_WORDS  = FFN_W_LOAD_WORDS + FFN_B_LOAD_WORDS;
    localparam int FFN_LOAD_WORDS     = (SEQUENCE_LEN * EMBEDDING_SIZE) / (C_S_AXIS_TDATA_WIDTH / 8);
    localparam int FFN_OUTPUT_WORDS   = (SEQUENCE_LEN * EMBEDDING_SIZE) / (C_M_AXIS_TDATA_WIDTH / 8);

    // --- FSM Sequential Logic ---
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            current_state <= S_IDLE;
            current_step_r <= Idle;
            transfer_in_progress <= 1'b0;
            delay_cnt <= '0;
        end else begin
            current_state <= next_state;
            current_step_r <= next_step;
            delay_cnt <= delay_cnt_next;
            if (dma_ag_start) begin
                transfer_in_progress <= 1'b1;
            end else if (dma_ag_done || next_state == S_IDLE) begin
                transfer_in_progress <= 1'b0;
            end
        end
    end

    // --- FSM Combinational Logic ---
    always_comb begin
        // Default assignments to prevent latches
        next_state = current_state;
        q_start = 1'b0; k_start = 1'b0; v_start = 1'b0; qk_start = 1'b0;
        av_start = 1'b0; ow_start = 1'b0; f1_start = 1'b0; f2_start = 1'b0;
        dma_ag_start = 1'b0;
        dma_ag_base_addr = 32'b0;
        dma_ag_len = 32'b0;

        case (current_state)
            S_IDLE: begin
                // Wait for a command from the host processor.
                if (start_load_attn_wb_i) next_state = S_WAIT_ATTN_WB_DATA;
                if (start_load_ffn_wb_i)  next_state = S_WAIT_FFN_WB_DATA;
                if (start_attn_i)         next_state = S_WAIT_ATTN_DATA;
                if (start_ffn_i)          next_state = S_WAIT_FFN_DATA;
            end
            
            // --- Attention WB Loading Path ---
            S_WAIT_ATTN_WB_DATA: begin
                if (s_axis_tvalid && !transfer_in_progress) begin
                    dma_ag_start     = 1'b1;
                    dma_ag_base_addr = BASE_PTR_INPUT[Q]; // Start of ATTN WB block
                    dma_ag_len       = ATTN_WB_LOAD_WORDS;
                    next_state       = S_SETUP_ATTN_WB;
                end
            end
            S_SETUP_ATTN_WB: begin
                if (dma_ag_done) next_state = S_IDLE;
            end

            // --- FFN WB Loading Path ---
            S_WAIT_FFN_WB_DATA: begin
                if (s_axis_tvalid && !transfer_in_progress) begin
                    dma_ag_start     = 1'b1;
                    dma_ag_base_addr = BASE_PTR_WEIGHT0[F1]; // Start of FFN WB block
                    dma_ag_len       = FFN_WB_LOAD_WORDS;
                    next_state       = S_SETUP_FFN_WB;
                end
            end
            S_SETUP_FFN_WB: begin
                if (dma_ag_done) next_state = S_IDLE;
            end

            // --- Attention Computation Path ---
            S_WAIT_ATTN_DATA: begin
                // Wait for Q, K, V data to arrive.
                if (s_axis_tvalid && !transfer_in_progress) begin
                    dma_ag_start = 1'b1;
                    dma_ag_base_addr = BASE_PTR_INPUT[Q];
                    dma_ag_len   = ATTN_LOAD_WORDS;
                    next_state   = S_SETUP_ATTN;
                end
            end
            S_SETUP_ATTN: begin
                if (dma_ag_done) next_state = S_START_Q;
            end
            
            S_START_Q: begin q_start = 1'b1; next_state = S_WAIT_Q_DONE; end
            S_WAIT_Q_DONE: if (q_done) next_state = S_START_K;

            S_START_K: begin k_start = 1'b1; next_state = S_WAIT_K_DONE; end
            S_WAIT_K_DONE: if (k_done) next_state = S_START_V;

            S_START_V: begin v_start = 1'b1; next_state = S_WAIT_V_DONE; end
            S_WAIT_V_DONE: if (v_done) next_state = S_START_QK;

            S_START_QK: begin qk_start = 1'b1; next_state = S_WAIT_QK_DONE; end
            S_WAIT_QK_DONE: if (qk_done) next_state = S_START_AV;

            S_START_AV: begin av_start = 1'b1; next_state = S_WAIT_AV_DONE; end
            S_WAIT_AV_DONE: if (av_done) next_state = S_START_OW;

            S_START_OW: begin ow_start = 1'b1; next_state = S_WAIT_OW_DONE; end
            S_WAIT_OW_DONE: if (ow_done) next_state = S_WAIT_ATTN_READ_READY; 
            
            S_WAIT_ATTN_READ_READY: begin
                // Wait for the host to be ready to accept the results.
                if (m_axis_tready && !transfer_in_progress) begin
                    dma_ag_start = 1'b1;
                    dma_ag_base_addr = BASE_PTR_OUTPUT[OW];
                    dma_ag_len   = ATTN_OUTPUT_WORDS;
                    next_state   = S_DONE_ATTN;
                end
            end
            
            S_DONE_ATTN: begin
                // When the results have been fully streamed out, return to idle.
                if (dma_ag_done) next_state = S_IDLE;
            end

            // --- FFN Computation Path ---
            S_WAIT_FFN_DATA: begin
                 // Wait for FFN input data to arrive.
                 if (s_axis_tvalid && !transfer_in_progress) begin
                    dma_ag_start = 1'b1;
                    dma_ag_base_addr = BASE_PTR_INPUT[F1];
                    dma_ag_len   = FFN_LOAD_WORDS;
                    next_state   = S_SETUP_FFN;
                end
            end
            
            S_SETUP_FFN: begin
                if (dma_ag_done) next_state = S_START_F1;
            end
            
            S_START_F1: begin f1_start = 1'b1; next_state = S_WAIT_F1_DONE; end
            S_WAIT_F1_DONE: if (f1_done) next_state = S_START_F2;

            S_START_F2: begin f2_start = 1'b1; next_state = S_WAIT_F2_DONE; end
            S_WAIT_F2_DONE: if (f2_done) next_state = S_WAIT_FFN_READ_READY;
            
            S_WAIT_FFN_READ_READY: begin
                // Wait for the host to be ready for the final results.
                if (m_axis_tready && !transfer_in_progress) begin
                    dma_ag_start = 1'b1;
                    dma_ag_base_addr = BASE_PTR_OUTPUT[F2];
                    dma_ag_len   = FFN_OUTPUT_WORDS;
                    next_state   = S_DONE_FFN;
                end
            end
            S_DONE_FFN: begin
                // When final results are sent, return to idle.
                if (dma_ag_done) next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // --- FSM Output Logic ---
    assign accelerator_idle_o = (current_state == S_IDLE);
    assign attn_wb_done_o     = (current_state == S_SETUP_ATTN_WB && dma_ag_done);
    assign ffn_wb_done_o      = (current_state == S_SETUP_FFN_WB && dma_ag_done);
    assign attn_done_o        = (current_state == S_DONE_ATTN && dma_ag_done);
    assign ffn_done_o         = (current_state == S_DONE_FFN && dma_ag_done);

    // --- DMA/Mux Control Logic ---
    // The memory controller is in DMA mode during all setup and done states.
    // It's in ITA (HWPE) mode only during the RUN states.
    assign dma_mode_o = (current_state inside {S_WAIT_ATTN_WB_DATA, S_SETUP_ATTN_WB,
                                             S_WAIT_FFN_WB_DATA,  S_SETUP_FFN_WB,
                                             S_WAIT_ATTN_DATA,    S_SETUP_ATTN,
                                             S_WAIT_FFN_DATA,     S_SETUP_FFN,
                                             S_WAIT_ATTN_READ_READY, S_DONE_ATTN,
                                             S_WAIT_FFN_READ_READY,  S_DONE_FFN});

    // dma_we_o is 1 for a DMA write (to URAM), 0 for a DMA read (from URAM)
    // We are writing TO the URAM during the SETUP states.
    assign dma_we_o = (current_state inside {S_WAIT_ATTN_WB_DATA, S_SETUP_ATTN_WB,
                                            S_WAIT_FFN_WB_DATA,  S_SETUP_FFN_WB,
                                            S_WAIT_ATTN_DATA,    S_SETUP_ATTN,
                                            S_WAIT_FFN_DATA,     S_SETUP_FFN});
    
    // --- Internal Signals for TCDM Connection ---
    logic [MP-1:0]                        tcdm_req;
    logic [MP-1:0]                        tcdm_gnt;
    logic [MP-1:0][31:0]                  tcdm_add;
    logic [MP-1:0]                        tcdm_wen;
    logic [MP-1:0][(MemDataWidth/8)-1:0]  tcdm_be;
    logic [MP-1:0][MemDataWidth-1:0]      tcdm_data;
    logic [MP-1:0][MemDataWidth-1:0]      tcdm_r_data;
    logic [MP-1:0]                        tcdm_r_valid;
    

    // --- HCI Interface for URAM Controller ---
    localparam hci_size_parameter_t `HCI_SIZE_PARAM(tcdm_mem) = '{
        DW:  AccDataWidth,
        AW:  DEFAULT_AW,
        BW:  DEFAULT_BW,
        UW:  DEFAULT_UW,
        IW:  DEFAULT_IW,
        EW:  DEFAULT_EW,
        EHW: DEFAULT_EHW
    };
    `HCI_INTF_ARRAY(tcdm_mem, clk_i, MP-1:0);

    ita_sequencer_hardcoded_q_step #(
        .M_TILE_LEN(M_TILE_LEN), 
        .SEQUENCE_LEN(SEQUENCE_LEN), 
        .PROJECTION_SPACE(PROJECTION_SPACE),
        .EMBEDDING_SIZE(EMBEDDING_SIZE), 
        .FEEDFORWARD_SIZE(FEEDFORWARD_SIZE),
        .ACTIVATION(ACTIVATION), 
        .SINGLE_ATTENTION(SINGLE_ATTENTION), 
        .N_CONTEXT(N_CONTEXT)
    ) i_ita_sequencer_q (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .start_i(q_start),
        .done_o(q_done),
        .hwpe_busy_i(busy_o),
        .periph_req_o(periph_req_seq),
        .periph_gnt_i(periph_gnt_seq),
        .periph_add_o(periph_add_seq),
        .periph_wen_o(periph_wen_seq),
        .periph_be_o(periph_be_seq),
        .periph_data_o(periph_data_seq)
    );

    ita_sequencer_hardcoded_k_step #(
        .M_TILE_LEN(M_TILE_LEN), 
        .SEQUENCE_LEN(SEQUENCE_LEN), 
        .PROJECTION_SPACE(PROJECTION_SPACE),
        .EMBEDDING_SIZE(EMBEDDING_SIZE), 
        .FEEDFORWARD_SIZE(FEEDFORWARD_SIZE),
        .ACTIVATION(ACTIVATION), 
        .SINGLE_ATTENTION(SINGLE_ATTENTION), 
        .N_CONTEXT(N_CONTEXT)
    ) i_ita_sequencer_k (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .start_i(k_start),
        .done_o(k_done),
        .hwpe_busy_i(busy_o),
        .periph_req_o(periph_req_seq),
        .periph_gnt_i(periph_gnt_seq),
        .periph_add_o(periph_add_seq),
        .periph_wen_o(periph_wen_seq),
        .periph_be_o(periph_be_seq),
        .periph_data_o(periph_data_seq)
    );
      
    ita_sequencer_hardcoded_v_step #(
        .M_TILE_LEN(M_TILE_LEN), 
        .SEQUENCE_LEN(SEQUENCE_LEN), 
        .PROJECTION_SPACE(PROJECTION_SPACE),
        .EMBEDDING_SIZE(EMBEDDING_SIZE), 
        .FEEDFORWARD_SIZE(FEEDFORWARD_SIZE),
        .ACTIVATION(ACTIVATION), 
        .SINGLE_ATTENTION(SINGLE_ATTENTION), 
        .N_CONTEXT(N_CONTEXT)
    ) i_ita_sequencer_v (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .start_i(v_start),
        .done_o(v_done),
        .hwpe_busy_i(busy_o),
        .periph_req_o(periph_req_seq),
        .periph_gnt_i(periph_gnt_seq),
        .periph_add_o(periph_add_seq),
        .periph_wen_o(periph_wen_seq),
        .periph_be_o(periph_be_seq),
        .periph_data_o(periph_data_seq)
    );

    ita_sequencer_hardcoded_qk_step #(
        .M_TILE_LEN(M_TILE_LEN), 
        .SEQUENCE_LEN(SEQUENCE_LEN), 
        .PROJECTION_SPACE(PROJECTION_SPACE),
        .EMBEDDING_SIZE(EMBEDDING_SIZE), 
        .FEEDFORWARD_SIZE(FEEDFORWARD_SIZE),
        .ACTIVATION(ACTIVATION), 
        .SINGLE_ATTENTION(SINGLE_ATTENTION), 
        .N_CONTEXT(N_CONTEXT)
    ) i_ita_sequencer_qk (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .start_i(qk_start),
        .done_o(qk_done),
        .hwpe_busy_i(busy_o),
        .periph_req_o(periph_req_seq),
        .periph_gnt_i(periph_gnt_seq),
        .periph_add_o(periph_add_seq),
        .periph_wen_o(periph_wen_seq),
        .periph_be_o(periph_be_seq),
        .periph_data_o(periph_data_seq)
    );

    ita_sequencer_hardcoded_av_step #(
        .M_TILE_LEN(M_TILE_LEN), 
        .SEQUENCE_LEN(SEQUENCE_LEN), 
        .PROJECTION_SPACE(PROJECTION_SPACE),
        .EMBEDDING_SIZE(EMBEDDING_SIZE), 
        .FEEDFORWARD_SIZE(FEEDFORWARD_SIZE),
        .ACTIVATION(ACTIVATION), 
        .SINGLE_ATTENTION(SINGLE_ATTENTION), 
        .N_CONTEXT(N_CONTEXT)
    ) i_ita_sequencer_av (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .start_i(av_start),
        .done_o(av_done),
        .hwpe_busy_i(busy_o),
        .periph_req_o(periph_req_seq),
        .periph_gnt_i(periph_gnt_seq),
        .periph_add_o(periph_add_seq),
        .periph_wen_o(periph_wen_seq),
        .periph_be_o(periph_be_seq),
        .periph_data_o(periph_data_seq)
    );

    ita_sequencer_hardcoded_ow_step #(
        .M_TILE_LEN(M_TILE_LEN), 
        .SEQUENCE_LEN(SEQUENCE_LEN), 
        .PROJECTION_SPACE(PROJECTION_SPACE),
        .EMBEDDING_SIZE(EMBEDDING_SIZE), 
        .FEEDFORWARD_SIZE(FEEDFORWARD_SIZE),
        .ACTIVATION(ACTIVATION), 
        .SINGLE_ATTENTION(SINGLE_ATTENTION), 
        .N_CONTEXT(N_CONTEXT)
    ) i_ita_sequencer_ow (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .start_i(ow_start),
        .done_o(ow_done),
        .hwpe_busy_i(busy_o),
        .periph_req_o(periph_req_seq),
        .periph_gnt_i(periph_gnt_seq),
        .periph_add_o(periph_add_seq),
        .periph_wen_o(periph_wen_seq),
        .periph_be_o(periph_be_seq),
        .periph_data_o(periph_data_seq)
    );

    // The HWPE wrapper contains the actual processing engine.
    ita_hwpe_wrap #(
        .AccDataWidth(AccDataWidth),
        .IdWidth     (IdWidth),
        .MemDataWidth(MemDataWidth)
    ) i_ita_hwpe_wrap (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .test_mode_i    (test_mode_i),
        .evt_o          (evt_o),
        .busy_o         (busy_o),
        .tcdm_req_o     (tcdm_req),
        .tcdm_add_o     (tcdm_add),
        .tcdm_wen_o     (tcdm_wen),
        .tcdm_be_o      (tcdm_be),
        .tcdm_data_o    (tcdm_data),
        .tcdm_gnt_i     (tcdm_gnt),
        .tcdm_r_data_i  (tcdm_r_data),
        .tcdm_r_valid_i (tcdm_r_valid),
        .periph_req_i   (periph_req_seq),
        .periph_gnt_o   (periph_gnt_seq),
        .periph_add_i   (periph_add_seq),
        .periph_wen_i   (periph_wen_seq),
        .periph_be_i    (periph_be_seq),
        .periph_data_i  (periph_data_seq),
        .periph_id_i    (ID),
        .periph_r_data_o(periph_r_data_seq),
        .periph_r_valid_o(periph_r_valid_seq),
        .periph_r_id_o  (periph_r_id_seq)
    );

    // The memory controller arbitrates access to the URAM between the
    // HWPE (ITA mode) and the external AXI-Stream interfaces (DMA mode).
    uram_memory_controller_ita_dma #(
        .MP            (MP),
        .TOTAL_WORDS   (TOTAL_WORDS),
        .MEM_INIT_FILES(MEM_INIT_FILES)
    ) i_uram_memory_controller_ita_dma (
        .clk_i (clk_i),
        .rst_ni(rst_ni),
        .tcdm  (tcdm_mem),
        .dma_mode_i(dma_mode_o),
        .dma_we_i(dma_we_o),
        .dma_addr_i(uram_addr),
        .dma_addr_valid_i(uram_addr_valid),
        .dma_addr_ready_o(uram_addr_ready),
        .dma_wdata_i(s_axis_tdata),
        .dma_wdata_valid_i(s_axis_tvalid),
        .dma_wdata_ready_o(s_axis_tready),
        .dma_rdata_o(m_axis_tdata),
        .dma_rdata_valid_o(m_axis_tvalid),
        .dma_rdata_ready_i(m_axis_tready)
    );
    
    // The address generator provides the URAM addresses for DMA transfers.
    dma_address_generator #(
        .C_M_AXIS_TDATA_WIDTH(C_M_AXIS_TDATA_WIDTH)
    ) i_dma_address_generator (
        .clk(clk_i),
        .reset_n(rst_ni),
        .start_i(dma_ag_start),
        .base_address_in(dma_ag_base_addr),
        .transfer_len_i(dma_ag_len),
        .done_o(dma_ag_done),
        .m_axis_tdata(uram_addr),
        .m_axis_tvalid(uram_addr_valid),
        .m_axis_tready(uram_addr_ready),
        .m_axis_tlast() 
    );

    // --- Connect HWPE TCDM signals to the HCI Interface ---
    generate
        for (genvar i = 0; i < MP; i++) begin : g_tcdm_binding
            assign tcdm_mem[i].req  = tcdm_req[i];
            assign tcdm_mem[i].add  = tcdm_add[i];
            assign tcdm_mem[i].wen  = tcdm_wen[i];
            assign tcdm_mem[i].be   = tcdm_be[i];
            assign tcdm_mem[i].data = tcdm_data[i];
            assign tcdm_gnt[i]      = tcdm_mem[i].gnt;
            assign tcdm_r_valid[i]  = tcdm_mem[i].r_valid;
            assign tcdm_r_data[i]   = tcdm_mem[i].r_data;
            assign tcdm_mem[i].user    = '0;
            assign tcdm_mem[i].id      = '0;
            assign tcdm_mem[i].ecc     = '0;
            assign tcdm_mem[i].ereq    = '0;
            assign tcdm_mem[i].r_eready = 1'b1;
        end
    endgenerate

endmodule : ITA_FPGA_WRAPPER