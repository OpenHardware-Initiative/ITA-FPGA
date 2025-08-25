`timescale 1ns/1ps

module tb_ITA_FPGA_WRAPPER;

    // =================================================================
    // Parameters and Constants
    // =================================================================
    // Match the DUT's default parameters
    localparam N_CORES = 1;
    
    localparam int unsigned AccDataWidth = 1024;
    localparam int unsigned IdWidth      = 8;
    localparam int unsigned MemDataWidth = 32;
    localparam int unsigned MP = (AccDataWidth / MemDataWidth);
    
    // AXI parameters
    localparam integer C_S_AXIS_TDATA_WIDTH = 32;
    localparam integer C_M_AXIS_TDATA_WIDTH = 32;
    
    // Data Parameters (matching DUT defaults)
    localparam int M_TILE_LEN = 64;
    localparam int SEQUENCE_LEN = 128;
    localparam int PROJECTION_SPACE = 128;
    localparam int EMBEDDING_SIZE = 256;
    localparam int FEEDFORWARD_SIZE = 256;
    
    // Testbench control
    localparam CLK_PERIOD = 10; // 100 MHz clock

    // Pre-calculated data transfer lengths (in 32-bit words)
    // These should be calculated based on the parameters to ensure correctness.
    // NOTE: For this example, these are placeholders. You must calculate the exact sizes.
    // Example calculation for Q_WORDS: (SEQUENCE_LEN * EMBEDDING_SIZE * 4 bytes/word) / (C_S_AXIS_TDATA_WIDTH / 8 bytes/word)
    localparam int WB_LOAD_WORDS     = 90976; // Placeholder: Calculate actual size of all weights/biases
    localparam int ATTN_LOAD_WORDS   = (SEQUENCE_LEN * EMBEDDING_SIZE * 3) / (C_S_AXIS_TDATA_WIDTH / 8); // Q, K, and V
    localparam int ATTN_OUTPUT_WORDS = (SEQUENCE_LEN * EMBEDDING_SIZE) / (C_M_AXIS_TDATA_WIDTH / 8);
    localparam int FFN_LOAD_WORDS    = (SEQUENCE_LEN * EMBEDDING_SIZE) / (C_S_AXIS_TDATA_WIDTH / 8);
    localparam int FFN_OUTPUT_WORDS  = (SEQUENCE_LEN * EMBEDDING_SIZE) / (C_M_AXIS_TDATA_WIDTH / 8);

    // =================================================================
    // Testbench Signals
    // =================================================================
    logic clk_i;
    logic rst_ni;
    logic test_mode_i;
    
    logic [C_M_AXIS_TDATA_WIDTH-1:0] base_addr_i;

    wire  [N_CORES-1:0][1:0] evt_o;
    wire                     busy_o;
    
    logic start_wb_i;
    logic start_attn_i;
    logic start_ffn_i;
    
    wire  wb_done_o;
    wire  attn_done_o;
    wire  ffn_done_o;
    wire  accelerator_idle_o;

    logic dma_mode_o;
    logic dma_we_o;
    
    logic [C_S_AXIS_TDATA_WIDTH-1:0] s_axis_tdata;
    logic                            s_axis_tvalid;
    wire                             s_axis_tready;
    
    wire  [C_M_AXIS_TDATA_WIDTH-1:0] m_axis_tdata;
    wire                             m_axis_tvalid;
    logic                            m_axis_tready;

    // =================================================================
    // DUT Instantiation
    // =================================================================
    ITA_FPGA_WRAPPER #(
        .AccDataWidth(AccDataWidth),
        .MemDataWidth(MemDataWidth),
        .C_S_AXIS_TDATA_WIDTH(C_S_AXIS_TDATA_WIDTH),
        .C_M_AXIS_TDATA_WIDTH(C_M_AXIS_TDATA_WIDTH),
        .M_TILE_LEN(M_TILE_LEN),
        .SEQUENCE_LEN(SEQUENCE_LEN),
        .PROJECTION_SPACE(PROJECTION_SPACE),
        .EMBEDDING_SIZE(EMBEDDING_SIZE),
        .FEEDFORWARD_SIZE(FEEDFORWARD_SIZE)
    ) i_dut (.*);

    // =================================================================
    // Clock and Reset Generation
    // =================================================================
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

    // Task to drive the s_axis interface from a text file
    task automatic drive_s_axis_from_file(string filename, int num_words);
        integer file;
        logic [C_S_AXIS_TDATA_WIDTH-1:0] data_word;

        $display("[%0t] Starting to drive data from file: %s", $time, filename);
        file = $fopen(filename, "r");
        if (file == 0) begin
            $error("Could not open file: %s", filename);
            $finish;
        end

        for (int i = 0; i < num_words; i++) begin
            if ($fscanf(file, "%h", data_word) != 1) begin
                $error("Failed to read word %0d from file %s", i, filename);
                $finish;
            end
            
            s_axis_tvalid <= 1'b1;
            s_axis_tdata <= data_word;
            
            @(posedge clk_i);
            while (s_axis_tready !== 1'b1) begin
                @(posedge clk_i);
            end
        end

        s_axis_tvalid <= 1'b0;
        $fclose(file);
        $display("[%0t] Finished driving %0d words from %s", $time, num_words, filename);
    endtask

    // Task to receive data from m_axis and write to a text file
    task automatic receive_m_axis_to_file(string filename, int num_words);
        integer file;

        $display("[%0t] Starting to receive data into file: %s", $time, filename);
        file = $fopen(filename, "w");
        if (file == 0) begin
            $error("Could not open file for writing: %s", filename);
            $finish;
        end

        m_axis_tready <= 1'b1;

        for (int i = 0; i < num_words; i++) begin
            while (m_axis_tvalid !== 1'b1) begin
                @(posedge clk_i);
            end
            
            $fdisplay(file, "%h", m_axis_tdata);
            @(posedge clk_i);
        end
        
        m_axis_tready <= 1'b0;
        $fclose(file);
        $display("[%0t] Finished receiving %0d words into %s", $time, num_words, filename);
    endtask

    // =================================================================
    // Main Test Sequence
    // =================================================================
    initial begin
        $display("========================================");
        $display("   Starting ITA_FPGA_WRAPPER Testbench  ");
        $display("========================================");

        // --- 1. Initialization ---
        test_mode_i <= 1'b0;
        base_addr_i <= 32'h0;
        start_wb_i <= 1'b0;
        start_attn_i <= 1'b0;
        start_ffn_i <= 1'b0;
        s_axis_tvalid <= 1'b0;
        s_axis_tdata <= '0;
        m_axis_tready <= 1'b0;
        
        # (CLK_PERIOD * 10);
//        @(negedge rst_ni);
//        @(posedge rst_ni);
//        $display("[%0t] Reset complete. Waiting for DUT to be idle.", $time);
        
        wait (accelerator_idle_o === 1'b1);
        $display("[%0t] DUT is IDLE.", $time);

        // --- 2. Weight/Bias Loading Phase ---
        $display("[%0t] Starting Weight/Bias loading phase.", $time);
        start_wb_i <= 1'b1;
        @(posedge clk_i);
        start_wb_i <= 1'b0;
        
        // Drive data onto the AXI stream
        drive_s_axis_from_file("/home/ge27lob/Desktop/ITA-FPGA/ita_kria_wrapper/mem_files/full_memory.txt", WB_LOAD_WORDS);
        
        // Wait for the done signal
        wait (wb_done_o === 1'b1);
        @(posedge clk_i);
        $display("[%0t] Weight/Bias loading complete (wb_done_o asserted).", $time);
        
        wait (accelerator_idle_o === 1'b1);
        $display("[%0t] DUT has returned to IDLE.", $time);

        // --- 3. Attention Calculation Phase ---
        $display("[%0t] Starting Attention calculation phase.", $time);
        start_attn_i <= 1'b1;
        @(posedge clk_i);
        start_attn_i <= 1'b0;
        
        // Fork separate processes for driving input and receiving output
        fork
            drive_s_axis_from_file("/home/ge27lob/Desktop/ITA-FPGA/ita_kria_wrapper/mem_files/full_memory.txt", ATTN_LOAD_WORDS);
            receive_m_axis_to_file("/home/ge27lob/Desktop/ITA-FPGA/ita_kria_wrapper/mem_files/out.txt", ATTN_OUTPUT_WORDS);
        join
        
        wait (attn_done_o === 1'b1);
        @(posedge clk_i);
        $display("[%0t] Attention calculation complete (attn_done_o asserted).", $time);
        
        wait (accelerator_idle_o === 1'b1);
        $display("[%0t] DUT has returned to IDLE.", $time);

        // --- 4. FFN Calculation Phase ---
        $display("[%0t] Starting FFN calculation phase.", $time);
        start_ffn_i <= 1'b1;
        @(posedge clk_i);
        start_ffn_i <= 1'b0;
        
        fork
            drive_s_axis_from_file("ffn_input.txt", FFN_LOAD_WORDS);
            receive_m_axis_to_file("ffn_output.txt", FFN_OUTPUT_WORDS);
        join
        
        wait (ffn_done_o === 1'b1);
        @(posedge clk_i);
        $display("[%0t] FFN calculation complete (ffn_done_o asserted).", $time);
        
        wait (accelerator_idle_o === 1'b1);
        $display("[%0t] DUT has returned to IDLE.", $time);

        // --- 5. End of Test ---
        $display("========================================");
        $display("      Testbench Finished Successfully   ");
        $display("========================================");
        $finish;
    end

endmodule