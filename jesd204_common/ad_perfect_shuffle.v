`timescale 1ns/100ps

module ad_perfect_shuffle #(
  parameter NUM_GROUPS = 1,
  parameter WORDS_PER_GROUP = 1,
  parameter WORD_WIDTH = 1
) (
  input [NUM_GROUPS*WORDS_PER_GROUP*WORD_WIDTH-1:0] data_in,
  output [NUM_GROUPS*WORDS_PER_GROUP*WORD_WIDTH-1:0] data_out
);

  localparam TOTAL_WORDS = NUM_GROUPS * WORDS_PER_GROUP;
  localparam TOTAL_WIDTH = TOTAL_WORDS * WORD_WIDTH;

  genvar i, j;
  generate
    for (i = 0; i < NUM_GROUPS; i = i + 1) begin: g_group
      for (j = 0; j < WORDS_PER_GROUP; j = j + 1) begin: g_word
        localparam src_start = (i * WORDS_PER_GROUP + j) * WORD_WIDTH;
        localparam src_end = src_start + WORD_WIDTH - 1;
        localparam dst_start = (j * NUM_GROUPS + i) * WORD_WIDTH;
        localparam dst_end = dst_start + WORD_WIDTH - 1;
        
        assign data_out[dst_end:dst_start] = data_in[src_end:src_start];
      end
    end
  endgenerate

endmodule 