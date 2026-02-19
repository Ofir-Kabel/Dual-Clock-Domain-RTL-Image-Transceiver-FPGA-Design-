`timescale 1ns / 1ps

package uart_defs_pkg;

  // ============================================================
  // UART Configuration
  // ============================================================
  localparam int TX_BR = 5_000_000;  //115_200;
  localparam int TRX_CLK_FREQ = 200_000_000;
  localparam int RX_BR = TX_BR; //115_200;
  localparam int BR16 = RX_BR << 4; 
  localparam int RX_ACC_DIFF = BR16 - RX_CLK_FREQ;
  localparam int RX_BR_MAX_CNT = RX_CLK_FREQ/RX_BR; 
  localparam int TX_PAUSE_SCALE = 100_000;  // scale convertion between ms to ns 
  localparam int RX_CLK_FREQ = TRX_CLK_FREQ;

  // ============================================================
  // Frame Definitions
  // ============================================================
  // BYTE_LEN removed (Found in common_pkg)

  localparam int TX_FRAME_LEN = 16 * 8;  // 17*8 bytes ***********************
  localparam int MAX_FRAME_LEN = 224;  // max frame length in bits
  localparam int RX_LEN = 10;  // From Rx_phy (Start + 8 Data + Stop)

  localparam IDX_0 =  TX_FRAME_LEN - 8;  // {
  localparam IDX_1 =  TX_FRAME_LEN - 16;  //    L 
  localparam IDX_2 =  TX_FRAME_LEN - 24;  //  A2
  localparam IDX_3 =  TX_FRAME_LEN - 32;  //  A1
  localparam IDX_4 =  TX_FRAME_LEN - 40;  //  A0
  localparam IDX_5 =  TX_FRAME_LEN - 48;  //  COMMA
  localparam IDX_6 =  TX_FRAME_LEN - 56;  //  L2
  localparam IDX_7 =  TX_FRAME_LEN - 64;  //  0 
  localparam IDX_8 =  TX_FRAME_LEN - 72;  //DH1
  localparam IDX_9 =  TX_FRAME_LEN - 80;  //  DH0
  localparam IDX_10 = TX_FRAME_LEN - 88;  //COMMA
  localparam IDX_11 = TX_FRAME_LEN - 96;  //L3
  localparam IDX_12 = TX_FRAME_LEN - 104;  //0
  localparam IDX_13 = TX_FRAME_LEN - 112;  //DL1
  localparam IDX_14 = TX_FRAME_LEN - 120;  //DL0
  localparam IDX_15 = TX_FRAME_LEN - 128;  //}

  typedef struct packed {
    logic [TX_FRAME_LEN-1:IDX_0] open_char;
    logic [IDX_0-1:IDX_1] letter0_char;
    logic [IDX_1-1:IDX_2] chunk_h3_char;
    logic [IDX_2-1:IDX_3] chunk_h2_char;
    logic [IDX_3-1:IDX_4] chunk_h1_char;
    logic [IDX_4-1:IDX_5] comma_or_close_char0;
    logic [IDX_5-1:IDX_6] letter1_char;
    logic [IDX_6-1:IDX_7] chunk_m3_char;
    logic [IDX_7-1:IDX_8] chunk_m2_char;
    logic [IDX_8-1:IDX_9] chunk_m1_char;
    logic [IDX_9-1:IDX_10] comma_or_close_char1;
    logic [IDX_10-1:IDX_11] letter2_char;
    logic [IDX_11-1:IDX_12] chunk_l3_char;
    logic [IDX_12-1:IDX_13] chunk_l2_char;
    logic [IDX_13-1:IDX_14] chunk_l1_char;
    logic [IDX_14-1:IDX_15] close_char;
  } rx_mac_frame_t;

  // ============================================================
  // ASCII Constants
  // ============================================================
  // Frame Delimiters
  localparam logic [7:0] OPEN_FRAME_ASCII = 8'h7B;  // '{'
  localparam logic [7:0] CLOSE_FRAME_ASCII = 8'h7D;  // '}'

  // Data Separators
  localparam logic [7:0] SEPERATE_ASCII = 8'h2C;  // ','
  localparam logic [7:0] INNER_DATA_OPEN = 8'h3C;  // '<'
  localparam logic [7:0] INNER_DATA_CLOSE = 8'h3E;  // '>'

  // Color / Command Codes
  localparam logic [7:0] ASCII_R = 8'h52;  // 'R'
  localparam logic [7:0] ASCII_W = 8'h57;  // 'W'
  localparam logic [7:0] ASCII_OPEN = 8'h7B;  // '{'
  localparam logic [7:0] ASCII_CLOSE = 8'h7D;  // '}'
  localparam logic [7:0] ASCII_COMMA = 8'h2C;  // ','
  localparam logic [7:0] ASCII_G = 8'h47;  // 'G'
  localparam logic [7:0] ASCII_B = 8'h42;  // 'B'
  localparam logic [7:0] ASCII_L = 8'h4C;  // 'L'
  localparam logic [7:0] ASCII_C = 8'h43;  // 'C'
  localparam logic [7:0] ASCII_P = 8'h50;  // 'P'
  localparam logic [7:0] ASCII_V = 8'h56;  // 'V'

  localparam logic [127:0] DEBUG_MSG = "{R_TEST_MESSAGE}";

endpackage
