`timescale 1ns/100ps

module sync_event #(
  parameter NUM_OF_EVENTS = 1,
  parameter ASYNC_CLK = 1
) (
  input in_clk,
  input [NUM_OF_EVENTS-1:0] in_event,
  input out_clk,
  output [NUM_OF_EVENTS-1:0] out_event
);

  genvar i;
  generate
    for (i = 0; i < NUM_OF_EVENTS; i = i + 1) begin: g_sync_event
      reg event_0 = 1'b0;
      reg event_1 = 1'b0;
      reg event_2 = 1'b0;
      
      always @(posedge in_clk) begin
        event_0 <= in_event[i];
      end
      
      always @(posedge out_clk) begin
        event_1 <= event_0;
        event_2 <= event_1;
      end
      
      assign out_event[i] = event_1 & ~event_2; // Rising edge detection
    end
  endgenerate

endmodule 