`timescale 1ns/1ps
`include "top_pkg.svh"


module rst_sync_pll (
    input logic clk_100M,
    input logic rst_n,
    output logic rst_n_sync_clk100M,
    output logic rst_n_sync_sys_clk,
    output logic wiz_clk_0_locked,
    output logic sys_clk
);
    
logic wiz_clk;
logic rst_n_sync_wiz_clk;

// SYNC RST_N FOR THE PLL CLK IN
rst_n_sync rst_n_sync_clk100M_inst(
.clk(clk_100M),
.rst_n(rst_n),
.rst_n_sync(rst_n_sync_clk100M)
);

// SYNC RST_N FOR THE SYS CLK
rst_n_sync rst_n_sync_sys_clk_inst(
.clk(sys_clk),
.rst_n(rst_n),
.rst_n_sync(rst_n_sync_sys_clk)
);

// SYNC RST_N FOR THE SYS CLK
rst_n_sync rst_n_sync_wiz_clk_inst(
.clk(wiz_clk),
.rst_n(rst_n),
.rst_n_sync(rst_n_sync_wiz_clk)
);

// clk_mux clk_mux_inst(
//     .clk_1(clk_100M),
//     .clk_2(wiz_clk),
//     .rst_n1(rst_n_sync_clk100M),
//     .rst_n2(rst_n_sync_wiz_clk),
//     .sel(wiz_clk_0_locked),
//     .clk_out(sys_clk)
// );
// assign rst_n_sync_sys_clk_locked = wiz_clk_0_locked && rst_n_sync_sys_clk;

BUFGMUX bufgmux_inst(
    .I0(clk_100M),       // Default Clock (Slow/Safe)
    .I1(wiz_clk),        // PLL Clock
    .S (wiz_clk_0_locked), // Select PLL when locked
    .O (sys_clk)
);

clk_wiz_0 clk_wiz_0_inst(
 .clk_out1(wiz_clk),
 .resetn(rst_n_sync_clk100M),
 .locked(wiz_clk_0_locked),
 .clk_in1(clk_100M)
);

endmodule