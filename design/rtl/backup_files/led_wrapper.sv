`timescale 1ns / 1ps

import defs_pkg::*;

module led_wrapper (
    input logic clk,
    input logic rst_n,
    input logic [BYTE_LEN-1:0] addr_low,
    input logic led_en,
    input logic [7:0] red_vec,
    input logic [7:0] green_vec,
    input logic [7:0] blue_vec,
    input logic wr_en,
    input logic [31:0] w_data,
    output logic [31:0] r_data,
    output logic led16_en,
    output logic led17_en,
    output logic [PWM_LEN-1:0] red_pwm,
    output logic [PWM_LEN-1:0] green_pwm,
    output logic [PWM_LEN-1:0] blue_pwm
);

  //EACH RGB CONNECTION
  logic [PWM_LEN-1:0] led16_red_pwm;
  logic [PWM_LEN-1:0] led16_green_pwm;
  logic [PWM_LEN-1:0] led16_blue_pwm;

  logic [PWM_LEN-1:0] led17_red_pwm;
  logic [PWM_LEN-1:0] led17_green_pwm;
  logic [PWM_LEN-1:0] led17_blue_pwm;

  led led16_inst (
      .clk(clk),
      .rst_n(rst_n),
      .color_en(led16_en),
      .red_vec(red_vec),
      .green_vec(green_vec),
      .blue_vec(blue_vec),
      .cie_en(ctrl_r.led16_cie),
      .red_out(led16_red_pwm),
      .green_out(led16_green_pwm),
      .blue_out(led16_blue_pwm)
  );

  led led17_inst (
      .clk(clk),
      .rst_n(rst_n),
      .color_en(led17_en),
      .red_vec(red_vec),
      .green_vec(green_vec),
      .blue_vec(blue_vec),
      .cie_en(ctrl_r.led17_cie),
      .red_out(led17_red_pwm),
      .green_out(led17_green_pwm),
      .blue_out(led17_blue_pwm)
  );

  always_comb begin
    case (1'b1)
      led17_en: begin
        red_pwm   = led17_red_pwm;
        green_pwm = led17_green_pwm;
        blue_pwm  = led17_blue_pwm;
      end
      led16_en: begin
        red_pwm   = led16_red_pwm;
        green_pwm = led16_green_pwm;
        blue_pwm  = led16_blue_pwm;
      end
      default: begin
        red_pwm   = '0;
        green_pwm = '0;
        blue_pwm  = '0;

      end
    endcase



  end

  //------------------------------------------

  //          LED Register File

  //------------------------------------------

  typedef enum logic [7:0] {
    CTRL = 8'h00,
    PATTERN = 8'h04
  } internal_addr_reg_t;

  typedef struct packed {
    logic [31:6] res;
    logic led17_cie;
    logic led16_cie;
    logic led17_sw;
    logic led16_sw;
    logic [1:0] led_sel;
  } led_ctrl_r;

  typedef struct packed {
    logic [31:2] res;
    logic [1:0]  led_pattern_sel;
  } led_pattern_r;

  led_ctrl_r ctrl_r;
  led_pattern_r pattern_r;
  logic led_addr_err;

  assign led16_en = (ctrl_r.led16_sw && ctrl_r.led_sel == 2'b01);
  assign led17_en = (ctrl_r.led17_sw && ctrl_r.led_sel == 2'b10);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_r <= '0;
      pattern_r <= '0;
      led_addr_err <= 1'b0;
    end else if (wr_en && led_en) begin
      case (addr_low)
        CTRL: ctrl_r <= w_data;
        PATTERN: pattern_r <= w_data;
        default: led_addr_err <= 1'b1;
      endcase
    end
  end

  always_comb begin
    if (!rst_n) begin
      r_data = '0;
    end else if (!wr_en && led_en) begin
      unique case (addr_low)
        CTRL: r_data = ctrl_r;
        PATTERN: r_data = pattern_r;
        default: begin
          r_data = '0;
        end
      endcase
    end else 
          r_data = '0;

  end

  //--------------------------------------------------




endmodule
