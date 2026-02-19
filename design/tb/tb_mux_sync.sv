`timescale 1ns / 1ps

module tb_mux_sync;

    //==========================================
    // Parameters and Signals
    //==========================================
    parameter int DATA_WIDTH = 32;

    // Inputs to DUT
    logic from_clk;
    logic to_clk;
    logic from_rst_n;
    logic to_rst_n;
    logic en;
    logic [DATA_WIDTH-1:0] din;

    // Outputs from DUT
    logic [DATA_WIDTH-1:0] dout;

    //==========================================
    // DUT Instantiation
    //==========================================
    mux_sync #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .from_clk(from_clk),
        .to_clk(to_clk),
        .from_rst_n(from_rst_n),
        .to_rst_n(to_rst_n),
        .en(en),
        .din(din),
        .dout(dout)
    );

    //==========================================
    // Clock Generation
    //==========================================
    // Source clock: 100MHz (10ns period)
    initial from_clk = 0;
    always #5 from_clk = ~from_clk;

    // Destination clock: ~33MHz (30ns period) - Slower and asynchronous
    initial to_clk = 0;
    always #23 to_clk = ~to_clk;


    task automatic set_val(logic [DATA_WIDTH-1:0] data);
        din <= data;
        en <= 1'b1;
        repeat (3) @(posedge to_clk);
        din <= '0;
        en <= 1'b0;
    endtask //automatic


    //==========================================
    // Stimulus and Checking
    //==========================================
    initial begin
        // 1. Initialize Signals
        from_rst_n = 0;
        to_rst_n = 0;
        en = 0;
        din = '0;

        // 2. Apply Reset
        #100;
        from_rst_n = 1;
        to_rst_n = 1;
        #50;

        $display("--- Starting Test ---");

        //-----------------------------------------------------
        // Test Case 1: Send first data packet
        //-----------------------------------------------------
        $display("[%0t] Sending Data: 0xDEADBEEF", $time);
        
        // Setup data and enable on source domain
        @(posedge from_clk);
        din <= 32'hDEADBEEF;
        en  <= 1'b1;

        // Wait for synchronization delay (2-3 clock cycles of destination clock)
        repeat (2) @(posedge to_clk);

        // Check result
        check_output(32'hDEADBEEF);

        // De-assert enable
        @(posedge from_clk);
        en <= 1'b0;
        
        // Wait a bit to ensure output holds value
        repeat (2) @(posedge to_clk);
        check_output(32'hDEADBEEF); // Should hold previous value

        #100;

        //-----------------------------------------------------
        // Test Case 2: Send second data packet
        //-----------------------------------------------------
        $display("[%0t] Sending Data: 0xCAFEBABE", $time);

        @(posedge from_clk);
        din <= 32'hCAFEBABE;
        en  <= 1'b1;

        // Wait for synchronization
        repeat (2) @(posedge to_clk);
        
        // Check result
        check_output(32'hCAFEBABE);

        // De-assert enable
        @(posedge from_clk);
        en <= 1'b0;

        //-----------------------------------------------------
        // Test Case 3: Change Data while Enable is LOW (Should NOT update)
        //-----------------------------------------------------
        $display("[%0t] Changing Data while EN=0 (Expect no change)", $time);
        
        @(posedge from_clk);
        din <= 32'h12345678; // Junk data
        en  <= 1'b0;         // Enable is low

        repeat (2) @(posedge to_clk);
        
        // Output should still be CAFEBABE
        if (dout === 32'hCAFEBABE) 
            $display("PASS: Output remained stable (0x%h) as expected.", dout);
        else 
            $error("FAIL: Output changed to 0x%h when EN was low!", dout);

        #100;
        set_val(32'h050505050);
        @(posedge from_clk);
        #150;
        $display("--- Test Finished ---");
        $finish;
    end

    //==========================================
    // Helper Task for Checking
    //==========================================
    task check_output(input logic [DATA_WIDTH-1:0] expected);
        if (dout === expected) begin
            $display("[%0t] PASS: Output matched expected value: 0x%h", $time, dout);
        end else begin
            $error("[%0t] FAIL: Expected 0x%h, got 0x%h", $time, expected, dout);
        end
    endtask

endmodule