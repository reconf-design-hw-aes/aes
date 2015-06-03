//======================================================================
//
// aes.core.v
// ----------
// The AES core. This core supports key size of 128, and 256 bits.
// Most of the functionality is within the submodules.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2013, 2014, Secworks Sweden AB
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

module aes_core(
                input wire            clk,
                input wire            reset_n,

                input wire            init,
                input wire            next,
                output wire           ready,

                input wire [255 : 0]  key,
                input wire            keylen,

                input wire [127 : 0]  block,
                output wire [127 : 0] result,
                output wire           result_valid,

                output wire           busy
               );




  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter CTRL_IDLE  = 2'h0;
  parameter CTRL_INIT  = 2'h1;
  parameter CTRL_NEXT  = 2'h2;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [1 : 0] aes_core_ctrl_reg;
  reg [1 : 0] aes_core_ctrl_new;
  reg         aes_core_ctrl_we;

  reg         result_valid_reg;
  reg         result_valid_new;
  reg         result_valid_we;

  reg         ready_reg;
  reg         ready_new;
  reg         ready_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg            init_state;

  wire [127 : 0] round_key;

  wire [3 : 0]   enc_round_nr;

  wire           enc_ready;
  wire           key_ready;

  wire [31 : 0]  enc_sboxw;
  wire [31 : 0]  keymem_sboxw;

  reg [31 : 0]   muxed_sboxw;
  wire [31 : 0]  new_sboxw;


  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------
  aes_encipher_block enc_block(
                               .clk(clk),
                               .reset_n(reset_n),

                               .next(next),

                               .keylen(keylen),
                               .round(enc_round_nr),
                               .round_key(round_key),

                               .sboxw(enc_sboxw),
                               .new_sboxw(new_sboxw),

                               .block(block),
                               .new_block(result),
                               .ready(enc_ready)
                              );


  aes_key_mem keymem(
                     .clk(clk),
                     .reset_n(reset_n),

                     .key(key),
                     .keylen(keylen),
                     .init(init),

                     .round(enc_round_nr),
                     .round_key(round_key),
                     .ready(key_ready),

                     .sboxw(keymem_sboxw),
                     .new_sboxw(new_sboxw)
                    );


  aes_sbox sbox(.sboxw(muxed_sboxw), .new_sboxw(new_sboxw));


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready        = ready_reg;
  assign result_valid = result_valid_reg;
  assign busy         = (aes_core_ctrl_new != CTRL_IDLE);


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin: reg_update
      if (!reset_n)
        begin
          result_valid_reg  <= 1'b0;
          ready_reg         <= 1'b1;
          aes_core_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin
          if (result_valid_we)
            begin
              result_valid_reg <= result_valid_new;
            end

          if (ready_we)
            begin
              ready_reg <= ready_new;
            end

          if (aes_core_ctrl_we)
            begin
              aes_core_ctrl_reg <= aes_core_ctrl_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // sbox_mux
  //
  // Controls which of the encipher datapath or the key memory
  // that gets access to the sbox.
  //----------------------------------------------------------------
  always @*
    begin : sbox_mux
      if (init_state)
        begin
          muxed_sboxw = keymem_sboxw;
        end
      else
        begin
          muxed_sboxw = enc_sboxw;
        end
    end // sbox_mux

  //----------------------------------------------------------------
  // aes_core_ctrl
  //
  // Control FSM for aes core. Basically tracks if we are in
  // key init, encipher or decipher modes and connects the
  // different submodules to shared resources and interface ports.
  //----------------------------------------------------------------
  always @*
    begin : aes_core_ctrl
      init_state        = 0;
      ready_new         = 0;
      ready_we          = 0;
      result_valid_new  = 0;
      result_valid_we   = 0;
      aes_core_ctrl_new = CTRL_IDLE;
      aes_core_ctrl_we  = 0;

      case (aes_core_ctrl_reg)
        CTRL_IDLE:
          begin
            if (init)
              begin
                init_state        = 1;
                ready_new         = 0;
                ready_we          = 1;
                result_valid_new  = 0;
                result_valid_we   = 1;
                aes_core_ctrl_new = CTRL_INIT;
                aes_core_ctrl_we  = 1;
              end
            else if (next)
              begin
                init_state        = 0;
                ready_new         = 0;
                ready_we          = 1;
                result_valid_new  = 0;
                result_valid_we   = 1;
                aes_core_ctrl_new = CTRL_NEXT;
                aes_core_ctrl_we  = 1;
              end
            else
              begin
                init_state = 0;
                ready_new = 1;
                ready_we = 1;
                result_valid_new = 0;
                result_valid_we = 1;
                aes_core_ctrl_new = CTRL_IDLE;
                aes_core_ctrl_we = 1;
              end
          end

        CTRL_INIT:
          begin
            init_state = 1;

            if (key_ready)
              begin
                ready_new         = 1;
                ready_we          = 1;
                aes_core_ctrl_new = CTRL_IDLE;
                aes_core_ctrl_we  = 1;
              end
          end

        CTRL_NEXT:
          begin
            init_state = 0;

            if (enc_ready)
              begin
                ready_new         = 1;
                ready_we          = 1;
                result_valid_new  = 1;
                result_valid_we   = 1;
                aes_core_ctrl_new = CTRL_IDLE;
                aes_core_ctrl_we  = 1;
             end
          end

        default:
          begin

          end
      endcase // case (aes_core_ctrl_reg)

    end // aes_core_ctrl
endmodule // aes_core

//======================================================================
// EOF aes_core.v
//======================================================================
