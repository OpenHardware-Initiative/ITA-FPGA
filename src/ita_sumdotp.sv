// In ita_sumdotp.sv

module ita_sumdotp
  import ita_package::*;
#(
  parameter integer HALF_N  = N / 2
)(
  input  logic sign_mode_i,
  input  logic signed [HALF_N-1:0][M-1:0][WI-1:0] inp1_p0_i,
  input  logic signed [HALF_N-1:0][M-1:0][WI-1:0] inp1_p1_i,
  input  logic signed [HALF_N-1:0][M-1:0][WI-1:0] inp2_p0_i,
  input  logic signed [HALF_N-1:0][M-1:0][WI-1:0] inp2_p1_i,
  output logic signed [N-1:0][WO-1:0] oup_o
);

  // --- MODIFICATION: Use two smaller internal wires instead of one large one ---
  logic [HALF_N-1:0][M-1:0][(WI+1)-1:0] inp1_p0_extended;
  logic [HALF_N-1:0][M-1:0][(WI+1)-1:0] inp1_p1_extended;

  // Sign-extend each part separately
  always_comb begin
    for (int i = 0; i < HALF_N; i++) begin
      for (int j = 0; j < M; j++) begin
        if (sign_mode_i == 1'b1) begin
          inp1_p0_extended[i][j] = {inp1_p0_i[i][j][WI-1], inp1_p0_i[i][j]};
          inp1_p1_extended[i][j] = {inp1_p1_i[i][j][WI-1], inp1_p1_i[i][j]};
        end else begin
          inp1_p0_extended[i][j] = {1'b0, inp1_p0_i[i][j]};
          inp1_p1_extended[i][j] = {1'b0, inp1_p1_i[i][j]};
        end
      end
    end
  end

  // Generate the dot products for the first half
  generate for (genvar i = 0; i < HALF_N; i++) begin: calculate_dotp_p0
    ita_dotp #( .M(M), .WI(WI), .WO(WO) ) i_dotp (
      .inp1_i (inp1_p0_extended[i]), // Use the extended part 0
      .inp2_i (inp2_p0_i[i]),
      .oup_o  (oup_o[i])
    );
  end endgenerate

  // Generate the dot products for the second half
  generate for (genvar i = 0; i < HALF_N; i++) begin: calculate_dotp_p1
    ita_dotp #( .M(M), .WI(WI), .WO(WO) ) i_dotp (
      .inp1_i (inp1_p1_extended[i]), // Use the extended part 1
      .inp2_i (inp2_p1_i[i]),
      .oup_o  (oup_o[i + HALF_N])
    );
  end endgenerate

endmodule