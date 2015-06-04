module my_aes_key_mem(
  input             clk,
  input             reset_n,

  input [127 : 0]   key,
  input             init,

  output [3 : 0]    round,
  output [127 : 0]  roundkey,
  output            roundkey_valid,

  output            ready
    );

wire clk;
wire reset_n;
wire [127 : 0] key;
wire init;

parameter AES_128_NUM_ROUNDS = 4'ha;
parameter STATE_IDLE = 2'b0;
parameter STATE_GENERATE = 2'b1;

wire [127 : 0] key_mem_new;

reg [1 : 0] state = STATE_IDLE;
wire [1 : 0] nextstate = (state == STATE_IDLE) ?
                           init ?
                             STATE_GENERATE :
                             STATE_IDLE :
                           (round_reg < AES_128_NUM_ROUNDS) ?
                             state :
                             STATE_IDLE ;

assign round = round_reg;
assign roundkey = key_mem_new;
assign roundkey_valid = (state == STATE_GENERATE);

reg [127 : 0] prev_key_reg;
wire [127 : 0] prev_key_new;

reg [7 : 0] rcon_reg;
wire [7 : 0] rcon_new;

reg [3 : 0] round_reg = 0;
wire [3 : 0] nextround = (state == STATE_IDLE) ?
                           4'h0 :
                           (round_reg < AES_128_NUM_ROUNDS) ?
                              round_reg + 4'h1 :
                              4'h0 ;

wire [127:0] sboxw;
wire [127:0] new_sboxw;

aes_sbox sbox(.sboxw(sboxw), .new_sboxw(new_sboxw));

assign ready = (nextstate == STATE_IDLE);

always @ (posedge clk or negedge reset_n)
begin
  if (!reset_n)
  begin
    prev_key_reg     <= 128'h00000000000000000000000000000000;
    state            <= 2'b0;
    rcon_reg         <= 8'h00;
    round_reg        <= 4'h0;
  end
  else
  begin
    state <= nextstate;
    round_reg <= nextround;
    rcon_reg <= rcon_new;
    prev_key_reg <= prev_key_new;
  end
end

wire round_key_update = (state == STATE_GENERATE);

assign rcon_new = (round_key_update)?
                  {rcon_reg[6 : 0], 1'b0} ^ (8'h1b & {8{rcon_reg[7]}}):
                  8'h8d;


wire [31 : 0] w0, w1, w2, w3, k0, k1, k2, k3;

wire [31 : 0] rconw, rotstw, trw;

assign w0 = prev_key_reg[127 : 096];
assign w1 = prev_key_reg[095 : 064];
assign w2 = prev_key_reg[063 : 032];
assign w3 = prev_key_reg[031 : 000];

assign k0 = w0 ^ trw;
assign k1 = w1 ^ w0 ^ trw;
assign k2 = w2 ^ w1 ^ w0 ^ trw;
assign k3 = w3 ^ w2 ^ w1 ^ w0 ^ trw;

assign rconw = {rcon_reg, 24'h000000};
assign sboxw = {96'h0, w3};
assign rotstw = {new_sboxw[23 : 00], new_sboxw[31 : 24]};
assign trw = rotstw ^ rconw;

assign key_mem_new = ((round_key_update) && (round_reg == 0)) ? key : {k0, k1, k2, k3};

assign prev_key_new = ((round_key_update) && (round_reg == 0)) ? key : {k0, k1, k2, k3};

endmodule
