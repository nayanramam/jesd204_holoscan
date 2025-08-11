`timescale 1ns/100ps

module ethernet_streamer #(
  parameter DATA_WIDTH = 64,
  parameter FRAME_SIZE = 1500,
  parameter DEST_MAC = 48'hAABBCCDDEEFF,
  parameter SRC_MAC = 48'h112233445566,
  parameter DEST_IP = 32'hC0A80101,  // 192.168.1.1
  parameter SRC_IP = 32'hC0A80102,   // 192.168.1.2
  parameter DEST_PORT = 16'h1234,
  parameter SRC_PORT = 16'h5678
) (
  // Clock and reset
  input clk,
  input reset,
  
  // JESD204 data interface
  input [DATA_WIDTH-1:0] jesd_data,
  input jesd_valid,
  input jesd_sof,
  input jesd_eof,
  
  // Ethernet interface
  output [7:0] eth_tx_data,
  output eth_tx_valid,
  input eth_tx_ready,
  output eth_tx_last,
  
  // Status
  output [31:0] packets_sent,
  output [31:0] bytes_sent,
  output link_status
);

  // State machine states
  localparam IDLE = 3'b000;
  localparam SEND_HEADER = 3'b001;
  localparam SEND_DATA = 3'b010;
  localparam SEND_PADDING = 3'b011;
  localparam WAIT_READY = 3'b100;
  
  reg [2:0] state = IDLE;
  reg [2:0] next_state;
  
  // Packet counters
  reg [31:0] packet_counter = 32'd0;
  reg [31:0] byte_counter = 32'd0;
  
  // Data buffer
  reg [DATA_WIDTH-1:0] data_buffer = 'b0;
  reg [15:0] data_length = 16'd0;
  reg [15:0] byte_count = 16'd0;
  
  // Ethernet frame components
  reg [7:0] eth_header [0:13]; // 14-byte Ethernet header
  reg [7:0] ip_header [0:19];  // 20-byte IP header
  reg [7:0] udp_header [0:7];  // 8-byte UDP header
  
  // Output signals
  reg [7:0] tx_data_reg = 8'd0;
  reg tx_valid_reg = 1'b0;
  reg tx_last_reg = 1'b0;
  
  // Initialize headers
  initial begin
    // Ethernet header
    eth_header[0] = 8'hAA; // Preamble
    eth_header[1] = 8'hAA;
    eth_header[2] = 8'hAA;
    eth_header[3] = 8'hAA;
    eth_header[4] = 8'hAA;
    eth_header[5] = 8'hAA;
    eth_header[6] = 8'hAA;
    eth_header[7] = 8'hAB; // SFD
    
    // Destination MAC (first 6 bytes)
    eth_header[8] = DEST_MAC[47:40];
    eth_header[9] = DEST_MAC[39:32];
    eth_header[10] = DEST_MAC[31:24];
    eth_header[11] = DEST_MAC[23:16];
    eth_header[12] = DEST_MAC[15:8];
    eth_header[13] = DEST_MAC[7:0];
    
    // Source MAC (next 6 bytes)
    eth_header[14] = SRC_MAC[47:40];
    eth_header[15] = SRC_MAC[39:32];
    eth_header[16] = SRC_MAC[31:24];
    eth_header[17] = SRC_MAC[23:16];
    eth_header[18] = SRC_MAC[15:8];
    eth_header[19] = SRC_MAC[7:0];
    
    // Type field (0x0800 for IP)
    eth_header[20] = 8'h08;
    eth_header[21] = 8'h00;
  end
  
  // State machine
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (jesd_valid && jesd_sof) begin
          next_state = SEND_HEADER;
        end
      end
      
      SEND_HEADER: begin
        if (eth_tx_ready) begin
          next_state = SEND_DATA;
        end
      end
      
      SEND_DATA: begin
        if (jesd_eof) begin
          next_state = SEND_PADDING;
        end
      end
      
      SEND_PADDING: begin
        if (eth_tx_ready) begin
          next_state = WAIT_READY;
        end
      end
      
      WAIT_READY: begin
        if (eth_tx_ready) begin
          next_state = IDLE;
        end
      end
    endcase
  end
  
  // State register
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end
  
  // Data processing
  always @(posedge clk) begin
    if (jesd_valid && jesd_sof) begin
      data_buffer <= jesd_data;
      data_length <= DATA_WIDTH / 8;
      byte_count <= 0;
    end
  end
  
  // Output generation
  always @(posedge clk) begin
    case (state)
      IDLE: begin
        tx_data_reg <= 8'd0;
        tx_valid_reg <= 1'b0;
        tx_last_reg <= 1'b0;
      end
      
      SEND_HEADER: begin
        tx_data_reg <= eth_header[byte_count];
        tx_valid_reg <= 1'b1;
        tx_last_reg <= 1'b0;
        if (eth_tx_ready) begin
          byte_count <= byte_count + 1;
        end
      end
      
      SEND_DATA: begin
        tx_data_reg <= data_buffer[7:0];
        tx_valid_reg <= 1'b1;
        tx_last_reg <= 1'b0;
        if (eth_tx_ready) begin
          data_buffer <= {8'd0, data_buffer[DATA_WIDTH-1:8]};
          byte_count <= byte_count + 1;
        end
      end
      
      SEND_PADDING: begin
        tx_data_reg <= 8'd0;
        tx_valid_reg <= 1'b1;
        tx_last_reg <= 1'b1;
      end
      
      WAIT_READY: begin
        tx_data_reg <= 8'd0;
        tx_valid_reg <= 1'b0;
        tx_last_reg <= 1'b0;
      end
    endcase
  end
  
  // Packet counter
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      packet_counter <= 32'd0;
      byte_counter <= 32'd0;
    end else begin
      if (state == WAIT_READY && next_state == IDLE) begin
        packet_counter <= packet_counter + 1;
        byte_counter <= byte_counter + byte_count;
      end
    end
  end
  
  // Output assignments
  assign eth_tx_data = tx_data_reg;
  assign eth_tx_valid = tx_valid_reg;
  assign eth_tx_last = tx_last_reg;
  assign packets_sent = packet_counter;
  assign bytes_sent = byte_counter;
  assign link_status = 1'b1; // Simplified

endmodule 