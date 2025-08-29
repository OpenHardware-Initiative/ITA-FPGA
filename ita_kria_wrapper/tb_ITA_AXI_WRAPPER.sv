`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/25/2025 04:17:00 PM
// Design Name: 
// Module Name: tb_ITA_AXI_WRAPPER
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import axi_vip_pkg::*;
import design_1_axi_vip_0_1_pkg::*;
import design_1_axi_vip_1_1_pkg::*;

module tb_ITA_AXI_WRAPPER(

    );
    
   
    // Clock signal
    bit clock;
    // Reset signal
    bit reset;
    
    logic [31:0] read_addr;
    logic [31:0] data;
    

    initial begin 
          reset <= 1'b0;
          clock <= 1'b0; // Initialize clock
          repeat (20) @(posedge clock);  
          reset <= 1'b1;
    end


    // Generates a 100MHz clock (10ns period)
    always #5 clock <= ~clock;

    design_1_axi_vip_0_1_mst_t       mst_agent;
    design_1_axi_vip_1_1_slv_mem_t   slv_agent;

    initial begin
        $display("=== TESTBENCH STARTED ===");
        // NOTE: Verify these hierarchical paths are correct for your design
        mst_agent = new("master vip agent",DUT.design_1_i.axi_vip_0.inst.IF);
        mst_agent.start_master();
        slv_agent = new("slave vip mem agent",DUT.design_1_i.axi_vip_1.inst.IF);
        slv_agent.start_slave();
        
        // MODIFICATION: Removed AXI-Stream VIP agent instantiation and setup
        /*
        str_slv_agent0 = new("slave vip agent",tb.DUT.design_1_i.axi4stream_vip_0.inst.IF);
        str_slv_agent0.vif_proxy.set_dummy_drive_type(XIL_AXI4STREAM_VIF_DRIVE_NONE);
        str_slv_agent0.set_agent_tag("Slave VIP");
        str_slv_agent0.set_verbosity(str_slv_agent_verbosity);
        str_slv_agent0.start_slave();
        */
        
        gen_wready();
        
        // Wait for reset to de-assert
        @(posedge clock);
        while (reset == 1'b0) @(posedge clock);
        @(posedge clock);
        
        // ============================================
        // TEST 1: Weight/Bias Loading
        // ============================================
        
              // Load weight/bias data into memory
        backdoor_mem_write_from_file("wb_data.mem", 32'h40010000, 32'h40011000);
        $display("Loaded weight/bias data to memory range 0x80000000-0x80001000");
        
        master_reg_write(32'h00000008, 32'h40000000); // current descriptor
        master_reg_write(32'h00000000, 32'h00047001); // enable interrupts, run
        
        master_reg_write(32'h40020000, 32'h00000000); // enable interrupts, run
        master_reg_write(32'h40020004, 32'h00000001); // enable interrupts, run
        // Read back configuration (optional, good for debug)
      master_reg_read(32'h00000008, data);
      $display("Read Current Descriptor: Addr=0x00000008, Data=0x%X", data); 
      master_reg_read(32'h00000000, data);
      $display("Read MM2S_DMACR: Addr=0x00000000, Data=0x%X", data);
      
      // Start DMA by writing tail descriptor
      master_reg_write(32'h00000010, 32'h400000C0);
      
      // Read status register before transfer
      master_reg_read(32'h00000004, data);
      $display("Initial MM2S Status Register: Addr=0x00000004, Data=0x%X", data);

//        // Start weight/bias loading in wrapper
//        master_reg_write(32'h40010010, 32'h00000001); // slv_reg1: start_wb_i = 1
//        $display("Started weight/bias loading in wrapper");
        
//        // Start MM2S DMA to feed data to wrapper
//        master_reg_write(32'h40000000, 32'h00001001); // MM2S: enable + run
//        $display("Started MM2S DMA transfer");
        
        // Wait for weight/bias loading completion
        wait_for_wrapper_status(32'h00000001, "Weight/Bias loading");
        
        // Clear start signal
        master_reg_write(32'h40010004, 32'h00000000);
        $display("Weight/Bias loading completed successfully!\n");
        
        
      
   end
   
   // MODIFICATION: Updated DUT instantiation to match your wrapper
   design_1_wrapper DUT (
      .clk_in1_0(clock),
      .reset(reset)
    );
   
  // Task to generate single beat, 32-bit register write transactions
  // This task is generic and does not need modification.
  task master_reg_write;
    input   [design_1_axi_vip_0_1_VIP_ADDR_WIDTH - 1:0]  address;
    input   [design_1_axi_vip_0_1_VIP_DATA_WIDTH - 1:0]  data;
    axi_transaction              wr_transaction;
    xil_axi_uint                 mtestID;
    xil_axi_ulong                mtestADDR;
    xil_axi_len_t                mtestBurstLength;
    xil_axi_size_t               mtestDataSize;
    xil_axi_burst_t              mtestBurstType;
    xil_axi_data_beat [255:0]    mtestWUSER;
    xil_axi_data_beat            mtestAWUSER;
    xil_axi_resp_t               mtestBresp;
    bit [32767:0]                mtestWData;

    mtestID = 0;
    mtestADDR = address;
    mtestBurstLength = 'h0;
    mtestDataSize = XIL_AXI_SIZE_4BYTE;
    mtestBurstType = XIL_AXI_BURST_TYPE_INCR;
    mtestAWUSER = 0;
    mtestWData[design_1_axi_vip_0_1_VIP_DATA_WIDTH - 1:0] = data;

    wr_transaction = mst_agent.wr_driver.create_transaction("write transaction");
    wr_transaction.set_write_cmd(mtestADDR, mtestBurstType, mtestID, mtestBurstLength, mtestDataSize);
    wr_transaction.set_data_block(mtestWData);
    wr_transaction.set_awuser(mtestAWUSER);
    for (xil_axi_uint beat = 0; beat < wr_transaction.get_len()+1; beat++) begin
        wr_transaction.set_wuser(beat, mtestWUSER[beat]);
    end
    wr_transaction.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
    mst_agent.wr_driver.send(wr_transaction);
    mst_agent.wr_driver.wait_rsp(wr_transaction);
    mtestBresp = wr_transaction.get_bresp();
    $display("MASTER_WRITE: Addr=0x%08h, Data=0x%08h, Resp=0x%h", address, data, mtestBresp);
  endtask :master_reg_write

  // MODIFIED TASK: Replaced with the version from your working example.
  task master_reg_read;
    input   [design_1_axi_vip_0_1_VIP_ADDR_WIDTH - 1:0]  address;
    output  [design_1_axi_vip_0_1_VIP_DATA_WIDTH - 1:0]  data;
    axi_transaction              rd_transaction;
    xil_axi_uint                 mtestID;
    xil_axi_ulong                mtestADDR;
    xil_axi_len_t                mtestBurstLength;
    xil_axi_size_t               mtestDataSize;
    xil_axi_burst_t              mtestBurstType;

    mtestID = 0;
    mtestADDR = address;
    mtestBurstLength = 'h0;
    mtestDataSize = XIL_AXI_SIZE_4BYTE;
    mtestBurstType = XIL_AXI_BURST_TYPE_INCR;

    rd_transaction = mst_agent.rd_driver.create_transaction("read transaction");
    rd_transaction.set_read_cmd(mtestADDR, mtestBurstType, mtestID, mtestBurstLength, mtestDataSize);
    rd_transaction.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
    mst_agent.rd_driver.send(rd_transaction);
    mst_agent.rd_driver.wait_rsp(rd_transaction);
    data = rd_transaction.get_data_beat(0);
    $display("MASTER_READ: Addr=0x%08h, Data=0x%08h", address, data);
 endtask :master_reg_read
  // Task to write to memory model from file
  // This task needs modification to use the correct memory model and address width.
task backdoor_mem_write_from_file;
  input string        file_name;
  input xil_axi_ulong start_addr;
  input xil_axi_ulong stop_addr;
  
  // A local memory to temporarily hold the file contents
  reg [31:0] mem [0:127];
  
  // The address for writing into the VIP's memory model
  bit [31:0] mem_wr_addr;
  
  // Read the hex file into the local 'mem' array
  $readmemh(file_name, mem);
  
  // Populate the AXI Slave VIP's memory model
  // This loop iterates through the target memory addresses and uses
  // a bitmask to calculate the corresponding index into the local 'mem' array.
  for (mem_wr_addr = start_addr; mem_wr_addr < stop_addr; mem_wr_addr += 4) begin
    // Get the data from the local 'mem' array using the calculated index
    bit [31:0] data_to_write = mem[(mem_wr_addr & 32'h000001FF) >> 2];
    
    // Write the data to the VIP's memory model at the specified address
    slv_agent.mem_model.backdoor_memory_write_4byte(mem_wr_addr, data_to_write, 4'hF);
  end
endtask :backdoor_mem_write_from_file

  // Task to set slave AXI VIP wready policy to always asserted
  task gen_wready();
    axi_ready_gen wready_gen;
    wready_gen = slv_agent.wr_driver.create_ready("wready");
    wready_gen.set_ready_policy(XIL_AXI_READY_GEN_NO_BACKPRESSURE);
    slv_agent.wr_driver.send_wready(wready_gen);
  endtask :gen_wready
  
  // MODIFICATION: Removed the slv0_gen_tready task as it's not needed.


// Add this task after your other task definitions
task wait_for_wrapper_status;
    input [31:0] status_mask;
    input string operation_name;
    
    logic [31:0] timeout_counter;
    logic [31:0] status_data;
    timeout_counter = 0;
    
    $display("Waiting for %s to complete...", operation_name);
    
    do begin
        master_reg_read(32'h40010008, status_data); // Read wrapper status
        repeat(10) @(posedge clock);
        timeout_counter++;
        
        if (timeout_counter > 1000) begin
            $error("Timeout waiting for %s completion!", operation_name);
            $finish;
        end
    end while (!(status_data & status_mask));
    
    $display("%s completed (status: 0x%08X)", operation_name, status_data);
endtask


endmodule
