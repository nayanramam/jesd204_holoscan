`timescale 1ns/100ps

module sync_bits #(
  parameter NUM_OF_BITS = 1,
  parameter ASYNC_CLK = 1
) (
  input [NUM_OF_BITS-1:0] in_bits,
  input out_clk,
  input out_resetn,
  output [NUM_OF_BITS-1:0] out_bits
);

  genvar i;
  generate
    for (i = 0; i < NUM_OF_BITS; i = i + 1) begin: g_sync_bit
      reg sync_bit_0 = 1'b0;
      reg sync_bit_1 = 1'b0;
      
      always @(posedge out_clk) begin
        if (out_resetn == 1'b0) begin
          sync_bit_0 <= 1'b0;
          sync_bit_1 <= 1'b0;
        end else begin
          sync_bit_0 <= in_bits[i];
          sync_bit_1 <= sync_bit_0;
        end
      end
      
      assign out_bits[i] = sync_bit_1;
    end
  endgenerate

endmodule 