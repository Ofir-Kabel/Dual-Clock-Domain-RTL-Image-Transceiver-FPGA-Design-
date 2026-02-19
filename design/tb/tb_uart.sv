`timescale 1ns / 1ps

`include "top_pkg.svh" 

module tb_uart;
    //========================================
    // 1. הגדרות תזמון ופרמטרים
    //========================================
    localparam CLK_FREQ_HZ = 250_000_000;
    localparam real CLK_PERIOD_NS = 1_000_000_000.0 / CLK_FREQ_HZ;

    localparam BAUD_RATE   = 5_000_000;
    localparam real BIT_PERIOD_NS = 1_000_000_000.0 / BAUD_RATE;

    `ifndef TX_FRAME_LEN
        localparam TX_FRAME_LEN = 128;
    `endif

    `ifndef BASE_ADDR_IMG
        localparam [7:0] BASE_ADDR_IMG = 8'h01; 
    `endif

    // הגדרות רלוונטיות ל-TB המקורי
    localparam IMG_HEIGHT = 256;
    localparam IMG_WIDTH  = 256;
    localparam [31:0] IMG_SIZE_CFG = 1'b1 << 20; 

    localparam [23:0] ADDR_IMG_BASE  = {BASE_ADDR_IMG, 16'h0000}; 
    localparam [7:0]  OFF_IMG_STATUS = 8'h00;
    localparam [7:0]  OFF_IMG_CTRL   = 8'h08; 

    //========================================
    // 2. הצהרת אותות
    //========================================
    logic clk;
    logic rst_n;
    
    // ממשקים
    logic i_tx_mac_str;
    logic [TX_FRAME_LEN-1:0] i_tx_mac_vec;
    logic o_tx_mac_done;
    logic o_tx_mac_ready;

    logic i_uart_en;
    logic i_wr_en;
    logic [7:0] i_addr_low;
    logic [31:0] i_w_data;
    logic [31:0] o_r_txr_data;

    logic i_rx_line;
    logic i_cmd_ack;
    logic o_rx_mac_done;
    logic [TX_FRAME_LEN-1:0] o_rx_mac_vec;

    logic o_tx_line;
    logic o_led_toggle;

    // משתנים ללולאות
    int i;
    logic [7:0] pixel_val;

    //========================================
    // 3. DUT Instantiation
    //========================================
    uart_wrapper DUT (
        .clk            (clk),     
        .rst_n          (rst_n),
        .tx_clk         (clk),
        .tx_sync_rst_n  (rst_n),
        .rx_clk         (clk),    
        .rx_sync_rst_n  (rst_n),
        .i_tx_mac_str   (i_tx_mac_str),
        .i_tx_mac_vec   (i_tx_mac_vec),
        .o_tx_mac_done  (o_tx_mac_done),
        .o_tx_mac_ready (o_tx_mac_ready),
        .i_uart_en      (i_uart_en),
        .i_wr_en        (i_wr_en),
        .i_addr_low     (i_addr_low),
        .i_w_data       (i_w_data),
        .o_r_txr_data   (o_r_txr_data),
        .i_rx_line      (i_rx_line),
        .i_cmd_ack      (i_cmd_ack),
        .o_rx_mac_done  (o_rx_mac_done),
        .o_rx_mac_vec   (o_rx_mac_vec),
        .o_tx_line      (o_tx_line),
        .o_led_toggle   (o_led_toggle)
    );

    //========================================
    // 4. Clock Generation
    //========================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD_NS/2.0) clk = ~clk;
    end

    //========================================
    // 5. Tasks
    //========================================

    task apply_reset();
        begin
            rst_n = 0;
            #100;
            rst_n = 1;
            #100;
        end
    endtask

    task send_uart_byte(input logic [7:0] data);
        integer j;
        begin
            i_rx_line = 1'b0; // Start
            #(BIT_PERIOD_NS); 
            for (j = 0; j < 8; j++) begin // Data
                i_rx_line = data[j];
                #(BIT_PERIOD_NS);
            end
            i_rx_line = 1'b1; // Stop
            #(BIT_PERIOD_NS);
            #(BIT_PERIOD_NS); // Idle gap
        end
    endtask

    task send_string(input string str);
        integer k;
        for (k=0; k<str.len(); k++) send_uart_byte(str.getc(k));
    endtask

    task wait_for_ack();
        begin
            fork
                begin
                    wait(o_rx_mac_done == 1'b1);
                    @(posedge clk);
                    i_cmd_ack = 1;
                    @(posedge clk);
                    i_cmd_ack = 0;
                    // זמן מנוחה קטן בין פקודות
                    #500; 
                end
                begin
                    #2_000_000; // Timeout מוגדל
                    $display("[TB ERROR] Timeout waiting for ack!");
                    $stop;
                end
            join_any
        end
    endtask

    // --- הפונקציה הקיימת לכתיבת רג'יסטר (32 ביט) ---
    task cmd_write(input [23:0] addr, input [31:0] data);
        begin
            // Header + Address
            send_string("{W");
            send_uart_byte(addr[23:16]); 
            send_uart_byte(addr[15:8]);  
            send_uart_byte(addr[7:0]);   

            // Upper 16 bits
            send_string(",V"); 
            send_uart_byte(8'h00);       
            send_uart_byte(data[31:24]); 
            send_uart_byte(data[23:16]); 

            // Lower 16 bits
            send_string(",V"); 
            send_uart_byte(8'h00);       
            send_uart_byte(data[15:8]);  
            send_uart_byte(data[7:0]);   
            
            // Footer
            send_string("}");
        end
    endtask

    // --- הפונקציה החדשה לכתיבת פיקסל (R,G,B) ---
    // מבוססת על שורות 20-22 בקובץ המקורי
    task cmd_wpixel(input [23:0] addr, input [7:0] r, input [7:0] g, input [7:0] b);
        begin
            // Header + Address
            send_string("{W");
            send_uart_byte(addr[23:16]); 
            send_uart_byte(addr[15:8]);  
            send_uart_byte(addr[7:0]);   

            // Pixel Marker ',P'
            send_string(",P");
            send_uart_byte(r);       
            send_uart_byte(g); 
            send_uart_byte(b); 
            
            // Footer
            send_string("}");
        end
    endtask

    //========================================
    // 6. תהליך הבדיקה הראשי
    //========================================
    initial begin
        // אתחול
        i_rx_line = 1'b1;
        i_tx_mac_str = 0;
        i_tx_mac_vec = 0;
        i_uart_en = 1;
        i_wr_en = 0;
        i_addr_low = 0;
        i_w_data = 0;
        i_cmd_ack = 0;

        apply_reset();

        $display("------------------------------------------------");
        $display(" Starting UART Wrapper Test (Full Sequence)");
        $display("------------------------------------------------");

        // ---------------------------------------------------------------------
        // שלב 0: כתיבת תמונה לזיכרון (Memory Initialization)
        // מבוסס על שורות 25-26 בקובץ המקורי
        // ---------------------------------------------------------------------
        $display("[TB] Step 0: Writing 1024 Pixels to Memory...");
        
        // הערה: כתיבת 1024 פיקסלים בסימולציית UART תיקח זמן (הרבה מחזורי שעון).
        // אם הסימולציה איטית מדי, אפשר להקטין את הלולאה ל-10 פיקסלים לבדיקה.
        for (i = 0; i < 1024; i++) begin
            pixel_val = i[7:0]; // המרה ל-8 ביט (כמו r=i במקור)
            
            // שימוש בפונקציה החדשה
            cmd_wpixel(i, pixel_val, pixel_val, pixel_val);
            
            // חובה לחכות ל-ACK כדי לא להציף את ה-RX Buffer של ה-DUT
            wait_for_ack();
            
            if (i % 100 == 0) $display("[TB] Written pixel %0d / 1024", i);
        end
        $display("[TB] Memory Initialization Complete.");

        // ---------------------------------------------------------------------
        // שלב 1: הגדרת גודל תמונה (קונפיגורציה)
        // ---------------------------------------------------------------------
        $display("[TB] Step 1: Configuring Image Size...");
        cmd_write(ADDR_IMG_BASE + OFF_IMG_STATUS, IMG_SIZE_CFG);
        wait_for_ack();

        // ---------------------------------------------------------------------
        // שלב 2: התחלת שידור (Trigger)
        // ---------------------------------------------------------------------
        $display("[TB] Step 2: Sending Start Command...");
        cmd_write(ADDR_IMG_BASE + OFF_IMG_CTRL, 32'h00000001);
        wait_for_ack();

        // ---------------------------------------------------------------------
        // שלב 3: סיום והמתנה לתוצאות (אופציונלי - רק כדי לראות TX)
        // ---------------------------------------------------------------------
        $display("[TB] Waiting for TX activity...");
        
        // כאן ה-FPGA אמור להתחיל לשדר חזרה.
        // נחכה עד שנראה פעילות בקו ה-TX
        wait(o_tx_line == 0);
        $display("[TB] TX Activity Detected! Test Successful.");

        #10000;
        $finish;
    end

endmodule