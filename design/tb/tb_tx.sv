`timescale 1ns / 1ps

// --- Mock Package for Simulation ---
package top_pkg1;
    localparam BYTE_LEN = 8;
    localparam TRX_CLK_FREQ = 100_000_000; // 100MHz
    localparam TX_BR = 57600; // Baud Rate
    localparam TX_PAUSE_SCALE = 100;
endpackage

import top_pkg1::*;

module tb_tx;

    // --- Signals ---
    logic clk = 0;
    logic rst_n = 0;
    
    // MAC Interface
    logic [127:0] i_tx_mac_vec;
    logic i_tx_mac_str;
    logic [31:0] o_r_reg_data;
    logic o_tx_mac_ready;
    logic o_tx_mac_done;

    // PHY Interface (Interconnects)
    logic [7:0] phy_data_in;
    logic phy_str;
    logic phy_tx_line;
    logic phy_byte_ready;
    logic phy_byte_done;
    logic phy_led;

    // Internal Debug Signals form MAC
    logic [127:0] debug_frame_reg;

    // --- Generate Clock (100MHz) ---
    always #5 clk = ~clk;

    // --- Instantiate DUTs ---
    Tx_mac_v0 dut_mac (
        .clk(clk),
        .rst_n(rst_n),
        .o_r_reg_data(o_r_reg_data),
        .i_tx_mac_vec(i_tx_mac_vec),
        .i_tx_phy_ready(phy_byte_ready), 
        .i_tx_phy_done(phy_byte_done),   
        .i_tx_mac_str(i_tx_mac_str),
        .o_tx_phy_vec(phy_data_in),      
        .frame_to_send(debug_frame_reg), 
        .o_tx_phy_str(phy_str),          
        .o_tx_mac_ready(o_tx_mac_ready),
        .o_tx_mac_done(o_tx_mac_done)
    );

    Tx_phy_v0 dut_phy (
        .clk(clk),
        .rst_n(rst_n),
        .tx_phy_str(phy_str),
        .data_in(phy_data_in),
        .delay_ms(8'd0), 
        .tx_line(phy_tx_line),
        .byte_ready(phy_byte_ready),
        .byte_done(phy_byte_done),
        .led_toggle(phy_led)
    );

    // ==========================================
    //  UART SOFTWARE MONITOR (Logic Analyzer)
    // ==========================================
    // חישוב זמן ביט בננו-שניות: (1 / 57600) * 1e9 = 17361.11ns
    real BIT_PERIOD_NS = 1000000000.0 / TX_BR; 

    task automatic uart_monitor_task();
        logic [7:0] captured_byte;
        integer i;
        
        forever begin
            // 1. חכה ל-Start Bit (ירידה מ-1 ל-0)
            @(negedge phy_tx_line);
            
            // 2. המתן חצי זמן ביט כדי להגיע לאמצע ה-Start Bit
            //    ואז דלג ביט שלם כדי להגיע לאמצע הביט הראשון (DATA 0)
            #(BIT_PERIOD_NS * 1.5); 

            // 3. דגימת 8 ביטים (LSB First)
            captured_byte = 0;
            for (i = 0; i < 8; i++) begin
                captured_byte[i] = phy_tx_line;
                #(BIT_PERIOD_NS); // המתנה לביט הבא
            end
            
            // 4. בדיקת Stop Bit (אמור להיות 1)
            if (phy_tx_line == 1'b1) begin
                $display("[ANALYZER] Time: %0t | Byte Detected: 0x%h (Char: '%s')", $time, captured_byte, captured_byte);
            end else begin
                $display("[ANALYZER] Time: %0t | FRAMING ERROR! Stop bit was 0", $time);
            end
        end
    endtask

    // --- Test Process ---
    initial begin
        // הפעלת המוניטור במקביל לטסט
        fork
            uart_monitor_task();
        join_none

        $display("--- Starting MAC-PHY Simulation ---");
        
        // 1. Initialize
        rst_n = 0;
        i_tx_mac_str = 0;
        i_tx_mac_vec = '0;
        #100;
        rst_n = 1;
        #100;

        // Packet 1
        i_tx_mac_vec = "{RX_TEST_123456}"; 
        $display("Time %0t: Loading Data into MAC: %s", $time, i_tx_mac_vec);

        @(posedge clk);
        i_tx_mac_str = 1;
        @(posedge clk);
        i_tx_mac_str = 0;

        wait(o_tx_mac_done);
        #20000; // רווח קטן בין פקודות

        // Packet 2
        i_tx_mac_vec = "{RX_TEST_789100}"; 
        $display("Time %0t: Loading Data into MAC: %s", $time, i_tx_mac_vec);

        @(posedge clk);
        i_tx_mac_str = 1;
        @(posedge clk);
        i_tx_mac_str = 0;
        
        wait(o_tx_mac_done);
        #1000;
        
        $display("--- Simulation Finished ---");
        $finish;
    end

endmodule