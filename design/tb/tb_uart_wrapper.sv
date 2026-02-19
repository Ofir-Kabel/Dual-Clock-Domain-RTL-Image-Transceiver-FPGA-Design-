`timescale 1ns / 1ps

// וודא שהקובץ הזה קיים, אחרת תצטרך להגדיר את TX_FRAME_LEN ידנית כאן
`include "top_pkg.svh" 

module tb_uart_wrapper;

    //========================================
    // 1. הגדרות תזמון קריטיות (הותאמו לבקשתך)
    //========================================
    
    // שעון מערכת: 200MHz
    localparam CLK_FREQ_HZ = 250_000_000; 
    localparam real CLK_PERIOD_NS = 1_000_000_000.0 / CLK_FREQ_HZ; // = 5.0ns

    // קצב UART: 5Mbps
    localparam BAUD_RATE   = 5_000_000;   
    localparam real BIT_PERIOD_NS = 1_000_000_000.0 / BAUD_RATE;   // = 200.0ns

    // הגדרת ברירת מחדל לאורך המסגרת אם לא הוגדר ב-pkg
    `ifndef TX_FRAME_LEN
        localparam TX_FRAME_LEN = 128; 
    `endif

    //========================================
    // 2. הצהרת אותות
    //========================================
    
    // שעונים וריסט
    logic clk;           // שעון ראשי (200MHz)
    logic rst_n;         // ריסט אסינכרוני

    // ממשק TX MAC (כניסות ל-FPGA לשליחה החוצה - לא הקריטי כרגע)
    logic i_tx_mac_str;
    logic [TX_FRAME_LEN-1:0] i_tx_mac_vec;
    logic o_tx_mac_done;
    logic o_tx_mac_ready;

    // ממשק רגיסטרים (RGF)
    logic i_uart_en;
    logic i_wr_en;
    logic [7:0] i_addr_low;
    logic [31:0] i_w_data;
    logic [31:0] o_r_txr_data;

    // === ממשק ה-RX (החלק הנבדק) ===
    logic i_rx_line;         // הקו שמגיע מה"מחשב" ל-FPGA
    logic i_cmd_ack;         // אישור שהמערכת קראה את ההודעה
    logic o_rx_mac_done;     // דגל שהתקבלה הודעה תקינה
    logic [TX_FRAME_LEN-1:0] o_rx_mac_vec; // המידע שהתקבל

    // יציאות פיזיות
    logic o_tx_line;
    logic o_led_toggle;

    //========================================
    // 3. יצירת ה-DUT (Device Under Test)
    //========================================
    uart_wrapper #(
        // אם יש פרמטרים ב-uart_wrapper, אפשר לדרוס אותם כאן.
        // כרגע נניח שהם מגיעים מ-pkg או מוגדרים בפנים.
        // .CLK_FREQ(CLK_FREQ_HZ),
        // .BAUD_RATE(BAUD_RATE)
    ) DUT (
        .clk            (clk),         // מחובר לשעון הכללי (לוגיקה פנימית)
        .rst_n          (rst_n),

        // חיבור שעונים ספציפיים (בסימולציה כולם אותו דבר)
        .tx_clk         (clk),         // 200MHz
        .tx_sync_rst_n  (rst_n),
        .rx_clk         (clk),         // 200MHz - קריטי ל-Rx_phy!
        .rx_sync_rst_n  (rst_n),

        // TX MAC
        .i_tx_mac_str   (i_tx_mac_str),
        .i_tx_mac_vec   (i_tx_mac_vec),
        .o_tx_mac_done  (o_tx_mac_done),
        .o_tx_mac_ready (o_tx_mac_ready),

        // RGF
        .i_uart_en      (i_uart_en),
        .i_wr_en        (i_wr_en),
        .i_addr_low     (i_addr_low),
        .i_w_data       (i_w_data),
        .o_r_txr_data   (o_r_txr_data),

        // RX Interface
        .i_rx_line      (i_rx_line),
        .i_cmd_ack      (i_cmd_ack),
        .o_rx_mac_done  (o_rx_mac_done),
        .o_rx_mac_vec   (o_rx_mac_vec),

        // PHY Outs
        .o_tx_line      (o_tx_line),
        .o_led_toggle   (o_led_toggle)
    );

    //========================================
    // 4. מחולל שעון (200MHz)
    //========================================
    initial begin
        clk = 0;
        // מחזור של 5ns => חצי מחזור 2.5ns
        forever #(CLK_PERIOD_NS/2.0) clk = ~clk;
    end

    //========================================
    // 5. משימות עזר (Tasks)
    //========================================

    // איפוס המערכת
    task apply_reset();
        begin
            $display("[TB @ %0t] Asserting Reset...", $time);
            rst_n = 0;
            #100; // החזקת ריסט לזמן מה
            rst_n = 1;
            $display("[TB @ %0t] Reset Released.", $time);
            #100; // המתנה להתייצבות
        end
    endtask

    // שליחת בייט בודד בפרוטוקול UART (8N1)
    task send_uart_byte(input logic [7:0] data);
        integer i;
        begin
            // 1. Start Bit (Low)
            i_rx_line = 1'b0;
            #(BIT_PERIOD_NS); 

            // 2. Data Bits (LSB First)
            for (i = 0; i < 8; i++) begin
                i_rx_line = data[i];
                #(BIT_PERIOD_NS);
            end

            // 3. Stop Bit (High)
            i_rx_line = 1'b1;
            #(BIT_PERIOD_NS);
            
            // מרווח קטן בין בייטים (Idle)
            #(BIT_PERIOD_NS); 
        end
    endtask

    //========================================
    // 6. תהליך הבדיקה הראשי
    //========================================
    initial begin
        // אתחול סיגנלים
        i_rx_line = 1'b1; // UART Idle is High
        i_tx_mac_str = 0;
        i_tx_mac_vec = 0;
        i_uart_en = 1;
        i_wr_en = 0;
        i_addr_low = 0;
        i_w_data = 0;
        i_cmd_ack = 0;

        // הפעלת ריסט
        apply_reset();

        $display("------------------------------------------------");
        $display(" Starting UART RX Test");
        $display(" Clock: 200 MHz, Baud: 5 Mbps");
        $display(" Sending Frame: { A B }");
        $display("------------------------------------------------");

        // --- שליחת הודעה מלאה ---
        // לפי Rx_mac.sv:
        // מסגרת חייבת להתחיל ב-'{' (0x7B)
        // ולהסתיים ב-'}' (0x7D)
        
        // 1. פתיחת מסגרת
        $display("[TB @ %0t] Sending START '{'", $time);
        send_uart_byte(8'h7B); 

        // 2. שליחת מידע (למשל האות 'A' והאות 'B')
        $display("[TB @ %0t] Sending DATA 'A'", $time);
        send_uart_byte(8'h41); 
        
        $display("[TB @ %0t] Sending DATA 'B'", $time);
        send_uart_byte(8'h42); 

        // 3. סגירת מסגרת
        $display("[TB @ %0t] Sending END '}'", $time);
        send_uart_byte(8'h7D); 

        // --- המתנה לתוצאות ---
        $display("[TB @ %0t] Waiting for FPGA response...", $time);

        // המתנה עד שה-MAC ירים דגל DONE
        // נותנים Timeout של בערך זמן שידור של בייט אחד ועוד קצת לעיבוד
        fork
            begin
                wait(o_rx_mac_done == 1'b1);
                $display("------------------------------------------------");
                $display("[TB @ %0t] SUCCESS! Frame Received.", $time);
                $display("[TB] Rx Data Vector: %h", o_rx_mac_vec);
                $display("------------------------------------------------");
                
                // שליחת ACK לניקוי
                @(posedge clk);
                i_cmd_ack = 1;
                @(posedge clk);
                i_cmd_ack = 0;
            end
            begin
                // Timeout Watchdog
                #50000; // 50us (זמן מספיק ל-5Mbps לשדר כמה בייטים)
                $display("------------------------------------------------");
                $display("[TB @ %0t] ERROR: Timeout! o_rx_mac_done never went high.", $time);
                $display(" Possible causes:");
                $display(" 1. Baud rate mismatch in Rx_phy parameters.");
                $display(" 2. Rx_phy FSM stuck.");
                $display(" 3. Rx_mac FSM didn't detect '{' start char.");
                $display("------------------------------------------------");
                $stop;
            end
        join_any
        
        #1000;
        $finish;
    end

endmodule