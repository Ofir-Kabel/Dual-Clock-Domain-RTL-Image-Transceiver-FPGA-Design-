# FPGA RGB Image Transfer System via High-Speed UART

## Project Overview

This project implements an FPGA-based system on the Nexys A7-100T board (Artix-7 FPGA) for transmitting and receiving RGB image data to/from a PC over a high-speed UART interface. The system supports a target UART baud rate of up to 5 Mbps (configurable, with default settings at 1 Mbps in the code), achieved by boosting the internal clock to 200 MHz (or potentially 320 MHz) using a PLL. Key features include:

- **UART Protocol Handling**: Receives commands/messages for RGB LED control, register file access, and image pixel data transfer.
- **Image Processing**: Stores RGB pixel data in memory (e.g., from `.mem` files) and transmits it via UART; supports gamma correction and scaling for color accuracy.
- **Peripherals**: Controls RGB LEDs (LED16/17), 7-segment displays, and general-purpose LEDs/switches.
- **Data Flow**: Inbound UART data is parsed for commands (e.g., read/write registers, set colors), while outbound data includes image pixels or acknowledgments.
- **Applications**: Suitable for real-time image transfer demos, LED lighting control, or UART-based debugging on FPGA platforms.

The design is written in SystemVerilog, targeting Xilinx Vivado for synthesis and implementation. It emphasizes modular architecture with reset synchronization, clock domain crossing (CDC), and error handling for robust operation.

## System Architecture & Data Flow

The system processes UART data from reception to output/display, with bidirectional flow for commands and responses. At a high level:

- **Inbound Data Path**: UART RX_LINE → Physical layer decoding (Rx_phy) → MAC layer framing (Rx_mac) → Message parsing (msg_parser) → Register file access or color processing → Output to LEDs/7-segment display.
- **Outbound Data Path**: Image memory (pixel_mem) or register reads → Sequencing (sequencer) → MAC framing (Tx_mac) → Physical layer encoding (Tx_phy) → UART TX_LINE.
- **Control and Clocking**: Centralized clock generation (rst_sync_pll) distributes clocks/resets. Asynchronous FIFOs (fifo_async) handle CDC between domains.

### Top-Level Connections (from `top.sv`)
- **Inputs**: `clk` (100 MHz board clock), `rst_n` (active-low reset), `RX_LINE` (UART RX), `BTNC` (center button for sequencing trigger).
- **Outputs**: `TX_LINE` (UART TX), `RX_RTS` (Request-to-Send), `LED_TOGGLE` (debug LED), `LED[4:0]` (status LEDs), `AN[7:0]` & `SEG7[6:0]` (7-segment display), `DP` (decimal point), RGB LEDs (`LED16_R/G/B`, `LED17_R/G/B`).
- **Internal Flow**:
  - UART RX → `uart_wrapper` (encompassing Rx_phy, Rx_mac, Tx_phy, Tx_mac) → Parsed messages to `msg_parser` → Addresses/data to `addr_selection` → Routed to wrappers (e.g., `pwm_wrapper` for PWM signals, `led_wrapper` for RGB control, `disp_wrapper` for 7-segment).
  - Image data from `pixel_mem` → `fifo_async` → `sequencer` → Tx_mac for transmission.
  - Clock muxing via `rst_sync_pll` ensures safe switching between 100 MHz and PLL-generated clocks.

### Text-Based Block Diagram
```
+---------------+     +-------------+     +-----------+     +-------------+
| Board Clock   | --> | rst_sync_pll| --> | Clk Mux   | --> | System Clock|
| (100 MHz)     |     | (PLL: 200MHz|     | (BUFGMUX) |     | (200 MHz)   |
+---------------+     +-------------+     +-----------+     +-------------+
                                 |
                                 v
+---------------+     +-------------+     +-----------+     +-------------+     +-----------------+
| UART RX_LINE | --> | Rx_phy     | --> | Rx_mac    | --> | msg_parser  | --> | addr_selection  |
+---------------+     +-------------+     +-----------+     +-------------+     +-----------------+
                                                                |                    |
                                                                v                    v
+---------------+     +-------------+     +-----------+     +-------------+     +-----------------+
| pixel_mem    | <-- | sequencer  | <-- | fifo_async| <-- | Image Data  |     | Wrappers: PWM,  |
| (RGB .mem)   |     +-------------+     +-----------+     | Processing  |     | LED, Display    |
+---------------+                                               +-------------+     +-----------------+
                                 |                                                  |
                                 v                                                  v
+---------------+     +-------------+     +-----------+                             +-----------------+
| UART TX_LINE | <-- | Tx_phy     | <-- | Tx_mac    |                             | Outputs: LEDs,  |
+---------------+     +-------------+     +-----------+                             | 7-Seg, etc.     |
                                                                                   +-----------------+
```

For a visual diagram, use Mermaid (paste into a Markdown viewer like GitHub):
```mermaid
graph TD
    A[Board Clock 100MHz] --> B[rst_sync_pll PLL 200MHz]
    B --> C[Clk Mux BUFGMUX]
    C --> D[System Clock 200MHz]
    E[UART RX_LINE] --> F[Rx_phy]
    F --> G[Rx_mac]
    G --> H[msg_parser]
    H --> I[addr_selection]
    J[pixel_mem RGB .mem] <--> K[sequencer]
    K <--> L[fifo_async]
    I --> M[Wrappers: PWM, LED, Display]
    M --> N[Outputs: LEDs, 7-Seg]
    O[UART TX_LINE] <-- P[Tx_phy]
    P <-- Q[Tx_mac]
    K --> Q
```

## Clocking Architecture

Clock management is critical for achieving high UART baud rates and ensuring timing closure.

- **Input Clock**: The board provides a 100 MHz clock (`clk`) via pin E3 (LVCMOS33).
- **PLL Generation**: The `rst_sync_pll` module uses Xilinx's `clk_wiz_0` IP to generate a higher-frequency clock (200 MHz default, configurable to 320 MHz). The PLL locks (`wiz_clk_0_locked`) after reset.
- **Clock Muxing**: `clk_mux` (or `bufgmux`) asynchronously selects between the 100 MHz input and PLL output based on PLL lock status. This ensures a safe fallback to 100 MHz if the PLL fails.
- **Reset Synchronization**: Resets are synchronized across domains using `rst_n_sync` modules. `rst_n_sync_clk100M` for the input domain, `rst_n_sync_sys_clk` for the system clock, and `rst_n_sync_wiz_clk` for the PLL output. This prevents metastability during clock switching.
- **Derived Clocks**: UART TX/RX use divided clocks (e.g., `TRX_CLK_FREQ = 200 MHz`). Display refresh uses `clk_div` for lower frequencies (e.g., 2 kHz).
- **Constraints**: The `.xdc` defines a 10 ns period (100 MHz) for the input clock and a 5 ns period (200 MHz) for the PLL output. No explicit CDC constraints are in the code, but async FIFOs handle crossings.

## Interface Specifications

- **UART**:
  - **Baud Rate**: Configurable; default 1 Mbps (`TX_BR = 1_000_000` in `uart_defs_pkg.sv`). Target 5 Mbps via clock scaling. Frame format: 8 data bits, no parity, 1 stop bit.
  - **Protocol**: Custom framing with ASCII delimiters (e.g., `{` start, `}` end). Supports commands like `R` (read), `W` (write), `L` (LED control), RGB color codes. Frames up to 136 bits (17 bytes).
  - **Fractional Accumulator**: In `Rx_phy.sv`, a 16x oversampling accumulator (`acc`) handles baud rate generation with precision (e.g., `BR16_PULSE_CNT = 15` for fractional timing).
  - **Pins**: RX on `uart_rx_in` (pin not explicitly mapped in XDC; assume PMOD or USB-UART), TX on `uart_tx_out`.

- **IOs (from `.xdc`)**:
  - **Clock**: E3 (`clk`).
  - **Reset/Switches**: J15 (`rst_n`), P17/P18/N17 (buttons/switches if used).
  - **LEDs**: H17/C17/D17/D18/E18/T10/U13/V10 (general LEDs), T9/T8/R8 (RGB LED16), P15/T11/R12 (RGB LED17).
  - **7-Segment Display**: T10/U13/V10 (AN/SEG pins detailed in XDC).
  - **UART**: Typically via USB-UART (e.g., J18 for TX/RX), but configurable.
  - **Other**: PMOD headers for expansion (e.g., JA/JB for additional IO).

## Module Description

| Module Name          | Responsibility |
|----------------------|----------------|
| `top.sv`            | Top-level integration: Connects all subsystems, routes signals from UART to peripherals. |
| `rst_sync_pll.sv`   | Generates PLL clock (200 MHz), synchronizes resets, and muxes clocks for safe domain switching. |
| `Rx_phy.sv`         | UART RX physical layer: Oversamples input, detects start/stop bits, outputs bytes with done pulses. Uses fractional accumulator for baud precision. |
| `Tx_phy.sv`         | UART TX physical layer: Serializes bytes, adds start/stop bits, handles pauses/delays. |
| `Rx_mac.sv`         | MAC layer for RX: Frames bytes into messages, checks delimiters, counts valid frames. |
| `Tx_mac.sv`         | MAC layer for TX: Breaks frames into bytes, manages transmission sequencing. |
| `uart_wrapper.sv`   | Wraps UART TX/RX PHY/MAC: Handles bidirectional UART with register access for stats. |
| `msg_parser.sv`     | Parses incoming frames: Extracts addresses, data, colors; generates write/enable signals for registers/LEDs. |
| `addr_selection.sv` | Routes addresses to peripherals (e.g., PWM, LED, SYS) based on high byte (A2). |
| `pwm_wrapper.sv`    | Generates PWM signals for RGB with configurable frequency/magnitude; includes gamma correction. |
| `led_wrapper.sv`    | Controls RGB LEDs (LED16/17): Applies scaling/gamma, enables based on selectors. |
| `disp_wrapper.sv`   | Drives 7-segment display: Decodes hex digits, scans with clock divider. |
| `pixel_mem.sv`      | ROM for RGB image data: Loads from `.mem` files, outputs pixels in packets. |
| `fifo_async.sv`     | Asynchronous FIFO: Buffers data across clock domains with almost-full/empty flags. |
| `sequencer.sv`      | Manages image transmission: Reads from memory/FIFO, formats for TX, handles BTNC trigger. |
| `scaling_factor.sv` | Applies color-specific scaling (e.g., green/blue factors) for CIE color accuracy. |
| `gamma_lut_table.sv`| LUT for gamma correction: Maps 8-bit inputs to 10-bit corrected values. |
| `clk_div.sv`        | Clock divider: Generates low-frequency pulses (e.g., for display refresh). |
| `rst_n_sync.sv`     | Synchronizes active-low resets to clock domains to avoid metastability. |
| `mux_sync.sv`       | Synchronizes data/enables across clock domains using flip-flops. |
| `clk_mux.sv`        | Custom clock multiplexer with sync logic for glitch-free switching. |
| `bufgmux.sv`        | Xilinx BUFGMUX primitive wrapper for clock selection. |
| `shift_reg.sv`      | Shift register for 7-segment anode scanning. |
| `disp_decoder.sv`   | Decodes 4-bit hex to 7-segment patterns. |
| `disp_reg.sv`       | Registers digits for display input. |
| `fifo.sv`           | Synchronous FIFO for buffering (used in wrappers). |
| `frame_parser.sv`   | Legacy/alternative frame parser (similar to msg_parser). |
| `uart_check.sv`     | Simple UART echo test module (for debugging). |
| Other Packages     | Define constants, types (e.g., `uart_defs_pkg.sv` for UART params, `regs_pkg.sv` for register maps). |

## Resource Usage & Constraints

- **Target Device**: Xilinx Artix-7 (XC7A100TCSG324-1) on Nexys A7-100T board.
- **Key Constraints (from `.xdc`)**:
  - Clock: 100 MHz input (period 10 ns), PLL output (period 5 ns for 200 MHz).
  - IO Standards: LVCMOS33 for most pins (e.g., clock, LEDs, switches).
  - Pin Mappings: Detailed for LEDs (e.g., H17 for LED0), 7-segment (e.g., T10 for CA), RGB LEDs, UART (USB-UART implied).
  - Config: Bank voltage VCCO, config voltage 3.3V.
  - Pull-ups: Enabled on switches/buttons for debouncing.
- **Expected Utilization**: Low to medium (e.g., <10% LUTs/FFs for core logic; PLL and FIFOs add complexity). Synthesis in Vivado should target timing closure at 200 MHz; use async FIFOs for CDC safety. No explicit power or area constraints in code; optimize via Vivado reports.