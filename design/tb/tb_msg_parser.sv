`timescale 1ns / 1ps

import defs_pkg::*;

module tb_msg_parser;

    //-------------------------------------------------------------------------
    // 1. Signal Declaration
    //-------------------------------------------------------------------------
    logic clk;
    logic rst_n;
    logic [MAX_FRAME_LEN-1:0] frame_data;

    // Outputs from DUT
    logic [7:0]   red;
    logic [7:0]   green;
    logic [7:0]   blue;
    logic         led16_msg;
    logic         led17_msg;
    // logic         led_err; // Removed if not in port list of updated RTL, or keep if added back

    logic [23:0]  addr;       
    logic [31:0]  wdata;
    logic         wr_en;
    logic         r_en;
    logic [31:0]  r_data;

    // Helper Signals (Simulating Address Decoder)
    logic pwm_en;
    logic led_en;
    logic sys_en;

    // ASCII Constants for Frame Construction
    localparam byte ASCII_OPEN  = 8'h7B; // '{'
    localparam byte ASCII_CLOSE = 8'h7D; // '}'
    localparam byte ASCII_LESS  = 8'h3C; // '<'
    localparam byte ASCII_MORE  = 8'h3E; // '>'
    localparam byte ASCII_COMMA = 8'h2C; // ','
    localparam byte ASCII_W     = 8'h57; // 'W'
    localparam byte ASCII_R     = 8'h52; // 'R'
    localparam byte ASCII_L     = 8'h4C; // 'L'
    localparam byte ASCII_V     = 8'h56; // 'V'
    localparam byte ASCII_G     = 8'h47; // 'G'
    localparam byte ASCII_B     = 8'h42; // 'B'

    //-------------------------------------------------------------------------
    // 2. Clock Generation
    //-------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    //-------------------------------------------------------------------------
    // 3. DUT Instantiation
    //-------------------------------------------------------------------------
    msg_parser u_dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .frame_data (frame_data),

        // RGB / LED Outputs
        .red        (red),
        .green      (green),
        .blue       (blue),
        .led16_msg  (led16_msg),
        .led17_msg  (led17_msg),

        // Register File Access
        .addr       (addr),
        .wdata      (wdata),
        .wr_en      (wr_en),
        .r_en       (r_en),       
        .r_data     (r_data)      
    );

    //-------------------------------------------------------------------------
    // 4. Address Decoding Logic (Simulation Only)
    //-------------------------------------------------------------------------
    assign pwm_en = (addr[23:16] == ADDR_A2_PWM); // 0x00
    assign led_en = (addr[23:16] == ADDR_A2_LED); // 0x01
    assign sys_en = (addr[23:16] == ADDR_A2_SYS); // 0x02

    //-------------------------------------------------------------------------
    // 5. Test Sequences
    //-------------------------------------------------------------------------
    initial begin
        // Init
        rst_n = 0;
        frame_data = '0;
        #50;
        rst_n = 1;
        #20;

        $display("---------------------------------------------------");
        $display("Starting Msg Parser Testbench (Corrected)");
        $display("---------------------------------------------------");

        // --- Test 1: Write to PWM Register ---
        // Address: PWM_RED_CTRL (0x00_00_04), Data: 0x12345678
        $display("[TEST 1] Write to PWM RED CTRL...");
        // Format: {W<00,00,04>,V<00,12,34>,V<00,56,78>}
        send_write_msg(ADDR_PWM_RED_CTRL, 32'h1234_5678);
        #20; 
        
        if (wr_en !== 1) $error("Test 1 Fail: wr_en should be 1");
        if (addr !== ADDR_PWM_RED_CTRL) $error("Test 1 Fail: Addr Mismatch. Got: %h", addr);
        if (wdata !== 32'h1234_5678) $error("Test 1 Fail: Data Mismatch. Got: %h", wdata);
        if (pwm_en !== 1) $error("Test 1 Fail: Address decoding (pwm_en) failed");

        // --- Test 2: Write to LED Register ---
        // Address: LED_CTRL (0x01_00_00)
        $display("[TEST 2] Write to LED CTRL...");
        send_write_msg(ADDR_LED_CTRL, 32'hFFFF_0000);
        #20;
        if (led_en !== 1) $error("Test 2 Fail: led_en should be 1");

        // --- Test 3: Read Command ---
        // Address: SYS_CTRL (0x02_00_00)
        $display("[TEST 3] Read from SYS CTRL...");
        // Format: {R<02,00,00>}
        send_read_msg(ADDR_SYS_CTRL);
        #20;
        if (r_en !== 1) $error("Test 3 Fail: r_en should be 1");
        if (sys_en !== 1) $error("Test 3 Fail: sys_en should be 1");
        if (addr !== ADDR_SYS_CTRL) $error("Test 3 Fail: Read Addr Mismatch. Got: %h", addr);

        // --- Test 4: Direct RGB Command ---
        // Values: R=100, G=200, B=050
        $display("[TEST 4] Sending RGB Values (100, 200, 050)...");
        send_rgb_msg(100, 200, 50);
        #20;
        if (red !== 8'd100) $error("Test 4 Fail: Red value mismatch. Got: %d", red);
        if (green !== 8'd200) $error("Test 4 Fail: Green value mismatch. Got: %d", green);
        if (blue !== 8'd50) $error("Test 4 Fail: Blue value mismatch. Got: %d", blue);

        // --- Test 5: LED Command Valid (17) ---
        $display("[TEST 5] Sending Valid LED Command '017'...");
        send_led_msg("017"); // L017
        #20;
        if (led17_msg !== 1) $error("Test 5 Fail: led17_msg should be 1");
        if (led16_msg !== 0) $error("Test 5 Fail: led16_msg should be 0");

        // --- Test 6: LED Command Valid (16) ---
        $display("[TEST 6] Sending Valid LED Command '016'...");
        send_led_msg("016"); // L016
        #20;
        if (led16_msg !== 1) $error("Test 6 Fail: led16_msg should be 1");
        if (led17_msg !== 0) $error("Test 6 Fail: led17_msg should be 0");

        // --- Test 7: Verify Internal Counters (Readback) ---
        $display("[TEST 7] Checking Internal Counters...");
        frame_data = '0; // Clear bus
        #10;
        
        // Read Address 0x00_00_00 (Msg Color Cnt)
        send_read_msg(24'h000000); 
        #20;
        // Check r_data. We sent 1 RGB command, so count should be 1.
        if (r_data !== 1) $display("Notice: RGB Counter is %d (Expected 1)", r_data);
        else $display("Pass: RGB Counter is correct.");

        $display("---------------------------------------------------");
        $display("Test Complete.");
        $display("---------------------------------------------------");
        $stop;
    end

    //-------------------------------------------------------------------------
    // Tasks (Helper methods to build frames)
    //-------------------------------------------------------------------------

    // 1. Generate Write Message: {W<A2,A1,A0>,V<00,DH1,DH0>,V<00,DL1,DL0>}
    // [FIXED]: Added ASCII_COMMA between bytes to match RTL skipping logic.
    task send_write_msg(input logic [23:0] addr_in, input logic [31:0] data_in);
        frame_data = {
            ASCII_OPEN, ASCII_W, ASCII_LESS,               // Idx 0,1,2
            addr_in[23:16], ASCII_COMMA,                   // Idx 3,4
            addr_in[15:8],  ASCII_COMMA,                   // Idx 5,6
            addr_in[7:0],                                  // Idx 7
            
            ASCII_MORE, ASCII_COMMA, ASCII_V, ASCII_LESS,  // Idx 8,9,10,11
            8'h00, ASCII_COMMA,                            // Idx 12,13
            data_in[31:24], ASCII_COMMA,                   // Idx 14,15
            data_in[23:16],                                // Idx 16
            
            ASCII_MORE, ASCII_COMMA, ASCII_V, ASCII_LESS,  // Idx 17,18,19,20
            8'h00, ASCII_COMMA,                            // Idx 21,22
            data_in[15:8],  ASCII_COMMA,                   // Idx 23,24
            data_in[7:0],                                  // Idx 25
            
            ASCII_MORE, ASCII_CLOSE,                       // Idx 26,27
            { (MAX_FRAME_LEN/8 - 28) {8'h00} }             // Zero Padding
        };
    endtask

    // 2. Generate Read Message: {R<A2,A1,A0>}
    // [FIXED]: Added ASCII_COMMA between address bytes.
    task send_read_msg(input logic [23:0] addr_in);
        frame_data = {
            ASCII_OPEN, ASCII_R, ASCII_LESS,               // Idx 0,1,2
            addr_in[23:16], ASCII_COMMA,                   // Idx 3,4
            addr_in[15:8],  ASCII_COMMA,                   // Idx 5,6
            addr_in[7:0],                                  // Idx 7
            
            ASCII_MORE, ASCII_CLOSE,                       // Idx 8,9
            { (MAX_FRAME_LEN/8 - 10) {8'h00} }             // Zero Padding
        };
    endtask

    // 4. Generate RGB Message: {Rxxx,Gxxx,Bxxx}
    task send_rgb_msg(input int r, input int g, input int b);
        frame_data = {
            ASCII_OPEN, ASCII_R, int_to_ascii3(r),         // { R 1 2 3
            ASCII_COMMA, ASCII_G, int_to_ascii3(g),        // , G 4 5 6
            ASCII_COMMA, ASCII_B, int_to_ascii3(b),        // , B 7 8 9
            ASCII_CLOSE,                                   // }
            { (MAX_FRAME_LEN/8 - 16) {8'h00} }             // Zero Padding
        };
    endtask

    // 5. Generate LED Message: {Lxxx}
    task send_led_msg(input logic [23:0] led_str);
        frame_data = {
            ASCII_OPEN, ASCII_L, led_str,                  // { L 0 1 6
            ASCII_CLOSE,                                   // }
            { (MAX_FRAME_LEN/8 - 6) {8'h00} }              // Zero Padding
        };
    endtask

    
    // Helper: Int to 3-digit ASCII
    function logic [23:0] int_to_ascii3(input int val);
        logic [7:0] d2, d1, d0;
        d2 = 8'h30 + (val / 100);
        d1 = 8'h30 + ((val % 100) / 10);
        d0 = 8'h30 + (val % 10);
        return {d2, d1, d0};
    endfunction

endmodule