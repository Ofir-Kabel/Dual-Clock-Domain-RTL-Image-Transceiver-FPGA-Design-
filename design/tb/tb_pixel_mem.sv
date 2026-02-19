`timescale 1ns / 1ps

module tb_pixel_mem;

  // 01/15/26 - 10:20
  parameter DATA_WIDTH = 8;

  logic clk;
  logic rst_n;
  logic i_almost_full;
  logic [9:0] i_img_size;

  logic [4*DATA_WIDTH-1:0] o_red_data;
  logic [4*DATA_WIDTH-1:0] o_green_data;
  logic [4*DATA_WIDTH-1:0] o_blue_data;
  logic pixel_pkt_load;
  logic o_done;

  pixel_mem #(
      .DATA_WIDTH(DATA_WIDTH)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .i_almost_full(i_almost_full),
      .o_red_data(o_red_data),
      .o_green_data(o_green_data),
      .o_blue_data(o_blue_data),
      .pixel_pkt_load(pixel_pkt_load),
      .o_done(o_done)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 0;
    i_almost_full = 0;
    i_img_size = 16;

    #20;
    rst_n = 1;
    #500;
    i_almost_full = 1;
    #500;
    i_almost_full = 0;
    #5000;
    $finish;
  end

endmodule
