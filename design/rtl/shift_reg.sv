`timescale 1ns/1ns
`include "top_pkg.svh"

module shift_reg #(
    parameter MAX_DIGITS_DISP = 8
)(
    input logic clk,
    input logic clk_pulse_out,
    input logic rst_n, 
    output logic [MAX_DIGITS_DISP-1:0] shift_out
);

logic [MAX_DIGITS_DISP-1:0] temp_out;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        temp_out <= 8'b11111110;
    end 
    else if(clk_pulse_out) begin
        temp_out <= {temp_out[MAX_DIGITS_DISP-2:0], temp_out[MAX_DIGITS_DISP-1]};
    end
end

assign shift_out = (!rst_n)? 8'hFF:temp_out;

endmodule


