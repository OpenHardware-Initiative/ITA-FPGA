// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module ita_max_finder
  import ita_package::*;
(
  input  logic         clk_i,
  input  logic         rst_ni,
  input  requant_oup_t x_i,
  input  requant_t     prev_max_i,
  output requant_t     max_o,
  output requant_t     max_diff_o
);


  function automatic requant_t reduce_max(input requant_oup_t vec);
    requant_oup_t stage;
    int size = N;
    int idx;
    begin
      stage = vec;
      while (size > 1) begin
        for (int i = 0; i < size/2; i++) begin
          if (stage[2*i] > stage[2*i+1])
            stage[i] = stage[2*i];
          else
            stage[i] = stage[2*i+1];
        end
        size = size / 2;
      end
      return stage[0];
    end
  endfunction

  requant_t max_val;

  always_comb begin
    max_val = reduce_max(x_i);

    if (prev_max_i > max_val) begin
      max_o = prev_max_i;
      max_diff_o = '0;
    end else begin
      max_o = max_val;
      max_diff_o = max_o - prev_max_i;
    end
  end

endmodule