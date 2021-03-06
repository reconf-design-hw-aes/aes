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

module USER_HW (
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
    wire usr_rst2 = ~usr_rst;
    assign usr_pio_ch0_rd_ack = 0;
    assign usr_pio_ch0_rd_data = 0;
    assign usr0_int_req = 0;
    assign usr1_int_req = 0;
    reg usr_pio_ch0_wr_ack;

    parameter n_aes_core = 16;                           // number of aes core

    wire key_ready [15:0];

    reg init;                                           // init key for aes core
    wire [0:n_aes_core - 1] aes_next;                   // per core start signal
    wire [0:n_aes_core - 1] aes_ready;                  // per core ready signal
    wire ready = & aes_ready;                           // ready signal

    wire [127:0] key;                                   // key

    wire [127:0] block = usr_host2board_dout[127:0];    // input block
    wire [127:0] aes_result [0:n_aes_core - 1];         // per core result
    wire [127:0] aes_clean_result [0:n_aes_core - 1];   // clean per core result
    wor [127:0] result;           // result
    wire [0:n_aes_core - 1] aes_result_valid;           // per core result valid
    wire result_valid = | aes_result_valid;

    for (genvar i = 0; i < n_aes_core; i = i + 1) begin
        assign result = aes_clean_result[i];
    end

    wire [3:0] round [15:0];
    wire [127:0] roundkey [15:0];
    wire         roundkey_valid [15:0];

    for (genvar i = 0; i < n_aes_core; i = i + 1) begin
        my_aes_encipher aes(
                    .clk(usr_clk),
                    .rst(usr_rst2),

                    .next(aes_next[i]),                 // start encoding
                    .init_round(round[i]),
                    .init_roundkey(roundkey[i]),
                    .init_roundkey_valid(roundkey_valid[i]),

                    .block(block),
                    .encblock(aes_result[i]),
                    .result_valid(aes_result_valid[i]),

                    .is_idle(aes_ready[i])
                    );
        assign aes_clean_result[i] = aes_result_valid[i] ? aes_result[i] : 0;
    end

    reg [31:0] key_pci [0:3];

    assign key = {key_pci[3], key_pci[2], key_pci[1], key_pci[0]};

    always @(posedge usr_clk or negedge usr_rst2)
    begin // key_pci, init
        if(~usr_rst2) begin
            key_pci[0] <= 0;
            key_pci[1] <= 0;
            key_pci[2] <= 0;
            key_pci[3] <= 0;
            init <= 0;
        end else begin
            if(usr_pio_ch0_wr_req == 1) begin
                usr_pio_ch0_wr_ack <= 1;
                if(usr_pio_ch0_wr_addr < 4) begin
                    key_pci[usr_pio_ch0_wr_addr] <= usr_pio_ch0_wr_data;
                end
                if(usr_pio_ch0_wr_addr == 4) begin
                    init <= 1;
                end else begin
                    init <= 0;
                end
            end else begin
                usr_pio_ch0_wr_ack <= 0;
                key_pci[0] <= key_pci[0];
                key_pci[1] <= key_pci[1];
                key_pci[2] <= key_pci[2];
                key_pci[3] <= key_pci[3];
                init <= 0;
            end
        end
    end

    wire next;
    integer current_aes = 0;

    for (genvar i = 0; i < n_aes_core; i = i + 1) begin // aes_next
        assign aes_next[i] = (current_aes == i) ? next : 0;
    end

    always @(posedge usr_clk or negedge usr_rst2)
    begin // current_aes
        if(~usr_rst2) begin
            current_aes <= 0;
        end else begin
            if(next == 1) begin
                current_aes <= (current_aes + 1) & (n_aes_core - 1);
            end
        end
    end

    wire fifo_full;
    wire fifo_empty;
    wire fifo_rd_en = (!usr_board2host_prog_full) && (!fifo_empty);
	 wire [127:0] fifo_dout;

    aes_result_fifo fifo(.clk(usr_clk),
                         .rst(usr_rst),
                         .din(result),
                         .wr_en(result_valid),
                         .rd_en(fifo_rd_en),
                         .dout(fifo_dout),
                         .full(),
                         .empty(fifo_empty),
                         .prog_full(fifo_full)
                         );

    reg fifo_full_reg;
    always @(posedge usr_clk or negedge usr_rst2) begin
        if (~usr_rst2) begin
            fifo_full_reg <= 1;
        end else begin
            fifo_full_reg <= fifo_full;
        end
    end

    assign usr_board2host_din = {2'b11, fifo_dout};

    assign usr_board2host_wr_en = fifo_rd_en;

    assign next = (~usr_host2board_empty) & (key_ready[0]) & (~fifo_full_reg) & (~init);

    assign usr_host2board_rd_en = next;

	 for (genvar i = 0 ; i < n_aes_core ; i = i + 1) begin
		 my_aes_key_mem keymem(
									  .clk(usr_clk),
									  .reset_n(usr_rst2),

									  .key(key),
									  .init(init),

									  .round(round[i]),
									  .roundkey(roundkey[i]),
									  .roundkey_valid(roundkey_valid[i]),

									  .ready(key_ready[i])
									  );
	 end



endmodule // USER_HW

//======================================================================
// EOF usr_top.v
//======================================================================
