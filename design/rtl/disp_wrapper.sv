`timescale 1ns/1ns
`include "top_pkg.svh"


module disp_wrapper #(
    parameter CLK_OUT_FREQ =500,
    parameter MAX_DIGITS_DISP = 8
)(
    input logic clk,
    input logic rst_n,
    input logic [BYTE_LEN-1:0] digit0,
    input logic [BYTE_LEN-1:0] digit1,
    input logic [BYTE_LEN-1:0] digit2,
    input logic [BYTE_LEN-1:0] digit3,
    output logic [MAX_DIGITS_DISP-1:0] AN,
    output logic [6:0] SEG7,
    output logic dot 
);
    
logic clk_pulse_out;
logic [MAX_DIGITS_DISP*4-1:0] hex_disp_vec;
logic [MAX_DIGITS_DISP-1:0] shift_out;

clk_div #(.CLK_OUT_FREQ(CLK_OUT_FREQ)) clk_div_inst (
    .clk(clk),
    .rst_n(rst_n),
    .clk_pulse_out(clk_pulse_out)
    );

shift_reg #(.MAX_DIGITS_DISP(MAX_DIGITS_DISP)) shift_reg_inst (
    .clk_pulse_out(clk_pulse_out),
    .rst_n(rst_n),
    .shift_out(shift_out),
    .clk(clk)
);

disp_decoder #(.MAX_DIGITS_DISP(MAX_DIGITS_DISP)) disp_decoder_inst (
    .rst_n(rst_n),
    .shift_out(shift_out),
    .din(hex_disp_vec),
    .SEG7(SEG7),
    .dot(dot)
);

disp_reg disp_reg_inst(
    .clk(clk),
    .rst_n(rst_n),
    .digit0(digit0),
    .digit1(digit1),
    .digit2(digit2),
    .digit3(digit3),
    .hex_disp_vec(hex_disp_vec)
);

assign AN = shift_out;

endmodule