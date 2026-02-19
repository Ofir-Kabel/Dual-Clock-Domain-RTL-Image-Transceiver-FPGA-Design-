`timescale 1ns / 1ps

`include "top_pkg.svh"

module tb_top_t1;
    // =========================================================================
    // 1. הגדרות גודל תמונה (User Configuration)
    // =========================================================================
    // TODO: בדוק בקבצי ה-mem שלך מה האורך שלהם.
    // אם יש 1024 שורות -> הגודל הוא 32. אם 4096 -> הגודל הוא 64.
    
    // חישוב ערך לקונפיגורציה (Height<<10 | Width)
    localparam IMG_HEIGHT = 256;
    localparam IMG_WIDTH  = 256;
    localparam IMG_MAX_ADDR = (IMG_HEIGHT * IMG_WIDTH);
    localparam [31:0] IMG_SIZE_CFG = 1'b1 << 20 ;

    // =========================================================================
    // 2. הגדרות ואותות
    // =========================================================================
    logic clk;
    logic rst_n;
    logic RX_LINE;
    wire  TX_LINE;
    logic [MAX_DIGITS_DISP-1:0] AN;
    logic [6:0] SEG7;
    logic LED_TOGGLE, DP;
    logic LED16_R, LED16_G, LED16_B;
    logic LED17_R, LED17_G, LED17_B;

    localparam CLK_PERIOD = 10;
    localparam BIT_PERIOD = 1_000_000_000 / TX_BR;

    // כתובות
    localparam [23:0] ADDR_IMG_BASE = {BASE_ADDR_IMG, 16'h0000}; 
    localparam [7:0] OFF_IMG_STATUS = 8'h00; 
    localparam [7:0] OFF_IMG_CTRL   = 8'h08; 

    logic [7:0] r,g,b;
    int i;

    // =========================================================================
    // 3. DUT Instantiation
    // =========================================================================
    top dut (
        .clk(clk), .rst_n(rst_n),
        .RX_LINE(RX_LINE), .TX_LINE(TX_LINE),
        // .AN(AN), .SEG7(SEG7), .LED_TOGGLE(LED_TOGGLE), .DP(DP),
        // .LED16_R(LED16_R), .LED16_G(LED16_G), .LED16_B(LED16_B),
        // .LED17_R(LED17_R), .LED17_G(LED17_G), .LED17_B(LED17_B)
        .BTNC(0)
    );

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // =========================================================================
    // 4. UART Tasks
    // =========================================================================
    task send_bit(input logic b);
        RX_LINE = b; #(BIT_PERIOD);
    endtask

    task send_byte(input logic [7:0] data);
        integer i;
        begin
            send_bit(0); 
            for (i=0; i<8; i++) send_bit(data[i]);
            send_bit(1); 
        end
    endtask

    task send_string(input string str);
        integer i;
        for (i=0; i<str.len(); i++) send_byte(str.getc(i));
    endtask

    task cmd_write(input [23:0] addr, input [31:0] data);
        begin
            send_string("{W");
            send_byte(addr[23:16]); //send_string(",");
            send_byte(addr[15:8]);  //send_string(",");
            send_byte(addr[7:0]);   //send_string(">");
            
            // Upper 16 bits
            send_string(",V"); 
            send_byte(8'h00);       //send_string(",");
            send_byte(data[31:24]); //send_string(","); 
            send_byte(data[23:16]); //send_string(">");

            // Lower 16 bits
            send_string(",V"); 
            send_byte(8'h00);       //send_string(","); 
            send_byte(data[15:8]);  //send_string(","); 
            send_byte(data[7:0]);   //send_string(">");
            
            send_string("}");
            #(BIT_PERIOD * 50);
        end
    endtask

    task cmd_wpixel(input [23:0] addr, input [7:0] r,input [7:0] g,input [7:0] b);
        begin
            send_string("{W");
            send_byte(addr[23:16]); //send_string(",");
            send_byte(addr[15:8]);  //send_string(",");
            send_byte(addr[7:0]);   //send_string(">");

            send_string(",P"); 
            send_byte(r);       //send_string(",");
            send_byte(g); //send_string(","); 
            send_byte(b); //send_string(">")
            
            send_string("}");
            #(BIT_PERIOD * 50);
        end
    endtask


    // =========================================================================
    // 5. Main Simulation Process
    // =========================================================================
    initial begin
        RX_LINE = 1;
        rst_n = 0;
             r=0;
             g=0;
             b=0;

        
        #(CLK_PERIOD * 100);
        rst_n = 1;
        #(CLK_PERIOD * 100);

        $display("\n=== STARTING INTERNAL IMAGE ROM TEST (Size: %0dx%0d) ===", IMG_WIDTH, IMG_HEIGHT);

        for(i = 0; i<1024;i++)begin
             r=i;
             g=i;
             b=i;
            cmd_wpixel(i,r,g,b);
        end

        // ---------------------------------------------------------------------
        // שלב 1: הגדרת גודל התמונה
        // ---------------------------------------------------------------------
        $display("[TB] Step 1: Configuring Image Size...");
        cmd_write(ADDR_IMG_BASE + OFF_IMG_STATUS, IMG_SIZE_CFG);

        // ---------------------------------------------------------------------
        // שלב 2: התחלת השידור
        // ---------------------------------------------------------------------
        $display("[TB] Step 2: Sending Start Command...");
        cmd_write(ADDR_IMG_BASE + OFF_IMG_CTRL, 32'h00000001);

        // ---------------------------------------------------------------------
        // שלב 3: בדיקת יציאת נתונים
        // ---------------------------------------------------------------------
        $display("[TB] Step 3: Waiting for TX data...");
        wait(TX_LINE == 0); 
        $display("[TB SUCCESS] Transmission Started!");

        // המתנה לשידור של לפחות 2 שורות
        repeat(IMG_WIDTH * 2 * 4) @(negedge TX_LINE);
        
        $display("[TB INFO] Data streaming observed.");
        #(BIT_PERIOD * 100);
        $finish;
    end

 // =========================================================================
    // 6. TX DEBUG MONITOR (Software UART Receiver)
    // =========================================================================
    
    // משתנים לשמירה ולתצוגה
    logic [7:0] debug_rx_byte;          // הבייט האחרון שנתפס
    logic [7:0] debug_rx_history [$];   // היסטוריה של כל מה שנשלח
    int         debug_bit_idx;

    initial begin
        // וודא שזה תואם להגדרה ב-uart_defs_pkg!
        // בגלל שבקובץ שלך כתוב 57600, נשתמש בזה כאן:
        localparam CURRENT_BR = 57600; 
        localparam REAL_BIT_PERIOD = 1_000_000_000 / CURRENT_BR;

        debug_rx_byte = 0;
        debug_rx_history = {}; // איפוס התור

        $display("[TX MONITOR] Listening on TX_LINE at Baud Rate: %0d (Bit Period: %0d ns)", CURRENT_BR, REAL_BIT_PERIOD);

        forever begin
            // 1. המתנה ל-Start Bit (ירידה מ-1 ל-0)
            @(negedge TX_LINE);
            
            // 2. המתנה לחצי זמן ביט (כדי לדגום באמצע ה-Start Bit ולוודא שהוא יציב)
            #(REAL_BIT_PERIOD / 2);

            if (TX_LINE == 1'b0) begin
                // 3. Start Bit תקין -> מדלגים לסוף ה-Start Bit (תחילת ה-Data)
                #(REAL_BIT_PERIOD); 

                // 4. דגימת 8 ביטים (LSB First)
                for (debug_bit_idx = 0; debug_bit_idx < 8; debug_bit_idx++) begin
                    debug_rx_byte[debug_bit_idx] = TX_LINE;
                    #(REAL_BIT_PERIOD); // המתנה לביט הבא
                end

                // 5. שמירת הבייט בתור והדפסה ללוג
                debug_rx_history.push_back(debug_rx_byte);
                
                // הדפסה יפה: אם זה תו קריא נציג אותו, אחרת נציג HEX
                if (debug_rx_byte >= 32 && debug_rx_byte <= 126) begin
                    $display("[TX MONITOR] Time: %t | Byte: 0x%h | Char: '%c'", $time, debug_rx_byte, debug_rx_byte);
                end else begin
                    $display("[TX MONITOR] Time: %t | Byte: 0x%h | Char: .", $time, debug_rx_byte);
                end

                // 6. בדיקת Stop Bit (צריך להיות 1)
                // אנחנו כרגע באמצע ה-Stop Bit (כי חיכינו תקופה מלאה מהביט האחרון)
                if (TX_LINE != 1'b1) begin
                    $display("[TX MONITOR ERROR] Time: %t | Stop Bit Missing (Line is 0)!", $time);
                end
                
            end else begin
                // זה היה Glitch (רעש) ולא התחלה אמיתית
            end
        end
    end

endmodule