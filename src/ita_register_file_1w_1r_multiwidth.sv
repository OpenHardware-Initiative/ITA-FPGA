// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module ita_register_file_1w_1r_multiwidth
#(
    parameter WADDR_WIDTH   = 2,
    parameter WDATA_WIDTH   = 768,
    parameter RDATA_WIDTH   = 384,

    localparam NUM_CUTS     = WDATA_WIDTH / RDATA_WIDTH,
    localparam RADDR_WIDTH  = WADDR_WIDTH + $clog2(NUM_CUTS),
    parameter W_N_ROWS      = 2**WADDR_WIDTH
)
(
    input  logic                                clk,
    input  logic                                rst_n,

    input  logic                                ReadEnable,
    input  logic [RADDR_WIDTH-1:0]              ReadAddr,
    output logic [RDATA_WIDTH-1:0]              ReadData,

    input  logic                                WriteEnable,
    input  logic [WADDR_WIDTH-1:0]              WriteAddr,
    input  logic [WDATA_WIDTH-1:0]              WriteData
);

    logic [$clog2(NUM_CUTS)-1:0]                read_bank_sel_d, read_bank_sel_q;
    logic [RDATA_WIDTH-1:0]                     ReadData_array   [NUM_CUTS];

    assign read_bank_sel_d = ReadAddr[$clog2(NUM_CUTS)-1:0];

    always_ff @(posedge clk or negedge rst_n)
    begin
        if(~rst_n)
        begin
            read_bank_sel_q <= '0;
        end
        else
        begin
            read_bank_sel_q <= read_bank_sel_d;
        end
    end

    assign ReadData = ReadData_array[read_bank_sel_q];

    genvar i;
    generate
        for (i = 0; i < NUM_CUTS; i++) begin : GEN_BANKS
            if (W_N_ROWS == 1) begin
                register_file_1r_1w_1row #(
                    .DATA_WIDTH(RDATA_WIDTH)
                ) bank (
                    .clk         ( clk                      ),
                    .ReadEnable  ( ReadEnable && (read_bank_sel_d == i) ),
                    .ReadData    ( ReadData_array[i]        ),
                    .WriteEnable ( WriteEnable              ),
                    .WriteData   ( WriteData[(i+1)*RDATA_WIDTH-1 : i*RDATA_WIDTH] )
                );
            end else begin
                register_file_1r_1w #(
                    .ADDR_WIDTH(WADDR_WIDTH),
                    .DATA_WIDTH(RDATA_WIDTH)
                ) bank (
                    .clk         ( clk                        ),
                    .ReadEnable  ( ReadEnable && (read_bank_sel_d == i) ),
                    .ReadAddr    ( ReadAddr[RADDR_WIDTH-1:$clog2(NUM_CUTS)] ),
                    .ReadData    ( ReadData_array[i]          ),
                    .WriteAddr   ( WriteAddr                  ),
                    .WriteEnable ( WriteEnable                ),
                    .WriteData   ( WriteData[(i+1)*RDATA_WIDTH-1 : i*RDATA_WIDTH] )
                );
            end
        end
    endgenerate

endmodule