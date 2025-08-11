`timescale 1ns/100ps

module util_ext_sync #(
  parameter ENABLED = 0
) (
  input clk,
  input ext_sync_arm,
  input ext_sync_disarm,
  input sync_in,
  output sync_armed
);

  reg sync_armed_reg = 1'b0;

  generate
    if (ENABLED) begin: g_enabled
      always @(posedge clk) begin
        if (ext_sync_arm) begin
          sync_armed_reg <= 1'b1;
        end else if (ext_sync_disarm) begin
          sync_armed_reg <= 1'b0;
        end
      end
    end else begin: g_disabled
      always @(posedge clk) begin
        sync_armed_reg <= 1'b0;
      end
    end
  endgenerate

  assign sync_armed = sync_armed_reg;

endmodule 