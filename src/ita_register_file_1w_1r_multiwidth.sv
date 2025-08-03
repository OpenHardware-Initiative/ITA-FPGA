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

genvar i;
    generate
        // FIX: Use a generate-if to handle the case where NUM_CUTS is 1.
        // This prevents the illegal part-select [-1:0] when $clog2(NUM_CUTS) is 0.
        if (NUM_CUTS <= 1) begin : GEN_SINGLE_BANK

            // Logic for when the write and read widths are the same (no banking).
            if (W_N_ROWS == 1) begin
                register_file_1r_1w_1row #(
                    .DATA_WIDTH(RDATA_WIDTH)
                ) bank (
                    .clk         ( clk         ),
                    .ReadEnable  ( ReadEnable    ),
                    .ReadData    ( ReadData      ),
                    .WriteEnable ( WriteEnable   ),
                    .WriteData   ( WriteData     )
                );
            end else begin
                register_file_1r_1w #(
                    .ADDR_WIDTH(WADDR_WIDTH),
                    .DATA_WIDTH(RDATA_WIDTH)
                ) bank (
                    .clk         ( clk         ),
                    .ReadEnable  ( ReadEnable    ),
                    .ReadAddr    ( ReadAddr    ), // Pass the full address
                    .ReadData    ( ReadData      ),
                    .WriteAddr   ( WriteAddr   ),
                    .WriteEnable ( WriteEnable   ),
                    .WriteData   ( WriteData     )
                );
            end

        end else begin : GEN_MULTI_BANK

            // This is the original logic, which is correct for NUM_CUTS > 1.
            logic [$clog2(NUM_CUTS)-1:0]                read_bank_sel_d, read_bank_sel_q;
            logic [RDATA_WIDTH-1:0]                     ReadData_array   [NUM_CUTS];

            assign read_bank_sel_d = ReadAddr[$clog2(NUM_CUTS)-1:0];

            always_ff @(posedge clk or negedge rst_n) begin
                if(~rst_n) begin
                    read_bank_sel_q <= '0;
                end else if (ReadEnable) begin // Gate with enable to save power
                    read_bank_sel_q <= read_bank_sel_d;
                end
            end

            assign ReadData = ReadData_array[read_bank_sel_q];

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
        end
    endgenerate

endmodule