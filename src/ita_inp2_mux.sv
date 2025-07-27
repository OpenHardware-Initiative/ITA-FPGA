// In ita_inp2_mux.sv

module ita_inp2_mux
  import ita_package::*;
#(
  parameter integer HALF_N  = N / 2
)(
  input  logic    clk_i,
  input  logic    rst_ni,
  input  logic    calc_en_i,
  input  weight_t weight_i,

  // --- MODIFICATION START ---
  // REMOVE the old, large output
  // output weight_t inp2_o

  // ADD two new, smaller output ports
  output logic signed [HALF_N-1:0][M-1:0][WI-1:0] inp2_p0_o,
  output logic signed [HALF_N-1:0][M-1:0][WI-1:0] inp2_p1_o
  // --- MODIFICATION END ---
);

  always_comb begin
    // Default outputs to zero
    inp2_p0_o = '0;
    inp2_p1_o = '0;

    if (calc_en_i) begin
      // Slice the large input bus and assign to the split output ports
      inp2_p0_o = weight_i[0        +: HALF_N];
      inp2_p1_o = weight_i[HALF_N   +: HALF_N];
    end
  end

endmodule