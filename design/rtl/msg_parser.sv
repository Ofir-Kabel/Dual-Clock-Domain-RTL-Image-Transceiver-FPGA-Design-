`timescale 1ns / 1ps
`include "top_pkg.svh"

module msg_parser (
    input logic trx_clk,
    input logic trx_rst_n,
    input logic                     clk,
    input logic                     rst_n,
    input logic [TX_FRAME_LEN-1:0] frame_data,
    input logic rx_mac_done,

    // RGB / LED Outputs
    output logic [7:0] red,
    output logic [7:0] green,
    output logic [7:0] blue,


    // Register File Access Outputs
    output logic [23:0] addr,   // A2, A1, A0
    output logic [31:0] wdata,  // DH1, DH0, DL1, DL0
    output logic        wr_en,  // 1 = Write, 0 = Read
    output logic        r_en,

    output logic        wr_pixel,
    output logic [23:0] pixel_data,

    // Readback Data (from internal counters)
    output logic [31:0] r_data,
    output logic cmd_ack
);

  //-------------------------------------------------------------------------
  // Helper Functions
  //-------------------------------------------------------------------------
  function logic [3:0] ascii2dec(input logic [7:0] char);
    if (char >= "0" && char <= "9") return char - "0";
    else return 4'd0;
  endfunction

  function logic [7:0] calc_val_shifted(input logic [3:0] h, input logic [3:0] t,
                                        input logic [3:0] u);
    logic [9:0] term_h;
    logic [7:0] term_t;
    term_h = (h << 6) + (h << 5) + (h << 2);
    term_t = (t << 3) + (t << 1);
    return term_h[7:0] + term_t + u;
  endfunction

  // logic cmd_ack;
  logic reg_valid;

  always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n) cmd_ack <= 0;
    else cmd_ack <= reg_valid;  // Acknowledge any valid command (read/write/pixel)
  end

  logic is_open;
  logic [7:0] char_cmd;
  logic [7:0] char_cmd2;
  logic [7:0] char_cmd3;

  assign is_open = (frame_data[TX_FRAME_LEN-1 : IDX_0] == "{");
  assign char_cmd = frame_data[IDX_0-1 : IDX_1];
  assign char_cmd2 = frame_data[IDX_5-1 : IDX_6];
  assign char_cmd3 =  frame_data[IDX_10-1 : IDX_11];

  logic is_w_cmd, is_r_cmd, is_rgb_cmd, is_l_cmd,is_pixel_cmd;
  
  logic is_R, is_END;
  assign is_R = (char_cmd == "R");
  assign is_END = (frame_data[IDX_4-1:IDX_5] == "}");
  
  assign is_w_cmd   = is_open && (char_cmd == "W") && (char_cmd2== "V") && (char_cmd3 == "V");
  assign is_rgb_cmd   = is_open && (char_cmd == "R") && (char_cmd2 == "G") && (char_cmd3 == "B");
  assign is_l_cmd   = is_open && (char_cmd == "L") && frame_data[IDX_4-1:IDX_5] == "}";
  assign is_pixel_cmd = is_open && (char_cmd == "W") && (char_cmd2 == "P");
  assign is_r_cmd = is_open && (char_cmd == "R") && frame_data[IDX_4-1:IDX_5] == "}";


  always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
      wr_en <= 0;
      r_en <= 0;
      wr_pixel <= 0;
      reg_valid <= 0;
    end else begin
      wr_pixel <= is_pixel_cmd;
      wr_en <= is_w_cmd;
      r_en <= is_r_cmd;
      reg_valid <= is_w_cmd || is_r_cmd || is_pixel_cmd;
    end
  end

  // Address & Data Parsing
  logic [7:0] raw_a2, raw_a1, raw_a0;
  assign raw_a2 = frame_data[IDX_1-1:IDX_2];
  assign raw_a1 = frame_data[IDX_2-1:IDX_3];
  assign raw_a0 = frame_data[IDX_3-1:IDX_4];

  logic [7:0] raw_dh1, raw_dh0, raw_dl1, raw_dl0;
  assign raw_dh1 = frame_data[IDX_7-1:IDX_8];
  assign raw_dh0 = frame_data[IDX_8-1:IDX_9];
  assign raw_dl1 = frame_data[IDX_12-1:IDX_13];
  assign raw_dl0 = frame_data[IDX_13-1:IDX_14];

  logic [7:0] raw_p2, raw_p1, raw_p0;
  
  assign raw_p2= frame_data[IDX_6-1:IDX_7];
  assign raw_p1= frame_data[IDX_7-1:IDX_8];
  assign raw_p0= frame_data[IDX_8-1:IDX_9];

  
  always_ff@ (posedge clk or negedge rst_n)begin
    if(!rst_n)begin
      wdata <='0;
      addr <='0;
      pixel_data <= '0;
    end else begin
          wdata   <= (is_w_cmd) ? {raw_dh1, raw_dh0, raw_dl1, raw_dl0} : 32'd0;
          addr   = (reg_valid) ? {raw_a2, raw_a1, raw_a0} : 24'd0;
          pixel_data <= (is_pixel_cmd) ? {raw_p2, raw_p1, raw_p0} : 24'd0;
    end
  end

  // RGB Parsing
  logic [7:0] r_d2, r_d1, r_d0;
  logic [7:0] g_d2, g_d1, g_d0;
  logic [7:0] b_d2, b_d1, b_d0;

  assign r_d2 = frame_data[IDX_1-1:IDX_2];
  assign r_d1 = frame_data[IDX_2-1:IDX_3];
  assign r_d0 = frame_data[IDX_3-1:IDX_4];
  assign g_d2 = frame_data[IDX_6-1:IDX_7];
  assign g_d1 = frame_data[IDX_7-1:IDX_8];
  assign g_d0 = frame_data[IDX_8-1:IDX_9];
  assign b_d2 = frame_data[IDX_11-1:IDX_12];
  assign b_d1 = frame_data[IDX_12-1:IDX_13];
  assign b_d0 = frame_data[IDX_13-1:IDX_14];

  logic rgb_fmt_valid;
  assign rgb_fmt_valid = (frame_data[IDX_14-1:IDX_15] == "}");

   logic rgb_valid;  // Internal signal

always_ff@(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
    red <= '0;
    green <= '0;
    blue <='0;
    rgb_valid <= 0;
  end else begin
    red <= is_rgb_cmd ? calc_val_shifted(
      ascii2dec(r_d2), ascii2dec(r_d1), ascii2dec(r_d0)
  ) : 8'd0;
  green <= is_rgb_cmd ? calc_val_shifted(
      ascii2dec(g_d2), ascii2dec(g_d1), ascii2dec(g_d0)
  ) : 8'd0;
blue <= is_rgb_cmd ? calc_val_shifted(
      ascii2dec(b_d2), ascii2dec(b_d1), ascii2dec(b_d0)
  ) : 8'd0;
  rgb_valid <= is_rgb_cmd && rgb_fmt_valid;
  end


end

  // LED Selector
  logic [7:0] l_last_digit;

  assign l_last_digit = frame_data[IDX_4-1:IDX_5];
  assign led_err      = is_l_cmd && (l_last_digit != "6" && l_last_digit != "7");

  //-------------------------------------------------------------------------
  // 2. Edge Detection (Pulse Generation)
  //-------------------------------------------------------------------------

  logic rgb_valid_d;
  logic led_valid_d;
  logic rgb_inc;
  logic led_inc;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rgb_valid_d <= 1'b0;
      led_valid_d <= 1'b0;
    end else begin
      rgb_valid_d <= rgb_valid;
      led_valid_d <= !led_err;
    end
  end

  // Rising Edge Detection: עכשיו 1, במחזור קודם היה 0
  assign rgb_inc = rgb_valid && !rgb_valid_d;
  assign led_inc = !led_valid_d && !led_err;

  //-------------------------------------------------------------------------
  // 3. Counters Implementation
  //-------------------------------------------------------------------------
  generic_cnt_t msg_color_cnt;
  generic_cnt_t msg_led_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) msg_color_cnt <= '0;
    else if (rx_mac_done && is_rgb_cmd)  // Increment only on pulse
      msg_color_cnt <= msg_color_cnt + 1;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) msg_led_cnt <= '0;
    else if (rx_mac_done && is_l_cmd)  // Increment only on pulse
      msg_led_cnt <= msg_led_cnt + 1;
  end

  //-------------------------------------------------------------------------
  // 4. Readback Logic
  //-------------------------------------------------------------------------

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_data <= '0;
    end else if (reg_valid && !wr_en) begin
      case (addr[7:0])
        8'h00:   r_data <= msg_color_cnt;
        8'h04:   r_data <= msg_led_cnt;
        default: r_data <= 32'd0;
      endcase
    end else begin
      r_data <= 32'd0;
    end
  end

  //-------------------------------------------------------------------------
  // 5. Output sync Logic
  //-------------------------------------------------------------------------
mux_sync mux_sync_inst(
    .from_clk(trx_clk),
    .to_clk(clk),
    .from_rst_n(trx_rst_n),
    .to_rst_n(rst_n),
    .en(en),
    .din(din),
    .dout(dout)
);

endmodule
