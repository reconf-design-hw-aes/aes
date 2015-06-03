module my_aes_encipher(
    input clk,
    input rst,  // negedge

    input next,

    input [3 : 0]     init_round,
    input [127 : 0]   init_roundkey,
    input             init_roundkey_valid,

    input [127 : 0]   block,
    output [127 : 0]  encblock,
    output            result_valid,

    output [127 : 0] is_idle
    );

parameter AES128_ROUNDS = 4'ha;
parameter STATE_IDLE = 2'b0;
parameter STATE_ENC = 2'b1;

reg [127 : 0] key_mem [0 : 10];

reg [1:0] state = 0;
wire [1:0] nextstate = (state == STATE_IDLE) ?
                      next ?
                        STATE_ENC :
                        STATE_IDLE :
                      (round_reg < AES128_ROUNDS) ?
                        STATE_ENC :
                        STATE_IDLE;
								

reg [3:0] round_reg = 0;
wire [3 : 0] next_round = (state == STATE_IDLE) ?
                      4'h0 :
                      (round_reg < AES128_ROUNDS) ?
                        round_reg + 1 :
                        4'h0;

wire [127:0] roundkey;

assign roundkey = key_mem[round_reg];

reg [127:0] block_reg;

assign encblock = block_reg;
assign sboxw = block_reg;
wire [127:0] news_boxw;

assign is_idle = (nextstate == STATE_IDLE);

reg result_valid_reg;
wire next_result_valid;

assign result_valid = result_valid_reg;
assign next_result_valid = (round_reg == AES128_ROUNDS);

function [7 : 0] gm2(input [7 : 0] op);
  begin
    gm2 = {op[6 : 0], 1'b0} ^ (8'h1b & {8{op[7]}});
  end
endfunction // gm2

function [7 : 0] gm3(input [7 : 0] op);
  begin
    gm3 = gm2(op) ^ op;
  end
endfunction // gm3

function [31 : 0] mixw(input [31 : 0] w);
  reg [7 : 0] b0, b1, b2, b3;
  reg [7 : 0] mb0, mb1, mb2, mb3;
  begin
    b0 = w[31 : 24];
    b1 = w[23 : 16];
    b2 = w[15 : 08];
    b3 = w[07 : 00];

    mb0 = gm2(b0) ^ gm3(b1) ^ b2      ^ b3;
    mb1 = b0      ^ gm2(b1) ^ gm3(b2) ^ b3;
    mb2 = b0      ^ b1      ^ gm2(b2) ^ gm3(b3);
    mb3 = gm3(b0) ^ b1      ^ b2      ^ gm2(b3);

    mixw = {mb0, mb1, mb2, mb3};
  end
endfunction // mixw

function [127 : 0] mixcolumns(input [127 : 0] data);
  reg [31 : 0] w0, w1, w2, w3;
  reg [31 : 0] ws0, ws1, ws2, ws3;
  begin
    w0 = data[127 : 096];
    w1 = data[095 : 064];
    w2 = data[063 : 032];
    w3 = data[031 : 000];

    ws0 = mixw(w0);
    ws1 = mixw(w1);
    ws2 = mixw(w2);
    ws3 = mixw(w3);

    mixcolumns = {ws0, ws1, ws2, ws3};
  end
endfunction // mixcolumns

function [127 : 0] shiftrows(input [127 : 0] data);
  reg [31 : 0] w0, w1, w2, w3;
  reg [31 : 0] ws0, ws1, ws2, ws3;
  begin
    w0 = data[127 : 096];
    w1 = data[095 : 064];
    w2 = data[063 : 032];
    w3 = data[031 : 000];

    ws0 = {w0[31 : 24], w1[23 : 16], w2[15 : 08], w3[07 : 00]};
    ws1 = {w1[31 : 24], w2[23 : 16], w3[15 : 08], w0[07 : 00]};
    ws2 = {w2[31 : 24], w3[23 : 16], w0[15 : 08], w1[07 : 00]};
    ws3 = {w3[31 : 24], w0[23 : 16], w1[15 : 08], w2[07 : 00]};

    shiftrows = {ws0, ws1, ws2, ws3};
  end
endfunction // shiftrows

function [127 : 0] addroundkey(input [127 : 0] data, input [127 : 0] rkey);
  begin
    addroundkey = data ^ rkey;
  end
  endfunction // addroundkey

always@(posedge clk or negedge rst)
begin
  if (~rst)
  begin
    state <= STATE_IDLE;
    round_reg <= 0;
    result_valid_reg <= 0;
  end
  else
  begin
    state <= nextstate;
    round_reg <= next_round;
    result_valid_reg <= next_result_valid;
  end
end

always@(posedge clk)
begin
  case(state)
    STATE_IDLE:
      if (next)
      begin
        block_reg <= block;
      end

    STATE_ENC:
      if (round_reg == 4'h0)
        block_reg <= addkey_init_block;
      else if (round_reg == AES128_ROUNDS)
        block_reg <= addkey_final_block;
      else
        block_reg <= addkey_main_block;
  endcase
end

wire shiftrows_block;
wire mixcolumns_block;
wire addkey_init_block;
wire addkey_main_block;
wire addkey_final_block;

assign shiftrows_block = shiftrows(new_sboxw);
assign mixcolumns_block = mixcolumns(shiftrows_block);
assign addkey_init_block = addroundkey(new_sboxw, roundkey);
assign addkey_main_block = addroundkey(mixcolumns_block, roundkey);
assign addkey_final_block = addroundkey(shiftrows_block, roundkey);

always@(posedge clk)
begin
  if (init_roundkey_valid)
  begin
    for (genvar i = 0 ; i < AES128_ROUNDS + 1 ; i = i + 1) begin
      if (i == init_round)
      begin
        key_mem[i] <= init_roundkey;
      end
      else
      begin
        key_mem[i]<= key_mem[i];
      end
    end
  end
  else
  begin
    for (genvar i = 0 ; i < AES128_ROUNDS + 1 ; i = i + 1) begin
      key_mem[i] <= key_mem[i];
    end
  end
end


aes_sbox sbox(.sboxw(sboxw), .new_sboxw(new_sboxw));

endmodule
