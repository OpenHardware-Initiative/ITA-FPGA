// NOTE: The original code uses SystemVerilog features. This version has been
// converted to be more compliant with Verilog-2001, as requested.
// However, some constructs like 'string' parameters and struct-based macros
// may rely on tool-specific extensions to work in Verilog-2001 mode.

`include "hci_helpers.svh"
// Verilog-2001 does not support 'import'. Assuming package contents are made
// available via `include`. The filenames are assumed based on package names.
`include "ita_hwpe_package.svh"
`include "hwpe_ctrl_package.svh"
`include "hwpe_stream_package.svh"
`include "hci_package.svh"

/*
 * This module wraps the ITA HWPE (ita_hwpe_wrap) and the URAM memory
 * controller (uram_memory_controller). It handles the internal TCDM
 * connection between them, exposing a clean interface that matches
 * the peripheral and control signals used in the provided testbench.
 */
module ita_top_wrapper #(
    // Parameters for ita_hwpe_wrap
    parameter AccDataWidth = 1024,
    parameter IdWidth      = 8,
    parameter MemDataWidth = 32,

    // Parameters for uram_memory_controller
    parameter TOTAL_WORDS = 277888, // Default size from TB
    // NOTE: 'string' is a SystemVerilog type. This may require a specific
    // simulator/synthesis tool that supports this as an extension.
    parameter string MEM_INIT_FILES [MP-1:0] = '{default:"none"}
) (
    // Global signals
    input  clk_i,
    input  rst_ni,
    input  test_mode_i,

    // Events from HWPE
    output [N_CORES-1:0][1:0] evt_o,
    output                   busy_o,

    // Peripheral slave port (to control the HWPE)
    input                    periph_req_i,
    output                   periph_gnt_o,
    input  [31:0]            periph_add_i,
    input                    periph_wen_i,
    input  [3:0]             periph_be_i,
    input  [31:0]            periph_data_i,
    input  [IdWidth-1:0]     periph_id_i,
    output [31:0]            periph_r_data_o,
    output                   periph_r_valid_o,
    output [IdWidth-1:0]     periph_r_id_o
);

    // Calculate the number of memory ports (MP)
    localparam MP = (AccDataWidth / MemDataWidth);

    // --- Internal Signals for TCDM Connection ---
    // These signals connect the ita_hwpe_wrap to the uram_memory_controller
    wire [MP-1:0]                      tcdm_req;
    wire [MP-1:0]                      tcdm_gnt;
    wire [MP-1:0][31:0]                tcdm_add;
    wire [MP-1:0]                      tcdm_wen;
    wire [MP-1:0][(MemDataWidth/8)-1:0] tcdm_be;
    wire [MP-1:0][MemDataWidth-1:0]    tcdm_data;
    wire [MP-1:0][MemDataWidth-1:0]    tcdm_r_data;
    wire [MP-1:0]                      tcdm_r_valid;

    // --- HCI Interface for URAM Controller ---
    // This creates an array of HCI interfaces, which is the expected
    // input format for the uram_memory_controller.
    // NOTE: The `hci_size_parameter_t` is likely a SystemVerilog struct.
    // This construct relies on the `hci_helpers.svh` macro definitions
    // being compatible with the target Verilog-2001 toolchain.
    localparam hci_size_parameter_t `HCI_SIZE_PARAM(tcdm_mem) = '{
        DW:  AccDataWidth,
        AW:  DEFAULT_AW,
        BW:  DEFAULT_BW,
        UW:  DEFAULT_UW,
        IW:  DEFAULT_IW,
        EW:  DEFAULT_EW,
        EHW: DEFAULT_EHW
    };
    `HCI_INTF_ARRAY(tcdm_mem, clk_i, MP-1:0);

    // --- Instantiate the ITA HWPE Wrapper ---
    // This is the main processing engine.
    ita_hwpe_wrap #(
        .AccDataWidth(AccDataWidth),
        .IdWidth     (IdWidth),
        .MemDataWidth(MemDataWidth)
    ) i_ita_hwpe_wrap (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .test_mode_i   (test_mode_i),
        .evt_o         (evt_o),
        .busy_o        (busy_o),

        // TCDM Master Ports (connected internally)
        .tcdm_req_o    (tcdm_req),
        .tcdm_add_o    (tcdm_add),
        .tcdm_wen_o    (tcdm_wen),
        .tcdm_be_o     (tcdm_be),
        .tcdm_data_o   (tcdm_data),
        .tcdm_gnt_i    (tcdm_gnt),
        .tcdm_r_data_i (tcdm_r_data),
        .tcdm_r_valid_i(tcdm_r_valid),

        // Peripheral Slave Port (exposed to the outside)
        .periph_req_i  (periph_req_i),
        .periph_gnt_o  (periph_gnt_o),
        .periph_add_i  (periph_add_i),
        .periph_wen_i  (periph_wen_i),
        .periph_be_i   (periph_be_i),
        .periph_data_i (periph_data_i),
        .periph_id_i   (periph_id_i),
        .periph_r_data_o(periph_r_data_o),
        .periph_r_valid_o(periph_r_valid_o),
        .periph_r_id_o (periph_r_id_o)
    );

    // --- Instantiate the URAM Memory Controller ---
    // This module models the URAM banks.
    uram_memory_controller #(
        .MP            (MP),
        .TOTAL_WORDS   (TOTAL_WORDS),
        .MEM_INIT_FILES(MEM_INIT_FILES)
    ) i_uram_memory_controller (
        .clk_i (clk_i),
        .rst_ni(rst_ni),
        .tcdm  (tcdm_mem) // Connect the HCI interface array
    );

    // --- Connect HWPE TCDM signals to the HCI Interface ---
    // This generate block translates the parallel TCDM signals from the
    // HWPE into the HCI interface array format required by the memory controller.
    // This logic is identical to the binding in your testbench.
    generate
        for (genvar i = 0; i < MP; i = i + 1) begin
            // Driving signals from HWPE to Memory Controller
            assign tcdm_mem[i].req  = tcdm_req[i];
            assign tcdm_mem[i].add  = tcdm_add[i];
            assign tcdm_mem[i].wen  = tcdm_wen[i];
            assign tcdm_mem[i].be   = tcdm_be[i];
            assign tcdm_mem[i].data = tcdm_data[i];

            // Driving signals from Memory Controller back to HWPE
            assign tcdm_gnt[i]     = tcdm_mem[i].gnt;
            assign tcdm_r_valid[i] = tcdm_mem[i].r_valid;
            assign tcdm_r_data[i]  = tcdm_mem[i].r_data;

            // Tie off unused HCI ports to default values
            assign tcdm_mem[i].user   = 1'b0;
            assign tcdm_mem[i].id     = '0;
            assign tcdm_mem[i].ecc    = '0;
            assign tcdm_mem[i].ereq   = '0;
            assign tcdm_mem[i].r_eready = 1'b1;
        end
    endgenerate

endmodule
