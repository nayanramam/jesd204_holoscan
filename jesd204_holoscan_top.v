`timescale 1ns/100ps

module jesd204_holoscan_top #(
  parameter NUM_LANES = 3,
  parameter NUM_CHANNELS = 4,
  parameter SAMPLES_PER_FRAME = 1,
  parameter CONVERTER_RESOLUTION = 14,
  parameter BITS_PER_SAMPLE = 16,
  parameter OCTETS_PER_BEAT = 4,
  parameter LINK_MODE = 1,  // 1 for 8B/10B, 2 for 64B/66B
  parameter DATA_PATH_WIDTH = LINK_MODE == 2 ? 8 : 4,
  parameter TPL_DATA_PATH_WIDTH = LINK_MODE == 2 ? 8 : 4
) (
  // System interface
  input sys_clk,
  input sys_reset,
  
  // FMC connector interface
  input [NUM_LANES-1:0] fmc_rx_p,
  input [NUM_LANES-1:0] fmc_rx_n,
  input fmc_sysref_p,
  input fmc_sysref_n,
  input fmc_sync_p,
  input fmc_sync_n,
  input fmc_clk_p,
  input fmc_clk_n,
  
  // Ethernet interface
  output [7:0] eth_tx_data,
  output eth_tx_valid,
  input eth_tx_ready,
  output eth_tx_last,
  
  // Status and control
  output [31:0] status_packets_sent,
  output [31:0] status_bytes_sent,
  output status_link_ready,
  output status_jesd_sync,
  output [NUM_LANES-1:0] status_lane_ready,
  
  // Configuration interface
  input [9:0] cfg_octets_per_multiframe,
  input [7:0] cfg_octets_per_frame,
  input cfg_disable_scrambler,
  input [7:0] cfg_frame_align_err_threshold,
  input [7:0] cfg_lmfc_offset,
  input cfg_sysref_oneshot,
  input cfg_sysref_disable
);

  // Internal signals
  wire jesd_clk;
  wire jesd_clk_locked;
  wire jesd_reset;
  
  wire [DATA_PATH_WIDTH*8*NUM_LANES-1:0] jesd_phy_data;
  wire [2*NUM_LANES-1:0] jesd_phy_header;
  wire [DATA_PATH_WIDTH*NUM_LANES-1:0] jesd_phy_charisk;
  wire [DATA_PATH_WIDTH*NUM_LANES-1:0] jesd_phy_notintable;
  wire [DATA_PATH_WIDTH*NUM_LANES-1:0] jesd_phy_disperr;
  wire [NUM_LANES-1:0] jesd_phy_block_sync;
  wire jesd_sysref;
  wire jesd_sync;
  
  wire [TPL_DATA_PATH_WIDTH*8*NUM_LANES-1:0] jesd_rx_data;
  wire jesd_rx_valid;
  wire [TPL_DATA_PATH_WIDTH-1:0] jesd_rx_eof;
  wire [TPL_DATA_PATH_WIDTH-1:0] jesd_rx_sof;
  wire [TPL_DATA_PATH_WIDTH-1:0] jesd_rx_eomf;
  wire [TPL_DATA_PATH_WIDTH-1:0] jesd_rx_somf;
  
  wire [NUM_LANES-1:0] jesd_sync_status;
  wire jesd_event_sysref_alignment_error;
  wire jesd_event_sysref_edge;
  wire jesd_event_frame_alignment_error;
  wire jesd_event_unexpected_lane_state_error;
  
  // Clock management
  lattice_clock_mgr #(
    .CLK_IN_FREQ(100_000_000),
    .CLK_OUT_FREQ(200_000_000)
  ) i_clock_mgr (
    .clk_in(sys_clk),
    .reset(sys_reset),
    .clk_out(jesd_clk),
    .locked(jesd_clk_locked)
  );
  
  assign jesd_reset = sys_reset || !jesd_clk_locked;
  
  // FMC interface
  fmc_jesd204_interface #(
    .NUM_LANES(NUM_LANES),
    .DATA_WIDTH(DATA_PATH_WIDTH*8),
    .LINK_MODE(LINK_MODE)
  ) i_fmc_interface (
    .fmc_rx_p(fmc_rx_p),
    .fmc_rx_n(fmc_rx_n),
    .fmc_sysref_p(fmc_sysref_p),
    .fmc_sysref_n(fmc_sysref_n),
    .fmc_sync_p(fmc_sync_p),
    .fmc_sync_n(fmc_sync_n),
    .fmc_clk_p(fmc_clk_p),
    .fmc_clk_n(fmc_clk_n),
    .jesd_clk(jesd_clk),
    .jesd_clk_locked(jesd_clk_locked),
    .jesd_data(jesd_phy_data),
    .jesd_charisk(jesd_phy_charisk),
    .jesd_notintable(jesd_phy_notintable),
    .jesd_disperr(jesd_phy_disperr),
    .jesd_block_sync(jesd_phy_block_sync),
    .jesd_sysref(jesd_sysref),
    .jesd_sync(jesd_sync),
    .reset(jesd_reset),
    .link_ready(status_link_ready)
  );
  
  // JESD204B receiver
  jesd204_rx #(
    .NUM_LANES(NUM_LANES),
    .NUM_LINKS(1),
    .NUM_INPUT_PIPELINE(1),
    .NUM_OUTPUT_PIPELINE(1),
    .LINK_MODE(LINK_MODE),
    .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
    .ENABLE_FRAME_ALIGN_CHECK(1),
    .ENABLE_FRAME_ALIGN_ERR_RESET(0),
    .ENABLE_CHAR_REPLACE(0),
    .ASYNC_CLK(1),
    .TPL_DATA_PATH_WIDTH(TPL_DATA_PATH_WIDTH)
  ) i_jesd204_rx (
    .clk(jesd_clk),
    .reset(jesd_reset),
    .device_clk(jesd_clk),
    .device_reset(jesd_reset),
    
    .phy_data(jesd_phy_data),
    .phy_header(jesd_phy_header),
    .phy_charisk(jesd_phy_charisk),
    .phy_notintable(jesd_phy_notintable),
    .phy_disperr(jesd_phy_disperr),
    .phy_block_sync(jesd_phy_block_sync),
    
    .sysref(jesd_sysref),
    .lmfc_edge(),
    .lmfc_clk(),
    
    .device_event_sysref_alignment_error(jesd_event_sysref_alignment_error),
    .device_event_sysref_edge(jesd_event_sysref_edge),
    .event_frame_alignment_error(jesd_event_frame_alignment_error),
    .event_unexpected_lane_state_error(jesd_event_unexpected_lane_state_error),
    
    .sync(jesd_sync_status),
    .phy_en_char_align(),
    
    .rx_data(jesd_rx_data),
    .rx_valid(jesd_rx_valid),
    .rx_eof(jesd_rx_eof),
    .rx_sof(jesd_rx_sof),
    .rx_eomf(jesd_rx_eomf),
    .rx_somf(jesd_rx_somf),
    
    .cfg_lanes_disable({NUM_LANES{1'b0}}),
    .cfg_links_disable(1'b0),
    .cfg_octets_per_multiframe(cfg_octets_per_multiframe),
    .cfg_octets_per_frame(cfg_octets_per_frame),
    .cfg_disable_scrambler(cfg_disable_scrambler),
    .cfg_disable_char_replacement(1'b0),
    .cfg_frame_align_err_threshold(cfg_frame_align_err_threshold),
    
    .device_cfg_octets_per_multiframe(cfg_octets_per_multiframe),
    .device_cfg_octets_per_frame(cfg_octets_per_frame),
    .device_cfg_beats_per_multiframe(cfg_octets_per_multiframe >> 2),
    .device_cfg_lmfc_offset(cfg_lmfc_offset),
    .device_cfg_sysref_oneshot(cfg_sysref_oneshot),
    .device_cfg_sysref_disable(cfg_sysref_disable),
    .device_cfg_buffer_early_release(1'b0),
    .device_cfg_buffer_delay(8'd0),
    
    .ctrl_err_statistics_reset(1'b0),
    .ctrl_err_statistics_mask(7'd0),
    
    .status_err_statistics_cnt(),
    .ilas_config_valid(),
    .ilas_config_addr(),
    .ilas_config_data(),
    .status_ctrl_state(),
    .status_lane_cgs_state(),
    .status_lane_ifs_ready(status_lane_ready),
    .status_lane_latency(),
    .status_lane_emb_state(),
    .status_lane_frame_align_err_cnt(),
    .status_synth_params0(),
    .status_synth_params1(),
    .status_synth_params2()
  );
  
  // Ethernet streamer
  ethernet_streamer #(
    .DATA_WIDTH(TPL_DATA_PATH_WIDTH*8*NUM_LANES),
    .FRAME_SIZE(1500),
    .DEST_MAC(48'hAABBCCDDEEFF),
    .SRC_MAC(48'h112233445566),
    .DEST_IP(32'hC0A80101),
    .SRC_IP(32'hC0A80102),
    .DEST_PORT(16'h1234),
    .SRC_PORT(16'h5678)
  ) i_ethernet_streamer (
    .clk(jesd_clk),
    .reset(jesd_reset),
    
    .jesd_data(jesd_rx_data),
    .jesd_valid(jesd_rx_valid),
    .jesd_sof(|jesd_rx_sof),
    .jesd_eof(|jesd_rx_eof),
    
    .eth_tx_data(eth_tx_data),
    .eth_tx_valid(eth_tx_valid),
    .eth_tx_ready(eth_tx_ready),
    .eth_tx_last(eth_tx_last),
    
    .packets_sent(status_packets_sent),
    .bytes_sent(status_bytes_sent),
    .link_status()
  );
  
  // Status assignments
  assign status_jesd_sync = |jesd_sync_status;

endmodule 