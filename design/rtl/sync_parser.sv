`timescale 1ns / 1ps
`include "top_pkg.svh"

module msg_parser_v0 (
    input logic trx_clk,
    input logic trx_rst_n,
    input logic                     clk,
    input logic                     rst_n,
    input logic [TX_FRAME_LEN-1:0] frame_data,
    input logic rx_mac_done,

    // RGB / LED Outputs
    output logic [7:0] red,
    output logic [7:0] green,
    output logic [7:0] blue,


    // Register File Access Outputs
    output logic [23:0] addr,   // A2, A1, A0
    output logic [31:0] wdata,  // DH1, DH0, DL1, DL0
    output logic        wr_en,  // 1 = Write, 0 = Read
    output logic        r_en,

    // Readback Data (from internal counters)
    output logic [31:0] r_data,
    output logic cmd_ack
);



endmodule
