`timescale 1ns / 1ps
`include "top_pkg.svh"

module bufgmux(
    input  logic clk_1,
    input  logic clk_2,
    input  logic sel,
    output logic clk_out
);

BUFGMUX #(
      .CLK_SEL_TYPE("ASYNC") 
   ) BUFGMUX_inst (
      .O(clk_out), 
      .I0(clk_1), 
      .I1(clk_2), 
      .S(sel)
   );

endmodule

