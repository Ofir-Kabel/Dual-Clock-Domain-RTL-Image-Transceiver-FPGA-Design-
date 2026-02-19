`timescale 1ns / 1ps
`include "top_pkg.svh"


module rst_n_sync (
    input logic clk,
    input logic rst_n,
    output  logic rst_n_sync
);

  (* ASYNC_REG = "TRUE" *) logic ff0_sync;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ff0_sync   <= 0;
      rst_n_sync <= 0;
    end else begin
      ff0_sync   <= 1;
      rst_n_sync <= ff0_sync;
    end
  end

endmodule
