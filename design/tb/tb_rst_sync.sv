`timescale 1ns / 1ps

module tb_rst_sync ();

  logic clk_100M;
  logic rst_n;
  logic rst_n_sync_clk100M;
  logic rst_n_sync_sys_clk;
  logic sys_clk;

  rst_sync_pll dut (
      .clk_100M(clk_100M),
      .rst_n(rst_n),
      .rst_n_sync_clk100M(rst_n_sync_clk100M),
      .rst_n_sync_sys_clk(rst_n_sync_sys_clk),
      .sys_clk(sys_clk)
  );

  initial begin
    clk_100M = 0;
    forever begin
      #5 clk_100M = ~clk_100M;
    end
  end

  initial begin
    rst_n = 0;
    #100;
    rst_n = 1;
    #2000;
    $finish;
  end


endmodule  //tb_rst_sync
