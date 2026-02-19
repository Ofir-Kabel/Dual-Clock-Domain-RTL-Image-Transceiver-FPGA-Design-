`timescale 1ns / 1ps

import defs_pkg::*;

module sequencer (
    input logic clk,
    input logic rst_n,

    input logic w_clk,
    input logic w_rst_n,

    input logic r_clk,
    input logic r_rst_n,


    //  RGF - I/O
    input logic wr_en,
    input logic img_sel_r,
    input logic [31:0] w_data,
    output logic [31:0] r_data_fifo,
    output logic [31:0] r_data_img,
    input logic [23:0] addr,

    //  RGF - MSG
    input logic read_cmd,
    input logic [31:0] r_data_msg,

    // TX_MAC
    input logic tx_mac_ready,
    input logic tx_mac_done,
    output logic [TX_FRAME_LEN-1:0] tx_mac_vec,
    output logic tx_mac_str,
    output logic o_rts
);

  //----------------------------------------------------------------
  // BIT DEFINITIONS (NO STRUCTS)
  //----------------------------------------------------------------

  // STATUS REGISTER BIT RANGES
  localparam ST_WIDTH_MSB = 19;
  localparam ST_WIDTH_LSB = 10;
  localparam ST_HEIGHT_MSB = 9;
  localparam ST_HEIGHT_LSB = 0;

  // TX MONITOR REGISTER BIT RANGES
  localparam MON_COL_MSB = 19;
  localparam MON_COL_LSB = 10;
  localparam MON_ROW_MSB = 9;
  localparam MON_ROW_LSB = 0;

  // CTRL REGISTER BIT RANGES
  localparam CTRL_START_BIT = 0;

  // REGISTER ADDRESSES
  localparam R_IMG_STATUS_ADDR = 0;
  localparam R_IMG_TX_MON_ADDR = 4;
  localparam R_IMG_CTRL_ADDR = 8;

  // Registers defined as logic vectors (32-bit)



  img_status_t img_status_r, img_status_r_v;
  img_tx_mon_t img_tx_mon_r, img_tx_mon_r_v;
  img_ctrl_t img_ctrl_r, img_ctrl_r_v;

  //----------------------------------------------------------------
  // INTERNAL SIGNALS & ROM
  //----------------------------------------------------------------
  logic almost_full_w;
  logic rgb_rom_done;
  logic pixel_pkt_load;
  logic [7:0] addr_low;
  assign addr_low = addr[7:0];

  logic [31:0] o_rom_red;
  logic [31:0] o_rom_green;
  logic [31:0] o_rom_blue;

  pixel_mem pixel_mem_inst (
      .clk(clk),
      .rst_n(rst_n),
      .i_almost_full(almost_full_w),
      .pixel_pkt_load(pixel_pkt_load),
      .i_img_size(10'd256),  // Example fixed size
      .o_red_data(o_rom_red),
      .o_green_data(o_rom_green),
      .o_blue_data(o_rom_blue),
      .o_done(rgb_rom_done)
  );

  //----------------------------------------------------------------
  // FIFO INSTANCE & PACKING
  //----------------------------------------------------------------
  logic push;
  logic pop;
  logic [31:0] fifo_dout;
  logic [31:0] fifo_din;
  logic o_full_w, o_half_full, o_almost_empty_r;


  fifo_async fifo_asycn_inst (
      .clk(clk),
      .rst_n(rst_n),
      .r_clk(r_clk),
      .r_rst_n(r_rst_n),
      .w_clk(w_clk),
      .w_rst_n(w_rst_n),
      .push(push),
      .pop(pop),
      .i_data(fifo_din),
      .o_data(fifo_dout),
      .o_empty_r(o_empty_r),
      .o_full_w(o_full_w),
      .o_half_full(o_half_full),
      .o_almost_empty_r(o_almost_empty_r),
      .o_almost_full_w(o_almost_full_w),
      .wr_en(wr_en),
      .sel_fifo_r(fifo_sel_r),
      .addr_low(addr_low),
      .w_data(w_data),
      .r_data(r_data_fifo)
  );

  //   fifo fifo_inst (
  //     .clk(clk),
  //     .rst_n(rst_n),
  //     .push(push),
  //     .pop(pop),
  //     .i_data(fifo_din),
  //     .o_data(fifo_dout),
  //     .o_empty(o_rts),
  //     .o_full_w(o_full_w),
  //     .o_half_full(o_half_full),
  //     .o_almost_empty_r(o_almost_empty_r),
  //     .o_almost_full(almost_full_w),
  //     .wr_en(wr_en),
  //     .sel_fifo_r(img_sel_r),
  //     .addr_low(addr_low),
  //     .w_data(w_data),
  //     .r_data(r_data_fifo)
  // );


  assign o_fifo_data = fifo_dout;

  logic [31:0] i_fifo_red_temp, i_fifo_green_temp, i_fifo_blue_temp;
  assign push = !almost_full_w;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i_fifo_red_temp <= 0;
      i_fifo_green_temp <= 0;
      i_fifo_blue_temp <= 0;
      fifo_din <= 0;
    end else begin
      if (push) begin
        fifo_din <= {
          8'h00, i_fifo_red_temp[31:24], i_fifo_green_temp[31:24], i_fifo_blue_temp[31:24]
        };
      end
      if (pixel_pkt_load) begin
        i_fifo_red_temp   <= o_rom_red;
        i_fifo_green_temp <= o_rom_green;
        i_fifo_blue_temp  <= o_rom_blue;
      end else begin
        i_fifo_red_temp   <= i_fifo_red_temp << 8;
        i_fifo_green_temp <= i_fifo_green_temp << 8;
        i_fifo_blue_temp  <= i_fifo_blue_temp << 8;
      end
    end
  end

  //----------------------------------------------------------------
  // COUNTERS LOGIC (Bit Slicing)
  //----------------------------------------------------------------
  typedef enum logic [1:0] {
    IDLE,
    IMG_MSG,
    RGF_MSG
  } tx_msg_t;
  tx_msg_t pst, nst;

  // always_ff @(posedge clk or negedge rst_n) begin
  //   if (!rst_n) begin
  //     img_tx_mon_r <= '0;
  //   end else if (pst == IMG_MSG && tx_mac_done) begin
  //     if (img_tx_mon_r[MON_COL_MSB:MON_COL_LSB] == img_status_r[ST_HEIGHT_MSB:ST_HEIGHT_LSB] - 1) begin
  //       img_tx_mon_r[MON_COL_MSB:MON_COL_LSB] <= 0;
  //       img_tx_mon_r[MON_ROW_MSB:MON_ROW_LSB] <= img_tx_mon_r[MON_ROW_MSB:MON_ROW_LSB] + 1;
  //     end else begin
  //       img_tx_mon_r[MON_COL_MSB:MON_COL_LSB] <= img_tx_mon_r[MON_COL_MSB:MON_COL_LSB] + 1;
  //     end
  //   end
  // end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      img_tx_mon_r <= '0;
    end else if (pst == IMG_MSG && tx_mac_done) begin
      if (img_tx_mon_r.col == img_status_.height - 1) begin
        img_tx_mon_r.col <= 0;
        img_tx_mon_r.row <= img_tx_mon_r.row + 1;
      end else begin
        img_tx_mon_r.col <= img_tx_mon_r.col + 1;
      end
    end
  end

  //----------------------------------------------------------------
  // REGISTERS & FSM
  //----------------------------------------------------------------
  logic r_img_writing_err, r_img_reading_err;

  always_comb begin
    img_status_r_v = w_data;
    img_ctrl_r_v   = w_data;
    img_tx_mon_r_v = w_data;
  end


  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      img_status_r <= '0;
      img_ctrl_r <= '0;
      r_img_writing_err <= 0;
    end else if (wr_en && img_sel_r) begin
      unique case (addr_low)
        R_IMG_STATUS_ADDR: begin
          img_status_r.reserved <= img_status_r_v.reserved;
          img_status_r.img_ready <= img_status_r_v.img_ready;
          img_status_r.height <= img_status_r_v.height;
          img_status_r.width <= img_status_r_v.width;
        end
        R_IMG_CTRL_ADDR: begin
          img_ctrl_r.reserved <= img_ctrl_r_v.reserved;
          img_ctrl_r.img_read <= img_ctrl_r_v.img_read;
        end
        default: r_img_writing_err <= 1'b1;
      endcase
    end
  end

  always_comb begin
    r_img_reading_err = 1'b0;
    r_data_img = '0;
    if (!wr_en && img_sel_r)
      case (addr_low)
        R_IMG_STATUS_ADDR: r_data_img = img_status_r;
        R_IMG_TX_MON_ADDR: r_data_img = img_tx_mon_r;
        default: r_img_reading_err = 1'b1;
      endcase
  end

  // FSM Next State
  logic img_trans, img_done_trans;

  // assign img_done_trans = (tx_mac_done && 
  //     (img_tx_mon_r[MON_COL_MSB:MON_COL_LSB] == img_status_r[ST_HEIGHT_MSB:ST_HEIGHT_LSB] - 1) && 
  //     (img_tx_mon_r[MON_ROW_MSB:MON_ROW_LSB] == img_status_r[ST_WIDTH_MSB:ST_WIDTH_LSB] - 1));

  assign img_done_trans = (tx_mac_done && (img_tx_mon_r.col == img_status_r.height - 1) && (img_tx_mon_r.row == img_status_r.width - 1));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) pst <= IDLE;
    else pst <= nst;
  end

  always_comb begin
    nst = pst;
    unique case (pst)
      IDLE: begin
        if (read_cmd) nst = RGF_MSG;
        // else if (img_ctrl_r[CTRL_START_BIT]) nst = IMG_MSG; 
        else if (img_ctrl_r.img_read) nst = IMG_MSG;
        else nst = IDLE;
      end
      IMG_MSG: begin
        if (read_cmd) nst = RGF_MSG;
        else if (img_done_trans) nst = IDLE;
        else nst = IMG_MSG;
      end
      RGF_MSG: begin
        if (read_cmd) nst = RGF_MSG;
        else if (img_trans) nst = IMG_MSG;
        else nst = IDLE;
      end
      default: nst = IDLE;
    endcase
  end

  // always_ff @(posedge clk or negedge rst_n) begin
  //   if (!rst_n) img_trans <= 0;
  //   else if (img_ctrl_r[CTRL_START_BIT]) img_trans <= 1;  // Bit Access
  //   else if (img_done_trans) img_trans <= 0;
  // end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) img_trans <= 0;
    else if (img_ctrl_r.img_read) img_trans <= 1;  // Bit Access
    else if (img_done_trans) img_trans <= 0;
  end

  //----------------------------------------------------------------
  // MSG COMPOSER
  //----------------------------------------------------------------
  localparam DATA_HH = 31;
  localparam DATA_HL = 16;
  localparam DATA_LH = 15;
  localparam DATA_LL = 0;

  // assign pop = (tx_mac_done || img_ctrl_r[CTRL_START_BIT]) && !o_rts && (pst == IMG_MSG);

  assign pop = (tx_mac_done || img_ctrl_r.img_read) && !o_rts && (pst == IMG_MSG);

  // always_ff @(posedge clk or negedge rst_n) begin
  //   if (!rst_n) begin
  //     tx_mac_vec <= '0;
  //     tx_mac_str <= 1'b0;
  //   end else begin
  //     tx_mac_str <= 1'b0;
  //     unique case (nst)
  //       IMG_MSG: begin
  //         if (pop) begin
  //           tx_mac_vec <= {
  //             13'd0,
  //             img_tx_mon_r[MON_ROW_MSB:MON_ROW_LSB],
  //             13'd0,
  //             img_tx_mon_r[MON_COL_MSB:MON_COL_LSB],
  //             fifo_dout
  //           };
  //           tx_mac_str <= 1'b1;
  //         end
  //       end
  //       RGF_MSG: begin
  //         if (read_cmd) begin
  //           tx_mac_vec <= {
  //             addr, 8'h00, r_data_msg[DATA_HH:DATA_HL], 8'h00, r_data_msg[DATA_LH:DATA_LL]
  //           };
  //           tx_mac_str <= 1'b1;
  //         end
  //       end
  //       default: tx_mac_vec <= '0;
  //     endcase
  //   end
  // end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_mac_vec <= '0;
      tx_mac_str <= 1'b0;
    end else begin
      tx_mac_str <= 1'b0;
      unique case (nst)
        IMG_MSG: begin
          if (pop) begin
            tx_mac_vec <= {13'd0, img_tx_mon_r.row, 13'd0, img_tx_mon_r.col, fifo_dout};
            tx_mac_str <= 1'b1;
          end
        end
        RGF_MSG: begin
          if (read_cmd) begin
            tx_mac_vec <= {
              addr, 8'h00, r_data_msg[DATA_HH:DATA_HL], 8'h00, r_data_msg[DATA_LH:DATA_LL]
            };
            tx_mac_str <= 1'b1;
          end
        end
        default: tx_mac_vec <= '0;
      endcase
    end
  end
endmodule
