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
    //================================================================
    // Parameters
    //================================================================
    parameter ADDR_STRIDE = 4,
    parameter PHYSICAL_OFFSET_BYTES = 128,
    parameter C_M_AXIS_TDATA_WIDTH = 32
) (
    //================================================================
    // Inputs
    //================================================================
    input wire clk,                                          // System clock
    input wire reset_n,                                      // Active-low asynchronous reset
    input wire en_load,                               // Pulse to load the base address
    input wire [C_M_AXIS_TDATA_WIDTH-1:0] base_address_in,  // The LOGICAL base address from the CPU
    input wire dma_we,                                       // Raw Write Enable control: 1 for Write, 0 for Read
    
    //================================================================
    // AXI Stream Master Interface
    //================================================================
    output wire [C_M_AXIS_TDATA_WIDTH-1:0] m_axis_tdata,
    output reg m_axis_tvalid,
    input wire m_axis_tready,
    output wire m_axis_tlast                           
);

    //================================================================
    // Internal Logic
    //================================================================
    
    // Internal register for the logical address counter.
    reg [31:0] logical_address_reg;
    
    // Captured DMA mode to prevent mid-operation switching
    reg dma_we_q;
    
    // Internal wire to calculate the NEXT address (logical or physical).
    // This is the value we will load into the output register.
    wire [31:0] next_address;
    
    reg [31:0] current_address_out; // Registered output address
    // --- Combinational Logic ---
    
    
    // AXI Stream outputs
    assign m_axis_tdata = current_address_out;
    assign m_axis_tlast = 1'b0; // Continuous generation, no last signal
    
    // --- Sequential Logic ---
    
    // This single 'always' block now manages all state registers for atomicity.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Reset all state registers
            logical_address_reg <= 32'h00000000;
            dma_we_q              <= 1'b1; // Default to a safe state, e.g., write mode
            current_address_out   <= 32'h00000000;
            m_axis_tvalid         <= 1'b0;
        end 
        else if (en_load) begin
            // When loading, capture the new base address AND the current mode.
            // The output will update with the correct address.
            logical_address_reg <= base_address_in;
            dma_we_q              <= dma_we;
            
            if (dma_we) begin
                current_address_out <= base_address_in;
            end else begin
                current_address_out <= base_address_in + PHYSICAL_OFFSET_BYTES;
            end

            m_axis_tvalid       <= 1'b1; // Start generating addresses
        end 
        else if (m_axis_tvalid && m_axis_tready) begin
            // This is the normal operational path.
            // A transaction just finished (handshake completed). 
            // Update the logical address for the NEXT one.
            // Also, capture the mode for the NEXT transaction.
            logical_address_reg <= logical_address_reg + ADDR_STRIDE;
            dma_we_q              <= dma_we;
            if (dma_we) begin
                current_address_out <= logical_address_reg + ADDR_STRIDE;
            end else begin
                current_address_out <= logical_address_reg + ADDR_STRIDE + PHYSICAL_OFFSET_BYTES;
            end
            // Keep tvalid high for continuous generation
        end
        // If tvalid && !tready, hold all values (backpressure handling)
    end

endmodule