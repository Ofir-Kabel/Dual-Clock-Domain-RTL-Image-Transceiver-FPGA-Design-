`timescale 1ns/1ns

package display_defs_pkg;

    // =================================================================
    // 1. DISPLAY CONFIGURATION
    // =================================================================
    localparam int MAX_DIGITS_DISP = 8;    // Number of 7-Seg digits
    localparam int CLK_OUT_FREQ    = 2000; // Scanning/Refresh frequency (Hz)
    
    // BYTE_LEN removed (Found in common_pkg)

    // =================================================================
    // 2. 7-SEGMENT ENCODING
    // =================================================================
    // Logic: Active LOW (0 = Segment ON, 1 = Segment OFF)
    // Format: [6:0] = {g, f, e, d, c, b, a}
    
    localparam logic [6:0] SEG_0   = 7'b0000001; // 0
    localparam logic [6:0] SEG_1   = 7'b1001111; // 1
    localparam logic [6:0] SEG_2   = 7'b0010010; // 2
    localparam logic [6:0] SEG_3   = 7'b0000110; // 3
    localparam logic [6:0] SEG_4   = 7'b1001100; // 4
    localparam logic [6:0] SEG_5   = 7'b0100100; // 5
    localparam logic [6:0] SEG_6   = 7'b0100000; // 6
    localparam logic [6:0] SEG_7   = 7'b0001111; // 7
    localparam logic [6:0] SEG_8   = 7'b0000000; // 8
    localparam logic [6:0] SEG_9   = 7'b0000100; // 9
    
    // Hex Characters
    localparam logic [6:0] SEG_A   = 7'b0001000; // A
    localparam logic [6:0] SEG_B   = 7'b1100000; // b
    localparam logic [6:0] SEG_C   = 7'b0110001; // C
    localparam logic [6:0] SEG_D   = 7'b1000010; // d
    localparam logic [6:0] SEG_E   = 7'b0110000; // E
    localparam logic [6:0] SEG_F   = 7'b0111000; // F
    
    // Special Symbols
    localparam logic [6:0] SEG_OFF = 7'b1111111; // All Segments OFF
    localparam logic [6:0] SEG_DOT = 7'b1111110; // Only Dot

endpackage