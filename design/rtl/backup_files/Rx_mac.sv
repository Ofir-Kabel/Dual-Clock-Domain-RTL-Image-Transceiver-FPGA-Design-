`timescale 1ns / 1ns
import defs_pkg::*;

module Rx_mac (
    input logic clk,
    input logic rst_n,
    
    output logic [31:0] r_data,             // Statistics: Valid frames count
    output logic [MAX_FRAME_LEN-1:0] frame_data, // Aligned to MSB
    output logic rx_mac_done,

    input logic rx_phy_done,
    input logic rx_mac_str,
    input logic [7:0] rx_vec
);

  // ASCII Constants
  localparam OPEN_FRAME_ASCII  = 8'h7B; // '{'
  localparam CLOSE_FRAME_ASCII = 8'h7D; // '}'

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
  logic [MAX_FRAME_LEN-1:0] temp_frame_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        temp_frame_reg <= '0;
        write_ptr <= MAX_FRAME_LEN - 1;
    end else begin
        
        // --- Reset / Clear Logic ---
        // When a new start bit is detected in IDLE, clear the buffer.
        // This ensures "padding" with zeros for short messages.
        if (pst == IDLE && rx_mac_str) begin
            temp_frame_reg <= '0;
            write_ptr <= MAX_FRAME_LEN - 1; // Reset pointer to Top (MSB)
        end 
        
        // --- Write Logic ---
        else if (rx_phy_done) begin
            // SystemVerilog Slice Syntax: [start_bit -: width]
            // Write the received byte exactly where the pointer is
            temp_frame_reg[write_ptr -: 8] <= rx_vec;
            
            // Move pointer down for the next byte (if not underflow)
            if (write_ptr >= 7) 
                write_ptr <= write_ptr - 8;
        end
    end
  end

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
    nst = pst; // Default

    unique case (pst)
      IDLE: begin
        if (rx_mac_str) nst = CHECK_START;
      end

      CHECK_START: begin
        if (rx_phy_done) begin
            // Must start with '{'
            if (rx_vec == OPEN_FRAME_ASCII) nst = PAYLOAD;
            else nst = IDLE; // Noise or invalid start
        end
      end

      PAYLOAD: begin
        if (rx_phy_done) begin
            // Stop condition: '}'
            if (rx_vec == CLOSE_FRAME_ASCII) begin
                nst = END_FRAME;
            end
            // Otherwise stay in PAYLOAD to receive next byte
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
    else if (pst == END_FRAME) begin
        // temp_frame_reg holds the data aligned to MSB (due to the pointer logic)
        // Unused bits are '0' (due to the clear logic in IDLE)
        frame_data <= temp_frame_reg; 
    end
  end

  // Done signal
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) rx_mac_done <= 0;
    else if (pst == END_FRAME) rx_mac_done <= 1;
    else rx_mac_done <= 0;
  end

  // Frame Counter (Statistics)
  generic_cnt_r bytes_recived_cnt; // Assuming this module exists in your project

  always_ff @(posedge clk or negedge rst_n) begin
     if (!rst_n)
         bytes_recived_cnt <= '0;
     else if (rx_mac_done)
         bytes_recived_cnt <= bytes_recived_cnt + 1; 
  end

  assign r_data = bytes_recived_cnt;

endmodule