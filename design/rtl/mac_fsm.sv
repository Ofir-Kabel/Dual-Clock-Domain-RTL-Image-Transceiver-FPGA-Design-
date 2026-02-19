`timescale 1ns / 1ns

import defs_pkg::*;

module mac_fsm (
    input logic clk,
    input logic rst_n,
    input logic byte_done,
    input logic str_frame,
    input logic [7:0] rx_vec,
    output logic [MAX_FRAME_LEN-1:0] frame_data,
    output logic frame_done
);

  //DATA INDICATORS PARAMS
  localparam LOW_ASCII_LETTER = 'h41;
  localparam HIGH_ASCII_LETTER = 'h5A;
  localparam LOW_ASCII_NUMBER = 'h30;
  localparam HIGH_ASCII_NUMBER = 'h39;
  localparam OPEN_FRAME_ASCII = 'h7B;
  localparam CLOSE_FRAME_ASCII = 'h7D;
  localparam SEPERATE_ASCII = 'h2C;

  // FSM states
  typedef enum logic [2:0] {
    IDLE,
    STR_FRAME,
    LETTER,
    DATA,
    COMMA_or_END_FRAME,
    END_FRAME
  } state_t;
  state_t pst, nst;

  //REGISTERS
  logic [MAX_FRAME_LEN-1:0] temp_frame_reg;
  logic [1:0] byte_data_count;
  logic data_valid;

  //-----------------------------------
  //
  //              FSM STATES
  //
  //-----------------------------------

  //PRESENT STATE BLOCK
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) pst <= IDLE;
    else pst <= nst;
  end


  //NEXT STATE BLOCK
  logic frame_err;


  always_comb begin : NST_BLOCK

    unique case (pst)
      IDLE: begin
        nst = (str_frame) ? STR_FRAME : IDLE;
      end
      STR_FRAME: begin
        if (byte_done && data_valid) begin
          nst = (rx_vec == OPEN_FRAME_ASCII) ? LETTER : IDLE;
          frame_err = (rx_vec == OPEN_FRAME_ASCII) ? 1'b0 : 1'b1;
        end else begin
          nst = STR_FRAME;
          frame_err = 1'b0;
        end
      end
      LETTER: begin
        if (byte_done) begin
          nst = (LOW_ASCII_LETTER <= rx_vec && rx_vec <= HIGH_ASCII_LETTER) ? DATA : IDLE;
          frame_err = (LOW_ASCII_LETTER <= rx_vec && rx_vec <= HIGH_ASCII_LETTER) ? 1'b0 : 1'b1;
        end else begin
          nst = DATA;
          frame_err = 1'b0;
        end
      end
      DATA: begin
        if (byte_done && data_valid) begin
          nst = (byte_data_count == 2) ? COMMA_or_END_FRAME : DATA;
          frame_err = 0;
        end else begin
          nst = DATA;
          frame_err = 1'b0;
        end
      end
      COMMA_or_END_FRAME: begin
        if (byte_done) begin
          if(rx_vec == SEPERATE_ASCII) begin
            nst = LETTER;
            frame_err = 0;
          end else if (rx_vec == CLOSE_FRAME_ASCII) begin
            nst = END_FRAME;
            frame_err = 0;
          end else begin
            nst = IDLE;
            frame_err = 1;
          end
        end else begin
          nst = COMMA_or_END_FRAME;
          frame_err = 0;
        end
      end
      END_FRAME: begin
        nst = IDLE;
        frame_err = 0;
      end
      default: begin
        nst = IDLE;
        frame_err = 0;
      end
    endcase
  end

  //--------------------------------------------
  
  //DATA THREE VALUES BLOCK
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) byte_data_count <= 0;
    else if (pst == DATA && byte_done && data_valid) begin
      byte_data_count <= byte_data_count + 1;
    end else if (pst != DATA) begin
      byte_data_count <= 0;
    end
  end
  //--------------------------------------------

  //DATA VALID BLOCK
  always_comb begin
    if (!rst_n) data_valid = 1;
    else begin
      unique case (pst)
        LETTER: data_valid = (LOW_ASCII_LETTER <= rx_vec && rx_vec <= HIGH_ASCII_LETTER) ? 1'b1 : 1'b0;
        DATA: data_valid = (LOW_ASCII_NUMBER <= rx_vec && rx_vec <= HIGH_ASCII_NUMBER) ? 1'b1 : 1'b0;
        COMMA_or_END_FRAME: data_valid = (rx_vec == SEPERATE_ASCII || rx_vec == CLOSE_FRAME_ASCII) ? 1'b1 : 1'b0;
        default: data_valid = 1;
      endcase
    end
  end
  //--------------------------------------------

  //TEMP FRAME REGISTER BLOCK
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      temp_frame_reg <= '0;
    end else if (nst == IDLE) begin
      temp_frame_reg <= '0;
    end else if (byte_done) begin
      temp_frame_reg <= {temp_frame_reg, rx_vec};
    end else
      temp_frame_reg <= temp_frame_reg;
  end
  //--------------------------------------------

  //OUTPUT FRAME BLOCK
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      frame_data   <= '0;
    end else if (nst == END_FRAME) begin
      frame_data   <= {temp_frame_reg,rx_vec};
    end else begin
      frame_data   <= frame_data;
    end
  end

  //---------------------------------------------

  //OUTPUT DONE FRAME BLOCK
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) frame_done <= 0;
    else if (nst == END_FRAME && byte_done) frame_done <= 1;
    else frame_done <= 0;
  end


endmodule
