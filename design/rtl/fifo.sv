`timescale 1ns / 1ps

// import defs_pkg::*;
// import top_pkg::*;

`include "top_pkg.svh"

module fifo (
    input logic clk,
    input logic rst_n,

    input logic push,
    input logic pop,
    input logic [31:0] i_data,
    output logic [31:0] o_data,

    output logic o_empty,
    output logic o_full,
    output logic o_half_full,
    output logic o_almost_empty,
    output logic o_almost_full,

    input logic wr_en,
    input logic sel_fifo_r,
    input logic [BYTE_LEN-1:0] addr_low,
    input logic [31:0] w_data,
    output logic [31:0] r_data
);

  localparam FIFO_LEN = 32;
  localparam FIFO_DEPTH = 16;
  localparam FIFO_ADDR_LEN = $clog2(FIFO_DEPTH);

  logic [FIFO_LEN-1:0] fifo[0:FIFO_DEPTH-1];

  // Pointers
  logic [FIFO_ADDR_LEN:0] w_pointer;
  logic [FIFO_ADDR_LEN:0] r_pointer;

  logic [FIFO_ADDR_LEN-1:0] af_tresh;
  logic [FIFO_ADDR_LEN-1:0] ae_tresh;

  logic wait_write;

  //-------------------------------------------
  // BIT DEFINITIONS (NO STRUCTS)
  //-------------------------------------------
  localparam FIFO_CTRL_ADDR = 0;

  // Bit positions for FIFO Control Register
  // localparam BIT_AF_MOD = 1;
  // localparam BIT_AE_MOD = 0;

  // Register defined as a simple vector
  fifo_ctrl_t fifo_ctrl_r , fifo_ctrl_r_v;

  //-------------------------------------------
  // FLAGS & THRESHOLDS LOGIC
  //-------------------------------------------
  logic [FIFO_ADDR_LEN:0] fifo_count;
  assign fifo_count = w_pointer - r_pointer;

  assign o_empty = (w_pointer == r_pointer);
  assign o_full = (w_pointer[FIFO_ADDR_LEN] != r_pointer[FIFO_ADDR_LEN]) && (w_pointer[FIFO_ADDR_LEN-1:0] == r_pointer[FIFO_ADDR_LEN-1:0]);

  assign o_half_full = (fifo_count >= (FIFO_DEPTH >> 1));
  assign o_almost_empty = (fifo_count <= ae_tresh);
  assign o_almost_full = (fifo_count >= (FIFO_DEPTH - af_tresh)) || wait_write;

  // always_comb begin : THRESHOLDS_DEFINE_BLOCK
  //   // Using Bit Slicing instead of .af_mod
  //   case (fifo_ctrl_r[BIT_AF_MOD])
  //     1'b0: af_tresh = (FIFO_DEPTH - 1) >> 1;
  //     1'b1: af_tresh = ((FIFO_DEPTH - 1) >> 1) + ((FIFO_DEPTH - 1) >> 2);
  //     default: af_tresh = (FIFO_DEPTH - 1) >> 1;
  //   endcase

  //   // Using Bit Slicing instead of .ae_mod
  //   case (fifo_ctrl_r[BIT_AE_MOD])
  //     1'b0: ae_tresh = ((FIFO_DEPTH - 1) >> 1) - ((FIFO_DEPTH - 1) >> 2);
  //     1'b1: ae_tresh = ((FIFO_DEPTH - 1) >> 2) - ((FIFO_DEPTH - 1) >> 3);
  //     default: ae_tresh = (FIFO_DEPTH - 1) >> 1;
  //   endcase
  // end

    always_comb begin : THRESHOLDS_DEFINE_BLOCK
    // Using Bit Slicing instead of .af_mod
    case (fifo_ctrl_r.af_mod)
      1'b0: af_tresh = (FIFO_DEPTH - 1) >> 1;
      1'b1: af_tresh = ((FIFO_DEPTH - 1) >> 1) + ((FIFO_DEPTH - 1) >> 2);
      default: af_tresh = (FIFO_DEPTH - 1) >> 1;
    endcase

    // Using Bit Slicing instead of .ae_mod
    case (fifo_ctrl_r.ae_mod)
      1'b0: ae_tresh = ((FIFO_DEPTH - 1) >> 1) - ((FIFO_DEPTH - 1) >> 2);
      1'b1: ae_tresh = ((FIFO_DEPTH - 1) >> 2) - ((FIFO_DEPTH - 1) >> 3);
      default: ae_tresh = (FIFO_DEPTH - 1) >> 1;
    endcase
  end

  //---------------------------------------
  // REGISTER WRITE LOGIC
  //---------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fifo_ctrl_r <= '0;
    end else if (wr_en && sel_fifo_r) begin
      if (addr_low == FIFO_CTRL_ADDR) begin
        // Writing to specific bits
        // fifo_ctrl_r[BIT_AF_MOD] <= w_data[BIT_AF_MOD];
        // fifo_ctrl_r[BIT_AE_MOD] <= w_data[BIT_AE_MOD];
        fifo_ctrl_r.reserved = '0;
        fifo_ctrl_r.af_mod <= fifo_ctrl_r_v.af_mod;
        fifo_ctrl_r.ae_mod <= fifo_ctrl_r_v.ae_mod;
      end
    end
  end

  assign fifo_ctrl_r_v = w_data;
  assign r_data = fifo_ctrl_r;

  //---------------------------------------
  // FIFO BUFFER LOGIC
  //---------------------------------------


  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wait_write <= '0;
    end else begin
      if (o_almost_full) wait_write <= 1'b1;
      else if (fifo_count <= ae_tresh) wait_write <= 1'b0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      o_data <= '0;
      r_pointer <= '0;
      w_pointer <= '0;
    end else begin
      if (pop && !o_empty) begin
        o_data <= fifo[r_pointer[FIFO_ADDR_LEN-1:0]];
        r_pointer <= r_pointer + 1;
      end
      if (push && !o_full && !wait_write) begin
        fifo[w_pointer[FIFO_ADDR_LEN-1:0]] <= i_data;
        w_pointer <= w_pointer + 1;
      end
    end
  end

int i;
  initial begin
    for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
      fifo[i] = '0;
    end
  end

endmodule
