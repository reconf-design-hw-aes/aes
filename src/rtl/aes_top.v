//======================================================================
//
// aes_top.v
// --------
// AES wrapper
//
//
// Author: Fiona Lee
// Copyright (c) 2015 Jackie Yang and Fiona Lee
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

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

  reg [127:0] block_reg = 0;

  always@(posedge clk)
  begin
    if (next)
    begin
      block_reg <= block;
    end
	 else
	 begin
		block_reg <= block_reg;
	 end
  end

  aes_core aes_core(
     .clk(clk),
     .reset_n(rst),

     .init(init),
     .next(next),
     .ready(ready),

     .key(key),
     .keylen(keylen),

     .block(block_reg),
     .result(result),
     .result_valid(result_valid),

     .busy(busy)
      );

endmodule

//======================================================================
// EOF aes_top.v
//======================================================================
