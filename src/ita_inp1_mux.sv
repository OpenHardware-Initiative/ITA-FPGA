// In ita_inp1_mux.sv

module ita_inp1_mux
  import ita_package::*;
(
  input  logic    clk_i    ,
  input  logic    rst_ni   ,
  input  logic    calc_en_i,
  input  inp_t    inp_i    ,
  output weight_t inp1_o
);

  always_comb begin
    inp1_o = '0;

    if (calc_en_i) begin
      {>>{inp1_o}} = {N{inp_i}};
    end
  end

endmodule