`timescale 1ns/1ps
`include "top_pkg.svh"


module pwm(
    input logic clk,
    input logic rst_n,
    input logic [$clog2(PWM_MAX)-1:0] max_pwm_out,
    input logic [PWM_LEN-1:0] duty_cycle,
    input logic [1:0] magnitude, 
    output logic pwm_out
);

typedef enum logic [1:0] {X1,X2,X4,X8} name;
logic [PWM_MAX-1:0] real_dc;

  // COUNTER
  logic [$clog2(PWM_MAX)-1:0] pwm_counter;

  always_comb begin
    real_dc = '0;
    case(magnitude)
    X1: real_dc = duty_cycle;
    X2: real_dc = duty_cycle << 1;
    X4: real_dc = duty_cycle << 2;
    X8: real_dc = duty_cycle << 3;
    default: real_dc = duty_cycle;
    endcase
  end


  // PWM LOGIC
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pwm_counter <= 'd0;
      pwm_out <= 1'b0;
    end else begin
      if (pwm_counter < max_pwm_out) begin
        pwm_counter <= pwm_counter + 1;
      end else begin
        pwm_counter <= 'd0;
      end

      if (pwm_counter < real_dc) begin
        pwm_out <= 1'b1;
      end else begin
        pwm_out <= 1'b0;
      end
    end
  end

//  RGF CONFIGURE




endmodule
