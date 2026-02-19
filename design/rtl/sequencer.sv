`timescale 1ns / 1ps
`include "top_pkg.svh"


module sequencer (
    input logic clk,
    input logic rst_n,

    input logic btnc_r,

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

    input wr_pixel,
    input logic [3*BYTE_LEN-1:0] i_pixel_data,
    // input logic [3*BYTE_LEN-1:0]  i_pixel_addr,

    //  RGF - MSG
    input logic read_cmd,
    input logic [31:0] tx_r_data,
    input logic reg_read_valid,

    output logic ready,
    output logic read,
    output logic trans,
    output logic comp,

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
  logic o_almost_full_w;
  logic wr_pixel_done;
  logic pixel_pkt_load;
  logic [7:0] addr_low;
  assign addr_low = addr[7:0];
  logic [9:0] row_index;
  logic [9:0] col_index;
  logic push;
  logic [31:0] o_rom_red;
  logic [31:0] o_rom_green;
  logic [31:0] o_rom_blue;

  pixel_mem_v0 pixel_mem_v0_inst (
      .clk(clk),
      .rst_n(rst_n),
      .comp(img_tx_mon_r.img_trans_compl),
      .i_almost_full(o_almost_full_w),
      .pixel_pkt_load(pixel_pkt_load),
      .wr_pixel(wr_pixel),
      .img_ready(img_status_r.img_ready),
      .img_read(img_ctrl_r.img_read),
      // .i_pixel_addr(i_pixel_addr),
      // .row_index(row_index),
      // .col_index(col_index),
      .i_pixel_data(i_pixel_data),
      .o_red_data(o_rom_red),
      .o_green_data(o_rom_green),
      .o_blue_data(o_rom_blue),
      .o_done_wr(wr_pixel_done)  //img_ready
  );
  assign row_index = img_tx_mon_r.row;
  assign col_index = img_tx_mon_r.col;

  //----------------------------------------------------------------
  // FIFO INSTANCE & PACKING
  //----------------------------------------------------------------
  logic pop;
  logic [31:0] fifo_dout;
  logic [31:0] o_fifo_data;
  logic [31:0] fifo_din;
  logic o_full_w, o_half_full, o_almost_empty_r, o_empty_r;
  logic fifo_write_en;


  fifo_async fifo_asycn_inst (
      .clk(clk),
      .rst_n(rst_n),
      .r_clk(r_clk),
      .r_rst_n(r_rst_n),
      .w_clk(w_clk),
      .w_rst_n(w_rst_n),
      .push(push),
      .pop(pop),
      // .img_ready(img_status_r.img_ready),
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

  function logic [23:0] bin_to_ascii3(
      input logic [9:0] val
  );  // Returns 3 ASCII bytes: '0'=8'h30, etc.
    logic [3:0] hundreds, tens, ones;
    hundreds = val / 100;
    tens = (val / 10) % 10;
    ones = val % 10;
    return {(hundreds + 8'h30), (tens + 8'h30), (ones + 8'h30)};
  endfunction


  assign o_fifo_data = fifo_dout;

  logic [31:0] i_fifo_red_temp, i_fifo_green_temp, i_fifo_blue_temp;
  logic [1:0] write_sub_pixel;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i_fifo_red_temp <= 0;
      i_fifo_green_temp <= 0;
      i_fifo_blue_temp <= 0;
      write_sub_pixel <= '0;
      fifo_write_en <= 1'b0;
      fifo_din <= 0;
    end else begin
      fifo_write_en <= 1'b0;
      if (!o_almost_full_w) begin
        fifo_din <= {
          8'h00, i_fifo_red_temp[31:24], i_fifo_green_temp[31:24], i_fifo_blue_temp[31:24]
        };
      end
      if (write_sub_pixel == 0 && pixel_pkt_load) begin
        i_fifo_red_temp <= o_rom_red;
        i_fifo_green_temp <= o_rom_green;
        i_fifo_blue_temp <= o_rom_blue;
        write_sub_pixel <= 2'd3;  // Start writing 4 pixels from this 32-bit word
        fifo_write_en <= 1'b1;
      end else if (write_sub_pixel > 0 && !o_almost_full_w) begin
        i_fifo_red_temp <= i_fifo_red_temp << 8;
        i_fifo_green_temp <= i_fifo_green_temp << 8;
        i_fifo_blue_temp <= i_fifo_blue_temp << 8;
        write_sub_pixel <= write_sub_pixel - 1;
        fifo_write_en <= 1'b1;
      end
    end
  end

  //SYNC FOR FIFO
  always_ff @(posedge r_clk or negedge r_rst_n) begin
    if (!r_rst_n) begin
      push <= 0;
    end else push <= fifo_write_en;
  end

  //----------------------------------------------------------------
  // COUNTERS LOGIC (Bit Slicing)
  //----------------------------------------------------------------
  typedef enum logic [1:0] {
    IDLE,
    IMG_MSG,
    RGF_MSG,
    PIX_MSG
  } tx_msg_t;
  tx_msg_t pst, nst;

  logic img_trans, img_done_trans;

  always_ff @(posedge r_clk or negedge r_rst_n) begin
    if (!r_rst_n) begin
      img_tx_mon_r.reserved <= '0;
      img_tx_mon_r.img_trans_err <= 1'b0;
      img_tx_mon_r.img_trans_compl <= 1'b0;
      img_tx_mon_r.col <= '0;
      img_tx_mon_r.row <= '0;
    end else begin
      if (pop) begin  //pst == IMG_MSG && tx_mac_done
        if (img_tx_mon_r.col == img_status_r.width - 1) begin
          img_tx_mon_r.col <= 0;
          img_tx_mon_r.row <= img_tx_mon_r.row + 1;
        end else begin
          img_tx_mon_r.col <= img_tx_mon_r.col + 1;
        end
      end else if (pst == IDLE || img_status_r.img_ready) begin
        img_tx_mon_r.col <= '0;
        img_tx_mon_r.row <= '0;
      end
      if (img_done_trans) img_tx_mon_r.img_trans_compl <= 1'b1;
      else if (img_status_r.img_ready) img_tx_mon_r.img_trans_compl <= 1'b0;
      //img_tx_mon_r.img_trans_err <=1'b0;
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
          img_status_r.reserved <= '0;
          img_status_r.img_ready <= img_status_r_v.img_ready;
          img_status_r.height <= IMG_H;  //img_status_r_v.height
          img_status_r.width <= IMG_W;  //img_status_r_v.width
        end
        R_IMG_CTRL_ADDR: begin
          img_ctrl_r.reserved <= '0;
          img_ctrl_r.img_read <= (img_status_r.img_ready && !img_tx_mon_r.img_trans_err)? img_ctrl_r_v.img_read:img_ctrl_r.img_read;
        end
        default: r_img_writing_err <= 1'b1;
      endcase
    end else begin
      img_ctrl_r.img_read <= 1'b0;
      img_status_r.img_ready <= (img_ctrl_r.img_read) ? 1'b0 : img_status_r.img_ready;
    end

  end


  always_comb begin
    r_img_reading_err = 1'b0;
    r_data_img = '0;
    if (read_cmd && img_sel_r)
      case (addr_low)
        R_IMG_STATUS_ADDR: r_data_img = img_status_r;
        R_IMG_TX_MON_ADDR: r_data_img = img_tx_mon_r;
        R_IMG_CTRL_ADDR:   r_data_img = '0;  // 0x08, W-only (read as 0)
        default:           r_img_reading_err = 1'b1;
      endcase
  end


  // FSM Next State

  logic done_col;
  logic done_row;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done_col <= 0;
      done_row <= 0;
    end else begin
      if (img_tx_mon_r.col == img_status_r.height - 1) done_col <= 1;
      else done_col <= 0;

      if (img_tx_mon_r.row == img_status_r.width - 1) done_row <= 1;
      else done_row <= 0;
    end
  end

  assign img_done_trans = (done_row && done_col);


  always_ff @(posedge r_clk or negedge r_rst_n) begin
    if (!r_rst_n) pst <= IDLE;
    else pst <= nst;
  end

  logic wr_pixel_valid;
  logic wr_pixel_pulse;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_pixel_valid <= 1'b0;
    end else begin
      wr_pixel_valid <= wr_pixel;
    end
  end
  assign wr_pixel_pulse = wr_pixel && !wr_pixel_valid;


  logic reg_read_valid_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_read_valid_q <= 1'b0;
    end else begin
      reg_read_valid_q <= read_cmd;
    end
  end


  always_comb begin
    nst = pst;
    unique case (pst)
      IDLE: begin
        if (reg_read_valid_q) nst = RGF_MSG;
        else if (img_ctrl_r.img_read) nst = IMG_MSG;
        else if (wr_pixel_pulse) nst = PIX_MSG;
        else nst = IDLE;
      end
      IMG_MSG: begin
        if (reg_read_valid_q) nst = RGF_MSG;
        else if (img_done_trans) nst = IDLE;
        else nst = IMG_MSG;
      end
      RGF_MSG: begin
        if (reg_read_valid_q) nst = RGF_MSG;
        else if (img_trans) nst = IMG_MSG;
        else nst = IDLE;
      end
      PIX_MSG: begin
        if (reg_read_valid_q) nst = RGF_MSG;
        else if (img_trans) nst = IMG_MSG;
        else nst = IDLE;
      end
      default: nst = IDLE;
    endcase
  end


  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) img_trans <= 0;
    else if (img_ctrl_r.img_read) img_trans <= 1;  // Bit Access
    else if (img_tx_mon_r.img_trans_compl) img_trans <= 0;
  end

  //----------------------------------------------------------------
  // MSG COMPOSER
  //----------------------------------------------------------------
  localparam DATA_HH = 31;
  localparam DATA_HL = 16;
  localparam DATA_LH = 15;
  localparam DATA_LL = 0;

  logic pop_cond;
  always_ff @(posedge r_clk or negedge r_rst_n) begin
    if (!r_rst_n) begin
      pop <= 0;
    end else if ((!o_empty_r) && (pst == IMG_MSG)) pop <= (tx_mac_done || img_ctrl_r.img_read);
    else pop <= 0;
  end

  // always_ff @(posedge r_clk or negedge r_rst_n) begin
  //   if (!r_rst_n) begin
  //     tx_mac_vec <= '0;
  //     tx_mac_str <= 1'b0;
  //   end else begin
  //     tx_mac_str <= 1'b0;
  //     unique case (nst)
  //       IDLE: begin
  //         if (btnc_r) begin
  //           tx_mac_vec <= DEBUG_MSG;
  //           tx_mac_str <= 1'b1;
  //         end else begin
  //           tx_mac_vec <= '0;
  //           tx_mac_str <= 1'b0;
  //         end
  //       end
  //       IMG_MSG: begin
  //         if (pop) begin
  //           tx_mac_vec <= {
  //             ASCII_OPEN,
  //             ASCII_R,
  //             14'd0,
  //             img_tx_mon_r.row,
  //             ASCII_COMMA,
  //             ASCII_C,
  //             14'd0,
  //             img_tx_mon_r.col,
  //             ASCII_COMMA,
  //             ASCII_P,
  //             fifo_dout[23:0],
  //             ASCII_CLOSE
  //           };
  //           tx_mac_str <= 1'b1;
  //         end
  //       end
  //       RGF_MSG: begin
  //         if (read_cmd) begin
  //           tx_mac_vec <= {
  //             ASCII_OPEN,
  //             ASCII_R,
  //             addr,
  //             ASCII_COMMA,
  //             ASCII_V,
  //             8'h00,
  //             tx_r_data[DATA_HH:DATA_HL],
  //             ASCII_COMMA,
  //             ASCII_V,
  //             8'h00,
  //             tx_r_data[DATA_LH:DATA_LL],
  //             ASCII_CLOSE
  //           };
  //           tx_mac_str <= 1'b1;
  //         end
  //       end

  //       default: tx_mac_vec <= '0;
  //     endcase
  //   end
  // end

  always_ff @(posedge r_clk or negedge r_rst_n) begin
    if (!r_rst_n) begin
      tx_mac_vec <= '0;
      tx_mac_str <= 1'b0;
    end else begin
      tx_mac_str <= 1'b0;
      unique case (nst)
        IDLE: begin
          if (btnc_r) begin
            tx_mac_vec <= DEBUG_MSG;
            tx_mac_str <= 1'b1;
          end else begin
            tx_mac_vec <= '0;
            tx_mac_str <= 1'b0;
          end
        end
        IMG_MSG: begin
          if (pop) begin
            tx_mac_vec <= {
              ASCII_OPEN,
              ASCII_R,
              14'd0,
              img_tx_mon_r.row,
              ASCII_COMMA,
              ASCII_C,
              14'd0,
              img_tx_mon_r.col,
              ASCII_COMMA,
              ASCII_P,
              fifo_dout[23:0],
              ASCII_CLOSE
            };
            tx_mac_str <= 1'b1;
          end
          //            begin
          //   if (pop) begin
          //     tx_mac_vec <= {
          //       ASCII_OPEN,
          //       ASCII_R,
          //       bin_to_ascii3(img_tx_mon_r.row),  // 24 bits: e.g., '0' '0' '0'
          //       ASCII_COMMA,
          //       ASCII_C,
          //       bin_to_ascii3(img_tx_mon_r.col),
          //       ASCII_COMMA,
          //       ASCII_P,
          //       fifo_dout[23:0],
          //       ASCII_CLOSE
          //     };
          //     tx_mac_str <= 1'b1;
          //   end
          // end
        end
        RGF_MSG: begin
          if (reg_read_valid_q) begin
            tx_mac_vec <= {
              ASCII_OPEN,
              ASCII_R,
              addr,
              ASCII_COMMA,
              ASCII_V,
              8'h00,
              tx_r_data[DATA_HH:DATA_HL],
              ASCII_COMMA,
              ASCII_V,
              8'h00,
              tx_r_data[DATA_LH:DATA_LL],
              ASCII_CLOSE
            };
            tx_mac_str <= 1'b1;
          end
        end
        PIX_MSG: begin
          tx_mac_vec <= {
            ASCII_OPEN,
            ASCII_R,
            14'd0,
            row_index,
            ASCII_COMMA,
            ASCII_C,
            14'd0,
            col_index,
            ASCII_COMMA,
            ASCII_P,
            i_pixel_data,
            ASCII_CLOSE
          };
          tx_mac_str <= 1'b1;
        end

        default: tx_mac_str <= 1'b0;
      endcase
    end
  end

  assign ready = img_status_r.img_ready;
  assign read  = img_ctrl_r.img_read;
  assign trans = img_trans;
  assign comp  = img_tx_mon_r.img_trans_compl;

endmodule
