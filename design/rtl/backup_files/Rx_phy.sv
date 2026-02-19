`timescale 1ns/1ns

import defs_pkg::*;

module Rx_phy #(parameter RX_BR = 57600) (
    input logic clk,
    input logic rst_n,
    input logic i_rx_line,
    // input logic wr_en,
    // input logic uart_en,
    // input logic [BYTE_LEN-1:0] addr_a0,
    // output logic [31:0] r_data,
    output logic [7:0] o_rx_phy_vec,
    output logic o_rx_phy_done,
    output logic o_rx_mac_str
);
    
//BR16 parameters
localparam BR16_PULSE_CNT = 15;

//RX parametrers
localparam RX_LEN = 10;

//FSM parameters
typedef enum logic [1:0] {IDLE,SAMPLE,BUSY,END_RX} rx_fsm_type;
rx_fsm_type pst,nst;

//FSM EN
logic sample_en;
logic busy_en;  


//FSM PULSES
logic br16_pulse;
logic rx_bit_pulse;
logic rx_str_pulse;
logic rx_busy_pulse;
logic rx_done_pulse;

//------------------------------------------------------

// FRACTIONAL ACCUMULATOR
localparam int BR16       = RX_BR * 16;        // 921_600
localparam int CLK_FREQ   = 100_000_000;    // 100 MHz

logic [$clog2(CLK_FREQ):0] br16_acc;       // רחב מספיק (עד ~100M, ~27 bit)
logic [3:0] br16_pulse_cnt;


always_ff @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin
        br16_acc   <= '0;
        br16_pulse <= 1'b0;
    end else begin
        br16_pulse <= 1'b0;  // default: no pulse
        br16_acc <= br16_acc + BR16;

        if (br16_acc >= CLK_FREQ) begin
            br16_acc   <= br16_acc + BR16 - CLK_FREQ;
            br16_pulse <= 1'b1;
        end
    end
end

//--------------------------------------------

//SYNCHRONIZER

logic stage,rx_data;

always_ff @( posedge clk or negedge rst_n ) begin : SYNCHRONIZER_BLOCK_2FF
    if(!rst_n)begin
        stage <= 1;
        rx_data <= '1;
    end else begin
        stage <= i_rx_line;
        rx_data <= stage;
    end
end

//-----------------------------------------

//FIRST DETECTING ZERO => fron IDLE to SAMPLE

logic [3:0] sample_counter;

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rx_str_pulse <= 0;
    else
        if(sample_en && br16_pulse && sample_counter == 0)
            if(rx_data == 0)
                rx_str_pulse <= 1;
            else
                rx_str_pulse <= 0;
        else
            rx_str_pulse <= 0;
end

//----------------------------------------

//SAMPLING THE ZERO START BIT: SAMPLE to BUSY
logic [2:0] sample_reg;


always_ff @( posedge clk or negedge rst_n ) begin : SAMPLING_BLOCK
    if(!rst_n)begin
        sample_reg <= 3'b111;
        sample_counter <= '0;
    end else if(sample_en && br16_pulse) begin
            sample_reg[0] <= rx_data;
            sample_reg[1] <= sample_reg[0];
            sample_reg[2] <= sample_reg[1];
        if(sample_reg == 3'd0 && sample_counter == 8)begin
            sample_counter <= '0;
        end else if(rx_data)begin
            sample_counter <= '0;
        end else begin
            sample_counter <= sample_counter + 1;
        end
    end         
end 

assign rx_busy_pulse = (sample_en && sample_counter == 8 && br16_pulse)? 1'b1:1'b0;

//-----------------------------------------

always_ff @(posedge clk or negedge rst_n)begin : BR16_CNT_BLOCK
    if (!rst_n) begin
        br16_pulse_cnt <= '0;

    end else if((busy_en && br16_pulse))
            br16_pulse_cnt <= br16_pulse_cnt + 1;
    else if (rx_busy_pulse)
            br16_pulse_cnt <= '0;
                
end

assign rx_bit_pulse =(busy_en && br16_pulse && br16_pulse_cnt == '0)? 1'b1:1'b0;

//-----------------------------------------

//BIT PULSE COUNTER: BUSY to END_RX
logic [3:0] bit_counter;
logic [RX_LEN-1:0] temp_rx_vec;

always_ff @(posedge clk or negedge rst_n)begin : BIT_CNT_BLOCK
    if (!rst_n) begin
        bit_counter <= '0;
        temp_rx_vec <= '0;
        o_rx_phy_vec <= '0;

    end else if(busy_en && rx_bit_pulse)begin
        if(bit_counter == RX_LEN - 1)begin
            bit_counter <= '0;

            o_rx_phy_vec <= temp_rx_vec[8:1];
        end else begin
            bit_counter <= bit_counter + 1;
            temp_rx_vec[bit_counter] <= rx_data;
        end
    end else if(pst == IDLE)
        temp_rx_vec <= '0;
end

assign rx_done_pulse = (busy_en && rx_bit_pulse && bit_counter == RX_LEN - 1)? 1'b1:1'b0;

//------------------------------------------

//-----------------------------------------
//
//              FSM STATES
//
//-----------------------------------------


//PST BLOCK
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        pst <= IDLE;
    else
        pst <= nst;
end

//----------------------------------------

//NST_BLOCK
always_comb begin
    case (pst)
        IDLE:begin
            nst = (rx_str_pulse)? SAMPLE:IDLE;
        end
        SAMPLE:begin
            nst = (rx_busy_pulse)? BUSY:SAMPLE;
        end
        BUSY:begin
            nst = (rx_done_pulse)? END_RX:BUSY;
        end
        END_RX:begin
            nst = IDLE;
        end 
        default:begin
            nst = IDLE;
        end 
    endcase
end

//-------------------------------------------

//------------------------------------------
//
//      EN CONTROL & OUTPUTS FSM BLOCKS 
//
//------------------------------------------

//SAMPLE ENABLE: (NST == IDLE/SAMPLE)
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        sample_en <= 0;
    else if (nst == IDLE || nst == SAMPLE )
        sample_en <= 1;
    else
        sample_en <= 0;
end

//BUSY ENABLE: (NST == BUSY)
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        busy_en <= 0;
    else if (nst == BUSY)
        busy_en <= 1;
    else
        busy_en <= 0;
end

//BYTE_DONE OUTPUT: (NST == END_RX)
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        o_rx_phy_done <= 0;
    else if (nst == END_RX)
        o_rx_phy_done <= 1;
    else
        o_rx_phy_done <= 0;
end

assign o_rx_mac_str = rx_str_pulse;

//---------------------------------------------------


endmodule