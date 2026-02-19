`timescale 1ns / 1ps

`include "top_pkg.svh"


module addr_selection (
    input logic clk,
    input logic rst_n,
    input logic [7:0] addr_A2,
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
    output logic [31:0] tx_r_data,
    output logic reg_read_valid
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
      BASE_ADDR_PWM: begin
        pwm_en = 1'b1;
      end
      BASE_ADDR_LED: begin
        led_en = 1'b1;
      end
      BASE_ADDR_SYS: begin
        sys_en = 1'b1;
      end
      BASE_ADDR_UART: begin
        uart_en = 1'b1;
      end
      BASE_ADDR_MSG: begin
        msg_en = 1'b1;
      end
      BASE_ADDR_IMG: begin
        img_en = 1'b1;
      end
      BASE_ADDR_FIFO: begin
        fifo_en = 1'b1;
      end
      default: begin
        addr_selection_err = 1'b1;
      end
    endcase
  end

  //   always_ff (posedge clk or negedge rst_n) begin 
  //     if(!rst_n)begin
  //           tx_r_data <= '0;
  //   reg_read_valid <= 1'b0;
  //     end else

  //   unique case (1'b1)
  //     pwm_en: begin
  //       tx_r_data <= r_data_pwm;
  //       reg_read_valid <= 1'b1;
  //     end
  //     led_en: begin
  //       tx_r_data <= r_data_led;
  //       reg_read_valid <= 1'b1;
  //     end
  //     sys_en: begin
  //       tx_r_data <= r_data_sys;
  //       reg_read_valid <= 1'b1;
  //     end
  //     uart_en: begin
  //       tx_r_data <= r_data_uart;
  //       reg_read_valid <= 1'b1;
  //     end
  //     msg_en: begin
  //       tx_r_data <= r_data_msg;
  //       reg_read_valid <= 1'b1;
  //     end
  //     img_en: begin
  //       tx_r_data <= r_data_img;
  //       reg_read_valid <= 1'b1;
  //     end
  //     fifo_en: begin
  //       tx_r_data <= r_data_fifo;
  //       reg_read_valid <= 1'b1;
  //     end
  //     default: begin
  //       tx_r_data <= '0;
  //       reg_read_valid <= 1'b0;
  //     end
  //   endcase
  // end


  always_comb begin : R_DATA_MUX_BLOCK
    tx_r_data = '0;
    reg_read_valid = 1'b0;
    unique case (1'b1)
      pwm_en: begin
        tx_r_data = r_data_pwm;
        reg_read_valid = 1'b1;
      end
      led_en: begin
        tx_r_data = r_data_led;
        reg_read_valid = 1'b1;
      end
      sys_en: begin
        tx_r_data = r_data_sys;
        reg_read_valid = 1'b1;
      end
      uart_en: begin
        tx_r_data = r_data_uart;
        reg_read_valid = 1'b1;
      end
      msg_en: begin
        tx_r_data = r_data_msg;
        reg_read_valid = 1'b1;
      end
      img_en: begin
        tx_r_data = r_data_img;
        reg_read_valid = 1'b1;
      end
      fifo_en: begin
        tx_r_data = r_data_fifo;
        reg_read_valid = 1'b1;
      end
      default: begin
        tx_r_data = '0;
        reg_read_valid = 1'b0;
      end
    endcase
  end


    // assign tx_r_data = 32'hDEADBEEF;
    // assign reg_read_valid = 1'b1;

endmodule
