`timescale 1ns / 1ps
`include "top_pkg.svh"

module tb_pixel_mem_v0;

    // Signals
    logic clk, rst_n;
    logic wr_pixel;
    logic [23:0] i_pixel_data;
    // Read side signals
    logic i_almost_full;
    logic comp;
    logic [31:0] o_red, o_green, o_blue;
    logic pixel_pkt_load;
    logic o_done_wr;

    // Simulation Parameters
    // We want at least 30 writes. Let's do 32 rows to be safe and align with power of 2.
    localparam NUM_ROWS = 32; 
    
    // Loop variables
    integer row_idx, byte_idx;
    logic [7:0] expected_val; // For verifying read data

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // DUT Instantiation
    pixel_mem_v0 dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_almost_full(i_almost_full),
        .comp(comp),
        .wr_pixel(wr_pixel),
        .i_pixel_data(i_pixel_data),
        .o_red_data(o_red),
        .o_green_data(o_green),
        .o_blue_data(o_blue),
        .pixel_pkt_load(pixel_pkt_load),
        .o_done_wr(o_done_wr)
    );

    // Task to send a single pixel
    task send_pixel(input logic [7:0] r, input logic [7:0] g, input logic [7:0] b);
        begin
            @(posedge clk);
            wr_pixel <= 1;
            i_pixel_data <= {r, g, b};
            @(posedge clk);
            wr_pixel <= 0;
            // Add small random delay to simulate realistic traffic
            repeat($urandom_range(0,1)) @(posedge clk);
        end
    endtask

            logic [31:0] expected_word;
            logic [7:0] b0, b1, b2, b3;
    // Main Stimulus
    initial begin
        // 1. Initialize
        rst_n = 0;
        wr_pixel = 0;
        i_almost_full = 1; // Block reading initially (Force FIFO/Memory to fill up)
        comp = 0;
        i_pixel_data = 0;
        
        #50 rst_n = 1;
        #20;

        $display("--- Starting FILL MEMORY Test (%0d Rows / %0d Pixels) ---", NUM_ROWS, NUM_ROWS*4);

        // ============================================================
        // WRITE PHASE
        // ============================================================
        for (row_idx = 0; row_idx < NUM_ROWS; row_idx++) begin
            
            // Send 4 bytes to pack one 32-bit word
            for (byte_idx = 0; byte_idx < 30; byte_idx++) begin
                // Generate sequential data: 0, 1, 2, 3, ... 127
                logic [7:0] current_val;
                current_val = (row_idx * 4) + byte_idx; 
                
                // Send same value to R, G, B for simplicity, or offset them if needed
                send_pixel(current_val, current_val + 8'h10, current_val + 8'h20);
            end

            // Wait for the Write Pulse (o_done_wr)
            // This confirms the DUT has packed 4 pixels and wrote 1 line to memory
            @(posedge clk);
            wait(o_done_wr); 
            $display("WRITE: Row %0d written to memory. (Data range: %0d to %0d)", 
                     row_idx, (row_idx*4), (row_idx*4)+3);
            
            @(posedge clk);
        end

        $display("--- Finished Writing. Memory should be full. Starting Read ---");
        
        // ============================================================
        // READ PHASE
        // ============================================================
        #100;
        i_almost_full = 0; // Release backpressure, allow DUT to output data

        for (row_idx = 0; row_idx < NUM_ROWS; row_idx++) begin
            
            // Wait for valid data output
            wait(pixel_pkt_load);
            
            $display("READ: Row %0d -> R=%h G=%h B=%h", row_idx, o_red, o_green, o_blue);

            // Construct Expected Data for checking
            // We sent sequential bytes. Assuming Big Endian Packing (Byte0 is MSB):
            // Row 0 expected: 00 01 02 03
            // Row 1 expected: 04 05 06 07
            // Note: If your DUT packs Little Endian, reverse the order below.
            

            
            b0 = (row_idx * 4) + 0;
            b1 = (row_idx * 4) + 1;
            b2 = (row_idx * 4) + 2;
            b3 = (row_idx * 4) + 3;
            
            expected_word = {b0, b1, b2, b3};

            if (o_red == expected_word) begin
                 $display("PASS: Row %0d Correct.", row_idx);
            end else begin
                 $display("FAIL: Row %0d Mismatch! Expected: %h, Got: %h", row_idx, expected_word, o_red);
            end
            
            @(posedge clk); 
            // Wait for signal to de-assert before next loop to avoid double counting
            while(pixel_pkt_load) @(posedge clk); 
        end

        #100;
        $display("--- TEST COMPLETE ---");
        $finish;
    end

endmodule