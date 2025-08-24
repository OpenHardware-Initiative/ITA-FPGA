`timescale 1ns/1ps

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
    parameter int SEQUENCE_LEN = 128,
    parameter int PROJECTION_SPACE = 128,
    parameter int EMBEDDING_SIZE = 256,
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
    output logic                   busy_o,
    
    // --- FSM Control Interface from CPU/System ---
    input  logic start_wb_i,         // Pulse to start writing weights/biases
    input  logic start_attn_i,       // Pulse to start the Attention block computation
    input  logic start_ffn_i,        // Pulse to start the FFN block computation
    input  logic dma_write_done_i,   // Pulse from DMA after it finishes writing to URAM
    input  logic dma_read_done_i,    // Pulse from DMA after it finishes reading from URAM
    
    // --- FSM Status Outputs to CPU/System
    output logic wb_done_o,          // Asserted when WB setup is complete
    output logic attn_done_o,        // Asserted when Attention block is done, results ready
    output logic ffn_done_o,         // Asserted when FFN block is done, final results ready
    output logic accelerator_idle_o, // Asserted when FSM is in the top-level IDLE state
    
    // SLAVE AXI STREAM Signals -> Wrapper
    input  logic [C_S_AXIS_TDATA_WIDTH-1:0] s_axis_tdata,
    input  logic s_axis_tvalid,
    output logic s_axis_tready,
    
    // MASTER AXI STREAM Signals <- Wrapper
    output logic [C_M_AXIS_TDATA_WIDTH-1:0] m_axis_tdata,
    output logic m_axis_tvalid,
    input  logic m_axis_tready
    
);
    
    // --- FSM State Definition (based on diagram) ---
    typedef enum logic [3:0] {
        S_IDLE,
        S_SETUP_WB,
        S_SETUP_ATTN,
        S_RUN_ATTN,
        S_DONE_ATTN,
        S_SETUP_FFN,
        S_RUN_FFN,
        S_DONE_FFN
    } state_t;
    
    state_t current_state, next_state;
    step_e  current_step_r, next_step;
    
    // --- Sequencer Control & Status Wires ---
    logic sequencer_start;
    logic sequencer_done;

    // --- Internal Peripheral Bus ---
    logic periph_req_seq;
    logic periph_gnt_seq;
    logic [31:0] periph_add_seq;
    logic periph_wen_seq;
    logic [3:0] periph_be_seq;
    logic [31:0] periph_data_seq;
    logic [31:0] periph_r_data_seq;
    logic periph_r_valid_seq;
    logic [IdWidth-1:0] periph_r_id_seq;
    
    // --- Parameter and Pointer Calculation (from Testbench) ---
    // FIX: Changed these to `localparam` for better synthesis practice.
    // This ensures they are treated as compile-time constants.
    localparam int N_TILES_SEQUENCE_DIM    = SEQUENCE_LEN / M_TILE_LEN;
    localparam int N_TILES_EMBEDDING_DIM   = EMBEDDING_SIZE / M_TILE_LEN;
    localparam int N_TILES_PROJECTION_DIM  = PROJECTION_SPACE / M_TILE_LEN;
    localparam int N_TILES_FEEDFORWARD_DIM = FEEDFORWARD_SIZE / M_TILE_LEN;

    // FIX: Defined the peripheral transaction ID, which was missing.
    // The `ita_hwpe_wrap` instance requires an ID, and this was undefined.
    localparam int ID = 0;

    logic [N_STATES-1:0] N_TILES_OUTER_X;
    logic [N_STATES-1:0] N_TILES_OUTER_Y;
    logic [N_STATES-1:0] N_TILES_INNER_DIM;
    logic [31:0] BASE_PTR [0:22];
    logic [N_STATES-1:0][31:0] BASE_PTR_INPUT;
    logic [N_STATES-1:0][31:0] BASE_PTR_WEIGHT0;
    logic [N_STATES-1:0][31:0] BASE_PTR_WEIGHT1;
    logic [N_STATES-1:0][31:0] BASE_PTR_BIAS;
    logic [N_STATES-1:0][31:0] BASE_PTR_OUTPUT;

    // This initial block calculates constants and pointers. Synthesis tools are
    // capable of unrolling these loops and calculations to create the final
    // constant values for the logic variables.
    initial begin
        N_TILES_OUTER_X[Q] = N_TILES_PROJECTION_DIM;
        N_TILES_OUTER_X[K] = N_TILES_PROJECTION_DIM;
        N_TILES_OUTER_X[V] = N_TILES_SEQUENCE_DIM;
        N_TILES_OUTER_X[QK] = N_TILES_SEQUENCE_DIM;
        N_TILES_OUTER_X[AV] = N_TILES_PROJECTION_DIM;
        N_TILES_OUTER_X[OW] = N_TILES_EMBEDDING_DIM;
        N_TILES_OUTER_X[F1] = N_TILES_FEEDFORWARD_DIM;
        N_TILES_OUTER_X[F2] = N_TILES_EMBEDDING_DIM;
        N_TILES_OUTER_Y[Q] = N_TILES_SEQUENCE_DIM;
        N_TILES_OUTER_Y[K] = N_TILES_SEQUENCE_DIM;
        N_TILES_OUTER_Y[V] = N_TILES_PROJECTION_DIM;
        N_TILES_OUTER_Y[QK] = 1;
        N_TILES_OUTER_Y[AV] = 1;
        N_TILES_OUTER_Y[OW] = N_TILES_SEQUENCE_DIM;
        N_TILES_OUTER_Y[F1] = N_TILES_SEQUENCE_DIM;
        N_TILES_OUTER_Y[F2] = N_TILES_SEQUENCE_DIM;
        N_TILES_INNER_DIM[Q] = N_TILES_EMBEDDING_DIM;
        N_TILES_INNER_DIM[K] = N_TILES_EMBEDDING_DIM;
        N_TILES_INNER_DIM[V] = N_TILES_EMBEDDING_DIM;
        N_TILES_INNER_DIM[QK] = N_TILES_PROJECTION_DIM;
        N_TILES_INNER_DIM[AV] = N_TILES_SEQUENCE_DIM;
        N_TILES_INNER_DIM[OW] = N_TILES_PROJECTION_DIM;
        N_TILES_INNER_DIM[F1] = N_TILES_EMBEDDING_DIM;
        N_TILES_INNER_DIM[F2] = N_TILES_FEEDFORWARD_DIM;

        BASE_PTR[0] = 0;
        BASE_PTR[1] = BASE_PTR[0] + SEQUENCE_LEN * EMBEDDING_SIZE;
        BASE_PTR[2] = BASE_PTR[1] + SEQUENCE_LEN * EMBEDDING_SIZE;
        BASE_PTR[3] = BASE_PTR[2] + PROJECTION_SPACE * EMBEDDING_SIZE;
        BASE_PTR[4] = BASE_PTR[3] + PROJECTION_SPACE * EMBEDDING_SIZE;
        BASE_PTR[5] = BASE_PTR[4] + PROJECTION_SPACE * EMBEDDING_SIZE;
        BASE_PTR[6] = BASE_PTR[5] + PROJECTION_SPACE * EMBEDDING_SIZE;
        BASE_PTR[7] = BASE_PTR[6] + PROJECTION_SPACE * 3;
        BASE_PTR[8] = BASE_PTR[7] + PROJECTION_SPACE * 3;
        BASE_PTR[9] = BASE_PTR[8] + PROJECTION_SPACE * 3;
        BASE_PTR[10] = BASE_PTR[9] + EMBEDDING_SIZE * 3;
        BASE_PTR[11] = BASE_PTR[10] + SEQUENCE_LEN * EMBEDDING_SIZE;
        BASE_PTR[12] = BASE_PTR[11] + EMBEDDING_SIZE * FEEDFORWARD_SIZE;
        BASE_PTR[13] = BASE_PTR[12] + FEEDFORWARD_SIZE * EMBEDDING_SIZE;
        BASE_PTR[14] = BASE_PTR[13] + FEEDFORWARD_SIZE * 3;
        BASE_PTR[15] = BASE_PTR[14] + EMBEDDING_SIZE * 3;
        BASE_PTR[16] = BASE_PTR[15] + SEQUENCE_LEN * PROJECTION_SPACE;
        BASE_PTR[17] = BASE_PTR[16] + SEQUENCE_LEN * PROJECTION_SPACE;
        BASE_PTR[18] = BASE_PTR[17] + SEQUENCE_LEN * PROJECTION_SPACE;
        BASE_PTR[19] = BASE_PTR[18] + SEQUENCE_LEN * SEQUENCE_LEN;
        BASE_PTR[20] = BASE_PTR[19] + SEQUENCE_LEN * PROJECTION_SPACE;
        BASE_PTR[21] = BASE_PTR[20] + SEQUENCE_LEN * EMBEDDING_SIZE;
        BASE_PTR[22] = BASE_PTR[21] + SEQUENCE_LEN * FEEDFORWARD_SIZE;

        BASE_PTR_INPUT[Q] = BASE_PTR[0];
        BASE_PTR_INPUT[K] = BASE_PTR[1];
        BASE_PTR_INPUT[V] = BASE_PTR[4];
        BASE_PTR_INPUT[QK] = BASE_PTR[15];
        BASE_PTR_INPUT[AV] = BASE_PTR[18];
        BASE_PTR_INPUT[OW] = BASE_PTR[19];
        BASE_PTR_INPUT[F1] = BASE_PTR[10];
        BASE_PTR_INPUT[F2] = BASE_PTR[21];
        BASE_PTR_WEIGHT0[Q] = BASE_PTR[2];
        BASE_PTR_WEIGHT0[K] = BASE_PTR[3];
        BASE_PTR_WEIGHT0[V] = BASE_PTR[1];
        BASE_PTR_WEIGHT0[QK] = BASE_PTR[16];
        BASE_PTR_WEIGHT0[AV] = BASE_PTR[17];
        BASE_PTR_WEIGHT0[OW] = BASE_PTR[5];
        BASE_PTR_WEIGHT0[F1] = BASE_PTR[11];
        BASE_PTR_WEIGHT0[F2] = BASE_PTR[12];
        BASE_PTR_BIAS[Q] = BASE_PTR[6];
        BASE_PTR_BIAS[K] = BASE_PTR[7];
        BASE_PTR_BIAS[V] = BASE_PTR[8];
        BASE_PTR_BIAS[QK] = 32'hXXXX;
        BASE_PTR_BIAS[AV] = 32'hXXXX;
        BASE_PTR_BIAS[OW] = BASE_PTR[9];
        BASE_PTR_BIAS[F1] = BASE_PTR[13];
        BASE_PTR_BIAS[F2] = BASE_PTR[14];
        BASE_PTR_OUTPUT[Q] = BASE_PTR[15];
        BASE_PTR_OUTPUT[K] = BASE_PTR[16];
        BASE_PTR_OUTPUT[V] = BASE_PTR[17];
        BASE_PTR_OUTPUT[QK] = BASE_PTR[18];
        BASE_PTR_OUTPUT[AV] = BASE_PTR[19];
        BASE_PTR_OUTPUT[OW] = BASE_PTR[20];
        BASE_PTR_OUTPUT[F1] = BASE_PTR[21];
        BASE_PTR_OUTPUT[F2] = BASE_PTR[22];

        for (int i = 0; i < 5; i++) begin
            BASE_PTR_WEIGHT1[i] = BASE_PTR_WEIGHT0[i+1];
        end
        BASE_PTR_WEIGHT1[7] = BASE_PTR_WEIGHT0[F2];
    end
    
    // --- FSM Sequential Logic ---
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            current_state <= S_IDLE;
            current_step_r <= Idle;
        end else begin
            current_state <= next_state;
            current_step_r <= next_step;
        end
    end

    // --- FSM Combinational Logic ---
    always_comb begin
        // Default assignments
        next_state = current_state;
        next_step = current_step_r;
        sequencer_start = 1'b0;

        case (current_state)
            S_IDLE: begin
                if (start_wb_i)   next_state = S_SETUP_WB;
                if (start_attn_i) next_state = S_SETUP_ATTN;
                if (start_ffn_i)  next_state = S_SETUP_FFN;
            end

            S_SETUP_WB:   if (dma_write_done_i) next_state = S_IDLE;
            S_SETUP_ATTN: if (dma_write_done_i) begin next_state = S_RUN_ATTN; next_step = Q; end
            S_SETUP_FFN:  if (dma_write_done_i) begin next_state = S_RUN_FFN;  next_step = F1; end

            S_RUN_ATTN: begin
                sequencer_start = 1'b1;
                if (sequencer_done) begin
                    case (current_step_r)
                        Q:  next_step = K;
                        K:  next_step = V;
                        V:  next_step = QK;
                        QK: next_step = AV;
                        AV: next_step = OW;
                        OW: begin next_state = S_DONE_ATTN; next_step = Idle; end
                        default: next_step = Idle;
                    endcase
                end
            end

            S_DONE_ATTN: if (dma_read_done_i) next_state = S_IDLE;

            S_RUN_FFN: begin
                sequencer_start = 1'b1;
                if (sequencer_done) begin
                    case (current_step_r)
                        F1: next_step = F2;
                        F2: begin next_state = S_DONE_FFN; next_step = Idle; end
                        default: next_step = Idle;
                    endcase
                end
            end

            S_DONE_FFN: if (dma_read_done_i) next_state = S_IDLE;

            default: next_state = S_IDLE;
        endcase
    end

    // --- FSM Output Logic ---
    assign accelerator_idle_o = (current_state == S_IDLE);
    assign wb_done_o          = (current_state == S_SETUP_WB && dma_write_done_i);
    assign attn_done_o        = (current_state == S_DONE_ATTN);
    assign ffn_done_o         = (current_state == S_DONE_FFN);

    assign dma_mode = (current_state == S_SETUP_WB) || (current_state == S_SETUP_ATTN) ||
                        (current_state == S_SETUP_FFN) || (current_state == S_DONE_ATTN) ||
                        (current_state == S_DONE_FFN);

    // dma_we_o is 1 for a DMA read (from URAM), 0 for a DMA write (to URAM)
    assign dma_we = (current_state == S_DONE_ATTN) || (current_state == S_DONE_FFN);
    
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
    
    ita_sequencer #(
        .M_TILE_LEN(M_TILE_LEN), 
        .SEQUENCE_LEN(SEQUENCE_LEN), 
        .PROJECTION_SPACE(PROJECTION_SPACE),
        .EMBEDDING_SIZE(EMBEDDING_SIZE), 
        .FEEDFORWARD_SIZE(FEEDFORWARD_SIZE),
        .ACTIVATION(ACTIVATION), 
        .SINGLE_ATTENTION(SINGLE_ATTENTION), 
        .N_CONTEXT(N_CONTEXT)
    ) i_ita_sequencer (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .start_i(sequencer_start),
        .step_i(current_step_r),
        .done_o(sequencer_done),
        .hwpe_busy_i(busy_o),
        .periph_req_o(periph_req_seq),
        .periph_gnt_i(periph_gnt_seq),
        .periph_add_o(periph_add_seq),
        .periph_wen_o(periph_wen_seq),
        .periph_be_o(periph_be_seq),
        .periph_data_o(periph_data_seq),
        .BASE_PTR_INPUT(BASE_PTR_INPUT), 
        .BASE_PTR_WEIGHT0(BASE_PTR_WEIGHT0),
        .BASE_PTR_WEIGHT1(BASE_PTR_WEIGHT1), 
        .BASE_PTR_BIAS(BASE_PTR_BIAS),
        .BASE_PTR_OUTPUT(BASE_PTR_OUTPUT), 
        .N_TILES_SEQUENCE_DIM(N_TILES_SEQUENCE_DIM),
        .N_TILES_EMBEDDING_DIM(N_TILES_EMBEDDING_DIM), 
        .N_TILES_PROJECTION_DIM(N_TILES_PROJECTION_DIM),
        .N_TILES_FEEDFORWARD_DIM(N_TILES_FEEDFORWARD_DIM), 
        .N_TILES_OUTER_X(N_TILES_OUTER_X),
        .N_TILES_OUTER_Y(N_TILES_OUTER_Y), 
        .N_TILES_INNER_DIM(N_TILES_INNER_DIM)
    );

    // --- Instantiate the ITA HWPE Wrapper ---
    ita_hwpe_wrap #(
        .AccDataWidth(AccDataWidth),
        .IdWidth     (IdWidth),
        .MemDataWidth(MemDataWidth)
    ) i_ita_hwpe_wrap (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .test_mode_i  (test_mode_i),
        .evt_o        (evt_o),
        .busy_o       (busy_o),

        // TCDM Master Ports (connected internally)
        .tcdm_req_o   (tcdm_req),
        .tcdm_add_o   (tcdm_add),
        .tcdm_wen_o   (tcdm_wen),
        .tcdm_be_o    (tcdm_be),
        .tcdm_data_o  (tcdm_data),
        .tcdm_gnt_i   (tcdm_gnt),
        .tcdm_r_data_i (tcdm_r_data),
        .tcdm_r_valid_i(tcdm_r_valid),

        // Peripheral Slave Port (exposed to the outside)
        .periph_req_i  (periph_req_seq),
        .periph_gnt_o  (periph_gnt_seq),
        .periph_add_i  (periph_add_seq),
        .periph_wen_i  (periph_wen_seq),
        .periph_be_i   (periph_be_seq),
        .periph_data_i (periph_data_seq),
        .periph_id_i   (ID), // Use the defined ID
        .periph_r_data_o(periph_r_data_seq),
        .periph_r_valid_o(periph_r_valid_seq),
        .periph_r_id_o (periph_r_id_seq)
    );

    // --- Instantiate the URAM Memory Controller ---
    uram_memory_controller_ita_dma #(
        .MP            (MP),
        .TOTAL_WORDS   (TOTAL_WORDS),
        .MEM_INIT_FILES(MEM_INIT_FILES)
    ) i_uram_memory_controller_ita_dma (
        .clk_i (clk_i),
        .rst_ni(rst_ni),
        .tcdm  (tcdm_mem), // Connect the HCI interface array
        
        // Control from FSM
        .dma_mode_i(dma_mode),
        .dma_we_i(dma_we),
        
        // Address gen signals
        .dma_addr_i(uram_addr),
        .dma_addr_valid_i(uram_addr_valid),
        .dma_addr_ready_o(uram_addr_ready),
        
        //  Data in signals (Write)
        .dma_wdata_i(s_axis_tdata),
        .dma_wdata_valid_i(s_axis_tvalid),
        .dma_wdata_ready_o(s_axis_tready),
        
        // Data out signals (Read)
        .dma_rdata_o(m_axis_tdata),
        .dma_rdata_valid_o(m_axis_tvalid),
        .dma_rdata_ready_i(m_axis_tready)
    );
    
    dma_address_generator (
        //================================================================
        // Inputs
        //================================================================
        .clk(clk_i),                        // System clock
        .reset_n(rst_ni),                   // Active-low asynchronous reset
        .en_load(),                         // Pulse to load the base address ####################### TODO CONNECT THIS CORRECTLY.
        .base_address(),                    // The LOGICAL base address from the CPU
        .dma_we(dma_we),                            // Raw Write Enable control: 1 for Write, 0 for Read
        
        //================================================================
        // AXI Stream Master Interface
        //================================================================
        .m_axis_tdata(uram_addr),
        .m_axis_tvalid(uram_addr_valid),
        .m_axis_tready(uram_addr_ready),
        .m_axis_tlast() 
      );

    // --- Connect HWPE TCDM signals to the HCI Interface ---
    generate
        for (genvar i = 0; i < MP; i++) begin : g_tcdm_binding
            // Driving signals from HWPE to Memory Controller
            assign tcdm_mem[i].req  = tcdm_req[i];
            assign tcdm_mem[i].add  = tcdm_add[i];
            assign tcdm_mem[i].wen  = tcdm_wen[i];
            assign tcdm_mem[i].be   = tcdm_be[i];
            assign tcdm_mem[i].data = tcdm_data[i];

            // Driving signals from Memory Controller back to HWPE
            assign tcdm_gnt[i]      = tcdm_mem[i].gnt;
            assign tcdm_r_valid[i]  = tcdm_mem[i].r_valid;
            assign tcdm_r_data[i]   = tcdm_mem[i].r_data;

            // Tie off unused HCI ports to default values
            assign tcdm_mem[i].user     = '0;
            assign tcdm_mem[i].id       = '0;
            assign tcdm_mem[i].ecc      = '0;
            assign tcdm_mem[i].ereq     = '0;
            assign tcdm_mem[i].r_eready = 1'b1;
        end
    endgenerate

endmodule : ITA_FPGA_WRAPPER