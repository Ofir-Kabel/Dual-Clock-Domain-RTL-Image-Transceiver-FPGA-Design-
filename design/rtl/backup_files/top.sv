`timescale 1ns / 1ns
import defs_pkg::*;

module top (
    input logic clk,
    input logic rst_n,
    input logic RX_LINE,
    output logic [MAX_DIGITS_DISP-1:0] AN,
    output logic [6:0] SEG7,
    output logic LED_TOGGLE,
    output logic DP,
    output logic TX_LINE,
    output logic RX_RTS,
    output logic LED16_R,
    output logic LED16_G,
    output logic LED16_B,
    output logic LED17_R,
    output logic LED17_G,
    output logic LED17_B
);

  //=========================
  //    INTERNAL SIGNALS
  //=========================

  // Address & Data
  logic [MAX_FRAME_LEN-1:0] rx_mac_vec;
  logic [23:0] addr;
  logic [31:0] w_data;

  // Colors
  logic [7:0] red, green, blue;

  // TX_MAC
  logic tx_mac_str;
  logic tx_mac_ready;
  logic tx_mac_done;

  //RX_MAC
  logic rx_mac_done;
  logic led_err;

  logic led_en, pwm_en, sys_en, uart_en, msg_en;
  logic led16_msg, led17_msg;

  // Read Data Buses
  logic wr_en;
  logic r_en;

  logic [31:0] r_data_uart;
  logic [31:0] tx_r_data;
  logic [31:0] r_data_pwm;
  logic [31:0] r_data_led;
  logic [31:0] r_data_sys;
  logic [31:0] r_data_msg;
  logic [31:0] r_data_fifo;
  logic [31:0] r_data_img;

  //TX MAC

  logic [TX_FRAME_LEN-1:0] tx_mac_vec;

  // PWM Interconnects
  logic [PWM_LEN-1:0] red_pwm, green_pwm, blue_pwm;
  logic red_pwm_out, green_pwm_out, blue_pwm_out;

  // Logic for display
  logic [7:0] digit3;
  assign digit3 = (led16_msg) ? 8'h2 : 8'h1;


  //======================================
  //      MODULE INSTANTIATIONS 
  //======================================

  uart_wrapper uart_wrapper_inst (
      .clk  (clk),
      .rst_n(rst_n),

      .i_wr_en(wr_en),
      .i_uart_en(uart_en),
      .i_addr_low(addr[BYTE_LEN-1:0]),
      .i_w_data(w_data),
      .o_r_txr_data(r_data_uart),

      .i_tx_mac_vec  (tx_mac_vec),
      .i_tx_mac_str  (tx_mac_str),
      .o_tx_mac_ready(tx_mac_ready),
      .o_tx_mac_done (tx_mac_done),

      .i_rx_line(RX_LINE),
      .o_tx_line(TX_LINE),

      .o_rx_mac_vec (rx_mac_vec),
      .o_rx_mac_done(rx_mac_done),

      .o_led_toggle(LED_TOGGLE)
  );

  msg_parser msg_parser_inst (
      .clk(clk),
      .rst_n(rst_n),
      .frame_data(rx_mac_vec),
      .rx_mac_done(rx_mac_done),
      .red(red),
      .green(green),
      .blue(blue),
      .addr(addr),
      .wdata(w_data),
      .wr_en(wr_en),
      .r_en(r_en),
      .r_data(r_data_msg)
  );

  addr_selection addr_selection_inst (
      .addr_A2(addr[BYTE_LEN*3-1:BYTE_LEN*2]),
      .r_data_pwm(r_data_pwm),
      .r_data_led(r_data_led),
      .r_data_sys(r_data_sys),
      .r_data_uart(r_data_uart),
      .r_data_msg(r_data_msg),
      .r_data_fifo(r_data_fifo),
      .r_data_img(r_data_img),
      .led_en(led_en),
      .pwm_en(pwm_en),
      .sys_en(sys_en),
      .uart_en(uart_en),
      .msg_en(msg_en),
      .img_en(img_en),
      .fifo_en(fifo_en),
      .tx_r_data(tx_r_data)
  );

  led_wrapper led_wrapper_inst (
      .clk(clk),
      .rst_n(rst_n),
      .addr_low(addr[BYTE_LEN-1:0]),
      .led_en(led_en),
      .red_vec(red),
      .green_vec(green),
      .blue_vec(blue),
      .wr_en(wr_en),
      .w_data(w_data),
      .r_data(r_data_led),
      .led16_en(led16_msg),
      .led17_en(led17_msg),
      .red_pwm(red_pwm),
      .green_pwm(green_pwm),
      .blue_pwm(blue_pwm)
  );

  pwm_wrapper pwm_wrapper_inst (
      .clk(clk),
      .rst_n(rst_n),
      .red_duty_cycle(red_pwm),
      .green_duty_cycle(green_pwm),
      .blue_duty_cycle(blue_pwm),
      .pwm_en(pwm_en),
      .wr_en(wr_en),
      .w_data(w_data),
      .addr_low(addr[BYTE_LEN-1:0]),
      .r_data(r_data_pwm),
      .red_pwm_out(red_pwm_out),
      .green_pwm_out(green_pwm_out),
      .blue_pwm_out(blue_pwm_out)
  );

  disp_wrapper #(
      .CLK_OUT_FREQ(CLK_OUT_FREQ),
      .MAX_DIGITS_DISP(MAX_DIGITS_DISP)
  ) warp_display_inst (
      .clk(clk),
      .rst_n(rst_n),
      .digit0(blue),
      .digit1(green),
      .digit2(red),
      .digit3(digit3),
      .AN(AN),
      .SEG7(SEG7),
      .dot(DP)
  );

  sequencer sequencer_inst (
      .clk         (clk),
      .rst_n       (rst_n),
      .w_clk       (clk),
      .w_rst_n     (rst_n),
      .r_clk       (clk),
      .r_rst_n     (rst_n),
      .wr_en       (wr_en),
      .img_sel_r   (img_en),
      .w_data      (w_data),
      .r_data_fifo (r_data_fifo),   //
      .r_data_img  (r_data_img),    //
      .addr        (addr),          //
      //  RGF - MSG
      .read_cmd    (r_en),
      //MSG COMPOSSER             
      .r_data_msg  (tx_r_data),     //
      // TX_MAC
      .tx_mac_ready(tx_mac_ready),
      .tx_mac_done (tx_mac_done),
      .tx_mac_vec  (tx_mac_vec),
      .tx_mac_str  (tx_mac_str),
      .o_rts       (RX_RTS)
  );

  //========================================
  //      OUTPUT ASSIGNMENTS
  //========================================

  assign LED16_R = (led16_msg) ? red_pwm_out : 1'b0;
  assign LED16_G = (led16_msg) ? green_pwm_out : 1'b0;
  assign LED16_B = (led16_msg) ? blue_pwm_out : 1'b0;

  assign LED17_R = (led16_msg) ? red_pwm_out : 1'b0;
  assign LED17_G = (led16_msg) ? green_pwm_out : 1'b0;
  assign LED17_B = (led16_msg) ? blue_pwm_out : 1'b0;


  //========================================
  //      REG - SYS_CONFIG
  //========================================
  sys_cfg_reg_t sys_cfg_r, sys_cfg_r_v;

  logic [BYTE_LEN-1:0] addr_low;
  assign addr_low = addr[BYTE_LEN-1:0];
  assign sys_cfg_r_v = w_data;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sys_cfg_r.sys_rst_n <= 1'b0;
      sys_cfg_r.sw_enable <= 1'b0;
      sys_cfg_r.reserved  <= '0;
    end else if (wr_en && sys_en) begin
      if (addr_low == 8'h00) begin
        sys_cfg_r.sys_rst_n <= sys_cfg_r_v.sys_rst_n;
        sys_cfg_r.sw_enable <= sys_cfg_r_v.sw_enable;
        sys_cfg_r.reserved  <= '0;
      end
    end
  end

endmodule
