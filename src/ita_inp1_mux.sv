// In ita_inp1_mux.sv

module ita_inp1_mux
  import ita_package::*;
#(
  parameter integer HALF_N  = N / 2
)(
  input  logic clk_i,
  input  logic rst_ni,
  input  logic calc_en_i,
  input  inp_t inp_i,

  // --- MODIFICATION START ---
  // REMOVE the old, large output
  // output weight_t inp1_o

  // ADD two new, smaller output ports
  output logic signed [HALF_N-1:0][M-1:0][WI-1:0] inp1_p0_o,
  output logic signed [HALF_N-1:0][M-1:0][WI-1:0] inp1_p1_o
  // --- MODIFICATION END ---
);

  // This intermediate signal helps with the replication logic
  weight_t inp1_full;

  always_comb begin
    inp1_full = '0;
    if (calc_en_i) begin
      // Create the full replicated signal internally first
      {>>{inp1_full}} = {N{inp_i}};
    end

    // Assign to the split output ports by slicing the full signal
    inp1_p0_o = inp1_full[0        +: HALF_N];
    inp1_p1_o = inp1_full[HALF_N   +: HALF_N];
  end

endmodule