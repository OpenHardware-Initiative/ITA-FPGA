`timescale 1ns / 1ps

module ITA_AXI_WRAPPER#(
    parameter integer C_S_AXIS_TDATA_WIDTH = 32,
    parameter integer C_M_AXIS_TDATA_WIDTH = 32,
    parameter integer C_S_AXI_DATA_WIDTH   = 32,
    parameter integer C_S_AXI_ADDR_WIDTH   = 4
) (
    input wire aclk,
    input wire aresetn,

    // SLAVE AXI STREAM
    input wire [C_S_AXIS_TDATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,
    
    // MASTER AXI STREAM
    output wire [C_M_AXIS_TDATA_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire m_axis_tlast,
    
    // SLAVE AXI LITE INTERFACE
    // Write Address Channel
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input wire [2 : 0] S_AXI_AWPROT,
    input wire  S_AXI_AWVALID,
    output wire S_AXI_AWREADY,

    // Write Data Channel
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input wire  S_AXI_WVALID,
    output wire S_AXI_WREADY,

    // Write Response Channel
    output wire [1 : 0] S_AXI_BRESP,
    output wire S_AXI_BVALID,
    input wire  S_AXI_BREADY,

    // Read Address Channel
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input wire [2 : 0] S_AXI_ARPROT,
    input wire  S_AXI_ARVALID,
    output wire S_AXI_ARREADY,

    // Read Data Channel
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [1 : 0] S_AXI_RRESP,
    output wire S_AXI_RVALID,
    input wire  S_AXI_RREADY
    
);
    //================================================================
    // AXI Lite Slave Logic
    //================================================================

    // Internal AXI4LITE signals
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_awaddr;
    reg                             axi_awready;
    reg                             axi_wready;
    reg                             axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_araddr;
    reg                             axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0]    axi_rdata;
    reg                             axi_rvalid;

    // Fixed response signals (OKAY)
    localparam [1:0] RESP_OKAY = 2'b00;

    // User Logic Slave Registers
    reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg0; // Base Address Register
    reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg1; // Control Register
    reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg2; // Status Register

    // I/O Connections for AXI Lite
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = RESP_OKAY; // OKAY response, no errors
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = RESP_OKAY; // OKAY response, no errors
    assign S_AXI_RVALID  = axi_rvalid;
    
    // --- AXI Write Channel Logic ---
    always @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_bvalid  <= 1'b0;
            axi_awaddr  <= 0;
        end
        else begin
            // AWREADY is asserted when slave is ready to accept a new address.
            // It is deasserted when a transaction is in progress.
            if (~axi_awready && S_AXI_BREADY && axi_bvalid) begin
                axi_awready <= 1'b1;
            end else if (S_AXI_AWVALID) begin
                axi_awready <= 1'b0;
            end

            // WREADY is asserted when an address has been latched and slave is ready for data.
            if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID) begin
                 axi_wready <= 1'b1;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                 axi_wready <= 1'b0;
            end

            // Latch the write address when the master provides a valid address
            if (S_AXI_AWVALID && ~axi_awready) begin
                axi_awaddr <= S_AXI_AWADDR;
            end

            // BVALID is asserted when both address and data phases are complete.
            if (axi_wready && S_AXI_WVALID && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
            end 
            else if (axi_bvalid && S_AXI_BREADY) begin
                axi_bvalid <= 1'b0;
            end
        end
    end
    
    
    integer i;
    // --- User Logic: Register Write Logic ---
    always @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
        end 
        else begin
            // Write to registers only when both address and data are valid and accepted
            if (axi_wready && S_AXI_WVALID) begin
                // Address bits [3:2] select the register for a 32-bit data bus
                case (axi_awaddr[C_S_AXI_ADDR_WIDTH-1:2])
                    2'h0: // Address 0x00
                        for (i = 0; i < (C_S_AXI_DATA_WIDTH/8); i = i + 1)
                            if (S_AXI_WSTRB[i])
                                slv_reg0[i*8 +: 8] <= S_AXI_WDATA[i*8 +: 8];
                    2'h1: // Address 0x04
                        
                        for (i = 0; i < (C_S_AXI_DATA_WIDTH/8); i = i + 1)
                            if (S_AXI_WSTRB[i])
                                slv_reg1[i*8 +: 8] <= S_AXI_WDATA[i*8 +: 8];
                    // Writes to other addresses (like the read-only status reg) are ignored
                    default: begin
                        slv_reg0 <= slv_reg0;
                        slv_reg1 <= slv_reg1;
                    end
                endcase
            end
        end
    end

    // --- AXI Read Channel Logic ---
    always @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_araddr  <= 0;
        end 
        else begin
            // ARREADY is asserted when the slave is ready to accept a read address.
            if (~axi_arready && S_AXI_RVALID && S_AXI_RREADY) begin
                axi_arready <= 1'b1;
            end else if(S_AXI_ARVALID) begin
                axi_arready <= 1'b0;
            end

            // Latch the read address from the master
            if (S_AXI_ARVALID && ~axi_arready) begin
                axi_araddr <= S_AXI_ARADDR;
            end

            // RVALID is asserted once a read address is latched.
            if (S_AXI_ARVALID && ~axi_arready) begin
                axi_rvalid <= 1'b1;
            end 
            else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // --- User Logic: Register Read Logic (Combinatorial) ---
    always @(*) begin
        // Address bits [3:2] select the register
        case (axi_araddr[C_S_AXI_ADDR_WIDTH-1:2])
            2'h0:    axi_rdata <= slv_reg0; // Address 0x00
            2'h1:    axi_rdata <= slv_reg1; // Address 0x04
            2'h2:    axi_rdata <= slv_reg2; // Address 0x08
            default: axi_rdata <= 0; // Return 0 for invalid read addresses
        endcase
    end


    //================================================================
    // ITA Core Instantiation and Connections
    //================================================================

    // Wires for connecting registers to the ITA core
    // Control signals (driven by slv_reg1)
    wire start_wb_i;
    wire start_attn_i;
    wire start_ffn_i;
    wire dma_write_done_i;
    wire dma_read_done_i;

    // Status signals (drive slv_reg2)
    wire [1:0] evt_o; // Assuming N_CORES is 1 for this wrapper
    wire       busy_o;
    wire       wb_done_o;
    wire       attn_done_o;
    wire       ffn_done_o;
    wire       accelerator_idle_o;
    wire       dma_mode_o;
    wire       dma_we_o;


    // De-concatenate control register to drive ITA inputs
    assign start_wb_i         = slv_reg1[0];
    assign start_attn_i       = slv_reg1[1];
    assign start_ffn_i        = slv_reg1[2];
    assign dma_write_done_i   = slv_reg1[3];
    assign dma_read_done_i    = slv_reg1[4];

    // Concatenate status outputs from ITA to drive the status register
    // This is a continuous assignment, so the status register is always up-to-date
    always @(*) begin
        slv_reg2 = {23'b0, busy_o, evt_o, dma_we_o, dma_mode_o, accelerator_idle_o, ffn_done_o, attn_done_o, wb_done_o};
    end
    
    // INSTANTIATION OF ITA
    ITA_FPGA_WRAPPER #(
        // Pass through relevant parameters
        .C_S_AXIS_TDATA_WIDTH(C_S_AXIS_TDATA_WIDTH),
        .C_M_AXIS_TDATA_WIDTH(C_M_AXIS_TDATA_WIDTH),
        .M_TILE_LEN(64),
        .SEQUENCE_LEN(128),
        .PROJECTION_SPACE(128),
        .EMBEDDING_SIZE(256),
        .FEEDFORWARD_SIZE(256)
        //.ACTIVATION(Relu) // Assuming Relu is a defined parameter
    ) i_ITA_FPGA_WRAPPER (
        .clk_i(aclk),
        .rst_ni(aresetn),
        .test_mode_i(1'b0),
        
        // Base Address from AXI Register slv_reg0
        .base_addr_i(slv_reg0),

        // Control Inputs from AXI Register slv_reg1
        .start_wb_i(start_wb_i),
        .start_attn_i(start_attn_i),
        .start_ffn_i(start_ffn_i),

        // Status Outputs to AXI Register slv_reg2
        .wb_done_o(wb_done_o),
        .attn_done_o(attn_done_o),
        .ffn_done_o(ffn_done_o),
        .accelerator_idle_o(accelerator_idle_o),

        // DMA/Mux Control
        .dma_mode_o(dma_mode_o),
        .dma_we_o(dma_we_o),

        // HWPE Status
        .evt_o(evt_o),
        .busy_o(busy_o),

        // AXI STREAM SLAVE PORT
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),

        // AXI STREAM MASTER PORT
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready)
    );
    
endmodule