`timescale 1ns / 1ps

`include "top_pkg.svh"

module mux_sync #(
    parameter int DATA_WIDTH = 32
) (
    input logic from_clk,
    input logic to_clk,
    input logic from_rst_n,
    input logic to_rst_n,
    input logic en,
    input logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout
);

  logic [DATA_WIDTH-1:0] data_q;
  always_ff @(posedge from_clk or negedge from_rst_n) begin 
    if (!from_rst_n) data_q <= '0;
    else data_q <= din;
  end

  logic q0, q1, q2;
  always_ff @(posedge from_clk or negedge from_rst_n) begin 
    if (!from_rst_n) q0 <= '0;
    else q0 <= en;
  end

  always_ff @(posedge to_clk or negedge to_rst_n) begin 
    if (!to_rst_n) begin
      q1 <= 0;
      q2 <= 0;
    end else begin
      q1 <= q0;
      q2 <= q1;
    end
  end

  always_ff @(posedge to_clk or negedge to_rst_n) begin 
    if (!to_rst_n) dout <= 0;
    else dout <= (q2) ? data_q : dout;

  end

endmodule  //mux_sync
