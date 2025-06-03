`timescale 1ns/1ps

module fft(
    input  logic        clk,
    input  logic        reset_n,
    input  logic        ready_in,
    input  logic [7:0]  data_in,
    output logic [7:0]  led
);

  // Clock divider for faster simulation 
  parameter DIV_COUNT = 25'b0000000000100000000000000;
  logic [24:0] div_cnt;
  logic slow_clk;

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      div_cnt  <= 25'b0;
      slow_clk <= 1'b0;
    end else begin
      if (div_cnt == DIV_COUNT - 1) begin
        div_cnt  <= 25'b0;
        slow_clk <= ~slow_clk;
      end else begin
        div_cnt <= div_cnt + 25'b1;
      end
    end
  end

  typedef enum logic [4:0] {
    S0, S1, S2, S3, S4, S5, S6, S7, S8, S9,
    S10, S11, S13, S15, S17
  } state_t;
  
  state_t state;
  logic signed [7:0] a, b;
  logic signed [7:0] yr, yi, zr, zi;
  logic [2:0] tw_idx;
  logic signed [7:0] tr[0:7], ti[0:7];

  initial 
    begin
    tr[0] = 8'b01111111;  ti[0] = 8'b00000000;
    tr[1] = 8'b01011011;  ti[1] = 8'b10100101;
    tr[2] = 8'b00000000;  ti[2] = 8'b10000001;
    tr[3] = 8'b10100101;  ti[3] = 8'b10100101;
    tr[4] = 8'b10000001;  ti[4] = 8'b00000000;
    tr[5] = 8'b10100101;  ti[5] = 8'b01011011;
    tr[6] = 8'b00000000;  ti[6] = 8'b01111111;
    tr[7] = 8'b01011011;  ti[7] = 8'b01011011;
  end

  logic signed [15:0] prod_r, prod_i;
  logic signed [7:0]  mult_r, mult_i;

   // Calculations
  always_ff @(posedge slow_clk or negedge reset_n) begin
    if (!reset_n) begin
      prod_r <= 16'sb0;
      prod_i <= 16'sb0;
      mult_r <= 8'sb0;
      mult_i <= 8'sb0;
    end else begin
      prod_r <= b * tr[tw_idx];
      prod_i <= b * ti[tw_idx];
      mult_r <= (prod_r + 16'sb0000000001000000) >>> 7;  // +64 -- rounding to nearest
      mult_i <= (prod_i + 16'sb0000000001000000) >>> 7;  // >>>7 -- Right shift by 7 bits
    end
  end

  wire signed [7:0] calc_yr = a + mult_r;
  wire signed [7:0] calc_yi = mult_i;
  wire signed [7:0] calc_zr = a - mult_r;
  wire signed [7:0] calc_zi = -mult_i;

  logic rdy_prev; // To track SW8 edge changing
  
  //Initial values
  always_ff @(posedge slow_clk or negedge reset_n) begin
    if (!reset_n) begin
      state    <= S0;
      rdy_prev <= 1'b0;
      tw_idx   <= 3'b000;
      a        <= 8'b0;
      b        <= 8'b0;
      yr       <= 8'b0;
      yi       <= 8'b0;
      zr       <= 8'b0;
      zi       <= 8'b0;
      led      <= 8'b00000000;
    end 
else 
    begin // FSM
      case (state)
        S0: state <= S1;
        S1: if (!ready_in) state <= S2;
        S2: if (ready_in)  state <= S3;
        S3: begin
              tw_idx <= data_in[2:0];
              state  <= S4;
            end
        S4: if (!ready_in) state <= S5;
        S5: if (ready_in)  state <= S6;
        S6: begin
              b <= data_in;
              state <= S7;
            end
        S7: if (!ready_in) state <= S8;
        S8: if (ready_in)  state <= S9;
        S9: begin
              a <= data_in;
              state <= S10;
            end
        S10: begin
               yr <= calc_yr;
               yi <= calc_yi;
               zr <= calc_zr;
               zi <= calc_zi;
               state <= S11;
            end
        S11: begin
               led <= yr;
               if (ready_in != rdy_prev)
                 state <= S13;
             end
        S13: begin
               led <= yi;
               if (ready_in != rdy_prev)
                 state <= S15;
             end
        S15: begin
               led <= zr;
               if (ready_in != rdy_prev)
                 state <= S17;
             end
        S17: begin
               led <= zi;
               if (ready_in != rdy_prev)
                 state <= S1;
             end
        default: state <= S0;
      endcase
      rdy_prev <= ready_in;
    end
  end

endmodule
