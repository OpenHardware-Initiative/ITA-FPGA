# This script was generated automatically by bender.
set ROOT "/Projects/Agus/ITA"

add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/src/hwpe/tb/tb_dummy_memory.sv \
    $ROOT/src/hwpe/tb/ita_hwpe_tb.sv \
    $ROOT/src/ita_package.sv \
    $ROOT/src/ita_accumulator.sv \
    $ROOT/src/ita_controller.sv \
    $ROOT/src/ita_dotp.sv \
    $ROOT/src/ita_fifo_controller.sv \
    $ROOT/src/ita_inp1_mux.sv \
    $ROOT/src/ita_inp2_mux.sv \
    $ROOT/src/ita_input_sampler.sv \
    $ROOT/src/ita_output_controller.sv \
    $ROOT/src/ita_register_file_1w_1r_double_width_write.sv \
    $ROOT/src/ita_register_file_1w_multi_port_read.sv \
    $ROOT/src/ita_register_file_1w_multi_port_read_we.sv \
    $ROOT/src/ita_requantizer.sv \
    $ROOT/src/ita_serdiv.sv \
    $ROOT/src/ita_softmax.sv \
    $ROOT/src/ita_softmax_top.sv \
    $ROOT/src/ita_sumdotp.sv \
    $ROOT/src/ita_weight_controller.sv \
    $ROOT/src/ita.sv \
    $ROOT/src/ita_max_finder.sv \
    $ROOT/src/ita_gelu.sv \
    $ROOT/src/ita_relu.sv \
    $ROOT/src/ita_activation.sv \
    $ROOT/src/ita_requantization_controller.sv \
    $ROOT/src/hwpe/ita_hwpe_package.sv \
    $ROOT/src/hwpe/ita_hwpe_ctrl.sv \
    $ROOT/src/hwpe/ita_hwpe_engine.sv \
    $ROOT/src/hwpe/ita_hwpe_input_buffer.sv \
    $ROOT/src/hwpe/ita_hwpe_input_bias_buffer.sv \
    $ROOT/src/hwpe/ita_hwpe_input_bias_fence.sv \
    $ROOT/src/hwpe/ita_hwpe_output_buffer.sv \
    $ROOT/src/hwpe/ita_hwpe_streamer.sv \
    $ROOT/src/hwpe/ita_hwpe_top.sv \
    $ROOT/src/hwpe/ita_hwpe_wrap.sv \
    $ROOT/src/tb/ita_tb.sv \
    $ROOT/src/tb/clk_rst_gen.sv \
    $ROOT/src/tb/rst_gen.sv \
    $ROOT/src/tb/activation_tb.sv \
]

set_property verilog_define [list \
    TARGET_FPGA \
    TARGET_ITA_HWPE \
    TARGET_ITA_HWPE_TEST \
    TARGET_RTL \
    TARGET_SYNTHESIS \
    TARGET_TEST \
    TARGET_VIVADO \
    TARGET_XILINX \
] [current_fileset]

set_property verilog_define [list \
    TARGET_FPGA \
    TARGET_ITA_HWPE \
    TARGET_ITA_HWPE_TEST \
    TARGET_RTL \
    TARGET_SYNTHESIS \
    TARGET_TEST \
    TARGET_VIVADO \
    TARGET_XILINX \
] [current_fileset -simset]




add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/common_verification-2d4a75665ce644a6/test/tb_clk_rst_gen.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/fpga/pad_functional_xilinx.sv \
    $ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/fpga/tc_clk_xilinx.sv \
    $ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/fpga/tc_sram_xilinx.sv \
    $ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/rtl/tc_sram_impl.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/test/tb_tc_sram.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/deprecated/pulp_clock_gating_async.sv \
    $ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/deprecated/cluster_clk_cells.sv \
    $ROOT/.bender/git/checkouts/tech_cells_generic-55fa3871c0dd2458/src/deprecated/pulp_clk_cells.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/binary_to_gray.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cb_filter_pkg.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cc_onehot.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_reset_ctrlr_pkg.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cf_math_pkg.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/clk_int_div.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/credit_counter.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/delta_counter.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/ecc_pkg.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/edge_propagator_tx.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/exp_backoff.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/fifo_v3.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/gray_to_binary.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/isochronous_4phase_handshake.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/isochronous_spill_register.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/lfsr.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/lfsr_16bit.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/lfsr_8bit.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/lossy_valid_to_stream.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/mv_filter.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/onehot_to_bin.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/plru_tree.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/passthrough_stream_fifo.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/popcount.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/rr_arb_tree.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/rstgen_bypass.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/serial_deglitch.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/shift_reg.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/shift_reg_gated.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/spill_register_flushable.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_demux.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_filter.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_fork.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_intf.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_join_dynamic.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_mux.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_throttle.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/sub_per_hash.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/sync.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/sync_wedge.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/unread.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/read.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/addr_decode_dync.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_2phase.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_4phase.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/clk_int_div_static.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/addr_decode.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/addr_decode_napot.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/multiaddr_decode.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cb_filter.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_fifo_2phase.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/clk_mux_glitch_free.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/counter.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/ecc_decode.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/ecc_encode.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/edge_detect.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/lzc.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/max_counter.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/rstgen.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/spill_register.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_delay.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_fifo.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_fork_dynamic.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_join.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_reset_ctrlr.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_fifo_gray.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/fall_through_register.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/id_queue.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_to_mem.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_arbiter_flushable.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_fifo_optimal_wrap.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_register.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_xbar.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_fifo_gray_clearable.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/cdc_2phase_clearable.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/mem_to_banks_detailed.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_arbiter.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/stream_omega_net.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/mem_to_banks.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/addr_decode_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/cb_filter_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/cdc_2phase_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/cdc_2phase_clearable_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/cdc_fifo_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/cdc_fifo_clearable_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/fifo_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/graycode_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/id_queue_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/passthrough_stream_fifo_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/popcount_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/rr_arb_tree_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/stream_test.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/stream_register_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/stream_to_mem_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/sub_per_hash_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/isochronous_crossing_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/stream_omega_net_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/stream_xbar_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/clk_int_div_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/clk_int_div_static_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/clk_mux_glitch_free_tb.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/test/lossy_valid_to_stream_tb.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/deprecated/clock_divider_counter.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/deprecated/clk_div.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/deprecated/find_first_one.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/deprecated/generic_LFSR_8bit.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/deprecated/generic_fifo.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/deprecated/prioarbiter.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/deprecated/pulp_sync.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/deprecated/pulp_sync_wedge.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/deprecated/rrarbiter.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/deprecated/clock_divider.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/deprecated/fifo_v2.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/deprecated/fifo_v1.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/edge_propagator_ack.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/edge_propagator.sv \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/src/edge_propagator_rx.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/tcdm_interconnect/tcdm_interconnect_pkg.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/tcdm_interconnect/addr_dec_resp_mux.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/tcdm_interconnect/amo_shim.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/variable_latency_interconnect/addr_decoder.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/tcdm_interconnect/xbar.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/variable_latency_interconnect/simplex_xbar.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/tcdm_interconnect/clos_net.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/tcdm_interconnect/bfly_net.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/variable_latency_interconnect/full_duplex_xbar.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/tcdm_interconnect/tcdm_interconnect.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/variable_latency_interconnect/variable_latency_bfly_net.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/variable_latency_interconnect/variable_latency_interconnect.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/FanInPrimitive_Req.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/ArbitrationTree.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/MUX2_REQ.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/AddressDecoder_Resp.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/TestAndSet.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/RequestBlock2CH.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/RequestBlock1CH.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/FanInPrimitive_Resp.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/ResponseTree.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/ResponseBlock.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/AddressDecoder_Req.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/XBAR_TCDM.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/XBAR_TCDM_WRAPPER.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/TCDM_PIPE_REQ.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/TCDM_PIPE_RESP.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/grant_mask.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco/priority_Flag_Req.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco/AddressDecoder_PE_Req.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco/AddressDecoder_Resp_PE.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco/ArbitrationTree_PE.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco/FanInPrimitive_Req_PE.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco/RR_Flag_Req_PE.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco/MUX2_REQ_PE.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco/FanInPrimitive_PE_Resp.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco/RequestBlock1CH_PE.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco/RequestBlock2CH_PE.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco/ResponseBlock_PE.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco/ResponseTree_PE.sv \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco/XBAR_PE.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/hwpe_stream_interfaces.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/hwpe_stream_package.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_assign.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_buffer.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_demux_static.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_deserialize.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_fence.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_merge.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_mux_static.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_serialize.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/basic/hwpe_stream_split.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_ctrl.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_scm.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_addressgen.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_addressgen_v2.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_addressgen_v3.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_sink_realign.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_source_realign.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_strbgen.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_streamer_queue.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_assign.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_mux.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_mux_static.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_reorder.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_reorder_static.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_earlystall.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_earlystall_sidech.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_scm_test_wrap.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_sidech.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_fifo_load_sidech.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/fifo/hwpe_stream_fifo_passthrough.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_source.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_fifo.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_fifo_load.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/tcdm/hwpe_stream_tcdm_fifo_store.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/streamer/hwpe_stream_sink.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/verif/hwpe_stream_traffic_gen.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/verif/hwpe_stream_traffic_recv.sv \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl/verif/tb_fifo.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/l2_tcdm_demux.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/lint_2_apb.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/lint_2_axi.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/axi_2_lint/axi64_2_lint32.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/axi_2_lint/axi_read_ctrl.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/axi_2_lint/axi_write_ctrl.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/axi_2_lint/lint64_to_32.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_L2/AddressDecoder_Req_L2.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_L2/AddressDecoder_Resp_L2.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_L2/ArbitrationTree_L2.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_L2/FanInPrimitive_Req_L2.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_L2/FanInPrimitive_Resp_L2.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_L2/MUX2_REQ_L2.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_L2/RequestBlock_L2_1CH.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_L2/RequestBlock_L2_2CH.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_L2/ResponseBlock_L2.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_L2/ResponseTree_L2.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_L2/RR_Flag_Req_L2.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_L2/XBAR_L2.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_BRIDGE/AddressDecoder_Req_BRIDGE.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_BRIDGE/AddressDecoder_Resp_BRIDGE.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_BRIDGE/ArbitrationTree_BRIDGE.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_BRIDGE/FanInPrimitive_Req_BRIDGE.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_BRIDGE/FanInPrimitive_Resp_BRIDGE.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_BRIDGE/MUX2_REQ_BRIDGE.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_BRIDGE/RequestBlock1CH_BRIDGE.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_BRIDGE/RequestBlock2CH_BRIDGE.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_BRIDGE/ResponseBlock_BRIDGE.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_BRIDGE/ResponseTree_BRIDGE.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_BRIDGE/RR_Flag_Req_BRIDGE.sv \
    $ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-b72bbb714e0dc5a5/RTL/XBAR_BRIDGE/XBAR_BRIDGE.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/common/hci_package.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/common/hci_interfaces.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_assign.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_fifo.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_mux_dynamic.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_mux_static.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_mux_ooo.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_r_valid_filter.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_r_id_filter.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_source.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_split.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/interco/hci_log_interconnect.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/interco/hci_log_interconnect_l2.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/interco/hci_new_log_interconnect.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/interco/hci_arbiter.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/interco/hci_router_reorder.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/core/hci_core_sink.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/interco/hci_router.sv \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/hci_interconnect.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_interfaces.sv \
    $ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_package.sv \
    $ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_regfile_ff.sv \
    $ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_regfile_latch.sv \
    $ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_seq_mult.sv \
    $ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_uloop.sv \
    $ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_regfile_latch_test_wrap.sv \
    $ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_regfile.sv \
    $ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl/hwpe_ctrl_slave.sv \
]
add_files -norecurse -fileset [current_fileset] [list \
    $ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/fpga_scm/register_file_1r_1w_all.sv \
    $ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/fpga_scm/register_file_1r_1w_be.sv \
    $ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/fpga_scm/register_file_1r_1w.sv \
    $ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/fpga_scm/register_file_1r_1w_1row.sv \
    $ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/fpga_scm/register_file_1r_1w_raw.sv \
    $ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/fpga_scm/register_file_1w_multi_port_read.sv \
    $ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/fpga_scm/register_file_1w_64b_multi_port_read_32b.sv \
    $ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/fpga_scm/register_file_1w_64b_1r_32b.sv \
    $ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/fpga_scm/register_file_2r_1w_asymm.sv \
    $ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/fpga_scm/register_file_2r_1w_asymm_test_wrap.sv \
    $ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/fpga_scm/register_file_2r_2w.sv \
    $ROOT/.bender/git/checkouts/scm-a479c2e455a7e638/fpga_scm/register_file_3r_2w.sv \
]

set_property include_dirs [list \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/include \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/common \
    $ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl \
] [current_fileset]

set_property include_dirs [list \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/low_latency_interco \
    $ROOT/.bender/git/checkouts/cluster_interconnect-d5833d25198a0133/rtl/peripheral_interco \
    $ROOT/.bender/git/checkouts/common_cells-a9dda427ecf0aef2/include \
    $ROOT/.bender/git/checkouts/hci-5c5dd55394261a4b/rtl/common \
    $ROOT/.bender/git/checkouts/hwpe-ctrl-b4d268c729c1adb1/rtl \
    $ROOT/.bender/git/checkouts/hwpe-stream-5514f8f76c0edc16/rtl \
] [current_fileset -simset]

