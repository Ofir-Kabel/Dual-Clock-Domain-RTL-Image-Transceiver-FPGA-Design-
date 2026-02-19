`timescale 1ns / 1ps
import defs_pkg::*;

module msg_parser (
    input logic                     clk,
    input logic                     rst_n,
    input logic [MAX_FRAME_LEN-1:0] frame_data,
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

    // Readback Data (from internal counters)
    output logic [31:0] r_data
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

  //-------------------------------------------------------------------------
  // 1. Message Type Detection & Parsing (Combinatorial)
  //-------------------------------------------------------------------------
  localparam IDX_0 = MAX_FRAME_LEN - 8;
  localparam IDX_1 = MAX_FRAME_LEN - 16;
  localparam IDX_2 = MAX_FRAME_LEN - 24;

  logic is_open;
  logic [7:0] char_cmd;
  logic [7:0] char_3rd;

  assign is_open  = (frame_data[MAX_FRAME_LEN-1 : IDX_0] == "{");
  assign char_cmd = frame_data[IDX_0-1 : IDX_1];
  assign char_3rd = frame_data[IDX_1-1 : IDX_2];

  logic is_w_cmd, is_r_cmd, is_rgb_cmd, is_l_cmd;
  logic reg_valid;

  assign is_w_cmd   = is_open && (char_cmd == "W");
  assign is_r_cmd   = is_open && (char_cmd == "R") && (char_3rd == "<");
  assign is_l_cmd   = is_open && (char_cmd == "L");
  assign is_rgb_cmd = is_open && (char_cmd == "R") && (char_3rd != "<");

  // Control Signals
  assign reg_valid  = is_w_cmd || is_r_cmd;
  assign wr_en      = is_w_cmd;
  assign r_en       = is_r_cmd;

  // Address & Data Parsing
  logic [7:0] raw_a2, raw_a1, raw_a0;
  assign raw_a2 = frame_data[MAX_FRAME_LEN-1-3*8 : MAX_FRAME_LEN-4*8];
  assign raw_a1 = frame_data[MAX_FRAME_LEN-1-5*8 : MAX_FRAME_LEN-6*8];
  assign raw_a0 = frame_data[MAX_FRAME_LEN-1-7*8 : MAX_FRAME_LEN-8*8];

  assign addr   = (reg_valid) ? {raw_a2, raw_a1, raw_a0} : 24'd0;

  logic [7:0] raw_dh1, raw_dh0, raw_dl1, raw_dl0;
  assign raw_dh1 = frame_data[MAX_FRAME_LEN-1-14*8 : MAX_FRAME_LEN-15*8];
  assign raw_dh0 = frame_data[MAX_FRAME_LEN-1-16*8 : MAX_FRAME_LEN-17*8];
  assign raw_dl1 = frame_data[MAX_FRAME_LEN-1-23*8 : MAX_FRAME_LEN-24*8];
  assign raw_dl0 = frame_data[MAX_FRAME_LEN-1-25*8 : MAX_FRAME_LEN-26*8];

  assign wdata   = is_w_cmd ? {raw_dh1, raw_dh0, raw_dl1, raw_dl0} : 32'd0;

  // RGB Parsing
  logic [7:0] r_d2, r_d1, r_d0;
  logic [7:0] g_d2, g_d1, g_d0;
  logic [7:0] b_d2, b_d1, b_d0;

  assign r_d2 = frame_data[MAX_FRAME_LEN-1-2*8 : MAX_FRAME_LEN-3*8];
  assign r_d1 = frame_data[MAX_FRAME_LEN-1-3*8 : MAX_FRAME_LEN-4*8];
  assign r_d0 = frame_data[MAX_FRAME_LEN-1-4*8 : MAX_FRAME_LEN-5*8];

  assign g_d2 = frame_data[MAX_FRAME_LEN-1-7*8 : MAX_FRAME_LEN-8*8];
  assign g_d1 = frame_data[MAX_FRAME_LEN-1-8*8 : MAX_FRAME_LEN-9*8];
  assign g_d0 = frame_data[MAX_FRAME_LEN-1-9*8 : MAX_FRAME_LEN-10*8];

  assign b_d2 = frame_data[MAX_FRAME_LEN-1-12*8 : MAX_FRAME_LEN-13*8];
  assign b_d1 = frame_data[MAX_FRAME_LEN-1-13*8 : MAX_FRAME_LEN-14*8];
  assign b_d0 = frame_data[MAX_FRAME_LEN-1-14*8 : MAX_FRAME_LEN-15*8];

  logic rgb_fmt_valid;
  assign rgb_fmt_valid = (frame_data[MAX_FRAME_LEN-1-15*8 : MAX_FRAME_LEN-16*8] == "}");

  logic rgb_valid;  // Internal signal
  assign red = is_rgb_cmd ? calc_val_shifted(
      ascii2dec(r_d2), ascii2dec(r_d1), ascii2dec(r_d0)
  ) : 8'd0;
  assign green = is_rgb_cmd ? calc_val_shifted(
      ascii2dec(g_d2), ascii2dec(g_d1), ascii2dec(g_d0)
  ) : 8'd0;
  assign blue = is_rgb_cmd ? calc_val_shifted(
      ascii2dec(b_d2), ascii2dec(b_d1), ascii2dec(b_d0)
  ) : 8'd0;

  assign rgb_valid = is_rgb_cmd && rgb_fmt_valid;

  // LED Selector
  logic [7:0] l_last_digit;

  assign l_last_digit = frame_data[MAX_FRAME_LEN-1-4*8 : MAX_FRAME_LEN-5*8];
  assign led_err      = is_l_cmd && (l_last_digit != "6" && l_last_digit != "7");

  //-------------------------------------------------------------------------
  // 2. Edge Detection (Pulse Generation)
  //-------------------------------------------------------------------------
  // אנחנו חייבים לזהות את ה"רגע" שבו ההודעה הופכת לתקפה כדי להגדיל את המונה פעם אחת בלבד

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
  uart_cnt_r msg_color_cnt;
  uart_cnt_r msg_led_cnt;

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
  // כתובות הקריאה למונים אלו (הנחה: אלו כתובות ייעודיות ל-Parser)
  // הערה: יש לוודא שהכתובות לא מתנגשות עם רכיבים אחרים במערכת

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


endmodule
