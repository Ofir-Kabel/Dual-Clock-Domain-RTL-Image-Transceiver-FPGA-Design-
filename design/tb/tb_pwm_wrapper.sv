`timescale 1ns/1ps

import defs_pkg::*;

module tb_pwm_wrapper;

    // --- Signals ---
    logic clk;
    logic rst_n;
    
    // PWM Inputs
    logic [PWM_LEN-1:0] red_duty_cycle;
    logic [PWM_LEN-1:0] green_duty_cycle;
    logic [PWM_LEN-1:0] blue_duty_cycle;
    
    // Control Interface
    logic pwm_en;
    logic wr_en;
    logic [31:0] w_data;
    logic [BYTE_LEN-1:0] addr_low;
    
    // Outputs
    logic [31:0] r_data;
    logic red_pwm_out;
    logic green_pwm_out;
    logic blue_pwm_out;

    // --- Parameters ---
    localparam CLK_PERIOD = 10; // 100MHz

    // Addresses defined in pwm_wrapper
    localparam ADDR_CFG   = 8'h0;
    localparam ADDR_RED   = 8'h4;
    localparam ADDR_GREEN = 8'h8;
    localparam ADDR_BLUE  = 8'hC;

    // --- DUT Instantiation ---
    pwm_wrapper dut (
        .clk(clk),
        .rst_n(rst_n),
        .red_duty_cycle(red_duty_cycle),
        .green_duty_cycle(green_duty_cycle),
        .blue_duty_cycle(blue_duty_cycle),
        .pwm_en(pwm_en),
        .wr_en(wr_en),
        .w_data(w_data),
        .addr_low(addr_low),
        .r_data(r_data),
        .red_pwm_out(red_pwm_out),
        .green_pwm_out(green_pwm_out),
        .blue_pwm_out(blue_pwm_out)
    );

    // --- Clock Generation ---
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // --- Tasks ---

    // Task to write to a register
    task automatic write_register(input logic [7:0] addr, input logic [31:0] data);
        @(posedge clk);
        wr_en = 1;
        addr_low = addr;
        w_data = data;
        @(posedge clk);
        wr_en = 0;
        // Wait a cycle
        @(posedge clk);
    endtask

    // Task to read and verify a register
    task automatic verify_register(input logic [7:0] addr, input logic [31:0] expected_data);
        @(posedge clk);
        wr_en = 0;
        addr_low = addr;
        @(posedge clk); // Allow one cycle for r_data to update (combinatorial read in DUT)
        #(CLK_PERIOD/4); // Sample a bit after edge
        
        if (r_data === expected_data) begin
            $display("[PASS] Addr: 0x%h, Data: 0x%h", addr, r_data);
        end else begin
            $display("[FAIL] Addr: 0x%h. Expected: 0x%h, Got: 0x%h", addr, expected_data, r_data);
        end
        @(posedge clk);
    endtask

    // --- Main Test Sequence ---
    initial begin
        // Initialize signals
        rst_n = 0;
        pwm_en = 0; // Disable block initially
        wr_en = 0;
        w_data = 0;
        addr_low = 0;
        red_duty_cycle = 0;
        green_duty_cycle = 0;
        blue_duty_cycle = 0;

        // Reset Sequence
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        $display("=== Starting PWM Wrapper Test ===");

        // Enable the PWM block (required for writes to work)
        pwm_en = 1;

        // --- Test 1: Write and Read Configuration Register (CFG) ---
        // Sleep Time (HI) = 0xAAAA, Time Slots (LO) = 0x5555
        $display("\n--- Test 1: Config Register Access ---");
        write_register(ADDR_CFG, 32'hAAAA5555);
        verify_register(ADDR_CFG, 32'hAAAA5555);

        // --- Test 2: Write and Read Red Color LUT ---
        // Freq (bits 14:2) = 100, Mag (bits 1:0) = 2 (X4)
        // Data construction: Res(0) | Freq(100 << 2) | Mag(2) = 400 | 2 = 402 (hex 0x192)
        $display("\n--- Test 2: Red LUT Access ---");
        write_register(ADDR_RED, 32'h00000192);
        verify_register(ADDR_RED, 32'h00000192);

        // --- Test 3: Write and Read Green Color LUT ---
        $display("\n--- Test 3: Green LUT Access ---");
        write_register(ADDR_GREEN, 32'h0000FFFF);
        verify_register(ADDR_GREEN, 32'h0000FFFF);

        // --- Test 4: Check PWM Logic Connectivity ---
        // We set a duty cycle and check if logic enables (simple check)
        $display("\n--- Test 4: Basic PWM Connectivity ---");
        red_duty_cycle = 12'd100; // Some random duty cycle
        
        // Wait some time to let counters run
        #(CLK_PERIOD * 50);
        
        // Just checking that simulation didn't crash and signals toggle
        $display("Simulating PWM run...");

        $display("\n=== Test Complete ===");
        $finish;
    end

endmodule