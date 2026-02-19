`timescale 1ns / 1ps

import defs_pkg::*;

module addr_selection (
    input logic [ 7:0] addr_A2,
    input logic [31:0] r_data_pwm,
    input logic [31:0] r_data_led,
    input logic [31:0] r_data_sys,
    input logic [31:0] r_data_uart,
    input logic [31:0] r_data_msg,
    input logic [31:0] r_data_img,
    input logic [31:0] r_data_fifo,

    output logic led_en,
    output logic pwm_en,
    output logic sys_en,
    output logic uart_en,
    output logic msg_en,
    output logic img_en,
    output logic fifo_en,
    output logic [31:0] tx_r_data
);

  logic addr_selection_err;

  always_comb begin : ADDR_SELECTION_COMB_BLOCK
    pwm_en = 1'b0;
    led_en = 1'b0;
    sys_en = 1'b0;
    uart_en = 1'b0;
    msg_en = 1'b0;
    img_en = 1'b0;
    fifo_en = 1'b0;
    addr_selection_err = 1'b0;
    unique case (addr_A2)
      ADDR_A2_PWM: begin
        pwm_en = 1'b1;
      end
      ADDR_A2_LED: begin
        led_en = 1'b1;
      end
      ADDR_A2_SYS: begin
        sys_en = 1'b1;
      end
      ADDR_A2_UART: begin
        uart_en = 1'b1;
      end
      ADDR_A2_MSG: begin
        msg_en = 1'b1;
      end
      ADDR_A2_IMG: begin
        img_en = 1'b1;
      end
      ADDR_A2_FIFO: begin
        fifo_en = 1'b1;
      end
      default: begin
        addr_selection_err = 1'b1;
      end
    endcase
  end

  always_comb begin : R_DATA_MUX_BLOCK
    tx_r_data <= '0;
    unique case (1'b1)
      pwm_en: begin
        tx_r_data <= r_data_pwm;
      end
      led_en: begin
        tx_r_data <= r_data_led;
      end
      sys_en: begin
        tx_r_data <= r_data_sys;
      end
      uart_en: begin
        tx_r_data <= r_data_uart;
      end
      msg_en: begin
        tx_r_data <= r_data_msg;
      end
      img_en: begin
        tx_r_data <= r_data_img;
      end
      fifo_en: begin
        tx_r_data <= r_data_fifo;
      end
      default: begin
        tx_r_data <= '0;
      end
    endcase
  end


endmodule
