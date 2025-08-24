`timescale 1ns/1ps

module uram_memory_controller_ita_dma
#(
  parameter int MP = 32,
  parameter int TOTAL_WORDS = 131072,
  parameter string MEM_INIT_FILES [MP-1:0] = '{default:"none"}
)
(
  input  logic clk_i,
  input  logic rst_ni,

  // --- Interface for ITA Accelerator ---
  hci_core_intf.target tcdm [MP-1:0],

  input  logic        dma_mode_i,       // 0=ITA Mode, 1=DMA Mode
  input  logic        dma_we_i,         // 1=Write to URAM (Load), 0=Read from URAM (Writeback)

  // Unified Address Channel
  input  logic        dma_addr_valid_i,
  input  logic [31:0] dma_addr_i,
  output logic        dma_addr_ready_o,

  // Write Data Channel (from DMA to URAMs)
  input  logic        dma_wdata_valid_i,
  input  logic [31:0] dma_wdata_i,
  output logic        dma_wdata_ready_o,

  // Read Data Channel (from URAMs to DMA)
  output logic        dma_rdata_valid_o,
  output logic [31:0] dma_rdata_o,
  input  logic        dma_rdata_ready_i
);

  // --- Geometry and Internal Signals ---
  localparam int BANK_DEPTH_WORDS = (TOTAL_WORDS + MP - 1) / MP;
  localparam int BANK_ADDR_W      = $clog2(BANK_DEPTH_WORDS);
  localparam int BANK_SEL_W       = $clog2(MP);
  localparam int BANK_ADDR_OFFSET = 2;

  // Final muxed inputs to the URAM primitives
  logic [MP-1:0][BANK_ADDR_W-1:0] bank_addra, bank_addrb;
  logic [MP-1:0][31:0]            bank_dinb;
  logic [MP-1:0][3:0]             bank_web;
  logic [MP-1:0]                  bank_ena, bank_enb;
  logic [MP-1:0][31:0]            bank_douta;

  // Signals from ITA crossbar
  logic [MP-1:0][BANK_ADDR_W-1:0] ita_bank_addra, ita_bank_addrb;
  logic [MP-1:0][31:0]            ita_bank_dinb;
  logic [MP-1:0][3:0]             ita_bank_web;
  logic [MP-1:0]                  ita_bank_ena, ita_bank_enb;

  // Signals from DMA crossbar
  logic [MP-1:0][BANK_ADDR_W-1:0] dma_bank_addra, dma_bank_addrb;
  logic [MP-1:0][31:0]            dma_bank_dinb;
  logic [MP-1:0][3:0]             dma_bank_web;
  logic [MP-1:0]                  dma_bank_ena, dma_bank_enb;


  // ====================================================================
  // --- ITA Crossbar Logic ---
  // ====================================================================
// Grant generation for ITA
generate for (genvar i = 0; i < MP; i++)
  assign tcdm[i].gnt = tcdm[i].req; 
endgenerate

// Crossbar arbitration logic for ITA
generate for (genvar i = 0; i < MP; i++) begin : g_ita_bank_logic
  // --- Write Crossbar to URAM Bank 'i' (from ITA) ---
  always_comb begin
  ita_bank_enb[i]   = 1'b0;
  ita_bank_addrb[i] = '0;
  ita_bank_dinb[i]  = '0;
  ita_bank_web[i]   = '0;

  case (1'b1)
    (tcdm[0].gnt && !tcdm[0].wen && (tcdm[0].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[0].add/(MP*4); ita_bank_dinb[i]=tcdm[0].data; ita_bank_web[i]=tcdm[0].be; end
    (tcdm[1].gnt && !tcdm[1].wen && (tcdm[1].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[1].add/(MP*4); ita_bank_dinb[i]=tcdm[1].data; ita_bank_web[i]=tcdm[1].be; end
    (tcdm[2].gnt && !tcdm[2].wen && (tcdm[2].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[2].add/(MP*4); ita_bank_dinb[i]=tcdm[2].data; ita_bank_web[i]=tcdm[2].be; end
    (tcdm[3].gnt && !tcdm[3].wen && (tcdm[3].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[3].add/(MP*4); ita_bank_dinb[i]=tcdm[3].data; ita_bank_web[i]=tcdm[3].be; end
    (tcdm[4].gnt && !tcdm[4].wen && (tcdm[4].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[4].add/(MP*4); ita_bank_dinb[i]=tcdm[4].data; ita_bank_web[i]=tcdm[4].be; end
    (tcdm[5].gnt && !tcdm[5].wen && (tcdm[5].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[5].add/(MP*4); ita_bank_dinb[i]=tcdm[5].data; ita_bank_web[i]=tcdm[5].be; end
    (tcdm[6].gnt && !tcdm[6].wen && (tcdm[6].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[6].add/(MP*4); ita_bank_dinb[i]=tcdm[6].data; ita_bank_web[i]=tcdm[6].be; end
    (tcdm[7].gnt && !tcdm[7].wen && (tcdm[7].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[7].add/(MP*4); ita_bank_dinb[i]=tcdm[7].data; ita_bank_web[i]=tcdm[7].be; end
    (tcdm[8].gnt && !tcdm[8].wen && (tcdm[8].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[8].add/(MP*4); ita_bank_dinb[i]=tcdm[8].data; ita_bank_web[i]=tcdm[8].be; end
    (tcdm[9].gnt && !tcdm[9].wen && (tcdm[9].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[9].add/(MP*4); ita_bank_dinb[i]=tcdm[9].data; ita_bank_web[i]=tcdm[9].be; end
    (tcdm[10].gnt && !tcdm[10].wen && (tcdm[10].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[10].add/(MP*4); ita_bank_dinb[i]=tcdm[10].data; ita_bank_web[i]=tcdm[10].be; end
    (tcdm[11].gnt && !tcdm[11].wen && (tcdm[11].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[11].add/(MP*4); ita_bank_dinb[i]=tcdm[11].data; ita_bank_web[i]=tcdm[11].be; end
    (tcdm[12].gnt && !tcdm[12].wen && (tcdm[12].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[12].add/(MP*4); ita_bank_dinb[i]=tcdm[12].data; ita_bank_web[i]=tcdm[12].be; end
    (tcdm[13].gnt && !tcdm[13].wen && (tcdm[13].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[13].add/(MP*4); ita_bank_dinb[i]=tcdm[13].data; ita_bank_web[i]=tcdm[13].be; end
    (tcdm[14].gnt && !tcdm[14].wen && (tcdm[14].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[14].add/(MP*4); ita_bank_dinb[i]=tcdm[14].data; ita_bank_web[i]=tcdm[14].be; end
    (tcdm[15].gnt && !tcdm[15].wen && (tcdm[15].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[15].add/(MP*4); ita_bank_dinb[i]=tcdm[15].data; ita_bank_web[i]=tcdm[15].be; end
    (tcdm[16].gnt && !tcdm[16].wen && (tcdm[16].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[16].add/(MP*4); ita_bank_dinb[i]=tcdm[16].data; ita_bank_web[i]=tcdm[16].be; end
    (tcdm[17].gnt && !tcdm[17].wen && (tcdm[17].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[17].add/(MP*4); ita_bank_dinb[i]=tcdm[17].data; ita_bank_web[i]=tcdm[17].be; end
    (tcdm[18].gnt && !tcdm[18].wen && (tcdm[18].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[18].add/(MP*4); ita_bank_dinb[i]=tcdm[18].data; ita_bank_web[i]=tcdm[18].be; end
    (tcdm[19].gnt && !tcdm[19].wen && (tcdm[19].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[19].add/(MP*4); ita_bank_dinb[i]=tcdm[19].data; ita_bank_web[i]=tcdm[19].be; end
    (tcdm[20].gnt && !tcdm[20].wen && (tcdm[20].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[20].add/(MP*4); ita_bank_dinb[i]=tcdm[20].data; ita_bank_web[i]=tcdm[20].be; end
    (tcdm[21].gnt && !tcdm[21].wen && (tcdm[21].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[21].add/(MP*4); ita_bank_dinb[i]=tcdm[21].data; ita_bank_web[i]=tcdm[21].be; end
    (tcdm[22].gnt && !tcdm[22].wen && (tcdm[22].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[22].add/(MP*4); ita_bank_dinb[i]=tcdm[22].data; ita_bank_web[i]=tcdm[22].be; end
    (tcdm[23].gnt && !tcdm[23].wen && (tcdm[23].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[23].add/(MP*4); ita_bank_dinb[i]=tcdm[23].data; ita_bank_web[i]=tcdm[23].be; end
    (tcdm[24].gnt && !tcdm[24].wen && (tcdm[24].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[24].add/(MP*4); ita_bank_dinb[i]=tcdm[24].data; ita_bank_web[i]=tcdm[24].be; end
    (tcdm[25].gnt && !tcdm[25].wen && (tcdm[25].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[25].add/(MP*4); ita_bank_dinb[i]=tcdm[25].data; ita_bank_web[i]=tcdm[25].be; end
    (tcdm[26].gnt && !tcdm[26].wen && (tcdm[26].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[26].add/(MP*4); ita_bank_dinb[i]=tcdm[26].data; ita_bank_web[i]=tcdm[26].be; end
    (tcdm[27].gnt && !tcdm[27].wen && (tcdm[27].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[27].add/(MP*4); ita_bank_dinb[i]=tcdm[27].data; ita_bank_web[i]=tcdm[27].be; end
    (tcdm[28].gnt && !tcdm[28].wen && (tcdm[28].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[28].add/(MP*4); ita_bank_dinb[i]=tcdm[28].data; ita_bank_web[i]=tcdm[28].be; end
    (tcdm[29].gnt && !tcdm[29].wen && (tcdm[29].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[29].add/(MP*4); ita_bank_dinb[i]=tcdm[29].data; ita_bank_web[i]=tcdm[29].be; end
    (tcdm[30].gnt && !tcdm[30].wen && (tcdm[30].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[30].add/(MP*4); ita_bank_dinb[i]=tcdm[30].data; ita_bank_web[i]=tcdm[30].be; end
    (tcdm[31].gnt && !tcdm[31].wen && (tcdm[31].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_enb[i]=1'b1; ita_bank_addrb[i]=tcdm[31].add/(MP*4); ita_bank_dinb[i]=tcdm[31].data; ita_bank_web[i]=tcdm[31].be; end
    default: ;
  endcase
end


  // --- Read Request Crossbar to URAM Bank 'i' (from ITA) ---
always_comb begin
  ita_bank_ena[i]   = 1'b0;
  ita_bank_addra[i] = '0;

  case (1'b1)
    (tcdm[0].gnt && tcdm[0].wen && (tcdm[0].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[0].add/(MP*4); end
    (tcdm[1].gnt && tcdm[1].wen && (tcdm[1].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[1].add/(MP*4); end
    (tcdm[2].gnt && tcdm[2].wen && (tcdm[2].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[2].add/(MP*4); end
    (tcdm[3].gnt && tcdm[3].wen && (tcdm[3].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[3].add/(MP*4); end
    (tcdm[4].gnt && tcdm[4].wen && (tcdm[4].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[4].add/(MP*4); end
    (tcdm[5].gnt && tcdm[5].wen && (tcdm[5].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[5].add/(MP*4); end
    (tcdm[6].gnt && tcdm[6].wen && (tcdm[6].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[6].add/(MP*4); end
    (tcdm[7].gnt && tcdm[7].wen && (tcdm[7].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[7].add/(MP*4); end
    (tcdm[8].gnt && tcdm[8].wen && (tcdm[8].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[8].add/(MP*4); end
    (tcdm[9].gnt && tcdm[9].wen && (tcdm[9].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[9].add/(MP*4); end
    (tcdm[10].gnt && tcdm[10].wen && (tcdm[10].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[10].add/(MP*4); end
    (tcdm[11].gnt && tcdm[11].wen && (tcdm[11].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[11].add/(MP*4); end
    (tcdm[12].gnt && tcdm[12].wen && (tcdm[12].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[12].add/(MP*4); end
    (tcdm[13].gnt && tcdm[13].wen && (tcdm[13].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[13].add/(MP*4); end
    (tcdm[14].gnt && tcdm[14].wen && (tcdm[14].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[14].add/(MP*4); end
    (tcdm[15].gnt && tcdm[15].wen && (tcdm[15].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[15].add/(MP*4); end
    (tcdm[16].gnt && tcdm[16].wen && (tcdm[16].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[16].add/(MP*4); end
    (tcdm[17].gnt && tcdm[17].wen && (tcdm[17].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[17].add/(MP*4); end
    (tcdm[18].gnt && tcdm[18].wen && (tcdm[18].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[18].add/(MP*4); end
    (tcdm[19].gnt && tcdm[19].wen && (tcdm[19].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[19].add/(MP*4); end
    (tcdm[20].gnt && tcdm[20].wen && (tcdm[20].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[20].add/(MP*4); end
    (tcdm[21].gnt && tcdm[21].wen && (tcdm[21].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[21].add/(MP*4); end
    (tcdm[22].gnt && tcdm[22].wen && (tcdm[22].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[22].add/(MP*4); end
    (tcdm[23].gnt && tcdm[23].wen && (tcdm[23].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[23].add/(MP*4); end
    (tcdm[24].gnt && tcdm[24].wen && (tcdm[24].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[24].add/(MP*4); end
    (tcdm[25].gnt && tcdm[25].wen && (tcdm[25].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[25].add/(MP*4); end
    (tcdm[26].gnt && tcdm[26].wen && (tcdm[26].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[26].add/(MP*4); end
    (tcdm[27].gnt && tcdm[27].wen && (tcdm[27].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[27].add/(MP*4); end
    (tcdm[28].gnt && tcdm[28].wen && (tcdm[28].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[28].add/(MP*4); end
    (tcdm[29].gnt && tcdm[29].wen && (tcdm[29].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[29].add/(MP*4); end
    (tcdm[30].gnt && tcdm[30].wen && (tcdm[30].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[30].add/(MP*4); end
    (tcdm[31].gnt && tcdm[31].wen && (tcdm[31].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
      begin ita_bank_ena[i]=1'b1; ita_bank_addra[i]=tcdm[31].add/(MP*4); end
    default: ;
  endcase
end
end endgenerate


// Read Return Path for ITA
generate for (genvar i = 0; i < MP; i++) begin : g_ita_port_return_logic
  // This logic is correct as it reads from the shared `bank_douta` signal.
  // Ensure this is the correct version (DIRECT or REVERSED) for your HWPE.
  // Assuming DIRECT path here for the example:
  logic                  port_is_reading_q;
  logic [BANK_SEL_W-1:0] read_target_bank_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
          port_is_reading_q  <= 1'b0;
          read_target_bank_q <= '0;
      end else begin
          port_is_reading_q  <= tcdm[i].gnt & tcdm[i].wen;
          read_target_bank_q <= tcdm[i].add[BANK_ADDR_OFFSET +: BANK_SEL_W];
      end
  end
  assign tcdm[i].r_valid = port_is_reading_q;
  assign tcdm[i].r_data  = port_is_reading_q ? bank_douta[read_target_bank_q] : 'z;
  assign tcdm[i].r_user = '0;
  assign tcdm[i].r_id = '0;
  assign tcdm[i].r_opc = '0;
  assign tcdm[i].r_ecc = '0;
  assign tcdm[i].egnt = '0;
  assign tcdm[i].r_evalid = '0;
end endgenerate


  /// ====================================================================
  // --- UNIFIED Streaming DMA Crossbar Logic ---
  // ====================================================================

  // --- Handshake Logic ---
  logic dma_write_go;
  logic dma_read_go;

  // A "go" for a write requires a valid address AND valid write data.
  assign dma_write_go = dma_addr_valid_i & dma_wdata_valid_i;
  
  // A "go" for a read requires a valid address AND a ready destination.
  assign dma_read_go  = dma_addr_valid_i & dma_rdata_ready_i;

  // We are ready for an address if we can perform the requested operation.
  assign dma_addr_ready_o = dma_we_i ? dma_write_go : dma_read_go;

  // We are ready to accept write data only when we are performing a write.
  assign dma_wdata_ready_o = dma_we_i & dma_addr_valid_i;


  // --- Address Decoding ---
  logic [BANK_SEL_W-1:0]  dma_target_bank;
  logic [BANK_ADDR_W-1:0] dma_local_addr;
  assign dma_target_bank = dma_addr_i[BANK_ADDR_OFFSET +: BANK_SEL_W];
  assign dma_local_addr  = dma_addr_i / (MP*4);


  // --- Read Return Path Pipelining ---
  logic read_in_flight_q;
  logic [BANK_SEL_W-1:0] read_target_bank_q;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      read_in_flight_q <= 1'b0;
      read_target_bank_q <= '0;
    end else begin
      // A read is considered "in flight" if we started one in the previous cycle.
      read_in_flight_q <= (dma_mode_i && ~dma_we_i && dma_read_go);
      if (dma_mode_i && ~dma_we_i && dma_read_go) begin
        read_target_bank_q <= dma_target_bank;
      end
    end
  end

  assign dma_rdata_valid_o = read_in_flight_q;
  assign dma_rdata_o = bank_douta[read_target_bank_q];


  // --- DMA to URAM Crossbar (Demux) ---
  generate
    for (genvar i = 0; i < MP; i++) begin : g_dma_bank_logic
        always_comb begin
            logic is_target_bank = (i == dma_target_bank);
            
            // Default all signals to disabled
            dma_bank_enb[i]   = 1'b0;
            dma_bank_addrb[i] = '0;
            dma_bank_dinb[i]  = '0;
            dma_bank_web[i]   = '0;
            dma_bank_ena[i]   = 1'b0;
            dma_bank_addra[i] = '0;

            // Activate write port if it's a write operation targeting this bank
            if (dma_we_i && dma_write_go && is_target_bank) begin
                dma_bank_enb[i]   = 1'b1;
                dma_bank_addrb[i] = dma_local_addr;
                dma_bank_dinb[i]  = dma_wdata_i;
                dma_bank_web[i]   = 4'hF;
            end
            
            // Activate read port if it's a read operation targeting this bank
            if (~dma_we_i && dma_read_go && is_target_bank) begin
                dma_bank_ena[i]   = 1'b1;
                dma_bank_addra[i] = dma_local_addr;
            end
        end
    end
  endgenerate


  // ====================================================================
  // --- Top-Level URAM Arbitration Muxing ---
  // ====================================================================
  generate
    for (genvar i = 0; i < MP; i++) begin : g_arbitration_mux
        assign bank_ena[i]   = dma_mode_i ? dma_bank_ena[i]   : ita_bank_ena[i];
        assign bank_addra[i] = dma_mode_i ? dma_bank_addra[i] : ita_bank_addra[i];
        assign bank_enb[i]   = dma_mode_i ? dma_bank_enb[i]   : ita_bank_enb[i];
        assign bank_addrb[i] = dma_mode_i ? dma_bank_addrb[i] : ita_bank_addrb[i];
        assign bank_dinb[i]  = dma_mode_i ? dma_bank_dinb[i]  : ita_bank_dinb[i];
        assign bank_web[i]   = dma_mode_i ? dma_bank_web[i]   : ita_bank_web[i];
    end
  endgenerate


   // ====================================================================
  // --- URAM Primitive Instantiation ---
  // ====================================================================
  generate
    for (genvar i = 0; i < MP; i++) begin : g_uram_instance
      xpm_memory_tdpram #(
        .MEMORY_SIZE        (BANK_DEPTH_WORDS * 32),
        .MEMORY_PRIMITIVE   ("ultra"),
        .ADDR_WIDTH_A       (BANK_ADDR_W),
        .ADDR_WIDTH_B       (BANK_ADDR_W),
        .READ_LATENCY_A     (1),
        .MEMORY_INIT_FILE   (MEM_INIT_FILES[i]),
        .CLOCKING_MODE      ("common_clock"),
        .READ_DATA_WIDTH_A  (32), .WRITE_DATA_WIDTH_A (32),
        .READ_DATA_WIDTH_B  (32), .WRITE_DATA_WIDTH_B (32),
        .READ_LATENCY_B     (1),
        .BYTE_WRITE_WIDTH_A (8), .BYTE_WRITE_WIDTH_B (8),
        .WRITE_MODE_A       ("no_change"), .WRITE_MODE_B ("no_change")
      ) uram_inst (
        .clka(clk_i), .ena(bank_ena[i]),   .wea(4'b0), .addra(bank_addra[i]), .dina(32'b0), .douta(bank_douta[i]),
        .clkb(clk_i), .enb(bank_enb[i]),   .web(bank_web[i]), .addrb(bank_addrb[i]), .dinb(bank_dinb[i]), .doutb()
      );
    end
  endgenerate
endmodule
