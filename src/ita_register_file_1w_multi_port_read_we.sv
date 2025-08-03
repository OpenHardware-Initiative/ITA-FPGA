module ita_register_file_1w_multi_port_read_we
#(
    parameter ADDR_WIDTH    = 5,
    parameter DATA_WIDTH    = 32,

    parameter N_READ        = 2,
    parameter N_WRITE       = 1,
    parameter N_EN          = 4
)
(
    input  logic                                   clk,
    input  logic                                   test_en_i,
    input   logic                                  rst_n,

    // Read port
    input  logic [N_READ-1:0]                      ReadEnable,
    input  logic [N_READ-1:0][ADDR_WIDTH-1:0]      ReadAddr,
    output logic [N_READ-1:0][DATA_WIDTH-1:0]      ReadData,

    // Write port
    input  logic                                   WriteEnable,
    input  logic [ADDR_WIDTH-1:0]                  WriteAddr,
    input  logic [N_EN-1:0][DATA_WIDTH/N_EN-1:0]   WriteData,
    input  logic [N_EN-1:0]                        WriteSelect
);

genvar i, j;
logic [N_READ-1:0][N_EN-1:0][DATA_WIDTH/N_EN-1:0] read_data;

generate
    for (i = 0; i < N_READ; i++) begin
        for (j = 0; j < N_EN; j++) begin

           // assign read_data[i][j] = ReadData[i][DATA_WIDTH/N_EN * (j+1) - 1 : DATA_WIDTH/N_EN * j];

            register_file_1r_1w
            #(
                .ADDR_WIDTH (ADDR_WIDTH),
                .DATA_WIDTH (DATA_WIDTH/N_EN),
                .BLOCK_RAM  (1)
            )
            rf_1r_1w_inst
            (
                .clk        (clk),
                .rst_n      (rst_n),

                .ReadEnable (ReadEnable[i]),
                .ReadAddr   (ReadAddr[i]),
                //.ReadData   (read_data[i][j]),
                .ReadData(ReadData[i][(j+1)*(DATA_WIDTH/N_EN)-1 -: (DATA_WIDTH/N_EN)]),

                .WriteAddr  (WriteAddr),
                .WriteEnable(WriteEnable & WriteSelect[j]),
                .WriteData  (WriteData[j])
            );
        end
    end
endgenerate

endmodule // register_file_1w_multi_port_read
