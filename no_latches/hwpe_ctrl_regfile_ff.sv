/* 
 * hwpe_ctrl_regfile_latch.sv
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 *
 * Copyright (C) 2014-2018 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 * 
 * Yvan Tortorella <yvan.tortorella@unibo.it>
 * 
 */

module hwpe_ctrl_regfile_ff #(
  parameter  int unsigned AddrWidth = 5,
  parameter  int unsigned DataWidth = 32,
  localparam int unsigned NumWords  = 2**AddrWidth,
  localparam int unsigned NumByte   = DataWidth/8
)(
  input  logic                 clk_i  ,
  input  logic                 rst_ni ,
  input  logic                 clear_i,

  // Read port
  input  logic                 ReadEnable_i,
  input  logic [AddrWidth-1:0] ReadAddr_i  ,
  output logic [DataWidth-1:0] ReadData_o  ,

  // Write port
  input  logic                 WriteEnable_i,
  input  logic [AddrWidth-1:0] WriteAddr_i  ,
  input  logic [DataWidth-1:0] WriteData_i  ,
  input  logic [NumByte-1:0]   WriteBE_i    ,

   // Memory content (false paths!)
  output logic [NumWords-1:0][DataWidth-1:0] MemContent_o
);

logic [NumWords-1:0][DataWidth-1:0] data_d, data_q;

logic clk_int;
logic enable, clkg_en;

assign enable = WriteEnable_i & (WriteAddr_i <= NumWords);


assign clkg_en = enable | clear_i;

assign ReadData_o = (ReadEnable_i && (ReadAddr_i <= NumWords)) ? data_q[ReadAddr_i] : '0;

/*
tc_clk_gating i_we_clkg    (
   .clk_i        ( clk_i   ),
   .en_i         ( clkg_en ),
   .test_en_i    ( 1'b0    ),
   .clk_o        ( clk_int )
);
*/

assign clk_int = clk_i;

for (genvar i = 0; i < NumWords; i++) begin
  for (genvar j = 0; j < NumByte; j++) begin
    assign data_d[i][j*8+:8] = (enable && (WriteAddr_i == i)) ? (WriteData_i[j*8+:8] & {8{WriteBE_i[j]}})
                                                              : data_q[i][j*8+:8];
  end
end

always_ff @(posedge clk_int, negedge rst_ni) begin
  if (~rst_ni)
    data_q <= '0;
  else begin
    if (clear_i)
      data_q <= '0;
    else
      data_q <= data_d;
  end
end

for (genvar i = 0; i < NumWords; i++) begin
  assign MemContent_o[i] = data_q[i];
end

endmodule : hwpe_ctrl_regfile_ff