`timescale 1ns/100ps

module jesd204_holoscan_tb;

  // Test parameters
  parameter NUM_LANES = 4;
  parameter NUM_CHANNELS = 4;
  parameter SAMPLES_PER_FRAME = 1;
  parameter CONVERTER_RESOLUTION = 14;
  parameter BITS_PER_SAMPLE = 16;
  parameter OCTETS_PER_BEAT = 4;
  parameter LINK_MODE = 1;
  parameter DATA_PATH_WIDTH = LINK_MODE == 2 ? 8 : 4;
  parameter TPL_DATA_PATH_WIDTH = LINK_MODE == 2 ? 8 : 4;
  
  // Clock and reset
  reg sys_clk = 0;
  reg sys_reset = 1;
  
  // FMC interface signals
  reg [NUM_LANES-1:0] fmc_rx_p = 0;
  reg [NUM_LANES-1:0] fmc_rx_n = 0;
  reg fmc_sysref_p = 0;
  reg fmc_sysref_n = 0;
  reg fmc_sync_p = 0;
  reg fmc_sync_n = 0;
  reg fmc_clk_p = 0;
  reg fmc_clk_n = 0;
  
  // Ethernet interface signals
  wire [7:0] eth_tx_data;
  wire eth_tx_valid;
  reg eth_tx_ready = 1;
  wire eth_tx_last;
  
  // Status signals
  wire [31:0] status_packets_sent;
  wire [31:0] status_bytes_sent;
  wire status_link_ready;
  wire status_jesd_sync;
  wire [NUM_LANES-1:0] status_lane_ready;
  
  // Configuration signals
  reg [9:0] cfg_octets_per_multiframe = 10'd256;
  reg [7:0] cfg_octets_per_frame = 8'd32;
  reg cfg_disable_scrambler = 0;
  reg [7:0] cfg_frame_align_err_threshold = 8'd8;
  reg [7:0] cfg_lmfc_offset = 8'd0;
  reg cfg_sysref_oneshot = 0;
  reg cfg_sysref_disable = 0;
  
  // Clock generation
  always #5 sys_clk = ~sys_clk;  // 100MHz system clock
  always #2.5 fmc_clk_p = ~fmc_clk_p;  // 200MHz JESD clock
  always #2.5 fmc_clk_n = ~fmc_clk_n;
  
  // Instantiate the top module
  jesd204_holoscan_top #(
    .NUM_LANES(NUM_LANES),
    .NUM_CHANNELS(NUM_CHANNELS),
    .SAMPLES_PER_FRAME(SAMPLES_PER_FRAME),
    .CONVERTER_RESOLUTION(CONVERTER_RESOLUTION),
    .BITS_PER_SAMPLE(BITS_PER_SAMPLE),
    .OCTETS_PER_BEAT(OCTETS_PER_BEAT),
    .LINK_MODE(LINK_MODE),
    .DATA_PATH_WIDTH(DATA_PATH_WIDTH),
    .TPL_DATA_PATH_WIDTH(TPL_DATA_PATH_WIDTH)
  ) dut (
    .sys_clk(sys_clk),
    .sys_reset(sys_reset),
    
    .fmc_rx_p(fmc_rx_p),
    .fmc_rx_n(fmc_rx_n),
    .fmc_sysref_p(fmc_sysref_p),
    .fmc_sysref_n(fmc_sysref_n),
    .fmc_sync_p(fmc_sync_p),
    .fmc_sync_n(fmc_sync_n),
    .fmc_clk_p(fmc_clk_p),
    .fmc_clk_n(fmc_clk_n),
    
    .eth_tx_data(eth_tx_data),
    .eth_tx_valid(eth_tx_valid),
    .eth_tx_ready(eth_tx_ready),
    .eth_tx_last(eth_tx_last),
    
    .status_packets_sent(status_packets_sent),
    .status_bytes_sent(status_bytes_sent),
    .status_link_ready(status_link_ready),
    .status_jesd_sync(status_jesd_sync),
    .status_lane_ready(status_lane_ready),
    
    .cfg_octets_per_multiframe(cfg_octets_per_multiframe),
    .cfg_octets_per_frame(cfg_octets_per_frame),
    .cfg_disable_scrambler(cfg_disable_scrambler),
    .cfg_frame_align_err_threshold(cfg_frame_align_err_threshold),
    .cfg_lmfc_offset(cfg_lmfc_offset),
    .cfg_sysref_oneshot(cfg_sysref_oneshot),
    .cfg_sysref_disable(cfg_sysref_disable)
  );
  
  // Test stimulus
  initial begin
    // Initialize
    sys_reset = 1;
    eth_tx_ready = 1;
    
    // Wait for reset
    #100;
    sys_reset = 0;
    #50;
    
    // Generate SYSREF
    repeat(10) begin
      #1000;
      fmc_sysref_p = 1;
      fmc_sysref_n = 0;
      #10;
      fmc_sysref_p = 0;
      fmc_sysref_n = 1;
    end
    
    // Generate JESD204 data
    repeat(1000) begin
      #100;
      // Simulate JESD204 data on all lanes
      for (int i = 0; i < NUM_LANES; i++) begin
        fmc_rx_p[i] = $random;
        fmc_rx_n[i] = ~fmc_rx_p[i];
      end
    end
    
    // Generate SYNC signal
    #1000;
    fmc_sync_p = 1;
    fmc_sync_n = 0;
    #100;
    fmc_sync_p = 0;
    fmc_sync_n = 1;
    
    // Continue data generation
    repeat(5000) begin
      #50;
      for (int i = 0; i < NUM_LANES; i++) begin
        fmc_rx_p[i] = $random;
        fmc_rx_n[i] = ~fmc_rx_p[i];
      end
    end
    
    // End simulation
    #10000;
    $display("Simulation completed");
    $display("Packets sent: %d", status_packets_sent);
    $display("Bytes sent: %d", status_bytes_sent);
    $display("Link ready: %b", status_link_ready);
    $display("JESD sync: %b", status_jesd_sync);
    $finish;
  end
  
  // Monitor Ethernet packets
  always @(posedge sys_clk) begin
    if (eth_tx_valid) begin
      $display("Ethernet TX: data=0x%02X, valid=%b, last=%b", 
               eth_tx_data, eth_tx_valid, eth_tx_last);
    end
  end
  
  // Monitor status changes
  always @(posedge sys_clk) begin
    if (status_link_ready) begin
      $display("Link is ready at time %t", $time);
    end
    if (status_jesd_sync) begin
      $display("JESD204 sync achieved at time %t", $time);
    end
  end
  
  // VCD dump
  initial begin
    $dumpfile("jesd204_holoscan_tb.vcd");
    $dumpvars(0, jesd204_holoscan_tb);
  end

endmodule 