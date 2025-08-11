`timescale 1ns/100ps

module util_pipeline_stage #(
  parameter WIDTH = 1,
  parameter REGISTERED = 1
) (
  input clk,
  input [WIDTH-1:0] in,
  output [WIDTH-1:0] out
);

  generate
    if (REGISTERED) begin: g_registered
      reg [WIDTH-1:0] data_reg = 'b0;
      
      always @(posedge clk) begin
        data_reg <= in;
      end
      
      assign out = data_reg;
    end else begin: g_unregistered
      assign out = in;
    end
  endgenerate

endmodule 