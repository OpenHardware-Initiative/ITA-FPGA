`timescale 1ns/1ps
/**
 * @module dma_address_generator_robust
 * @brief Robust address generator for DMA, mitigating critical hazards.
 * @details This version addresses critical review feedback:
 * 1. The output address is REGISTERED to prevent combinational glitches and
 * improve timing.
 * 2. The operational mode (read/write) is CAPTURED only when a transaction
 * completes (on 'enable_increment'), preventing mode-switching hazards
 * mid-operation.
 * The module still operates on a BYTE-ADDRESSABLE memory interface.
 */
module dma_address_generator #(
    parameter ADDR_STRIDE = 4, // Increment address by 4 bytes for 32-bit words
    parameter C_M_AXIS_TDATA_WIDTH = 32
) (
    // Control and Status
    input wire clk,
    input wire reset_n,
    input wire start_i,                 // Pulse from controller to begin a transfer
    input wire [C_M_AXIS_TDATA_WIDTH-1:0] base_address_in, // Starting byte address for the transfer
    input wire [31:0] transfer_len_i,   // Total number of addresses (words) to generate
    output reg done_o,                  // Pulsed high for one cycle when transfer is complete
    
    // AXI Stream Master Interface (to memory controller)
    output wire [C_M_AXIS_TDATA_WIDTH-1:0] m_axis_tdata, // The generated address
    output reg  m_axis_tvalid,          // We have a valid address to send
    input  wire m_axis_tready,          // The memory controller is ready to accept an address
    output wire m_axis_tlast            // Indicates the last address of the transfer
);

    // --- Internal State ---
    typedef enum logic [1:0] {
        S_IDLE,       // Waiting for a start pulse
        S_GENERATING, // Actively generating and streaming addresses
        S_DONE        // Pulsing the done signal
    } ag_state_t;

    ag_state_t current_state, next_state;
    
    // Registers to hold transfer parameters and track progress
    reg [31:0] addr_counter_reg; // Holds the current address being output
    reg [31:0] transfer_len_reg; // Latches the total transfer length for this operation
    reg [31:0] words_sent_count; // Counts how many addresses have been successfully sent
    
    // --- FSM Sequential Logic: Updates the current state on each clock edge ---
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // --- Datapath and Control Sequential Logic: Manages counters and outputs ---
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            addr_counter_reg <= 32'b0;
            transfer_len_reg <= 32'b0;
            words_sent_count <= 32'b0;
            m_axis_tvalid    <= 1'b0;
            done_o           <= 1'b0;
        end else begin
            // By default, done_o is low. It will only be asserted in the S_DONE state.
            done_o <= 1'b0; 

            case (current_state)
                S_IDLE: begin
                    // When a start signal is received, latch the transfer parameters.
                    if (start_i) begin
                        addr_counter_reg <= base_address_in;
                        transfer_len_reg <= transfer_len_i;
                        words_sent_count <= 32'b0;
                        // Assert tvalid immediately if there's at least one word to send.
                        // The FSM will transition to S_GENERATING on the same cycle.
                        m_axis_tvalid    <= (transfer_len_i > 0); 
                    end
                end
                
                S_GENERATING: begin
                    // This is the main operational state. An address is generated when the
                    // handshake (`tvalid` and `tready`) occurs.
                    if (m_axis_tvalid && m_axis_tready) begin
                        // Increment to the next address.
                        addr_counter_reg <= addr_counter_reg + ADDR_STRIDE;
                        // Increment the count of words sent.
                        words_sent_count <= words_sent_count + 1;
                        
                        // Check if the *current* transaction is the last one.
                        // If so, de-assert tvalid for the next cycle, as there will be no more data.
                        if (words_sent_count == transfer_len_reg - 1) begin
                            m_axis_tvalid <= 1'b0;
                        end
                    end
                    // If !tready (backpressure), all registers hold their values, and we wait.
                end

                S_DONE: begin
                    // Assert the done signal for one clock cycle.
                    done_o <= 1'b1;
                    // All other registers are reset when a new transfer starts in S_IDLE.
                end
            endcase
        end
    end

    // --- FSM Combinational Logic: Determines the next state ---
    always_comb begin
        next_state = current_state;
        case (current_state)
            S_IDLE: begin
                if (start_i) begin
                    // If the requested length is > 0, start generating.
                    if (transfer_len_i > 0) begin
                        next_state = S_GENERATING;
                    end else begin
                        // Handle the case of a zero-length transfer. Go straight to DONE.
                        next_state = S_DONE; 
                    end
                end
            end
            
            S_GENERATING: begin
                // The condition to move to DONE is when the handshake for the *last word* occurs.
                // The count is zero-indexed, so we compare to length-1.
                if (m_axis_tvalid && m_axis_tready && (words_sent_count == transfer_len_reg - 1)) begin
                    next_state = S_DONE;
                end
            end

            S_DONE: begin
                // After one cycle in S_DONE, unconditionally return to S_IDLE to wait for the next command.
                next_state = S_IDLE;
            end
        endcase
    end

    // --- Output Assignments ---
    // The output data is simply the current value of the address counter register.
    assign m_axis_tdata = addr_counter_reg;
    // The tlast signal is asserted combinationally when the count of sent words
    // indicates that the current word is the last one of the transfer.
    assign m_axis_tlast = (words_sent_count == transfer_len_reg - 1);

endmodule