//======================================================================
//
// usr_top.v
// --------
// PCI-e wrapper for AES.
//
//
// Author: Jackie Yang
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

module USER_HW(

  input usr_clk,
  /*user reset, in usr_clk clock domain*/
  input usr_rst,
  /*user PIO interface, in user clock domain*/
  input  [14:0] usr_pio_ch0_wr_addr,
  input  [31:0] usr_pio_ch0_wr_data,
  input  usr_pio_ch0_wr_req,
  output usr_pio_ch0_wr_ack,
  input  [14:0] usr_pio_ch0_rd_addr,
  output [31:0] usr_pio_ch0_rd_data,
  input  usr_pio_ch0_rd_req,
  output usr_pio_ch0_rd_ack,
  /*user interrupt interface, in user "user_int_clk" clock domain*/
  // user interrupt 0 (vector = 0)

  output usr0_int_req,

  input  usr0_int_clr,

  input  usr0_int_enable,

  // user interrupt 1 (vector = 1)

  output usr1_int_req,

  input  usr1_int_clr,

  input  usr1_int_enable,
  /*user DMA interface, in user clock domain, clock is from user's usr_host2board_clk and usr_board2host_clk*/
  //output  usr_host2board_clk,
  input   [129:0] usr_host2board_dout,
  input   usr_host2board_empty,
  input   usr_host2board_almost_empty,
  output  usr_host2board_rd_en,
  //output  usr_board2host_clk,
  output  [129:0] usr_board2host_din,
  input   usr_board2host_prog_full,
  output  usr_board2host_wr_en
);

endmodule // USER_HW

//======================================================================
// EOF usr_top.v
//======================================================================
