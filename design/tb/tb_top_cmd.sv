`timescale 1ns / 1ps
`include "top_pkg.svh"

module tb_top_cmd;

    // =========================================================================
    // 1. הגדרות וקבועים
    // =========================================================================
    
    // קצב השידור - חייב להיות תואם ל-RTL (5Mbps)
    localparam BAUD_RATE     = 5_000_000;
    localparam BIT_PERIOD_NS = 1_000_000_000 / BAUD_RATE; // 200ns
    localparam CLK_FREQ_HZ   = 100_000_000;
    localparam CLK_PERIOD_NS = 10;

    // Base Addresses (Based on your CSVs descriptions assumption)
    localparam ADDR_SYS  = 24'h000000; // SYS_CFG
    localparam ADDR_LED  = 24'h010000; // LED_CTRL
    localparam ADDR_PWM  = 24'h020000; // PWM_CFG
    localparam ADDR_UART = 24'h030000; // UART CNT
    localparam ADDR_IMG  = 24'h050000; // IMG STATUS

    // Signals
    logic clk;
    logic rst_n;
    logic RX_LINE;  // Input to FPGA (TB sends here)
    wire  TX_LINE;  // Output from FPGA (TB monitors here)
    
    // Peripherals (Just to close ports)
    logic [7:0] AN;
    logic [6:0] SEG7;
    logic LED_TOGGLE, DP;
    logic RX_RTS;
    logic [4:0] LED;
    logic BTNC;
    logic LED16_R, LED16_G, LED16_B;
    logic LED17_R, LED17_G, LED17_B;

    // =========================================================================
    // 2. DUT Instantiation
    // =========================================================================
    top DUT (
        .clk(clk),
        .rst_n(rst_n),
        .RX_LINE(RX_LINE),
        .AN(AN),
        .SEG7(SEG7),
        .LED_TOGGLE(LED_TOGGLE),
        .DP(DP),
        .TX_LINE(TX_LINE),
        .RX_RTS(RX_RTS),
        .LED(LED),
        .BTNC(BTNC),
        .LED16_R(LED16_R), .LED16_G(LED16_G), .LED16_B(LED16_B),
        .LED17_R(LED17_R), .LED17_G(LED17_G), .LED17_B(LED17_B)
    );

    // =========================================================================
    // 3. Clock & Reset
    // =========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    // =========================================================================
    // 4. UART Tasks (המנוע של ה-TB)
    // =========================================================================

    // שליחת בייט בודד ב-UART
    task send_byte(input logic [7:0] data);
        integer i;
        begin
            // Start Bit (0)
            RX_LINE = 1'b0;
            #(BIT_PERIOD_NS);
            
            // Data Bits (LSB First)
            for (i = 0; i < 8; i++) begin
                RX_LINE = data[i];
                #(BIT_PERIOD_NS);
            end
            
            // Stop Bit (1)
            RX_LINE = 1'b1;
            #(BIT_PERIOD_NS);
            
            // מרווח קטן בין תווים
            #(BIT_PERIOD_NS); 
        end
    endtask

    // שליחת פקודת Register Write מלאה (16 בייטים)
    // Format: { W A2 A1 A0 , V 0 DH1 DH0 , V 0 DL1 DL0 }
    task send_reg_write(input logic [23:0] addr, input logic [31:0] data);
        begin
            $display("[TB] Sending REG WRITE: Addr=0x%h, Data=0x%h", addr, data);
            
            send_byte(8'h7B); // {
            send_byte(8'h57); // W
            
            // Address
            send_byte(addr[23:16]);
            send_byte(addr[15:8]);
            send_byte(addr[7:0]);
            
            // Separator 1
            send_byte(8'h2C); // ,
            send_byte(8'h56); // V
            send_byte(8'h00); // Padding
            
            // Data High (Bits 31:16)
            send_byte(data[31:24]);
            send_byte(data[23:16]);
            
            // Separator 2
            send_byte(8'h2C); // ,
            send_byte(8'h56); // V
            send_byte(8'h00); // Padding
            
            // Data Low (Bits 15:0)
            send_byte(data[15:8]);
            send_byte(data[7:0]);
            
            send_byte(8'h7D); // }
        end
    endtask

    // שליחת פקודת Register Read
    // Format: { R A2 A1 A0 }
    task send_reg_read(input logic [23:0] addr);
        begin
            $display("[TB] Sending REG READ: Addr=0x%h", addr);
            send_byte(8'h7B); // {
            send_byte(8'h52); // R
            
            send_byte(addr[23:16]);
            send_byte(addr[15:8]);
            send_byte(addr[7:0]);
            
            // במידה וה-Parser שלך דורש 16 בייטים גם בקריאה, נמלא ב-Padding
            // אם הוא מסתפק ב-5 בייטים, השורות הבאות מיותרות (אבל לרוב לא מזיקות)
            /*
            repeat(10) send_byte(8'h00); 
            */

            send_byte(8'h7D); // }
        end
    endtask

    // שליחת פיקסל בודד
    // Format: { W A2 A1 A0 , P R G B }
    // הערה: השימוש ב-W כאן תלוי בלוגיקה שלך. אם יש Opcode ייעודי לפיקסל (כמו I), שנה את ה-0x57.
    task send_pixel_write(input logic [23:0] addr, input logic [7:0] r, input logic [7:0] g, input logic [7:0] b);
        begin
            $display("[TB] Sending PIXEL WRITE: R=%h G=%h B=%h", r, g, b);
            
            send_byte(8'h7B); // {
            send_byte(8'h57); // W (Assuming W implies write, distinct by 'P')
            
            send_byte(addr[23:16]);
            send_byte(addr[15:8]);
            send_byte(addr[7:0]);
            
            send_byte(8'h2C); // ,
            send_byte(8'h50); // P (Pixel Indicator)
            
            send_byte(r);
            send_byte(g);
            send_byte(b);
            
            send_byte(8'h7D); // }
        end
    endtask

    // =========================================================================
    // 5. TX Monitor (האזנה לתשובות מה-FPGA)
    // =========================================================================
    initial begin : tx_monitor
        logic [7:0] rx_byte;
        integer i;
        
        forever begin
            // חכה ל-Start Bit (ירידה ל-0)
            @(negedge TX_LINE);
            
            // דלג לאמצע ה-Start Bit ואז לאמצע הביט הראשון
            #(BIT_PERIOD_NS + (BIT_PERIOD_NS/2));
            
            rx_byte = 0;
            for (i=0; i<8; i++) begin
                rx_byte[i] = TX_LINE;
                #(BIT_PERIOD_NS);
            end
            
            // הדפס מה קיבלנו
            if (rx_byte >= 32 && rx_byte <= 126)
                $display("[FPGA RESPONSE] Char: '%c' (Hex: %h)", rx_byte, rx_byte);
            else
                $display("[FPGA RESPONSE] Hex: %h", rx_byte);
        end
    end

    // =========================================================================
    // 6. Test Sequence (התסריט הראשי)
    // =========================================================================
    initial begin
        // אתחול
        RX_LINE = 1;
        BTNC = 0;
        rst_n = 0;
        #100;
        rst_n = 1;
        #1000;
        
        $display("=== STARTING TEST SCENARIO ===");

        // --- שלב 1: אתחול המערכת (SYS_CFG) ---
        // כתיבה לכתובת 0: Enable System
        send_reg_read(ADDR_IMG + 0, 32'h00000001);
        #5000;

        // --- שלב 2: הגדרת לדים (LED CTRL) ---
        // כתיבה ל-LED CTRL: הפעלת LED16 ו-LED17
        // נניח ביט 2 ו-3 מפעילים אותם
        send_reg_read(ADDR_IMG + 0, 32'h0000000C);
        #5000;

        // --- שלב 3: הגדרת צבעים (PWM) ---
        // נכתוב ערכים לטבלאות ה-LUT של הצבעים
        // Red LUT (Offset 4) -> Value 0x100 (Full Power example)
        send_reg_write(ADDR_PWM + 4, 32'h00000100); 
        #2000;
        // Green LUT (Offset 8)
        send_reg_write(ADDR_PWM + 8, 32'h00000080); 
        #2000;
        // Blue LUT (Offset 12)
        send_reg_write(ADDR_PWM + 12, 32'h00000010);
        #5000;

        // --- שלב 4: בדיקת קריאה (Register Read) ---
        // ננסה לקרוא חזרה את מה שכתבנו ל-SYS_CFG או לקרוא מונה RX
        $display("--- Testing Register Read ---");
        send_reg_read(ADDR_SYS + 0); 
        // אנו מצפים לראות ב-Console שה-TX Monitor מדפיס תשובה
        #10000;

        // --- שלב 5: כתיבת פיקסל בודד (Single Pixel Write) ---
        $display("--- Testing Single Pixel Write ---");
        // נשלח פיקסל סגול (Red+Blue)
        send_pixel_write(24'h000000, 8'hFF, 8'h00, 8'hFF);
        #5000;

        // --- שלב 6: בדיקת Burst (פקודות התחלה) ---
        $display("--- Testing Image Burst Start ---");
        // שליחת IMG READY
        send_reg_write(ADDR_IMG + 0, 32'h00100000); // הגדרת Ready (למשל ביט 20)
        #2000;
        // שליחת IMG START/READ
        send_reg_write(ADDR_IMG + 8, 32'h00000001); // Trigger start
        
        // כאן ה-FPGA אמור להתחיל לשפוך מידע. ה-TX Monitor יציג הרבה בייטים.
        #50000;

        $display("=== TEST FINISHED ===");
        $finish;
    end

endmodule