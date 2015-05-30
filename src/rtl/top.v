module aes_top(
   input wire clk,
   input wire rst,

   input wire init,   // key init
   input wire next,   // start encoding a block
   output wire ready, // key is ready

   input wire [255:0] key,
   input wire         keylen,

   input wire [127 : 0]   block,
   output wire [127 : 0]  result,
   output wire            result_valid,

   output wire busy
    );

  parameter ENC = 1'b1;

  aes_core aes_core(
     .clk(clk),
     .reset_n(reset_n),

     .encdec(ENC),
     .init(init),
     .next(next),
     .ready(ready),

     .key(key),
     .keylen(keylen),

     .block(block),
     .result(result),
     .result_valid(result_valid),

     .busy(busy)
      );

endmodule
