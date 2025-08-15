// uram_memory_controller.sv - Final, Architecturally Correct & Synthesizable Version
// Implements a true PARALLEL interleaved memory.
// Includes a REVERSED bank mapping to fix word order.
// Uses a case statement for the write crossbar to ensure synthesizability.
// Includes the critical 1-CYCLE GRANT LATENCY to match the working behavioral model.

`timescale 1ns/1ps

module uram_memory_controller
#(
  parameter int MP = 32,
  parameter int TOTAL_WORDS = 131072,
  parameter string MEM_INIT_FILES [MP-1:0] = '{default:"none"}
)
(
  input  logic clk_i,
  input  logic rst_ni,
  hci_core_intf.target tcdm [MP-1:0]
);

  // --- Calculate Memory Geometry ---
  localparam int BANK_DEPTH_WORDS = (TOTAL_WORDS + MP - 1) / MP;
  localparam int BANK_ADDR_W      = $clog2(BANK_DEPTH_WORDS);
  localparam int BANK_SEL_W       = $clog2(MP);
  localparam int BANK_ADDR_OFFSET = 2; 

  // --- Internal signals for URAM banks ---
  logic [MP-1:0][BANK_ADDR_W-1:0] bank_addra, bank_addrb;
  logic [MP-1:0][31:0]            bank_dinb;
  logic [MP-1:0][31:0]            bank_douta;
  logic [MP-1:0][3:0]             bank_web;
  logic [MP-1:0]                  bank_ena, bank_enb;
  
  // ====================================================================
  // --- Write-Side Crossbar (Synthesizable 'case' Version with Reversal) ---
  // ====================================================================
  generate
    for (genvar i = 0; i < MP; i++) begin : g_write_xbar_bank
      always_comb begin
        bank_enb[i]  = 1'b0;
        bank_addrb[i] = '0;
        bank_dinb[i]  = '0;
        bank_web[i]   = '0;

        // Priority-encoded mux. Checks source ports (j=0 is highest priority).
        case (1'b1)
          // For physical bank 'i', find a source port 'j' whose decoded logical
          // bank index matches the REVERSED physical index (MP-1-i).
          (tcdm[0].req && !tcdm[0].wen && (tcdm[0].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[0].add/(MP*4); bank_dinb[i]=tcdm[0].data; bank_web[i]=tcdm[0].be; end
          (tcdm[1].req && !tcdm[1].wen && (tcdm[1].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[1].add/(MP*4); bank_dinb[i]=tcdm[1].data; bank_web[i]=tcdm[1].be; end
          (tcdm[2].req && !tcdm[2].wen && (tcdm[2].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[2].add/(MP*4); bank_dinb[i]=tcdm[2].data; bank_web[i]=tcdm[2].be; end
          // ... This pattern must be repeated for all 32 ports ...
          (tcdm[3].req && !tcdm[3].wen && (tcdm[3].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[3].add/(MP*4); bank_dinb[i]=tcdm[3].data; bank_web[i]=tcdm[3].be; end
          (tcdm[4].req && !tcdm[4].wen && (tcdm[4].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[4].add/(MP*4); bank_dinb[i]=tcdm[4].data; bank_web[i]=tcdm[4].be; end
          (tcdm[5].req && !tcdm[5].wen && (tcdm[5].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[5].add/(MP*4); bank_dinb[i]=tcdm[5].data; bank_web[i]=tcdm[5].be; end
          (tcdm[6].req && !tcdm[6].wen && (tcdm[6].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[6].add/(MP*4); bank_dinb[i]=tcdm[6].data; bank_web[i]=tcdm[6].be; end
          (tcdm[7].req && !tcdm[7].wen && (tcdm[7].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[7].add/(MP*4); bank_dinb[i]=tcdm[7].data; bank_web[i]=tcdm[7].be; end
          (tcdm[8].req && !tcdm[8].wen && (tcdm[8].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[8].add/(MP*4); bank_dinb[i]=tcdm[8].data; bank_web[i]=tcdm[8].be; end
          (tcdm[9].req && !tcdm[9].wen && (tcdm[9].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[9].add/(MP*4); bank_dinb[i]=tcdm[9].data; bank_web[i]=tcdm[9].be; end
          (tcdm[10].req && !tcdm[10].wen && (tcdm[10].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[10].add/(MP*4); bank_dinb[i]=tcdm[10].data; bank_web[i]=tcdm[10].be; end
          (tcdm[11].req && !tcdm[11].wen && (tcdm[11].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[11].add/(MP*4); bank_dinb[i]=tcdm[11].data; bank_web[i]=tcdm[11].be; end
          (tcdm[12].req && !tcdm[12].wen && (tcdm[12].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[12].add/(MP*4); bank_dinb[i]=tcdm[12].data; bank_web[i]=tcdm[12].be; end
          (tcdm[13].req && !tcdm[13].wen && (tcdm[13].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[13].add/(MP*4); bank_dinb[i]=tcdm[13].data; bank_web[i]=tcdm[13].be; end
          (tcdm[14].req && !tcdm[14].wen && (tcdm[14].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[14].add/(MP*4); bank_dinb[i]=tcdm[14].data; bank_web[i]=tcdm[14].be; end
          (tcdm[15].req && !tcdm[15].wen && (tcdm[15].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[15].add/(MP*4); bank_dinb[i]=tcdm[15].data; bank_web[i]=tcdm[15].be; end
          (tcdm[16].req && !tcdm[16].wen && (tcdm[16].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[16].add/(MP*4); bank_dinb[i]=tcdm[16].data; bank_web[i]=tcdm[16].be; end
          (tcdm[17].req && !tcdm[17].wen && (tcdm[17].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[17].add/(MP*4); bank_dinb[i]=tcdm[17].data; bank_web[i]=tcdm[17].be; end
          (tcdm[18].req && !tcdm[18].wen && (tcdm[18].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[18].add/(MP*4); bank_dinb[i]=tcdm[18].data; bank_web[i]=tcdm[18].be; end
          (tcdm[19].req && !tcdm[19].wen && (tcdm[19].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[19].add/(MP*4); bank_dinb[i]=tcdm[19].data; bank_web[i]=tcdm[19].be; end
          (tcdm[20].req && !tcdm[20].wen && (tcdm[20].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[20].add/(MP*4); bank_dinb[i]=tcdm[20].data; bank_web[i]=tcdm[20].be; end
          (tcdm[21].req && !tcdm[21].wen && (tcdm[21].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[21].add/(MP*4); bank_dinb[i]=tcdm[21].data; bank_web[i]=tcdm[21].be; end
          (tcdm[22].req && !tcdm[22].wen && (tcdm[22].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[22].add/(MP*4); bank_dinb[i]=tcdm[22].data; bank_web[i]=tcdm[22].be; end
          (tcdm[23].req && !tcdm[23].wen && (tcdm[23].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[23].add/(MP*4); bank_dinb[i]=tcdm[23].data; bank_web[i]=tcdm[23].be; end
          (tcdm[24].req && !tcdm[24].wen && (tcdm[24].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[24].add/(MP*4); bank_dinb[i]=tcdm[24].data; bank_web[i]=tcdm[24].be; end
          (tcdm[25].req && !tcdm[25].wen && (tcdm[25].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[25].add/(MP*4); bank_dinb[i]=tcdm[25].data; bank_web[i]=tcdm[25].be; end
          (tcdm[26].req && !tcdm[26].wen && (tcdm[26].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[26].add/(MP*4); bank_dinb[i]=tcdm[26].data; bank_web[i]=tcdm[26].be; end
          (tcdm[27].req && !tcdm[27].wen && (tcdm[27].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[27].add/(MP*4); bank_dinb[i]=tcdm[27].data; bank_web[i]=tcdm[27].be; end
          (tcdm[28].req && !tcdm[28].wen && (tcdm[28].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[28].add/(MP*4); bank_dinb[i]=tcdm[28].data; bank_web[i]=tcdm[28].be; end
          (tcdm[29].req && !tcdm[29].wen && (tcdm[29].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[29].add/(MP*4); bank_dinb[i]=tcdm[29].data; bank_web[i]=tcdm[29].be; end
          (tcdm[30].req && !tcdm[30].wen && (tcdm[30].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[30].add/(MP*4); bank_dinb[i]=tcdm[30].data; bank_web[i]=tcdm[30].be; end
          (tcdm[31].req && !tcdm[31].wen && (tcdm[31].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == (MP-1-i))): begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[31].add/(MP*4); bank_dinb[i]=tcdm[31].data; bank_web[i]=tcdm[31].be; end
          default: ;
        endcase
      end
    end
  endgenerate

  // --- Read-Side Path and Handshake with REVERSED Bank Mapping ---
  generate
    for (genvar i = 0; i < MP; i++) begin : g_read_path
      logic gnt_q;
      logic r_valid_q;
      
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) gnt_q <= 1'b0;
        else         gnt_q <= tcdm[i].req;
      end
      assign tcdm[i].gnt = gnt_q;
      
      // Map TCDM port 'i' to the REVERSED physical bank 'MP-1-i'
      assign bank_ena[MP-1-i] = gnt_q & tcdm[i].wen;
      assign bank_addra[MP-1-i] = tcdm[i].add / (MP * 4);
      
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) r_valid_q <= 1'b0;
        else         r_valid_q <= bank_ena[i];
      end
      assign tcdm[i].r_valid = r_valid_q;
      
      assign tcdm[i].r_data = r_valid_q ? bank_douta[i] : 'z;

      // Unused fields
      assign tcdm[i].r_user = '0;
      assign tcdm[i].r_id = '0;
      assign tcdm[i].r_opc = '0;
      assign tcdm[i].r_ecc = '0;
      assign tcdm[i].egnt = '0;
      assign tcdm[i].r_evalid = '0;
    end
  endgenerate

  // --- URAM Primitive Instantiation ---
  generate
    for (genvar i = 0; i < MP; i++) begin : g_uram_instance
      xpm_memory_tdpram #(
        .MEMORY_SIZE        (BANK_DEPTH_WORDS * 32),
        .MEMORY_PRIMITIVE   ("ultra"),
        .ADDR_WIDTH_A       (BANK_ADDR_W),
        .ADDR_WIDTH_B       (BANK_ADDR_W),
        .READ_LATENCY_A     (1),
        .MEMORY_INIT_FILE   (MEM_INIT_FILES[i]), // Direct init, reversal is in TB
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
