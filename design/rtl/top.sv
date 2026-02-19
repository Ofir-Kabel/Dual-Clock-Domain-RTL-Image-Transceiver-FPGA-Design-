`timescale 1ns / 1ns
`include "top_pkg.svh"

module top (
    input logic clk,
    input logic rst_n,
    input logic RX_LINE,
    // output logic [MAX_DIGITS_DISP-1:0] AN,
    // output logic [6:0] SEG7,
    // output logic LED_TOGGLE,
    // output logic DP,
    output logic TX_LINE,
    output logic RX_RTS,
    // input logic TX_CTS,
    output logic [5:0] LED,

    // output logic LED16_R,
    // output logic LED16_G,
    // output logic LED16_B,
    // output logic LED17_R,
    // output logic LED17_G,
    // output logic LED17_B

        input logic BTNC
);

  //=========================
  //    INTERNAL SIGNALS
  //=========================

  //SYNC
  logic rst_n_sync_clk100M;
  logic rst_n_sync_clk_wiz;
  logic clk_wiz;

  // Address & Data
  logic [TX_FRAME_LEN-1:0] rx_mac_vec;
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
  logic cmd_ack;

  logic wr_pixel;
  logic [23:0] pixel_data;
  logic led_en, pwm_en, sys_en, uart_en, msg_en;
  logic led16_msg, led17_msg;

  // Read Data Buses
  logic wr_en;
  logic r_en;
  logic fifo_en;
  logic img_en;

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
  logic uart;
  uart_wrapper uart_wrapper_inst (
      .clk  (clk),
      .rst_n(rst_n_sync_clk100M),

      .tx_clk(clk_wiz),
      .tx_sync_rst_n(rst_n_sync_clk_wiz),

      .rx_clk(clk_wiz),
      .rx_sync_rst_n(rst_n_sync_clk_wiz),

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
      .o_tx_line(TX_LINE),  // Changed to internal signal for MUX

      .o_rx_mac_vec(rx_mac_vec),
      .o_rx_mac_done(rx_mac_done),
      .i_cmd_ack(cmd_ack),

      .o_led_toggle(LED_TOGGLE)
  );

  // logic uart;
  // uart_wrapper uart_wrapper_inst (
  //     .clk  (clk),
  //     .rst_n(rst_n_sync_clk100M),

  //     .tx_clk(clk),
  //     .tx_sync_rst_n(rst_n_sync_clk100M),

  //     .rx_clk(clk),
  //     .rx_sync_rst_n(rst_n_sync_clk100M),

  //     .i_wr_en(wr_en),
  //     .i_uart_en(uart_en),
  //     .i_addr_low(addr[BYTE_LEN-1:0]),
  //     .i_w_data(w_data),
  //     .o_r_txr_data(r_data_uart),

  //     .i_tx_mac_vec  (tx_mac_vec),
  //     .i_tx_mac_str  (tx_mac_str),
  //     .o_tx_mac_ready(tx_mac_ready),
  //     .o_tx_mac_done (tx_mac_done),

  //     .i_rx_line(RX_LINE),
  //     .o_tx_line(TX_LINE),  // Changed to internal signal for MUX

  //     .o_rx_mac_vec(rx_mac_vec),
  //     .o_rx_mac_done(rx_mac_done),
  //     .i_cmd_ack(cmd_ack),

  //     .o_led_toggle(LED_TOGGLE)
  // );


  msg_parser_v0 msg_parser_v0_inst (
    .trx_clk(clk_wiz),
    .trx_rst_n(rst_n_sync_clk_wiz),
      .clk(clk),
      .rst_n(rst_n_sync_clk100M),
      .frame_data(rx_mac_vec),
      .rx_mac_done(rx_mac_done),
      .rx_mac_done_sync(rx_mac_done_sync),
      .red(red),
      .green(green),
      .blue(blue),
      .addr(addr),
      .wdata(w_data),
      .wr_en(wr_en),
      .r_en(r_en),
      .r_data(r_data_msg),
      .cmd_ack(cmd_ack),
      .wr_pixel(wr_pixel),
      .pixel_data(pixel_data)
  );

  logic reg_read_valid;

  addr_selection addr_selection_inst (
      .clk(clk),
      .rst_n(rst_n_sync_clk100M),
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
      .tx_r_data(tx_r_data),
      .reg_read_valid(reg_read_valid)
  );

  // led_wrapper led_wrapper_inst (
  //     .clk(clk),
  //     .rst_n(rst_n_sync_clk100M),
  //     .addr_low(addr[BYTE_LEN-1:0]),
  //     .led_en(led_en),
  //     .red_vec(red),
  //     .green_vec(green),
  //     .blue_vec(blue),
  //     .wr_en(wr_en),
  //     .w_data(w_data),
  //     .r_data(r_data_led),
  //     .led16_en(led16_msg),
  //     .led17_en(led17_msg),
  //     .red_pwm(red_pwm),
  //     .green_pwm(green_pwm),
  //     .blue_pwm(blue_pwm)
  // );

  // pwm_wrapper pwm_wrapper_inst (
  //     .clk(clk),
  //     .rst_n(rst_n_sync_clk100M),
  //     .red_duty_cycle(red_pwm),
  //     .green_duty_cycle(green_pwm),
  //     .blue_duty_cycle(blue_pwm),
  //     .pwm_en(pwm_en),
  //     .wr_en(wr_en),
  //     .w_data(w_data),
  //     .addr_low(addr[BYTE_LEN-1:0]),
  //     .r_data(r_data_pwm),
  //     .red_pwm_out(red_pwm_out),
  //     .green_pwm_out(green_pwm_out),
  //     .blue_pwm_out(blue_pwm_out)
  // );

  // disp_wrapper #(
  //     .CLK_OUT_FREQ(CLK_OUT_FREQ),
  //     .MAX_DIGITS_DISP(MAX_DIGITS_DISP)
  // ) warp_display_inst (
  //     .clk(clk),
  //     .rst_n(rst_n_sync_clk100M),
  //     .digit0(blue),
  //     .digit1(green),
  //     .digit2(red),
  //     .digit3(digit3),
  //     .AN(AN),
  //     .SEG7(SEG7),
  //     .dot(DP)
  // );

  logic ready;
  logic read;
  logic trans;
  logic comp;
  logic btnc_r;

  // ila_0 ila_inst (
  // .clk(clk),
  // .probe0(clk_wiz),
  // .probe1(TX_LINE),
  // .probe2(RX_LINE),
  // .probe3(btnc_r),
  // .probe4(img_en),
  // .probe5(r_en),
  // .probe6(tx_mac_str),
  // .probe7(tx_mac_ready),
  // .probe8(tx_mac_done),
  // .probe9(RX_LINE)
  // );

  sequencer sequencer_inst (
      .clk           (clk),
      .rst_n         (rst_n_sync_clk100M),
      .w_clk         (clk),
      .w_rst_n       (rst_n_sync_clk100M),
      .r_clk         (clk_wiz),
      .r_rst_n       (rst_n_sync_clk_wiz),
      .wr_en         (wr_en),
      .img_sel_r     (img_en),
      .w_data        (w_data),
      .r_data_fifo   (r_data_fifo),         //
      .r_data_img    (r_data_img),          //
      .addr          (addr),                //
      //  RGF - MSG
      .read_cmd      (r_en),
      .reg_read_valid(reg_read_valid),
      //MSG COMPOSSER             
      .tx_r_data    (tx_r_data),           //
      // TX_MAC
      .tx_mac_ready  (tx_mac_ready),
      .tx_mac_done   (tx_mac_done),
      .tx_mac_vec    (tx_mac_vec),
      .tx_mac_str    (tx_mac_str),
      .btnc_r        (btnc_r),              //DEBUGGING
      .wr_pixel      (wr_pixel),
      .i_pixel_data  (pixel_data),

      .ready(ready),
      .read (read),
      .trans(trans),
      .comp (comp),

      .o_rts(RX_RTS)
  );


  logic btnc_q;
  always_ff @(posedge clk or negedge rst_n_sync_clk100M) begin
    if (!rst_n_sync_clk100M) btnc_q <= 1'b0;
    else btnc_q <= BTNC;
  end

  assign btnc_r = !btnc_q & BTNC;

  logic wiz_clk_0_locked;

  rst_sync_pll rst_sync_pll_inst (
      .clk_100M(clk),
      .rst_n(rst_n),
      .rst_n_sync_clk100M(rst_n_sync_clk100M),
      .rst_n_sync_sys_clk(rst_n_sync_clk_wiz),
      .wiz_clk_0_locked(wiz_clk_0_locked),
      .sys_clk(clk_wiz)
  );

  //========================================
  //      OUTPUT ASSIGNMENTS
  //========================================

  // assign LED16_R = (led16_msg) ? red_pwm_out : 1'b0;
  // assign LED16_G = (led16_msg) ? green_pwm_out : 1'b0;
  // assign LED16_B = (led16_msg) ? blue_pwm_out : 1'b0;

  // assign LED17_R = (led16_msg) ? red_pwm_out : 1'b0;
  // assign LED17_G = (led16_msg) ? green_pwm_out : 1'b0;
  // assign LED17_B = (led16_msg) ? blue_pwm_out : 1'b0;

  logic reg_read;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) reg_read <= 1'b0;
    else reg_read <= r_en;
  end

  assign LED = {btnc_r, reg_read, comp, trans, read, ready, wiz_clk_0_locked};

  //========================================
  //      REG - SYS_CONFIG
  //========================================
  sys_cfg_reg_t sys_cfg_r, sys_cfg_r_v;

  logic [BYTE_LEN-1:0] addr_low;
  assign addr_low = addr[BYTE_LEN-1:0];


  // always_ff @(posedge clk or negedge rst_n_sync_clk100M) begin
  //   if (!rst_n_sync_clk100M) begin
  //     sys_cfg_r.sys_rst_n <= 1'b0;
  //     sys_cfg_r.sw_enable <= 1'b0;
  //     sys_cfg_r.reserved  <= '0;
  //   end else if (wr_en && sys_en) begin
  //     if (addr_low == 8'h00) begin
  //       sys_cfg_r.sys_rst_n <= sys_cfg_r_v.sys_rst_n;
  //       sys_cfg_r.sw_enable <= sys_cfg_r_v.sw_enable;
  //       sys_cfg_r.reserved  <= '0;
  //     end
  //   end
  // end
  assign sys_cfg_r_v = w_data;
  assign r_data_sys = sys_cfg_r;

endmodule
