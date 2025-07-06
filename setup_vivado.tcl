# ========================================================================
#             New Vivado Project Creation Script
#
# This script is designed to replicate the successful manual project
# creation workflow, ensuring all properties and file dependencies
# are handled correctly.
# ========================================================================

# --- 1. Project Configuration ---
set proj_name "ITA-kria-vivado"
#set part_name "xck26-sfvc784-2LV-c"
set board_part "xilinx.com:kr260_som:part0:1.1"
set top_rtl   "ita_hwpe_top"
set top_tb    "ita_hwpe_tb"
set ROOT [file dirname [info script]]

# --- 2. Create the Project ---
puts "INFO: Creating Vivado project..."
create_project -force $proj_name ./$proj_name
set_property board_part $board_part [current_project]

# --- 3. Add Project Source Files (from your manual workflow) ---
puts "INFO: Adding project source files..."
add_files -norecurse -scan_for_includes [list \
    "$ROOT/src/ita_weight_controller.sv" \
    "$ROOT/src/ita_sumdotp.sv" \
    "$ROOT/src/hwpe/ita_hwpe_input_bias_buffer.sv" \
    "$ROOT/src/ita_input_sampler.sv" \
    "$ROOT/src/hwpe/ita_hwpe_wrap.sv" \
    "$ROOT/src/ita_max_finder.sv" \
    "$ROOT/src/hwpe/ita_hwpe_input_bias_fence.sv" \
    "$ROOT/src/hwpe/ita_hwpe_streamer.sv" \
    "$ROOT/src/ita_serdiv.sv" \
    "$ROOT/src/ita_register_file_1w_1r_double_width_write.sv" \
    "$ROOT/src/ita_register_file_1w_multi_port_read_we.sv" \
    "$ROOT/src/ita_requantization_controller.sv" \
    "$ROOT/src/ita_controller.sv" \
    "$ROOT/src/ita_inp1_mux.sv" \
    "$ROOT/src/ita_inp2_mux.sv" \
    "$ROOT/src/ita_activation.sv" \
    "$ROOT/src/ita_fifo_controller.sv" \
    "$ROOT/src/ita_package.sv" \
    "$ROOT/src/ita_softmax.sv" \
    "$ROOT/src/ita_softmax_top.sv" \
    "$ROOT/src/ita.sv" \
    "$ROOT/src/ita_requantizer.sv" \
    "$ROOT/src/hwpe/ita_hwpe_output_buffer.sv" \
    "$ROOT/src/ita_gelu.sv" \
    "$ROOT/src/hwpe/ita_hwpe_input_buffer.sv" \
    "$ROOT/src/hwpe/ita_hwpe_top.sv" \
    "$ROOT/src/ita_output_controller.sv" \
    "$ROOT/src/hwpe/ita_hwpe_package.sv" \
    "$ROOT/src/ita_register_file_1w_multi_port_read.sv" \
    "$ROOT/src/ita_relu.sv" \
    "$ROOT/src/hwpe/ita_hwpe_engine.sv" \
    "$ROOT/src/ita_accumulator.sv" \
    "$ROOT/src/ita_dotp.sv" \
    "$ROOT/src/hwpe/ita_hwpe_ctrl.sv" \
]
update_compile_order -fileset sources_1

# --- 4. Add Bender Dependency Files (in logical groups) ---
puts "INFO: Adding Bender dependency files..."

# Add Headers
add_files -norecurse -scan_for_includes "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/common/hci_helpers.svh"

# Add hwpe-stream and hci files
add_files -norecurse -scan_for_includes [list \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/hwpe_stream_interfaces.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_earlystall.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/common/hci_interfaces.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_mux.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_split.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_assign.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_sidech.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/interco/hci_arbiter.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_r_id_filter.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_addressgen.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_addressgen_v3.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_passthrough.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_scm_test_wrap.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_strbgen.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_split.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_mux_static.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_mux_dynamic.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_sink_realign.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_fifo.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_source.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_assign.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_source_realign.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/common/hci_package.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_mux_static.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_fifo_store.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_fifo_load.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/interco/hci_new_log_interconnect.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_fifo_load_sidech.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/hwpe_stream_package.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_earlystall_sidech.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_addressgen_v2.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_r_valid_filter.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_reorder.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_serialize.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_sink.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_source.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/interco/hci_router_reorder.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_demux_static.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_reorder_static.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_buffer.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_scm.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_mux_ooo.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_assign.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_fence.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_ctrl.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_sink.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/interco/hci_log_interconnect_l2.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_merge.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/interco/hci_log_interconnect.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_deserialize.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_mux_static.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_streamer_queue.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/interco/hci_router.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/hci_interconnect.sv" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_fifo.sv" \
]
update_compile_order -fileset sources_1

# Add common_cells, tech_cells, and hwpe-ctrl files
add_files -norecurse -scan_for_includes [list \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_demux.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/fifo_v3.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/lzc.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/deprecated/pulp_pwr_cells.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/edge_propagator_rx.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_arbiter_flushable.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_seq_mult.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/unread.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/ecc_decode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_intf.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/edge_propagator.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/clk_int_div_static.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_package.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/rtl/tc_sram.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_fork.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_interfaces.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/deprecated/pulp_clk_cells.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/gray_to_binary.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/deprecated/cluster_clk_cells.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_fifo_gray_clearable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/addr_decode_napot.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_regfile_latch.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/clk_mux_glitch_free.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_uloop.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_4phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/read.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/lfsr_16bit.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/onehot_to_bin.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/lossy_valid_to_stream.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/shift_reg_gated.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/sync_wedge.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/addr_decode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_fork_dynamic.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/id_queue.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_fifo_2phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/mem_to_banks_detailed.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/plru_tree.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_fifo_optimal_wrap.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cf_math_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/clk_int_div.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/addr_decode_dync.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/passthrough_stream_fifo.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_filter.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_regfile_latch_test_wrap.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_2phase_clearable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_mux.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/deprecated/pulp_buffer.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cc_onehot.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/rstgen_bypass.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/edge_propagator_tx.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/rr_arb_tree.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_regfile_ff.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/ecc_encode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/fall_through_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/popcount.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/lfsr_8bit.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/deprecated/cluster_pwr_cells.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/edge_detect.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/serial_deglitch.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_throttle.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/binary_to_gray.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/isochronous_4phase_handshake.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_slave.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_delay.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/mem_to_banks.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_fifo.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_to_mem.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/max_counter.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/deprecated/generic_rom.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cb_filter_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/spill_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/spill_register_flushable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/delta_counter.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/deprecated/generic_memory.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/mv_filter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/shift_reg.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/rtl/tc_sram_impl.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_fifo_gray.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cb_filter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_xbar.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/edge_propagator_ack.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/tc_pwr.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_reset_ctrlr_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_2phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_reset_ctrlr.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/exp_backoff.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/rstgen.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/deprecated/pad_functional.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/lfsr.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/credit_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/isochronous_spill_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/sync.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_join_dynamic.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_omega_net.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_join.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_arbiter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/sub_per_hash.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_regfile.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/rtl/tc_clk.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/multiaddr_decode.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/deprecated/pulp_clock_gating_async.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/ecc_pkg.sv" \
]
update_compile_order -fileset sources_1

# Add scm files
add_files -norecurse -scan_for_includes [list \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_2r_1w_asymm.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1w_multi_port_read_be.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1w_64b_multi_port_read_32b_1row.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1w_64b_multi_port_read_32b.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1w_multi_port_read.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_multi_way_1w_64b_multi_port_read_32b.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_2r_2w.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1r_1w_test_wrap_bypass.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1w_128b_multi_port_read_32b.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_2r_1w_asymm_test_wrap.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_3r_2w.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_3r_2w_be.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1w_64b_multi_port_read_128b.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1r_1w_all_test_wrap.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1w_multi_port_read_1row.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1r_1w_be.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1r_1w_test_wrap.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1r_1w_all.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1w_64b_1r_32b.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_multi_way_1w_multi_port_read.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1r_1w.sv" \
    "$ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/latch_scm/register_file_1r_1w_1row.sv" \
]
update_compile_order -fileset sources_1

# --- 5. Set Include Directories ---
puts "INFO: Setting include directories..."
set_property include_dirs [list \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/include" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/common" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl" \
] [current_fileset]

set_property include_dirs [list \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco" \
    "$ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/include" \
    "$ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/common" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl" \
] [get_filesets sim_1]


# --- 6. Set Verilog Defines (Macros) ---
# These macros are extracted from the Makefile and compile.tcl to align
# the Vivado project with the original compilation environment.
puts "INFO: Setting Verilog defines..."
set verilog_macros [list \
    "TARGET_ITA_HWPE" \
    "TARGET_ITA_HWPE_TEST" \
    "TARGET_RTL" \
    "TARGET_SIMULATION" \
    "TARGET_TEST" \
    "TARGET_VSIM" \
    "NO_STALLS=0" \
    "SINGLE_ATTENTION=0" \
    "SEQ_LENGTH=64" \
    "EMBED_SIZE=128" \
    "PROJ_SPACE=192" \
    "FF_SIZE=256" \
    "BIAS=0" \
    "ACTIVATION=Identity" \
    "HCI_ASSERT_DELAY=\#41ps" \
]

# Apply the macros to both synthesis and simulation filesets
set_property verilog_define $verilog_macros [get_filesets sources_1]
set_property verilog_define $verilog_macros [get_filesets sim_1]


# --- 7. Configure Simulation Fileset ---
puts "INFO: Configuring simulation fileset..."
add_files -fileset sim_1 -norecurse -scan_for_includes [list \
    "$ROOT/src/tb/activation_tb.sv" \
    "$ROOT/src/hwpe/tb/ita_hwpe_tb.sv" \
    "$ROOT/src/hwpe/tb/tb_dummy_memory.sv" \
    "$ROOT/src/tb/clk_rst_gen.sv" \
    "$ROOT/src/tb/ita_tb.sv" \
    "$ROOT/src/tb/rst_gen.sv" \
]

# --- 8. Finalize Setup ---
puts "INFO: Setting top-level modules..."
set_property source_mgmt_mode None [current_project]
update_compile_order -fileset sources_1
set_property top $top_rtl [get_filesets sources_1]

update_compile_order -fileset sim_1
set_property top $top_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property source_mgmt_mode All [current_project]

puts "INFO: Project setup complete."