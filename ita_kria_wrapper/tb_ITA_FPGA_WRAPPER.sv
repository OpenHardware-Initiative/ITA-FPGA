`timescale 1ns/1ps

module tb_ITA_FPGA_WRAPPER;

    // =================================================================
    // Parameters and Constants
    // =================================================================
    localparam N_CORES = 1;

    localparam int unsigned AccDataWidth = 1024;
    localparam int unsigned IdWidth      = 8;
    localparam int unsigned MemDataWidth = 32;
    localparam int unsigned MP = (AccDataWidth / MemDataWidth);

    localparam integer C_S_AXIS_TDATA_WIDTH = 32;
    localparam integer C_M_AXIS_TDATA_WIDTH = 32;

    parameter integer N_PE = `ifdef ITA_N `ITA_N `else 16 `endif;
    parameter integer M_TILE_LEN = `ifdef ITA_M `ITA_M `else 64 `endif;
    parameter integer SEQUENCE_LEN = `ifdef SEQ_LENGTH `SEQ_LENGTH `else M_TILE_LEN `endif;
    parameter integer PROJECTION_SPACE = `ifdef PROJ_SPACE `PROJ_SPACE `else M_TILE_LEN `endif;
    parameter integer EMBEDDING_SIZE = `ifdef EMBED_SIZE `EMBED_SIZE `else M_TILE_LEN `endif;
    parameter integer FEEDFORWARD_SIZE = `ifdef FF_SIZE `FF_SIZE `else M_TILE_LEN `endif;
    parameter activation_e ACTIVATION = `ifdef ACTIVATION `ACTIVATION `else Identity `endif;
    parameter integer SINGLE_ATTENTION = `ifdef SINGLE_ATTENTION `SINGLE_ATTENTION `else 0 `endif;
    localparam CLK_PERIOD = 10; // 100 MHz clock
    
    
    typedef enum logic [5:0] {
        S_IDLE,
        // Attention WB Loading
        S_WAIT_ATTN_WB_DATA,
        S_SETUP_ATTN_WB,
        // FFN WB Loading
        S_WAIT_FFN_WB_DATA,
        S_SETUP_FFN_WB,
        // Attention Path States
        S_WAIT_ATTN_DATA,
        S_SETUP_ATTN,
        S_START_Q, S_WAIT_Q_DONE,
        S_START_K, S_WAIT_K_DONE,
        S_START_V, S_WAIT_V_DONE,
        S_START_QK, S_WAIT_QK_DONE,
        S_START_AV, S_WAIT_AV_DONE,
        S_START_OW, S_WAIT_OW_DONE,
        S_OW_F1,
        S_WAIT_ATTN_READ_READY,
        S_DONE_ATTN,
        // FFN Path States
        S_WAIT_FFN_DATA,
        S_SETUP_FFN,
        S_START_F1, S_WAIT_F1_DONE,
        S_START_F2, S_WAIT_F2_DONE,
        S_WAIT_FFN_READ_READY,
        S_DONE_FFN
    } state_t;


    // ==============================================================================
    // MODIFICATION START: Corrected Word Count Calculations
    // The parameter 'H' was undefined. Assuming H=1 as implied by the non-parameterized
    // design of the accelerator. The formulas now directly calculate the number of
    // 32-bit words based on the byte sizes of the data structures.
    // ==============================================================================
    // All weights (Wq, Wk, Wv, Wo) are 8-bit.
    localparam int ATTN_W_BYTES = 4 * EMBEDDING_SIZE * PROJECTION_SPACE;
    // All biases (Bq, Bk, Bv, Bo) are 24-bit (3 bytes).
    localparam int ATTN_B_BYTES = (3 * PROJECTION_SPACE * 3) + (1 * EMBEDDING_SIZE * 3);
    localparam int ATTN_WB_LOAD_WORDS = (ATTN_W_BYTES + ATTN_B_BYTES + 3) / 4; // Ceiling division

    // FFN weights (Wff1, Wff2) are 8-bit.
    localparam int FFN_W_BYTES = 2 * EMBEDDING_SIZE * FEEDFORWARD_SIZE;
    // FFN biases (Bff1, Bff2) are 24-bit (3 bytes).
    localparam int FFN_B_BYTES = (1 * FEEDFORWARD_SIZE * 3) + (1 * EMBEDDING_SIZE * 3);
    localparam int FFN_WB_LOAD_WORDS = (FFN_W_BYTES + FFN_B_BYTES + 3) / 4; // Ceiling division

    // Input q, k, v are 8-bit. Here we load q and k. V is derived from k.
    localparam int ATTN_INPUT_BYTES = 2 * SEQUENCE_LEN * EMBEDDING_SIZE;
    localparam int ATTN_LOAD_WORDS = (ATTN_INPUT_BYTES + 3) / 4;

    // Final attention output (OW) is 8-bit.
    localparam int ATTN_OUTPUT_BYTES = SEQUENCE_LEN * EMBEDDING_SIZE;
    localparam int ATTN_OUTPUT_WORDS = (ATTN_OUTPUT_BYTES + 3) / 4;

    // FFN input is 8-bit.
    localparam int FFN_INPUT_BYTES = SEQUENCE_LEN * EMBEDDING_SIZE;
    localparam int FFN_LOAD_WORDS = (FFN_INPUT_BYTES + 3) / 4;

    // Final FFN output (F2) is 8-bit.
    localparam int FFN_OUTPUT_BYTES = SEQUENCE_LEN * EMBEDDING_SIZE;
    localparam int FFN_OUTPUT_WORDS = (FFN_OUTPUT_BYTES + 3) / 4;
    // ==============================================================================
    // MODIFICATION END
    // ==============================================================================


    // =================================================================
    // Testbench Signals
    // =================================================================
    logic clk_i;
    logic rst_ni;
    logic test_mode_i;

    wire  [N_CORES-1:0][1:0] evt_o;
    wire                     busy_o;

    logic start_load_attn_wb_i;
    logic start_load_ffn_wb_i;
    logic start_attn_i;
    logic start_ffn_i;
    
    string simdir;
    
    logic [31:0] packed_m0, packed_m1;
    logic [31:0] packed_s0, packed_s1;
    logic [31:0] packed_a0, packed_a1;
    logic [31:0] gelu_packed, act_rqs_packed;


    wire  attn_wb_done_o;
    wire  ffn_wb_done_o;
    wire  attn_done_o;
    wire  ffn_done_o;
    wire  accelerator_idle_o;

    // RQS and Activation Constant Signals
    logic [31:0] rqs_eps_mult0_i, rqs_eps_mult1_i, rqs_eps_mult2_i;
    logic [31:0] rqs_rshift0_i,   rqs_rshift1_i,   rqs_rshift2_i;
    logic [31:0] rqs_add0_i,      rqs_add1_i,      rqs_add2_i, rqs_add3_i, rqs_add4_i;
    logic [31:0] activation_gelu_const_i;
    logic [31:0] activation_rqs_const_i;

    logic [C_S_AXIS_TDATA_WIDTH-1:0] s_axis_tdata;
    logic                            s_axis_tvalid;
    wire                             s_axis_tready;

    wire  [C_M_AXIS_TDATA_WIDTH-1:0] m_axis_tdata;
    wire                             m_axis_tvalid;
    logic                            m_axis_tready;

    // Base Pointer Logic
    logic [31:0] BASE_PTR [0:22];
    logic [31:0] BASE_PTR_INPUT_Q;
    logic [31:0] BASE_PTR_INPUT_FF1;
    logic [31:0] BASE_PTR_WEIGHT0_Q;
    logic [31:0] BASE_PTR_WEIGHT0_FF1;
    logic [31:0] BASE_PTR_OUTPUT_OW;
    logic [31:0] BASE_PTR_OUTPUT_F2;
    logic [N_STATES-1:0][31:0] BASE_PTR_INPUT;
    logic [N_STATES-1:0][31:0] BASE_PTR_WEIGHT0;
    
    // DUT Instantiation
    ITA_FPGA_WRAPPER #(
        .AccDataWidth(AccDataWidth), .MemDataWidth(MemDataWidth),
        .C_S_AXIS_TDATA_WIDTH(C_S_AXIS_TDATA_WIDTH), .C_M_AXIS_TDATA_WIDTH(C_M_AXIS_TDATA_WIDTH),
        .M_TILE_LEN(M_TILE_LEN), .SEQUENCE_LEN(SEQUENCE_LEN),
        .PROJECTION_SPACE(PROJECTION_SPACE), .EMBEDDING_SIZE(EMBEDDING_SIZE),
        .FEEDFORWARD_SIZE(FEEDFORWARD_SIZE)
    ) i_dut (.*);

    // Clock and Reset Generation
    initial begin
        clk_i = 0;
        forever #(CLK_PERIOD / 2) clk_i = ~clk_i;
    end

    initial begin
        rst_ni = 1'b0;
        # (CLK_PERIOD * 5);
        rst_ni = 1'b1;
    end

    // =================================================================
    // Helper Tasks
    // =================================================================

    // MODIFICATION: Made file seeking more robust.
    task automatic drive_s_axis_from_file(input string filename, input int byte_offset, input int num_words, input state_t dut_state);
        integer file, word_offset;
        logic [31:0] dummy_word;
        logic [C_S_AXIS_TDATA_WIDTH-1:0] data_word;


        word_offset = byte_offset / 4;
        $display("[%0t] INFO: Starting to drive %0d words from file '%s', starting at word offset %0d (byte offset %0h)", $time, num_words, filename, word_offset, byte_offset);

        file = $fopen(filename, "r");
        if (file == 0) begin $error("[%0t] FATAL: Could not open file: %s", $time, filename); $finish; end

        // Robustly seek to the correct word offset
        for (int j = 0; j < word_offset; j++) begin
            if ($feof(file)) begin $error("[%0t] FATAL: Reached EOF while seeking to offset in %s", $time, filename); $finish; end
            $fscanf(file, "%h", dummy_word);
        end

//        for (int i = 0; i < num_words; i++) begin
//            if ($feof(file)) begin $error("[%0t] FATAL: Reached EOF prematurely while reading from %s", $time, filename); $finish; end
//            $fscanf(file, "%h", data_word);
//            s_axis_tvalid <= 1'b1;
//            s_axis_tdata <= data_word;
//            @(posedge clk_i);
//             while (s_axis_tready !== 1'b1) begin
//              if (dut_state == S_WAIT_QK_DONE) begin
//                  $display("[%0t] DEBUG: DUT state is S_WAIT_QK_DONE, forcing handshake complete.", $time);
//                  break;
//               end
//              @(posedge clk_i);
//            end
//        end

        for (int i = 0; i < num_words; i++) begin
            if ($feof(file)) begin $error("[%0t] FATAL: Reached EOF prematurely while reading from %s", $time, filename); $finish; end
            $fscanf(file, "%h", data_word);
            s_axis_tvalid <= 1'b1;
            s_axis_tdata <= data_word;
//            @(posedge clk_i);
             while (s_axis_tready !== 1'b1) begin
              @(posedge clk_i);
            end
        end

        s_axis_tvalid <= 1'b0;
        $fclose(file);
        $display("[%0t] INFO: Finished driving %0d words from '%s'.", $time, num_words, filename);
    endtask

    // MODIFICATION: New verification task to compare output against a golden file.
    task automatic verify_m_axis_output(input string golden_filename, input int num_words);
        integer golden_file, mismatch_count;
        logic [C_M_AXIS_TDATA_WIDTH-1:0] golden_data, actual_data;

        $display("[%0t] INFO: Starting verification of %0d words against golden file '%s'.", $time, num_words, golden_filename);
        golden_file = $fopen(golden_filename, "r");
        if (golden_file == 0) begin $error("[%0t] FATAL: Could not open golden file: %s", $time, golden_filename); $finish; end

        mismatch_count = 0;
        m_axis_tready <= 1'b1;

        for (int i = 0; i < num_words; i++) begin
            while (m_axis_tvalid !== 1'b1) @(posedge clk_i);

            actual_data = m_axis_tdata;

            if ($feof(golden_file)) begin $error("[%0t] FATAL: Golden file '%s' is shorter than expected.", $time, golden_filename); $finish; end
            $fscanf(golden_file, "%h", golden_data);

            if (actual_data !== golden_data) begin
                $display("[%0t] ERROR: Mismatch at word %0d. Expected: %h, Got: %h", $time, i, golden_data, actual_data);
                mismatch_count++;
                if (mismatch_count >= 10) begin
                    $error("[%0t] FATAL: Too many mismatches. Halting simulation.", $time);
                    $finish;
                end
            end
            @(posedge clk_i);
        end

        m_axis_tready <= 1'b0;
        $fclose(golden_file);

        if (mismatch_count == 0) begin
            $display("[%0t] SUCCESS: Verification passed for '%s'.", $time, golden_filename);
        end else begin
            $error("[%0t] FATAL: Verification FAILED for '%s' with %0d mismatches.", $time, golden_filename, mismatch_count);
            $finish;
        end
    endtask

    task automatic load_and_pack_rqs_values(
        output logic [31:0] packed_mul0,
        output logic [31:0] packed_mul1,
        output logic [31:0] packed_shift0,
        output logic [31:0] packed_shift1,
        output logic [31:0] packed_add0,
        output logic [31:0] packed_add1
    );
        // Local arrays to hold the raw values from files
        logic signed [7:0]   eps_mult[8];
        logic signed [7:0]   right_shift[8];
        // NOTE: The original TB packs 8-bit values for 'add'. We will replicate this.
        logic signed [7:0]   add[8];
        integer fd, ret_code;

        // --- Read 7 values from ATTN files ---
        fd = $fopen({simdir,"/","RQS_ATTN_MUL.txt"}, "r");   for (int i=0; i<7; i++) ret_code = $fscanf(fd, "%d", eps_mult[i]);    $fclose(fd);
        fd = $fopen({simdir,"/","RQS_ATTN_SHIFT.txt"}, "r"); for (int i=0; i<7; i++) ret_code = $fscanf(fd, "%d", right_shift[i]); $fclose(fd);
        fd = $fopen({simdir,"/","RQS_ATTN_ADD.txt"}, "r");   for (int i=0; i<7; i++) ret_code = $fscanf(fd, "%d", add[i]);          $fclose(fd);

        // --- Read 1 value from FFN files ---
        fd = $fopen({simdir,"/","RQS_FFN_MUL.txt"}, "r");   ret_code = $fscanf(fd, "%d", eps_mult[7]);    $fclose(fd);
        fd = $fopen({simdir,"/","RQS_FFN_SHIFT.txt"}, "r"); ret_code = $fscanf(fd, "%d", right_shift[7]); $fclose(fd);
        fd = $fopen({simdir,"/","RQS_FFN_ADD.txt"}, "r");   ret_code = $fscanf(fd, "%d", add[7]);          $fclose(fd);

        // --- Pack the 8 values of each type into two 32-bit words, exactly like the original TB ---
        packed_mul0   = {eps_mult[3],    eps_mult[2],    eps_mult[1],    eps_mult[0]};
        packed_mul1   = {eps_mult[7],    eps_mult[6],    eps_mult[5],    eps_mult[4]};
        packed_shift0 = {right_shift[3], right_shift[2], right_shift[1], right_shift[0]};
        packed_shift1 = {right_shift[7], right_shift[6], right_shift[5], right_shift[4]};
        packed_add0   = {add[3],         add[2],         add[1],         add[0]};
        packed_add1   = {add[7],         add[6],         add[5],         add[4]};

        $display("[%0t] Layer-specific RQS values loaded and packed correctly.", $time);
    endtask

    task automatic load_and_pack_activation_values(
        output logic [31:0] packed_gelu,
        output logic [31:0] packed_act_rqs
    );
        logic signed [15:0] gelu_b, gelu_c;
        logic signed [7:0]  act_mult, act_shift;
        logic signed [15:0] act_add;
        integer fd, ret_code;

        // --- Read the five files ---
        fd = $fopen({simdir,"/","GELU_B.txt"}, "r"); ret_code = $fscanf(fd, "%d", gelu_b); $fclose(fd);
        fd = $fopen({simdir,"/","GELU_C.txt"}, "r"); ret_code = $fscanf(fd, "%d", gelu_c); $fclose(fd);
        fd = $fopen({simdir,"/","activation_requant_mult.txt"}, "r"); ret_code = $fscanf(fd, "%d", act_mult); $fclose(fd);
        fd = $fopen({simdir,"/","activation_requant_shift.txt"}, "r"); ret_code = $fscanf(fd, "%d", act_shift); $fclose(fd);
        fd = $fopen({simdir,"/","activation_requant_add.txt"}, "r"); ret_code = $fscanf(fd, "%d", act_add); $fclose(fd);

        // --- Pack the values into 32-bit words ---
        packed_gelu = {gelu_c, gelu_b};
        packed_act_rqs = {act_add, act_shift, act_mult};

        $display("[%0t] Activation constants loaded and packed.", $time);
    endtask

    // =================================================================
    // Main Test Sequence
    // =================================================================
    initial begin
    

        simdir = {"C:/Users/micha/Documents/GitHub/ITA-FPGA/ita_kria_wrapper/data_S64_E128_P192_F256_H1_B1_Relu"};
        // Base pointer calculations for the logical memory map
        BASE_PTR[0 ] = 0; //input q
        BASE_PTR[1 ] = BASE_PTR[0 ] + SEQUENCE_LEN * EMBEDDING_SIZE;
        BASE_PTR[2 ] = BASE_PTR[1 ] + SEQUENCE_LEN * EMBEDDING_SIZE;
        BASE_PTR[3 ] = BASE_PTR[2 ] + PROJECTION_SPACE * EMBEDDING_SIZE;
        BASE_PTR[4 ] = BASE_PTR[3 ] + PROJECTION_SPACE * EMBEDDING_SIZE;
        BASE_PTR[5 ] = BASE_PTR[4 ] + PROJECTION_SPACE * EMBEDDING_SIZE;
        BASE_PTR[6 ] = BASE_PTR[5 ] + PROJECTION_SPACE * EMBEDDING_SIZE;
        BASE_PTR[7 ] = BASE_PTR[6 ] + PROJECTION_SPACE * 3;
        BASE_PTR[8 ] = BASE_PTR[7 ] + PROJECTION_SPACE * 3;
        BASE_PTR[9 ] = BASE_PTR[8 ] + PROJECTION_SPACE * 3;
        BASE_PTR[10] = BASE_PTR[9 ] + EMBEDDING_SIZE * 3;
        BASE_PTR[11] = BASE_PTR[10] + SEQUENCE_LEN * EMBEDDING_SIZE;
        BASE_PTR[12] = BASE_PTR[11] + EMBEDDING_SIZE * FEEDFORWARD_SIZE;
        BASE_PTR[13] = BASE_PTR[12] + FEEDFORWARD_SIZE * EMBEDDING_SIZE;
        BASE_PTR[14] = BASE_PTR[13] + FEEDFORWARD_SIZE * 3;
        BASE_PTR[15] = BASE_PTR[14] + EMBEDDING_SIZE * 3;
        // The rest are intermediate/output pointers, not strictly needed for loading
        // but included for completeness.
        BASE_PTR[16] = BASE_PTR[15] + SEQUENCE_LEN * PROJECTION_SPACE;
        BASE_PTR[17] = BASE_PTR[16] + SEQUENCE_LEN * PROJECTION_SPACE;
        BASE_PTR[18] = BASE_PTR[17] + SEQUENCE_LEN * PROJECTION_SPACE;
        BASE_PTR[19] = BASE_PTR[18] + SEQUENCE_LEN * SEQUENCE_LEN;
        BASE_PTR[20] = BASE_PTR[19] + SEQUENCE_LEN * PROJECTION_SPACE;
        BASE_PTR[21] = BASE_PTR[20] + SEQUENCE_LEN * EMBEDDING_SIZE;
        BASE_PTR[22] = BASE_PTR[21] + SEQUENCE_LEN * FEEDFORWARD_SIZE;

        // Assign pointers for easier access, matching DUT/sequencer view
        BASE_PTR_INPUT[Q]   = BASE_PTR[0];
        BASE_PTR_INPUT[F1]  = BASE_PTR[10]; // Note: FFN Input is at a different location
        BASE_PTR_WEIGHT0[Q] = BASE_PTR[2];  // Wq is the start of ATTN WB
        BASE_PTR_WEIGHT0[F1]= BASE_PTR[11]; // Wff is the start of FFN WB

        $display("========================================");
        $display("   Starting ITA_FPGA_WRAPPER Testbench  ");
        $display("========================================");

        // --- 1. Initialization ---
        test_mode_i <= 1'b0;
        start_load_attn_wb_i <= 1'b0;
        start_load_ffn_wb_i  <= 1'b0;
        start_attn_i <= 1'b0;
        start_ffn_i <= 1'b0; 
        s_axis_tvalid <= 1'b0;
        s_axis_tdata <= '0;
        m_axis_tready <= 1'b0;

        @(posedge rst_ni);
        wait (accelerator_idle_o === 1'b1);
        $display("[%0t] DUT is IDLE.", $time);
        
        # (CLK_PERIOD * 10);
//        @(negedge rst_ni);
//        @(posedge rst_ni);
//        $display("[%0t] Reset complete. Waiting for DUT to be idle.", $time);
        
        wait (accelerator_idle_o === 1'b1);
        $display("[%0t] DUT is IDLE.", $time);

        
        // Call the corrected packing task.
        load_and_pack_rqs_values(packed_m0, packed_m1, packed_s0, packed_s1, packed_a0, packed_a1);
        load_and_pack_activation_values(gelu_packed, act_rqs_packed);

        $display("[%0t] Driving all constants to DUT ports.", $time);
        // Drive the 6 correct signals.
        rqs_eps_mult0_i <= packed_m0;
        rqs_eps_mult1_i <= packed_m1;
        rqs_rshift0_i   <= packed_s0;
        rqs_rshift1_i   <= packed_s1;
        rqs_add0_i      <= packed_a0;
        rqs_add1_i      <= packed_a1;

        activation_gelu_const_i <= gelu_packed;
        activation_rqs_const_i  <= act_rqs_packed;

        // --- 2. Load Attention Weights & Biases ---
        $display("[%0t] STEP 1: Starting Attention WB loading.", $time);
        start_load_attn_wb_i <= 1'b1;
        @(posedge clk_i);
        start_load_attn_wb_i <= 1'b0;
        drive_s_axis_from_file({simdir,"/","mem.txt"}, BASE_PTR_WEIGHT0[Q], ATTN_WB_LOAD_WORDS, i_dut.current_state);
        wait (attn_wb_done_o === 1'b1);
        @(posedge clk_i);
        $display("[%0t] Attention WB loading complete.", $time);
        wait (accelerator_idle_o === 1'b1);

        // --- 3. Load FFN Weights & Biases ---
        $display("[%0t] STEP 2: Starting FFN WB loading.", $time);
        start_load_ffn_wb_i <= 1'b1;
        @(posedge clk_i);
        start_load_ffn_wb_i <= 1'b0;
        drive_s_axis_from_file({simdir,"/","mem.txt"}, BASE_PTR_WEIGHT0[F1], FFN_WB_LOAD_WORDS, i_dut.current_state);
        wait (ffn_wb_done_o === 1'b1);
        @(posedge clk_i);
        $display("[%0t] FFN WB loading complete.", $time);
        wait (accelerator_idle_o === 1'b1);

        // --- 4. Attention Calculation ---
        $display("[%0t] STEP 3: Starting Attention calculation and verification.", $time);
        start_attn_i <= 1'b1;
        @(posedge clk_i);
        start_attn_i <= 1'b0;
        drive_s_axis_from_file({simdir,"/","mem.txt"}, BASE_PTR_INPUT[Q], ATTN_LOAD_WORDS, i_dut.current_state);
            // Simultaneously check the final output (OW) against its golden file
        verify_m_axis_output({simdir,"/","OW.txt"}, ATTN_OUTPUT_WORDS);
        wait (attn_done_o === 1'b1);
        @(posedge clk_i);
        $display("[%0t] Attention calculation and verification complete.", $time);
        wait (accelerator_idle_o === 1'b1);

        // --- 5. FFN Calculation ---
        $display("[%0t] STEP 4: Starting FFN calculation and verification.", $time);
        start_ffn_i <= 1'b1;
        @(posedge clk_i);
        start_ffn_i <= 1'b0;
        fork
            // Drive the FFN input (which is the result of the previous layer, residing at BASE_PTR[10])
            drive_s_axis_from_file({simdir,"/","mem.txt"}, BASE_PTR_INPUT[F1], FFN_LOAD_WORDS, i_dut.current_state);
            // Changed to use the verification task
//            
        join
        verify_m_axis_output({simdir,"/","F2.txt"}, FFN_OUTPUT_WORDS);
        wait (ffn_done_o === 1'b1);
        @(posedge clk_i);
        $display("[%0t] FFN calculation and verification complete.", $time);
        wait (accelerator_idle_o === 1'b1);

        // --- 5. End of Test ---
        $display("========================================");
        $display("      Testbench Finished Successfully   ");
        $display("========================================");
        $finish;
    end

endmodule