`timescale 1ns / 1ps
`include "top_pkg.svh"

module clk_mux(
    input  logic clk_1,
    input  logic clk_2,
    input  logic rst_n1,
    input  logic rst_n2,
    input  logic sel,
    output logic clk_out
);

  logic ff0_clk1;
  logic ff0_clk2;

  logic sync1_o;
  logic sync2_o;

  logic and_sync_1_o;
  logic and_sync_2_o;


  always_ff @(posedge clk_1 or negedge rst_n1) begin : CLK_1_SYNC
    if (!rst_n1) begin
      ff0_clk1 <= 0;
      sync1_o <= 0;
    end else begin
      ff0_clk1 <= !sel && !sync2_o;
      sync1_o <= ff0_clk1;
    end
  end

  always_ff @(posedge clk_2 or negedge rst_n2) begin : CLK_2_SYNC
    if (!rst_n2) begin
      ff0_clk2 <= 0;
      sync2_o <= 0;
    end else begin
      ff0_clk2 <= sel && !sync1_o;
      sync2_o <= ff0_clk2;
    end
  end

  assign and_sync_1_o = (clk_1 && sync1_o);
  assign and_sync_2_o = (clk_2 && sync2_o);

  assign clk_out = and_sync_1_o || and_sync_2_o;
// BUFGMUX #(
//       .CLK_SEL_TYPE("ASYNC") 
//    ) BUFGMUX_inst (
//       .O(clk_out), 
//       .I0(clk_1), 
//       .I1(clk_2), 
//       .S(sel)
//    );

endmodule

