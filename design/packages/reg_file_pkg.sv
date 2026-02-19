`timescale 1ns / 1ps

package regs_pkg;

  // ==============================================================================
  // 1. BASE ADDRESSES (High Address / Block Select)
  // ==============================================================================
  // This defines the MSB of the address (A2 in your documentation).
  // It acts as the "Chip Select" for each peripheral.
  // Format: 8-bit Base Address
  typedef enum logic [7:0] {
    BASE_ADDR_LED  = 8'h01,
    BASE_ADDR_SYS  = 8'h02,
    BASE_ADDR_UART = 8'h03,
    BASE_ADDR_MSG  = 8'h04,
    BASE_ADDR_IMG  = 8'h05,
    BASE_ADDR_FIFO = 8'h06,
    BASE_ADDR_PWM  = 8'h07
  } base_addr_t;

  // ==============================================================================
  // 2. REGISTER OFFSETS (Low Address / Local Register Select)
  // ==============================================================================
  // These are the offsets within each block (relative address).
  // Format: 8-bit Offset (typically aligned to 32-bit words: 0x0, 0x4, 0x8...)

  // --- PWM Block Offsets ---
  localparam logic [7:0] OFFS_PWM_CFG = 8'h00;
  localparam logic [7:0] OFFS_PWM_RED_CTRL = 8'h04;
  localparam logic [7:0] OFFS_PWM_GREEN_CTRL = 8'h08;
  localparam logic [7:0] OFFS_PWM_BLUE_CTRL = 8'h0C;

  // --- LED Block Offsets ---
  localparam logic [7:0] OFFS_LED_CTRL = 8'h00;
  localparam logic [7:0] OFFS_LED_PATTERN = 8'h04;

  // --- SYS Block Offsets ---
  localparam logic [7:0] OFFS_SYS_CFG = 8'h00;

  // --- UART Block Offsets ---
  localparam logic [7:0] OFFS_UART_TX_CNT = 8'h00;
  localparam logic [7:0] OFFS_UART_RX_CNT = 8'h04;

  // --- MSG Block Offsets ---
  localparam logic [7:0] OFFS_MSG_COLOR_CNT = 8'h00;
  localparam logic [7:0] OFFS_MSG_CFG_CNT = 8'h04;

  // --- SEQ Block Offsets ---
  localparam logic [7:0] OFFS_IMG_STATUS = 8'h00;
  localparam logic [7:0] OFFS_IMG_TX_MON = 8'h04;
  localparam logic [7:0] OFFS_IMG_CTRL = 8'h08;

  // --- FIFO Block Offsets ---
  localparam logic [7:0] OFFS_FIFO_CTRL = 8'h00;

  // ==============================================================================
  // 3. REGISTER STRUCTURES (Bit Fields / Memory Map)
  // ==============================================================================
  // Defining structs here allows for easy "slicing" in the RTL.
  // Instead of doing `data[15:2]`, you can do `reg.freq`.

  // ----------------------------------------------------------------------------
  // SYS Block Structures
  // ----------------------------------------------------------------------------
  typedef struct packed {
    logic [31:2] reserved;   // Reserved for future use
    logic        sys_rst_n;  // Software Reset (Active Low)
    logic        sw_enable;  // System Enable
  } sys_cfg_reg_t;

  // ----------------------------------------------------------------------------
  // PWM Block Structures
  // ----------------------------------------------------------------------------
  // Configuration Register
  typedef struct packed {
    logic [31:16] sleep_time;  // Sleep cycles
    logic [15:0]  time_slots;  // Total time slots
  } pwm_cfg_reg_t;

  // Color Control Register (Reused for Red, Green, Blue)
  typedef struct packed {
    logic [31:15] reserved;
    logic [14:2]  freq;       // Frequency divider / max value
    logic [1:0]   magnitude;  // Brightness magnitude (X1, X2, X4, X8)
  } pwm_color_ctrl_t;

  // ----------------------------------------------------------------------------
  // LED Block Structures
  // ----------------------------------------------------------------------------
  // Main Control Register
  typedef struct packed {
    logic [31:6] reserved;
    logic        led17_cie;  // CIE correction enable for LED17
    logic        led16_cie;  // CIE correction enable for LED16
    logic        led17_sw;   // Switch enable for LED17
    logic        led16_sw;   // Switch enable for LED16
    logic [1:0]  led_sel;    // Selection Mux (01=LED16, 10=LED17)
  } led_ctrl_reg_t;

  // Pattern Register
  typedef struct packed {
    logic [31:2] reserved;
    logic [1:0]  pattern_sel;  // Pattern selection mode
  } led_pattern_reg_t;

  // ----------------------------------------------------------------------------
  // SEQ Block Structures
  // ----------------------------------------------------------------------------
  // Main Control Register
  typedef struct packed {
    logic [31:21] reserved;
    logic img_ready;
    logic [19:10] height;
    logic [9:0] width;
  } img_status_t;

  typedef struct packed {
    logic [31:20] reserved;
    logic img_trans_err;
    logic img_trans_compl;
    logic [19:10] col;
    logic [9:0] row;
  } img_tx_mon_t;

  typedef struct packed {
    logic [31:1] reserved;
    logic img_read;
  } img_ctrl_t;

  // ----------------------------------------------------------------------------
  // FIFO Block Structures
  // ----------------------------------------------------------------------------
  // Main Control Register
  typedef struct packed {
    logic [31:2] reserved;
    logic af_mod;
    logic ae_mod;
  } fifo_ctrl_t;

  // ----------------------------------------------------------------------------
  // General Counter Structure (Used for UART, MSG, etc.)
  // ----------------------------------------------------------------------------
  // Counter Struct (Used in both Rx and Tx MAC)
  typedef struct packed {logic [31:0] cnt;} generic_cnt_t;

endpackage
