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

  // --- Geometry and Internal Signals ---
  localparam int BANK_DEPTH_WORDS = (TOTAL_WORDS + MP - 1) / MP;
  localparam int BANK_ADDR_W      = $clog2(BANK_DEPTH_WORDS);
  localparam int BANK_SEL_W       = $clog2(MP);
  localparam int BANK_ADDR_OFFSET = 2;
  logic [MP-1:0][BANK_ADDR_W-1:0] bank_addra, bank_addrb;
  logic [MP-1:0][31:0]            bank_dinb, bank_douta;
  logic [MP-1:0][3:0]             bank_web;
  logic [MP-1:0]                  bank_ena, bank_enb;


  // ====================================================================
  // --- Stage 1: Grant Generation ---
  // ====================================================================
  generate
    for (genvar i = 0; i < MP; i++) begin : g_grant
        assign tcdm[i].gnt = tcdm[i].req;
    end
  endgenerate
    
  // ====================================================================
  // --- Stage 2: Bank-Centric Request Crossbars ---
  // ====================================================================
  generate
    for (genvar i = 0; i < MP; i++) begin : g_bank_logic
        // --- Write Crossbar to URAM Bank 'i' (Direct mapping) ---
        always_comb begin
            bank_enb[i]   = 1'b0;
            bank_addrb[i] = '0;
            bank_dinb[i]  = '0;
            bank_web[i]   = '0;
            case (1'b1)
  (tcdm[0].gnt  && !tcdm[0].wen  && (tcdm[0].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[0].add /(MP*4); bank_dinb[i]=tcdm[0].data; bank_web[i]=tcdm[0].be; end
  (tcdm[1].gnt  && !tcdm[1].wen  && (tcdm[1].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[1].add /(MP*4); bank_dinb[i]=tcdm[1].data; bank_web[i]=tcdm[1].be; end
  (tcdm[2].gnt  && !tcdm[2].wen  && (tcdm[2].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[2].add /(MP*4); bank_dinb[i]=tcdm[2].data; bank_web[i]=tcdm[2].be; end
  (tcdm[3].gnt  && !tcdm[3].wen  && (tcdm[3].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[3].add /(MP*4); bank_dinb[i]=tcdm[3].data; bank_web[i]=tcdm[3].be; end
  (tcdm[4].gnt  && !tcdm[4].wen  && (tcdm[4].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[4].add /(MP*4); bank_dinb[i]=tcdm[4].data; bank_web[i]=tcdm[4].be; end
  (tcdm[5].gnt  && !tcdm[5].wen  && (tcdm[5].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[5].add /(MP*4); bank_dinb[i]=tcdm[5].data; bank_web[i]=tcdm[5].be; end
  (tcdm[6].gnt  && !tcdm[6].wen  && (tcdm[6].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[6].add /(MP*4); bank_dinb[i]=tcdm[6].data; bank_web[i]=tcdm[6].be; end
  (tcdm[7].gnt  && !tcdm[7].wen  && (tcdm[7].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[7].add /(MP*4); bank_dinb[i]=tcdm[7].data; bank_web[i]=tcdm[7].be; end
  (tcdm[8].gnt  && !tcdm[8].wen  && (tcdm[8].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[8].add /(MP*4); bank_dinb[i]=tcdm[8].data; bank_web[i]=tcdm[8].be; end
  (tcdm[9].gnt  && !tcdm[9].wen  && (tcdm[9].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[9].add /(MP*4); bank_dinb[i]=tcdm[9].data; bank_web[i]=tcdm[9].be; end
  (tcdm[10].gnt && !tcdm[10].wen && (tcdm[10].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[10].add/(MP*4); bank_dinb[i]=tcdm[10].data; bank_web[i]=tcdm[10].be; end
  (tcdm[11].gnt && !tcdm[11].wen && (tcdm[11].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[11].add/(MP*4); bank_dinb[i]=tcdm[11].data; bank_web[i]=tcdm[11].be; end
  (tcdm[12].gnt && !tcdm[12].wen && (tcdm[12].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[12].add/(MP*4); bank_dinb[i]=tcdm[12].data; bank_web[i]=tcdm[12].be; end
  (tcdm[13].gnt && !tcdm[13].wen && (tcdm[13].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[13].add/(MP*4); bank_dinb[i]=tcdm[13].data; bank_web[i]=tcdm[13].be; end
  (tcdm[14].gnt && !tcdm[14].wen && (tcdm[14].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[14].add/(MP*4); bank_dinb[i]=tcdm[14].data; bank_web[i]=tcdm[14].be; end
  (tcdm[15].gnt && !tcdm[15].wen && (tcdm[15].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[15].add/(MP*4); bank_dinb[i]=tcdm[15].data; bank_web[i]=tcdm[15].be; end
  (tcdm[16].gnt && !tcdm[16].wen && (tcdm[16].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[16].add/(MP*4); bank_dinb[i]=tcdm[16].data; bank_web[i]=tcdm[16].be; end
  (tcdm[17].gnt && !tcdm[17].wen && (tcdm[17].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[17].add/(MP*4); bank_dinb[i]=tcdm[17].data; bank_web[i]=tcdm[17].be; end
  (tcdm[18].gnt && !tcdm[18].wen && (tcdm[18].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[18].add/(MP*4); bank_dinb[i]=tcdm[18].data; bank_web[i]=tcdm[18].be; end
  (tcdm[19].gnt && !tcdm[19].wen && (tcdm[19].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[19].add/(MP*4); bank_dinb[i]=tcdm[19].data; bank_web[i]=tcdm[19].be; end
  (tcdm[20].gnt && !tcdm[20].wen && (tcdm[20].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[20].add/(MP*4); bank_dinb[i]=tcdm[20].data; bank_web[i]=tcdm[20].be; end
  (tcdm[21].gnt && !tcdm[21].wen && (tcdm[21].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[21].add/(MP*4); bank_dinb[i]=tcdm[21].data; bank_web[i]=tcdm[21].be; end
  (tcdm[22].gnt && !tcdm[22].wen && (tcdm[22].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[22].add/(MP*4); bank_dinb[i]=tcdm[22].data; bank_web[i]=tcdm[22].be; end
  (tcdm[23].gnt && !tcdm[23].wen && (tcdm[23].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[23].add/(MP*4); bank_dinb[i]=tcdm[23].data; bank_web[i]=tcdm[23].be; end
  (tcdm[24].gnt && !tcdm[24].wen && (tcdm[24].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[24].add/(MP*4); bank_dinb[i]=tcdm[24].data; bank_web[i]=tcdm[24].be; end
  (tcdm[25].gnt && !tcdm[25].wen && (tcdm[25].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[25].add/(MP*4); bank_dinb[i]=tcdm[25].data; bank_web[i]=tcdm[25].be; end
  (tcdm[26].gnt && !tcdm[26].wen && (tcdm[26].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[26].add/(MP*4); bank_dinb[i]=tcdm[26].data; bank_web[i]=tcdm[26].be; end
  (tcdm[27].gnt && !tcdm[27].wen && (tcdm[27].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[27].add/(MP*4); bank_dinb[i]=tcdm[27].data; bank_web[i]=tcdm[27].be; end
  (tcdm[28].gnt && !tcdm[28].wen && (tcdm[28].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[28].add/(MP*4); bank_dinb[i]=tcdm[28].data; bank_web[i]=tcdm[28].be; end
  (tcdm[29].gnt && !tcdm[29].wen && (tcdm[29].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[29].add/(MP*4); bank_dinb[i]=tcdm[29].data; bank_web[i]=tcdm[29].be; end
  (tcdm[30].gnt && !tcdm[30].wen && (tcdm[30].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[30].add/(MP*4); bank_dinb[i]=tcdm[30].data; bank_web[i]=tcdm[30].be; end
  (tcdm[31].gnt && !tcdm[31].wen && (tcdm[31].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):
    begin bank_enb[i]=1'b1; bank_addrb[i]=tcdm[31].add/(MP*4); bank_dinb[i]=tcdm[31].data; bank_web[i]=tcdm[31].be; end
  default: ;
endcase
        end

        // --- Read Request Crossbar to URAM Bank 'i' (Direct mapping) ---
        always_comb begin
            bank_ena[i]   = 1'b0;
            bank_addra[i] = '0;
            case (1'b1)
  (tcdm[0].gnt  && tcdm[0].wen  && (tcdm[0].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[0].add /(MP*4);  end
  (tcdm[1].gnt  && tcdm[1].wen  && (tcdm[1].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[1].add /(MP*4);  end
  (tcdm[2].gnt  && tcdm[2].wen  && (tcdm[2].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[2].add /(MP*4);  end
  (tcdm[3].gnt  && tcdm[3].wen  && (tcdm[3].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[3].add /(MP*4);  end
  (tcdm[4].gnt  && tcdm[4].wen  && (tcdm[4].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[4].add /(MP*4);  end
  (tcdm[5].gnt  && tcdm[5].wen  && (tcdm[5].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[5].add /(MP*4);  end
  (tcdm[6].gnt  && tcdm[6].wen  && (tcdm[6].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[6].add /(MP*4);  end
  (tcdm[7].gnt  && tcdm[7].wen  && (tcdm[7].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[7].add /(MP*4);  end
  (tcdm[8].gnt  && tcdm[8].wen  && (tcdm[8].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[8].add /(MP*4);  end
  (tcdm[9].gnt  && tcdm[9].wen  && (tcdm[9].add [BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[9].add /(MP*4);  end
  (tcdm[10].gnt && tcdm[10].wen && (tcdm[10].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[10].add/(MP*4); end
  (tcdm[11].gnt && tcdm[11].wen && (tcdm[11].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[11].add/(MP*4); end
  (tcdm[12].gnt && tcdm[12].wen && (tcdm[12].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[12].add/(MP*4); end
  (tcdm[13].gnt && tcdm[13].wen && (tcdm[13].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[13].add/(MP*4); end
  (tcdm[14].gnt && tcdm[14].wen && (tcdm[14].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[14].add/(MP*4); end
  (tcdm[15].gnt && tcdm[15].wen && (tcdm[15].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[15].add/(MP*4); end
  (tcdm[16].gnt && tcdm[16].wen && (tcdm[16].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[16].add/(MP*4); end
  (tcdm[17].gnt && tcdm[17].wen && (tcdm[17].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[17].add/(MP*4); end
  (tcdm[18].gnt && tcdm[18].wen && (tcdm[18].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[18].add/(MP*4); end
  (tcdm[19].gnt && tcdm[19].wen && (tcdm[19].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[19].add/(MP*4); end
  (tcdm[20].gnt && tcdm[20].wen && (tcdm[20].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[20].add/(MP*4); end
  (tcdm[21].gnt && tcdm[21].wen && (tcdm[21].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[21].add/(MP*4); end
  (tcdm[22].gnt && tcdm[22].wen && (tcdm[22].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[22].add/(MP*4); end
  (tcdm[23].gnt && tcdm[23].wen && (tcdm[23].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[23].add/(MP*4); end
  (tcdm[24].gnt && tcdm[24].wen && (tcdm[24].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[24].add/(MP*4); end
  (tcdm[25].gnt && tcdm[25].wen && (tcdm[25].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[25].add/(MP*4); end
  (tcdm[26].gnt && tcdm[26].wen && (tcdm[26].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[26].add/(MP*4); end
  (tcdm[27].gnt && tcdm[27].wen && (tcdm[27].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[27].add/(MP*4); end
  (tcdm[28].gnt && tcdm[28].wen && (tcdm[28].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[28].add/(MP*4); end
  (tcdm[29].gnt && tcdm[29].wen && (tcdm[29].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[29].add/(MP*4); end
  (tcdm[30].gnt && tcdm[30].wen && (tcdm[30].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[30].add/(MP*4); end
  (tcdm[31].gnt && tcdm[31].wen && (tcdm[31].add[BANK_ADDR_OFFSET +: BANK_SEL_W] == i)):  begin bank_ena[i]=1'b1; bank_addra[i]=tcdm[31].add/(MP*4); end
  default: ;
endcase
            
        end
    end
  endgenerate
  
    // ====================================================================
  // --- Read Return Path Logic (FULLY DIRECT MAPPED) ---
  // ====================================================================
  generate
    for (genvar i = 0; i < MP; i++) begin : g_port_return_logic
        logic                  port_is_reading_q;
        logic [BANK_SEL_W-1:0] read_target_bank_q;

        // Pipeline Stage 1: Register which bank THIS port is reading from.
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (!rst_ni) begin
                port_is_reading_q  <= 1'b0;
                read_target_bank_q <= '0;
            end else begin
                port_is_reading_q  <= tcdm[i].gnt & tcdm[i].wen;
                read_target_bank_q <= tcdm[i].add[BANK_ADDR_OFFSET +: BANK_SEL_W];
            end
        end
        
        // Pipeline Stage 2: Assert valid and select data from the correct bank.
        assign tcdm[i].r_valid = port_is_reading_q;
        assign tcdm[i].r_data  = port_is_reading_q ? bank_douta[read_target_bank_q] : 'z;

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

