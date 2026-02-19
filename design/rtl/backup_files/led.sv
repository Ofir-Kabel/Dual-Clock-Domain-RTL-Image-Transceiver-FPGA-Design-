`timescale 1ns/1ps

import defs_pkg::*;

module led (
    input logic clk,
    input logic rst_n,
    input logic color_en,
    input logic [7:0] red_vec,
    input logic [7:0] green_vec,
    input logic [7:0] blue_vec,
    input logic cie_en,
    output logic [PWM_LEN-1:0] red_out,
    output logic [PWM_LEN-1:0] green_out,
    output logic [PWM_LEN-1:0] blue_out
);
    logic is_green = 1'b0;
    logic is_blue = 1'b1;

    logic[9:0] red_scale_in;
    logic[9:0] green_scale_in;
    logic[9:0] blue_scale_in;
    
    logic[PWM_LEN-1:0] green_scale_out;
    logic[PWM_LEN-1:0] blue_scale_out;

    scaling_factor scaling_factor_green_inst (
    .clk(clk),
    .rst_n(rst_n),
    .blue_nor_green(is_green),   // 1=Blue, 0=Green
    .color_vec(green_scale_in),  // From Gamma (0-1023)
    .scale_factor_out(green_scale_out)  // Expanded to 12-bit to hold value ~2680
    );

    scaling_factor scaling_factor_blue_inst (
    .clk(clk),
    .rst_n(rst_n),
    .blue_nor_green(is_blue),   // 1=Blue, 0=Green
    .color_vec(blue_scale_in),  // From Gamma (0-1023)
    .scale_factor_out(blue_scale_out)  // Expanded to 12-bit to hold value ~2680
    );

//-----------------------------------------------------

//COLOR LOADING 
always_ff @(posedge clk or negedge rst_n)begin
    if (!rst_n) begin
        red_scale_in <= '0;
        green_scale_in <= '0;
        blue_scale_in <= '0;
    end else if(color_en)begin
        red_scale_in <= gamma_table[red_vec];
        green_scale_in <= gamma_table[green_vec];
        blue_scale_in  <= gamma_table[blue_vec];
    end else begin
        red_scale_in <= '0;
        green_scale_in <= '0;
        blue_scale_in <= '0;
    end
end

//COLORS OUTPUT TO PWM
always_ff @(posedge clk or negedge rst_n)begin
    if (!rst_n) begin
        red_out <= '0;
        green_out <= '0;
        blue_out <= '0;
    end else if(cie_en)begin
        red_out <= red_scale_in;
        green_out <= green_scale_out;
        blue_out <= blue_scale_out;
    end else begin
        red_out <= gamma_table[red_vec];
        green_out <=gamma_table[green_vec];
        blue_out <= gamma_table[blue_vec];
    end
end



endmodule