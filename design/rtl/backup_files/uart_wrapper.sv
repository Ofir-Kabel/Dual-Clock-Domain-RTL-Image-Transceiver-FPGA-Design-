`timescale 1ns / 1ps

import defs_pkg::*;

module uart_wrapper (
    input logic clk,
    input logic rst_n,
    //TX MAC
    input logic i_tx_mac_str,
    input logic [223:0] i_tx_mac_vec,
    output logic o_tx_mac_done,
    output logic o_tx_mac_ready,
    //RFG
    input logic i_uart_en,
    input logic i_wr_en,
    input logic [7:0] i_addr_low,
    input logic [31:0] i_w_data,
    output logic [31:0] o_r_txr_data,
    //RX PHY
    input logic i_rx_line,
    //RX MAC
    output logic o_rx_mac_done,
    output logic [MAX_FRAME_LEN-1:0] o_rx_mac_vec,
    //TX PHY
    output logic o_tx_line,
    output logic o_led_toggle
);

//=============================
//    INTERNAL SIGNALS
//=============================

  //RX MAC-PHY SIGNALS
  logic [BYTE_LEN-1:0] rx_phy_vec;
  logic rx_phy_done;
  logic rx_mac_str;
  logic [31:0] r_data_rx;

  //TX MAC-PHY SIGNALS 
  logic [7:0] tx_phy_vec;
  logic [7:0] tx_delay_ms;
  logic tx_phy_str;
  logic tx_phy_ready;
  logic tx_phy_done;
  logic [31:0] r_data_tx;

//=============================
//    INSTATIONATIONS
//=============================

Tx_mac Tx_mac_v2_inst (
    .clk(clk),
    .rst_n(rst_n),
    .o_r_reg_data(r_data_tx),
    .i_tx_mac_vec(i_tx_mac_vec),
    .i_tx_phy_ready(tx_phy_ready), 
    .i_tx_phy_done(tx_phy_done),   
    .i_tx_mac_str(i_tx_mac_str),
    .o_tx_phy_vec(tx_phy_vec),     
    .o_tx_phy_str(tx_phy_str),
    .o_tx_mac_ready(o_tx_mac_ready),    
    .o_tx_mac_done(o_tx_mac_done)
);

//--------------------------------------
Tx_phy Tx_phy_inst (
      .clk(clk),
      .rst_n(rst_n),
      .tx_phy_str(tx_phy_str),
      .data_in(tx_phy_vec),
      .delay_ms(tx_delay_ms),
      .tx_line(o_tx_line),
      .byte_ready(tx_phy_ready),
      .byte_done(tx_phy_done),
      .led_toggle(o_led_toggle)
  );
  assign tx_delay_ms = '0;

//-----------------------------------------
Rx_mac Rx_mac_inst (
      .clk(clk),
      .rst_n(rst_n),
      .r_data(r_data_rx), 
      .rx_phy_done(rx_phy_done),
      .rx_mac_str(rx_mac_str),
      .rx_vec(rx_phy_vec), 
      .frame_data(o_rx_mac_vec), 
      .rx_mac_done(o_rx_mac_done) 
  );

//-------------------------------------------
  Rx_phy Rx_phy_inst (
      .clk(clk),
      .rst_n(rst_n),
      .i_rx_line(i_rx_line),
      .o_rx_phy_vec(rx_phy_vec),
      .o_rx_phy_done(rx_phy_done),
      .o_rx_mac_str(rx_mac_str)
  );

//=============================
//    REG - READ_DATA
//=============================

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) o_r_txr_data <= '0;
    else if (!i_wr_en && i_addr_low == 8'h00 && i_uart_en) o_r_txr_data <= r_data_rx;
    else if (!i_wr_en && i_addr_low == 8'h04 && i_uart_en) o_r_txr_data <= r_data_tx;
    else o_r_txr_data <= '0;
  end

endmodule
