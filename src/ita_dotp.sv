module ita_dotp #(
    parameter integer M  = 64,
    parameter integer WI = 8,
    parameter integer WO = 26,
    parameter integer WS = WI + 1
) (
    input  logic signed [WS*M-1:0]     inp1_i,
    input  logic signed [WI*M-1:0]     inp2_i,
    output logic signed [  WO-1:0]     oup_o
);

    // --- STAGE 1: Element-wise Multiplication ---
    localparam int PROD_WIDTH = WS + WI; // 9 + 8 = 17 bits
    (* use_dsp = "yes" *) logic signed [PROD_WIDTH-1:0] products[0:M-1];

    generate
        for (genvar i = 0; i < M; i = i + 1) begin: multiplication_loop
            assign products[i] = signed'(inp1_i[WS*i +: WS]) * signed'(inp2_i[WI*i +: WI]);
        end
    endgenerate


    // --- STAGE 2: Balanced Adder Tree ---
    logic signed [WO-1:0] tree_level [0:$clog2(M)][M-1:0];

    //
    // * THE FIX IS HERE *
    //
    // Instead of a direct whole-array assignment which caused the error,
    // we use a generate-for loop to assign each element individually.
    // This allows Verilog to correctly sign-extend each 17-bit product
    // into the 26-bit storage for the first level of the adder tree.
    generate
        for (genvar i = 0; i < M; i = i + 1) begin: init_tree_level_0
            assign tree_level[0][i] = products[i];
        end
    endgenerate

    // Build the rest of the adder tree from level 1 onwards.
    generate
        for (genvar i = 1; i <= $clog2(M); i = i + 1) begin: add_tree_level_loop
            for (genvar j = 0; j < M / (2**i); j = j + 1) begin: add_node_loop
                // This line is correct and prevents intermediate overflow.
                assign tree_level[i][j] = {tree_level[i-1][2*j][WO-1], tree_level[i-1][2*j]} + tree_level[i-1][2*j+1];
            end
        end
    endgenerate


    // --- STAGE 3: Final Output ---
    assign oup_o = tree_level[$clog2(M)][0];

endmodule