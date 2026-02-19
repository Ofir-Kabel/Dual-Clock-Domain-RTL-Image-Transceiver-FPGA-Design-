`timescale 1ns / 1ps

`include "top_pkg.svh"

module fifo_async(
    input logic clk,
    input logic rst_n,

    input logic r_clk,
    input logic r_rst_n,

    input logic w_clk,
    input logic w_rst_n,

    // input logic img_ready,
    input logic push,
    input logic pop,
    input logic [FIFO_WIDTH-1:0] i_data,
    output logic [FIFO_WIDTH-1:0] o_data,

    output logic o_empty_r,
    output logic o_full_w,
    output logic o_half_full,
    output logic o_almost_empty_r,
    output logic o_almost_full_w,

    input logic wr_en,
    input logic sel_fifo_r,
    input logic [BYTE_LEN-1:0] addr_low,
    input logic [WORD_WIDTH-1:0] w_data,
    output logic [WORD_WIDTH-1:0] r_data
);

  // LOCALPARAMS
  localparam PTR_WIDTH = $clog2(FIFO_DEPTH);

  //FIFO_MEM
  logic [FIFO_WIDTH-1:0] mem[0:FIFO_DEPTH-1];

  //RGF
  fifo_ctrl_t fifo_ctrl_r, fifo_ctrl_r_v;

  //============================================================
  // REG RW OPERATION AND ASSIGNMENT
  //============================================================

  //WRITING
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fifo_ctrl_r <= '0;
    end else if (wr_en && sel_fifo_r) begin
      if (addr_low == OFFS_FIFO_CTRL) begin
        fifo_ctrl_r.reserved <= '0;
        fifo_ctrl_r.af_mod   <= fifo_ctrl_r_v.af_mod;
        fifo_ctrl_r.ae_mod   <= fifo_ctrl_r_v.ae_mod;

      end
    end
  end

  assign fifo_ctrl_r_v = w_data;
  assign r_data = fifo_ctrl_r;

  //ASSIGNMENT 
  logic [PTR_WIDTH-1:0] af_tresh;
  logic [PTR_WIDTH-1:0] ae_tresh;

  always_comb begin : THRESHOLDS_DEFINE_BLOCK
    case (fifo_ctrl_r.af_mod)
      1'b0: af_tresh = FIFO_DEPTH - 1 - ((FIFO_DEPTH - 1) >> 3);
      1'b1: af_tresh = FIFO_DEPTH - 1 - (((FIFO_DEPTH - 1) >> 4));
      default: af_tresh = FIFO_DEPTH - 1 - ((FIFO_DEPTH - 1) >> 3);
    endcase

    case (fifo_ctrl_r.ae_mod)
      1'b0: ae_tresh = ((FIFO_DEPTH - 1) >> 3);
      1'b1: ae_tresh = ((FIFO_DEPTH - 1) >> 4);
      default: ae_tresh = ((FIFO_DEPTH - 1) >> 3);
    endcase
  end

  //============================================================
  // GRAY <=> BIN FUNCTIONS
  //============================================================

  function automatic logic [PTR_WIDTH-1:0] bin2gray(input logic [PTR_WIDTH-1:0] bin);
    return bin ^ (bin >> 1);
  endfunction

  function automatic logic [PTR_WIDTH-1:0] gray2bin(input logic [PTR_WIDTH-1:0] gray);
    logic [PTR_WIDTH-1:0] bin;
    bin[PTR_WIDTH-1] = gray[PTR_WIDTH-1];
    for (int i = PTR_WIDTH - 2; i >= 0; i--) begin
      bin[i] = gray[i] ^ bin[i+1];
    end
    return bin;
  endfunction

  //---------------------------------------
  // FIFO BUFFER LOGIC
  //---------------------------------------


  // ============================================================
  // SECTION 1: WRITE DOMAIN (w_clk)
  // ============================================================
  logic [PTR_WIDTH:0] w_ptr_bin, w_ptr_gray;
  logic [PTR_WIDTH:0] r_ptr_gray_sync;  // Read ptr synced to Write clk

  always_ff @(posedge w_clk or negedge w_rst_n) begin
    if (!w_rst_n) begin
      w_ptr_bin  <= '0;
      w_ptr_gray <= '0;
    end else if (push) begin
      w_ptr_bin <= w_ptr_bin + 1;
      w_ptr_gray <= bin2gray(w_ptr_bin + 1);
    end
  end

  // always_ff @(posedge w_clk or negedge w_rst_n) begin
  //   if (!w_rst_n) begin
  //     w_ptr_bin  <= '0;
  //     w_ptr_gray <= '0;
  //   end else if (push) begin
  //     w_ptr_bin <= w_ptr_bin + 1;
  //     w_ptr_gray <= bin2gray(w_ptr_bin + 1);
  //   end else if(img_ready) begin
  //     w_ptr_bin <= '0;
  //     w_ptr_gray <= '0;
  //   end
  // end

  //different block to ensure vivado choose to use BRAM for mem
  always_ff @(posedge w_clk) begin
      if (push) begin
      mem[w_ptr_bin[PTR_WIDTH-1:0]] <= i_data;
    end
  end


  // ============================================================
  // SECTION 2: READ DOMAIN (r_clk)
  // ============================================================
  logic [PTR_WIDTH:0] r_ptr_bin, r_ptr_gray;
  logic [PTR_WIDTH:0] w_ptr_gray_sync;  // Write ptr synced to Read clk

  always_ff @(posedge r_clk or negedge r_rst_n) begin
    if (!r_rst_n) begin
      r_ptr_bin  <= '0;
      r_ptr_gray <= '0;
      o_data     <= '0;
    end else if (pop && !o_empty_r) begin
      o_data     <= mem[r_ptr_bin[PTR_WIDTH-1:0]];
      r_ptr_bin  <= r_ptr_bin + 1;
      r_ptr_gray <= bin2gray(r_ptr_bin + 1);
    end 
  end

  // always_ff @(posedge r_clk or negedge r_rst_n) begin
  //   if (!r_rst_n) begin
  //     r_ptr_bin  <= '0;
  //     r_ptr_gray <= '0;
  //     o_data     <= '0;
  //   end else if (pop && !o_empty_r) begin
  //     o_data     <= mem[r_ptr_bin[PTR_WIDTH-1:0]];
  //     r_ptr_bin  <= r_ptr_bin + 1;
  //     r_ptr_gray <= bin2gray(r_ptr_bin + 1);
  //   end else if (img_ready) begin
  //     r_ptr_bin  <= '0;
  //     r_ptr_gray <= '0;
  //   end
  // end

  //---------------------------------------
  // SYNC 2DFF - READ + LOGIC FLAGS
  //---------------------------------------

  // assign w_ptr_gray = bin2gray(w_ptr_bin);
  // assign r_ptr_gray = bin2gray(r_ptr_bin);

  //R - SYNC
  logic [PTR_WIDTH:0] w_gray_meta;
  always_ff @(posedge r_clk or negedge r_rst_n) begin
    if (!r_rst_n) {w_ptr_gray_sync, w_gray_meta} <= '0;
    else {w_ptr_gray_sync, w_gray_meta} <= {w_gray_meta, w_ptr_gray};
  end

    //W - SYNC
  logic [PTR_WIDTH:0] r_gray_meta;
  always_ff @(posedge w_clk or negedge w_rst_n) begin
    if (!w_rst_n) {r_ptr_gray_sync, r_gray_meta} <= '0;
    else {r_ptr_gray_sync, r_gray_meta} <= {r_gray_meta, r_ptr_gray};
  end


  //-------------------------------------------
  // FLAGS & THRESHOLDS LOGIC
  //-------------------------------------------

  logic [PTR_WIDTH:0] w_ptr_bin_sync;
  logic [PTR_WIDTH:0] r_ptr_bin_sync;

  assign w_ptr_bin_sync = gray2bin(w_ptr_gray_sync);
  assign r_ptr_bin_sync = gray2bin(r_ptr_gray_sync);

  logic wait_write;
  logic [PTR_WIDTH:0] count_r;
  logic [PTR_WIDTH:0] count_w;

  logic [PTR_WIDTH:0] count;

assign count = w_ptr_bin - r_ptr_bin;

  assign count_r          = w_ptr_bin_sync - r_ptr_bin;
  assign o_almost_empty_r = (count < ae_tresh);
  assign o_half_full      = (count >= (FIFO_DEPTH / 2));

  assign count_w = w_ptr_bin - r_ptr_bin_sync;
  assign o_almost_full_w = (count >= (af_tresh) || wait_write);

  assign o_empty_r = (r_ptr_gray == w_ptr_gray_sync);
  assign o_full_w  = (w_ptr_gray == {~r_ptr_gray_sync[PTR_WIDTH:PTR_WIDTH-1], 
                                      r_ptr_gray_sync[PTR_WIDTH-2:0]});

  always_ff @(posedge w_clk or negedge w_rst_n) begin
    if (!w_rst_n) begin
      wait_write <= 0;
    end else begin
      if (o_almost_empty_r) wait_write <= 1'b0;
      else if (o_almost_full_w) wait_write <= 1'b1;
    end
  end



endmodule
