`timescale 1ns/1ps


module rst_sync_pll (
    input logic clk_100M,
    input logic rst_n,
    output logic rst_n_sync_sys_clk_locked,
    output logic sys_clk
);
    
logic rst_n_sync_clk100M;
logic rst_n_sync_clk_pll;

logic pll_locked;
logic rst_n_pll_en;

// SYNC RST_N FOR THE PLL CLK IN
rst_n_sync rst_n_sync_clk100M_inst(
.clk(clk_100M),
.rst_n(rst_n),
.rst_n_sync(rst_n_sync_clk100M)
);

// rst_n_sync rst_n_sync_clk_pll_inst(
// .clk(sys_clk),
// .rst_n(rst_n),
// .rst_n_sync(rst_n_sync_clk_pll)
// );

// SYNC RST_N FOR THE SYS CLK
rst_n_sync rst_n_sync_sys_clk_inst(
.clk(sys_clk),
.rst_n(rst_n),
.rst_n_sync(rst_n_sync_sys_clk)
);

// PLL SYS CLK
pll pll_int(
.sys_clk(sys_clk),
 .resetn(rst_n_sync_clk100M),
 .locked(pll_locked),
 .clk_in1(clk_100M)
);

assign rst_n_sync_sys_clk_locked = pll_locked && rst_n_sync_sys_clk;
endmodule