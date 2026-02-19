`timescale 1ns/1ns

import defs_pkg::*;

module disp_reg (
    input clk,
    input logic rst_n,
    input logic [7:0] digit0,
    input logic [7:0] digit1,
    input logic [7:0] digit2,
    input logic [7:0] digit3,
    output logic [31:0] hex_disp_vec
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hex_disp_vec <= 32'h00000000;
    end else begin
        hex_disp_vec <= {digit3, digit2, digit1, digit0};
    end
end

endmodule