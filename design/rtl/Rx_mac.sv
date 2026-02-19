`timescale 1ns / 1ns
`include "top_pkg.svh"

module Rx_mac (
    input logic clk,
    input logic rst_n,

    output logic [            31:0] r_data,      // Statistics: Valid frames count
    output logic [TX_FRAME_LEN-1:0] frame_data,  // Aligned to MSB
    output logic                    rx_mac_done,

    input logic rx_phy_done,
    input logic cmd_ack,
    //input logic rx_phy_err,
    input logic rx_mac_str,
    input logic [7:0] rx_vec
);

  // FSM States
  typedef enum logic [1:0] {
    IDLE,
    CHECK_START, // Verify if the first byte is '{'
    PAYLOAD,     // Receive data (Binary or Text) until '}'
    END_FRAME
  } rx_mac_state_t;

  rx_mac_state_t pst, nst;

  // -----------------------------------------------------------
  // 1. Write Pointer & Buffer Logic (The Solution)
  // -----------------------------------------------------------
  // 'write_ptr' points to the MSB of the current byte slot.
  // It starts at the top and decrements by 8.
  int write_ptr;
  logic [TX_FRAME_LEN-1:0] temp_frame_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      temp_frame_reg <= '0;
      write_ptr <= TX_FRAME_LEN - 1;
    end else begin

      // --- Reset / Clear Logic ---
      // When a new start bit is detected in IDLE, clear the buffer.
      // This ensures "padding" with zeros for short messages.
      if (pst == IDLE && rx_mac_str) begin
        temp_frame_reg <= '0;
        write_ptr <= TX_FRAME_LEN - 1;  // Reset pointer to Top (MSB)
      end  // --- Write Logic ---
      else if (rx_phy_done) begin
        // SystemVerilog Slice Syntax: [start_bit -: width]
        // Write the received byte exactly where the pointer is
        temp_frame_reg[write_ptr-:8] <= rx_vec; //(!rx_phy_err)? rx_vec : '0;

        // Move pointer down for the next byte (if not underflow)
        if (write_ptr >= 7) write_ptr <= write_ptr - 8; //(!rx_phy_err)? write_ptr - 8 : write_ptr;
      end
    end
  end

  //============================================================
logic [3:0] end_byte_cnt;  // Counts bytes received after detecting '}' to know when to stop accepting data
logic end_frame;

    always_ff @( posedge clk or negedge rst_n ) begin
    if(!rst_n) end_byte_cnt <= 0;
    else if (pst == PAYLOAD && rx_phy_done) end_byte_cnt <= end_byte_cnt + 1;
    else if (pst == IDLE) end_byte_cnt <= 0;  
end

assign end_frame = (end_byte_cnt == 4) || (end_byte_cnt == 9) || (end_byte_cnt == 14);  

  //============================================================

  // -----------------------------------------------------------
  // 2. FSM Logic
  // -----------------------------------------------------------

  // Present State
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) pst <= IDLE;
    else pst <= nst;
  end

  // Next State Logic
  always_comb begin : NST_BLOCK
    nst = pst;  // Default

    unique case (pst)
      IDLE: begin
        if (rx_mac_str) nst = CHECK_START;
      end

      CHECK_START: begin
        if (rx_phy_done) begin
          // Must start with '{'
          if (rx_vec == OPEN_FRAME_ASCII) nst = PAYLOAD;
          else nst = IDLE;  // Noise or invalid start
        end
      end

      PAYLOAD: begin
        if (rx_phy_done) begin
          //if rx_phy_err than go back to IDLE?
          if (rx_vec == CLOSE_FRAME_ASCII && end_frame) begin
            nst = END_FRAME;
          end 
          else begin
            nst = PAYLOAD;
          end
        end
      end

      END_FRAME: begin
        nst = IDLE;
      end

      default: nst = IDLE;
    endcase
  end

  // -----------------------------------------------------------
  // 3. Outputs
  // -----------------------------------------------------------

  // Update output only when frame is complete
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) frame_data <= '0;
    else if(cmd_ack) frame_data <= '0;
    else if (pst == END_FRAME) frame_data <= temp_frame_reg;
        
  end

  // Done signal
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) rx_mac_done <= 0;
    else if (pst == END_FRAME) rx_mac_done <= 1;
    else rx_mac_done <= 0;
  end

  // Frame Counter (Statistics)
  generic_cnt_t bytes_recived_cnt;  // Assuming this module exists in your project

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) bytes_recived_cnt <= '0;
    else if (rx_mac_done) bytes_recived_cnt <= bytes_recived_cnt + 1;
  end

  assign r_data = bytes_recived_cnt;

endmodule
