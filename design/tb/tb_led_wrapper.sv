`timescale 1ns/1ps

import defs_pkg::*;

module tb_led_wrapper;

    // --- Signals ---
    logic clk;
    logic rst_n;
    
    // Address & Control
    logic [BYTE_LEN-1:0] addr_low;
    logic led_en; // Master enable for the block
    logic wr_en;
    logic [31:0] w_data;
    logic [31:0] r_data;

    // Color Inputs
    logic [7:0] red_vec;
    logic [7:0] green_vec;
    logic [7:0] blue_vec;

    // Outputs
    logic led16_en;
    logic led17_en;
    logic [PWM_LEN-1:0] red_pwm;
    logic [PWM_LEN-1:0] green_pwm;
    logic [PWM_LEN-1:0] blue_pwm;

    // --- Parameters ---
    localparam CLK_PERIOD = 10;
    
    // Addresses defined in led_wrapper
    localparam ADDR_CTRL    = 8'h00;
    localparam ADDR_PATTERN = 8'h04;

    // --- DUT Instantiation ---
    led_wrapper dut (
        .clk(clk),
        .rst_n(rst_n),
        .addr_low(addr_low),
        .led_en(led_en),
        .red_vec(red_vec),
        .green_vec(green_vec),
        .blue_vec(blue_vec),
        .wr_en(wr_en),
        .w_data(w_data),
        .r_data(r_data),
        .led16_en(led16_en),
        .led17_en(led17_en),
        .red_pwm(red_pwm),
        .green_pwm(green_pwm),
        .blue_pwm(blue_pwm)
    );

    // --- Clock Generation ---
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // --- Tasks ---

    task automatic write_reg(input logic [7:0] addr, input logic [31:0] data);
        @(posedge clk);
        wr_en = 1;
        addr_low = addr;
        w_data = data;
        @(posedge clk);
        wr_en = 0;
        @(posedge clk);
    endtask

    task automatic verify_reg(input logic [7:0] addr, input logic [31:0] expected);
        @(posedge clk);
        wr_en = 0;
        addr_low = addr;
        @(posedge clk); 
        #(CLK_PERIOD/4);
        
        if (r_data === expected)
            $display("[PASS] Addr: 0x%h, Data: 0x%h", addr, r_data);
        else
            $display("[FAIL] Addr: 0x%h, Expected: 0x%h, Got: 0x%h", addr, expected, r_data);
    endtask

    // --- Main Test Sequence ---
    initial begin
        // Init
        rst_n = 0;
        led_en = 0; 
        wr_en = 0;
        w_data = 0;
        addr_low = 0;
        red_vec = 0; green_vec = 0; blue_vec = 0;

        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        $display("=== Starting LED Wrapper Test ===");

        // Enable block for RGF access
        led_en = 1;

        // --- Test 1: Control Register (Enable LED16) ---
        // Struct format: [31:6]res, [5]17_cie, [4]16_cie, [3]17_sw, [2]16_sw, [1:0]led_sel
        // To enable LED16: led16_sw=1, led_sel=01. 
        // Binary: ...000 00101 (0x05)
        $display("\n--- Test 1: Select LED 16 ---");
        write_reg(ADDR_CTRL, 32'h00000005);
        verify_reg(ADDR_CTRL, 32'h00000005);
        
        // Wait and check hardware output signal
        #(CLK_PERIOD);
        if (led16_en === 1 && led17_en === 0) 
            $display("[PASS] Hardware signal LED16_EN is HIGH");
        else 
            $display("[FAIL] LED16_EN should be high. 16=%b, 17=%b", led16_en, led17_en);

        // --- Test 2: Control Register (Enable LED17 with CIE) ---
        // led17_cie=1 (bit 5), led17_sw=1 (bit 3), led_sel=10 (bits 1:0)
        // Binary: ... 101010 -> 0x2A
        $display("\n--- Test 2: Select LED 17 with CIE ---");
        write_reg(ADDR_CTRL, 32'h0000002A); 
        verify_reg(ADDR_CTRL, 32'h0000002A);
        
        #(CLK_PERIOD);
        if (led16_en === 0 && led17_en === 1) 
            $display("[PASS] Hardware signal LED17_EN is HIGH");
        else 
            $display("[FAIL] LED17_EN should be high. 16=%b, 17=%b", led16_en, led17_en);

        // --- Test 3: Data Path (Gamma -> Scaling -> Output) ---
        // Using LED17 (selected above)
        $display("\n--- Test 3: Color Data Path ---");
        red_vec = 8'd255;   // Should map to max gamma
        green_vec = 8'd0;
        blue_vec = 8'd128;

        // Allow pipeline delay (Gamma access + Scaling factor calculation)
        #(CLK_PERIOD * 5); 

        $display("Inputs: R_vec=%d, G_vec=%d, B_vec=%d", red_vec, green_vec, blue_vec);
        $display("Outputs: R_pwm=%d, G_pwm=%d, B_pwm=%d", red_pwm, green_pwm, blue_pwm);
        
        if (red_pwm > 0) $display("[PASS] Red PWM output detected");
        else $display("[FAIL] Red PWM is zero");

        // --- Test 4: Pattern Register ---
        $display("\n--- Test 4: Pattern Register ---");
        write_reg(ADDR_PATTERN, 32'h00000003); // Select pattern 3 (11 binary)
        verify_reg(ADDR_PATTERN, 32'h00000003);

        $display("\n=== Test Complete ===");
        $finish;
    end

endmodule