`timescale 1ns / 1ps

import defs_pkg::*;


module Tx_mac (
    input logic clk,
    input logic rst_n,

    output logic [31:0] o_r_reg_data,

    input  logic [223:0] i_tx_mac_vec,
    input  logic         i_tx_phy_ready,
    input  logic         i_tx_phy_done,
    input  logic         i_tx_mac_str,
    output logic [  7:0] o_tx_phy_vec,
    output logic         o_tx_phy_str,    //Tx_phy start pulse
    output logic         o_tx_mac_ready,
    output logic         o_tx_mac_done
);

  logic [TX_FRAME_LEN-1:0] frame_to_send;


  typedef enum logic [1:0] {
    IDLE,
    SEND_FRAME,
    TRANS_DONE
  } tx_mac_fsm_type;
  tx_mac_fsm_type pst, nst;
  logic [4:0] byte_index;
  logic last_byte_pulse;


  /////////////////
  //
  //  FSM STATES
  //
  /////////////////

  //PRESENT STATE BLOCK
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) pst <= IDLE;
    else pst <= nst;
  end

  //NEXT STATE BLOCK
  always_comb begin
    unique case (pst)
      IDLE: begin
        nst = (i_tx_mac_str) ? SEND_FRAME : IDLE;
      end
      SEND_FRAME: begin
        nst = (last_byte_pulse) ? TRANS_DONE : SEND_FRAME;
      end
      TRANS_DONE: begin
        nst = (i_tx_phy_ready) ? IDLE : TRANS_DONE;
      end
      default: nst = IDLE;
    endcase
  end

  //OPERATION BLOCK
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      o_tx_phy_str <= 1'b0;
      last_byte_pulse <= 1'b0;
      o_tx_mac_done <= 1'b0;
      byte_index <= 32'd1;
      frame_to_send <= '0;
      o_tx_phy_vec <= '0;
    end else begin
      case (nst)
        IDLE: begin
          frame_to_send <= i_tx_mac_vec;
          o_tx_phy_vec <= 8'h00;
          byte_index <= 32'd1;
          o_tx_mac_done <= 1'b0;
          o_tx_phy_str <= 1'b0;
        end
        SEND_FRAME: begin
          if (i_tx_phy_done || pst == IDLE) o_tx_phy_str <= 1'b1;
          else o_tx_phy_str <= 1'b0;

          if (i_tx_phy_done && byte_index == 32'd29) begin
            last_byte_pulse <= 1'b1;
          end else begin
            last_byte_pulse <= 1'b0;
          end

          if (i_tx_phy_done) begin
            byte_index <= byte_index + 1;
            frame_to_send <= frame_to_send << BYTE_LEN;
            o_tx_phy_vec <= frame_to_send[MAX_FRAME_LEN-1 : MAX_FRAME_LEN-BYTE_LEN];
          end

        end
        TRANS_DONE: begin
          o_tx_phy_str <= 1'b0;
          last_byte_pulse <= 1'b0;
          o_tx_mac_done <= 1'b1;
        end
        default: begin
          o_tx_phy_str <= 1'b0;
          last_byte_pulse <= 1'b0;
          byte_index <= 32'd1;
          o_tx_mac_done <= 1'b0;
          o_tx_phy_vec <= '0;
        end
      endcase
    end
  end

  // CNT RGF
  generic_cnt_r bytes_transmited_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) bytes_transmited_cnt <= '0;
    else if (o_tx_mac_done) bytes_transmited_cnt <= bytes_transmited_cnt + 1;
  end

  assign o_r_reg_data = bytes_transmited_cnt;


endmodule
