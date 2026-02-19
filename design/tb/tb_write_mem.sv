`timescale 1ns / 1ps

`include "top_pkg.svh"

module tb_write_mem;

    // הגדרות זמן (מות�?�? ל-5Mbps)
    localparam BAUD_RATE     = 5_000_000;
    localparam BIT_PERIOD_NS = 1_000_000_000 / BAUD_RATE; // 200ns
    localparam CLK_PERIOD_NS = 10; // 100MHz

    // סיגנלי�?
    logic clk = 0;
    logic rst_n = 0;
    logic RX_LINE = 1; // קו ה-UART (כניסה ל-FPGA)
    wire  TX_LINE;
    wire  RX_RTS;      // חשוב לבדוק �?ת זה �?�? הזיכרון מתמל�?!
    
    // יצי�?ות כלליות (ל�? קריטיות לבדיקה זו)
    wire [7:0] AN;
    wire [6:0] SEG7;
    wire LED_TOGGLE, DP;
    wire [5:0] LED;
    wire LED16_R, LED16_G, LED16_B;
    wire LED17_R, LED17_G, LED17_B;

    // חיבור ה-DUT
    top DUT (
        .clk(clk),
        .rst_n(rst_n),
        .RX_LINE(RX_LINE),
        .TX_LINE(TX_LINE),
        .RX_RTS(RX_RTS),
        .AN(AN), .SEG7(SEG7), .LED_TOGGLE(LED_TOGGLE), .DP(DP),
        .LED(LED), .BTNC(1'b0),
        .LED16_R(LED16_R), .LED16_G(LED16_G), .LED16_B(LED16_B),
        .LED17_R(LED17_R), .LED17_G(LED17_G), .LED17_B(LED17_B)
    );

    // יצירת שעון
    always #(CLK_PERIOD_NS/2) clk = ~clk;

    // --- משימה לשליחת בייט (Low Level) ---
    task send_byte(input logic [7:0] data);
        integer i;
        begin
            RX_LINE = 1'b0; // Start Bit
            #(BIT_PERIOD_NS);
            for (i = 0; i < 8; i++) begin
                RX_LINE = data[i];
                #(BIT_PERIOD_NS);
            end
            RX_LINE = 1'b1; // Stop Bit
            #(BIT_PERIOD_NS);
        end
    endtask

    // --- משימה לשליחת חבילת פיקסל מל�?ה ---
    // הפורמט: { W A2 A1 A0 , P R G B }
    task send_pixel_pkt(input logic [23:0] addr, input logic [7:0] r, input logic [7:0] g, input logic [7:0] b);
        begin
            send_byte(8'h7B); // {
            send_byte(8'h57); // W
            
            send_byte(addr[23:16]); // A2
            send_byte(addr[15:8]);  // A1
            send_byte(addr[7:0]);   // A0
            
            send_byte(8'h2C); // ,
            send_byte(8'h50); // P
            
            send_byte(r);     // Red
            send_byte(g);     // Green
            send_byte(b);     // Blue
            
            send_byte(8'h7D); // }
            
            // השהייה קטנה בין פקטי�? (�?ופציונלי, מדמה רווחי�? קטני�? מהמחשב)
            #(BIT_PERIOD_NS * 2);
        end
    endtask

    // --- התסריט הר�?שי ---
    initial begin
        // 1. �?יפוס המערכת
        $display("--- System Reset ---");
        rst_n = 0;
        RX_LINE = 1;
        #200;
        rst_n = 1;
        #200;

        // 2. לול�?ת שליחת 30 פיקסלי�?
        $display("--- Starting 30-Pixel Burst Write ---");
        
        for (int i = 0; i < 30; i++) begin
            // לוגיקה ליצירת צבעי�? משתני�?:
            // כתובת: i (0, 1, 2...)
            // �?דו�?: עולה (i * 8)
            // ירוק: יורד (255 - i * 5)
            // כחול: קבוע/מתחלף (i * 2)
            
            send_pixel_pkt(
                24'(i),           // Address
                8'(i * 8),        // Red
                8'(255 - i * 5),  // Green
                8'(i * 2)         // Blue
            );
            
            $display("Sent Pixel Addr: %0d | R: %0d G: %0d B: %0d", i, i*8, 255-i*5, i*2);
        end

        // 3. המתנה כדי לר�?ות ב-Waveform שהכתיבה הסתיימה
        #5000;
        
        $display("--- Test Completed ---");
        $finish;
    end

endmodule