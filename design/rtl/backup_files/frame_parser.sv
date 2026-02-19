`timescale 1ns/1ps

import defs_pkg::*;

module frame_parser (
    input logic [MAX_FRAME_LEN-1:0] frame_data,
    output logic [7:0] red,
    output logic [7:0] green,
    output logic [7:0] blue,
    output logic [23:0] addr,
    output logic [31:0] wdata,
    output logic rgb_valid,
    output logic which_led, // 0=LED16, 1=LED17
    output logic which_msg, // 0=MSG1 (RGB), 1=MSG2 (L)
    output logic wr_en,
    output logic led_err
);

//MSG_DETECTION


// Open frame
localparam OPEN_H = MAX_FRAME_LEN-1;
localparam OPEN_L = MAX_FRAME_LEN-BYTE_LEN;

// addr indx
// <
localparam ADDR_2_H = MAX_FRAME_LEN-3*BYTE_LEN-1;
localparam ADDR_2_L = MAX_FRAME_LEN-4*BYTE_LEN;
// , 
localparam ADDR_1_H = MAX_FRAME_LEN-5*BYTE_LEN-1;
localparam ADDR_1_L = MAX_FRAME_LEN-6*BYTE_LEN;
// ,
localparam ADDR_0_H = MAX_FRAME_LEN-7*BYTE_LEN-1;
localparam ADDR_0_L = MAX_FRAME_LEN-8*BYTE_LEN;
// >
// }
// { R < A2 , A1 , A0 > }

// Symbol ASCII
localparam OPERATION_SYMBOL_H = MAX_FRAME_LEN-9;
localparam OPERATION_SYMBOL_L = MAX_FRAME_LEN-16; 

localparam WD_3_H = MAX_FRAME_LEN-13*BYTE_LEN-1;
localparam WD_3_L = MAX_FRAME_LEN-14*BYTE_LEN;
localparam WD_2_H = MAX_FRAME_LEN-15*BYTE_LEN-1;
localparam WD_2_L = MAX_FRAME_LEN-16*BYTE_LEN;
localparam WD_1_H = MAX_FRAME_LEN-21*BYTE_LEN-1;
localparam WD_1_L = MAX_FRAME_LEN-22*BYTE_LEN;
localparam WD_0_H = MAX_FRAME_LEN-25*BYTE_LEN-1;
localparam WD_0_L = MAX_FRAME_LEN-26*BYTE_LEN;

// Close READ frame
localparam CLOSE_READ_H = MAX_FRAME_LEN-73;
localparam CLOSE_READ_L = MAX_FRAME_LEN-80; // Note: MAX_FRAME_LEN-128 =0

logic write_msg_en;
logic read_msg_en;
logic led_msg_en;
logic rgb_msg_en;

logic w_cond;
logic r_cond;
logic rgb_cond;
logic l_cond;

assign w_cond = (open_valid && frame_data[OPERATION_SYMBOL_H:OPERATION_SYMBOL_L]==ASCII_W);
assign r_cond = (open_valid && frame_data[OPERATION_SYMBOL_H:OPERATION_SYMBOL_L]==ASCII_R && frame_data[CLOSE_READ_H:CLOSE_READ_L] == ASCII_CLOSE);
assign l_cond = (open_valid && frame_data[OPERATION_SYMBOL_H:OPERATION_SYMBOL_L]==ASCII_L);
assign r_cond = (open_valid && frame_data[OPERATION_SYMBOL_H:OPERATION_SYMBOL_L]==ASCII_R && close_valid == ASCII_CLOSE);

always_comb begin
    write_msg_en <= 1'b0;
    read_msg_en <= 1'b0;
    led_msg_en <=1'b0;
    rgb_msg_en <=1'b0;

    unique case (1'b1)
        w_cond:    write_msg_en <= 1'b1
        r_cond:    read_msg_en <=1'b1
        l_cond:    led_msg_en <=1'b1;
        r_cond:    rgb_msg_en <=1'b1
        default: begin
            write_msg_en <= 1'b0;
            read_msg_en <= 1'b0;
            led_msg_en <=1'b0;
            rgb_msg_en <=1'b0;
        end
    endcase
end

assign addr =(write_msg_en || read_msg_en)? {frame_data[ADDR_2_H:ADDR_2_L],frame_data[ADDR_1_H:ADDR_1_L],frame_data[ADDR_0_H:ADDR_0_L]}:'0;
assign wdata =(write_msg_en)? {frame_data[WD_3_H:WD_3_L],frame_data[WD_2_H:WD_2_L],frame_data[WD_1_H:WD_1_L],frame_data[WD_0_H:WD_0_L]}:'0;


//////////////////////////////////////////////////////
//                LED HANDELING
//////////////////////////////////////////////////////



// Index definitions for full frame (MSG1: RGB)

// Open frame
localparam OPEN_SH = MAX_FRAME_LEN-1;
localparam OPEN_SL = MAX_FRAME_LEN-8;

// RED
localparam R_SH = MAX_FRAME_LEN-9;      //R symbol high
localparam R_SL = MAX_FRAME_LEN-16;     //R symbol low  
localparam R_HH = MAX_FRAME_LEN-17;     //R hundred high
localparam R_HL = MAX_FRAME_LEN-24;     //R hundred low
localparam R_DH = MAX_FRAME_LEN-25;
localparam R_DL = MAX_FRAME_LEN-32;
localparam R_OH = MAX_FRAME_LEN-33;
localparam R_OL = MAX_FRAME_LEN-40;

// Comma1 after RED
localparam COMMA1_SH = MAX_FRAME_LEN-41;
localparam COMMA1_SL = MAX_FRAME_LEN-48;

// GREEN
localparam G_SH = MAX_FRAME_LEN-49;
localparam G_SL = MAX_FRAME_LEN-56;
localparam G_HH = MAX_FRAME_LEN-57;
localparam G_HL = MAX_FRAME_LEN-64;
localparam G_DH = MAX_FRAME_LEN-65;
localparam G_DL = MAX_FRAME_LEN-72;
localparam G_OH = MAX_FRAME_LEN-73;
localparam G_OL = MAX_FRAME_LEN-80;

// Comma2 after GREEN
localparam COMMA2_SH = MAX_FRAME_LEN-81;
localparam COMMA2_SL = MAX_FRAME_LEN-88;

// BLUE (or L for MSG2)
localparam B_SH = MAX_FRAME_LEN-89;
localparam B_SL = MAX_FRAME_LEN-96;
localparam B_HH = MAX_FRAME_LEN-97;
localparam B_HL = MAX_FRAME_LEN-104;
localparam B_DH = MAX_FRAME_LEN-105;
localparam B_DL = MAX_FRAME_LEN-112;
localparam B_OH = MAX_FRAME_LEN-113;
localparam B_OL = MAX_FRAME_LEN-120;

// Close frame
localparam CLOSE_SH = MAX_FRAME_LEN-121;
localparam CLOSE_SL = MAX_FRAME_LEN-128; // Note: MAX_FRAME_LEN-128 =0

// Use same positions for L as B (aligned for both frame types)
localparam L_SH = B_SH;
localparam L_SL = B_SL;
localparam L_HH = B_HH;
localparam L_HL = B_HL;
localparam L_DH = B_DH;
localparam L_DL = B_DL;
localparam L_OH = B_OH;
localparam L_OL = B_OL;

// Temp values (digits converted from ASCII)
logic [7:0] temp_red_h, temp_red_d, temp_red_o;
logic [7:0] temp_green_h, temp_green_d, temp_green_o;
logic [7:0] temp_blue_h, temp_blue_d, temp_blue_o;
logic [7:0] temp_led_h, temp_led_d, temp_led_o;
logic [7:0] red_value, green_value, blue_value;

// Format validations (to use the bits and fix "no load" warnings)
logic open_valid, close_valid, comma1_valid, comma2_valid;
logic red_valid,green_valid,blue_valid;

assign open_valid = (frame_data[OPEN_SH:OPEN_SL] == ASCII_OPEN);
assign close_valid = (frame_data[CLOSE_SH:CLOSE_SL] == ASCII_CLOSE);
assign comma1_valid = (frame_data[COMMA1_SH:COMMA1_SL] == ASCII_COMMA);
assign comma2_valid = (frame_data[COMMA2_SH:COMMA2_SL] == ASCII_COMMA);

// RED parsing
assign temp_red_h = (frame_data[R_SH:R_SL] == ASCII_R) ? frame_data[R_HH:R_HL] - 8'd48 : 8'd0;
assign temp_red_d = (frame_data[R_SH:R_SL] == ASCII_R) ? frame_data[R_DH:R_DL] - 8'd48 : 8'd0;
assign temp_red_o = (frame_data[R_SH:R_SL] == ASCII_R) ? frame_data[R_OH:R_OL] - 8'd48 : 8'd0;
assign red_value = (temp_red_h << 5) + (temp_red_h << 6) + (temp_red_h << 2) + (temp_red_d << 3) + (temp_red_d << 1) + temp_red_o;
assign red_valid = (frame_data[R_SH:R_SL] == ASCII_R) & (red_value <= 8'd255);
assign red = red_valid ? red_value : 8'd0;

// GREEN parsing
assign temp_green_h = (frame_data[G_SH:G_SL] == ASCII_G) ? frame_data[G_HH:G_HL] - 8'd48 : 8'd0;
assign temp_green_d = (frame_data[G_SH:G_SL] == ASCII_G) ? frame_data[G_DH:G_DL] - 8'd48 : 8'd0;
assign temp_green_o = (frame_data[G_SH:G_SL] == ASCII_G) ? frame_data[G_OH:G_OL] - 8'd48 : 8'd0;
assign green_value = (temp_green_h << 5) + (temp_green_h << 6) + (temp_green_h << 2) + (temp_green_d << 3) + (temp_green_d << 1) + temp_green_o;
assign green_valid = (frame_data[G_SH:G_SL] == ASCII_G) & (green_value <= 8'd255);
assign green = green_valid ? green_value : 8'd0;

// BLUE parsing
assign temp_blue_h = (frame_data[B_SH:B_SL] == ASCII_B) ? frame_data[B_HH:B_HL] - 8'd48 : 8'd0;
assign temp_blue_d = (frame_data[B_SH:B_SL] == ASCII_B) ? frame_data[B_DH:B_DL] - 8'd48 : 8'd0;
assign temp_blue_o = (frame_data[B_SH:B_SL] == ASCII_B) ? frame_data[B_OH:B_OL] - 8'd48 : 8'd0;
assign blue_value = (temp_blue_h << 5) + (temp_blue_h << 6) + (temp_blue_h << 2) + (temp_blue_d << 3) + (temp_blue_d << 1) + temp_blue_o;
assign blue_valid = (frame_data[B_SH:B_SL] == ASCII_B) & (blue_value <= 8'd255);
assign blue = blue_valid ? blue_value : 8'd0;

// RGB valid (includes format checks to use all bits)
assign rgb_valid = red_valid & green_valid & blue_valid & open_valid & close_valid & comma1_valid & comma2_valid;

// LED index parsing (same positions as blue)
assign temp_led_h = frame_data[L_HH:L_HL] - 8'd48;
assign temp_led_d = frame_data[L_DH:L_DL] - 8'd48;
assign temp_led_o = frame_data[L_OH:L_OL] - 8'd48;

// Which LED (0 if 016, 1 if 017)
assign which_led = (l_cond) & (temp_led_h == 8'd0) & (temp_led_d == 8'd1) & (temp_led_o == 8'd7);

// LED error (if L but not 016/017) - fixed bug by changing || to &&
assign led_err = (l_cond) & ( !((temp_led_o == 8'd6) || (temp_led_o == 8'd7)) );

// Which message type
assign which_msg = (frame_data[L_SH:L_SL] == ASCII_L) ? 1'b1 : 1'b0;


//-------------------------------------------------------------------------------------------

// CNT RGF
uart_cnt_r color_msg_cnt;
uart_cnt_r cfg_msg_cnt;

always_ff @(posedge clk or negedge rst_n)begin
   if(!rst_n)
        color_msg_cnt <= '0;
    else if(byte_done && r_cond)
        color_msg_cnt <= color_msg_cnt + 1;
end

always_ff @(posedge clk or negedge rst_n)begin
   if(!rst_n)
        cfg_msg_cnt <= '0;
    else if(byte_done && l_cond)
        cfg_msg_cnt <= cfg_msg_cnt + 1;
end
    

endmodule