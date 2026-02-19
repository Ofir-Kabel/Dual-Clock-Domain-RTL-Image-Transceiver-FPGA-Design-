`timescale 1ns / 1ps

module tb_top;

    // =========================================================================
    // 1. הגדרות וקבועים
    // =========================================================================
    localparam BAUD_RATE     = 5_000_000; // מהיר לסימולציה
    localparam BIT_PERIOD_NS = 1_000_000_000 / BAUD_RATE;
    localparam CLK_PERIOD_NS = 10; // 100MHz

    // כתובות IMG
    localparam ADDR_IMG_BASE   = 24'h050000;
    localparam ADDR_IMG_STATUS = ADDR_IMG_BASE + 0;
    localparam ADDR_IMG_MON    = ADDR_IMG_BASE + 4;
    localparam ADDR_IMG_CTRL   = ADDR_IMG_BASE + 8;

    // סיגנלים
    logic clk = 0;
    logic rst_n = 0;
    logic RX_LINE = 1;
    wire  TX_LINE;
    
    // חיבורים ל-DUT
    wire [7:0] AN;
    wire [6:0] SEG7;
    wire LED_TOGGLE, DP, RX_RTS;
    wire [4:0] LED;
    logic BTNC = 0;
    wire LED16_R, LED16_G, LED16_B;
    wire LED17_R, LED17_G, LED17_B;

    // Instantiation
    top DUT (
        .clk(clk),
        .rst_n(rst_n),
        .RX_LINE(RX_LINE),
        .TX_LINE(TX_LINE),
        // שאר הפורטים...
        .AN(AN), .SEG7(SEG7), .LED_TOGGLE(LED_TOGGLE), .DP(DP),
        .RX_RTS(RX_RTS), .LED(LED), .BTNC(BTNC),
        .LED16_R(LED16_R), .LED16_G(LED16_G), .LED16_B(LED16_B),
        .LED17_R(LED17_R), .LED17_G(LED17_G), .LED17_B(LED17_B)
    );

    // שעון
    always #(CLK_PERIOD_NS/2) clk = ~clk;

    // =========================================================================
    // 2. משימות UART (כולל ריפוד!)
    // =========================================================================
    task uart_send_byte(input logic [7:0] b);
        integer i;
        begin
            RX_LINE = 0; #(BIT_PERIOD_NS); // Start
            for (i=0; i<8; i++) begin RX_LINE = b[i]; #(BIT_PERIOD_NS); end
            RX_LINE = 1; #(BIT_PERIOD_NS); // Stop
            #(BIT_PERIOD_NS * 2);
        end
    endtask

    // שליחת כתיבה (16 בייטים)
    task write_reg(input logic [23:0] addr, input logic [31:0] data);
        begin
            $display("[TB CMD] WRITE -> Addr: %h, Data: %h", addr, data);
            uart_send_byte("{"); uart_send_byte("W");
            uart_send_byte(addr[23:16]); uart_send_byte(addr[15:8]); uart_send_byte(addr[7:0]);
            uart_send_byte(","); uart_send_byte("V"); uart_send_byte(0);
            uart_send_byte(data[31:24]); uart_send_byte(data[23:16]);
            uart_send_byte(","); uart_send_byte("V"); uart_send_byte(0);
            uart_send_byte(data[15:8]); uart_send_byte(data[7:0]);
            uart_send_byte("}");
        end
    endtask

    // שליחת קריאה מרופדת (Padded Read - 16 Bytes total)
    // זה קריטי כדי לוודא שה-Parser לא נתקע בהמתנה
    task read_reg(input logic [23:0] addr);
        begin
            $display("[TB CMD] READ -> Addr: %h", addr);
            uart_send_byte("{"); uart_send_byte("R");
            uart_send_byte(addr[23:16]); uart_send_byte(addr[15:8]); uart_send_byte(addr[7:0]);
            uart_send_byte("}");
        end
    endtask

    // =========================================================================
    // 3. ה-"Spy" הפנימי (Internal Monitoring)
    // זה החלק הכי חשוב! הוא מסתכל לתוך ה-RTL בזמן אמת.
    // =========================================================================
    always @(posedge clk) begin
       
        if (DUT.sequencer_inst.read_cmd == 1'b1) begin
            $display("\n>>> [INTERNAL SPY] READ CMD DETECTED @ Time %0t <<<", $time);
            
            // 1. האם הרגיסטר מחזיק את המידע הנכון?
            $display("    1. Register Value (img_status_r): %h", DUT.sequencer_inst.img_status_r);
            
            // 2. האם ה-Enable לקריאה פעיל?
            $display("    2. Logic Checks: read_cmd=%b, img_sel_r=%b", 
                     DUT.sequencer_inst.read_cmd, DUT.sequencer_inst.img_sel_r);
            
            // 3. האם ה-Sequencer מוציא את המידע החוצה?
            $display("    3. Sequencer OUTPUT (r_data_img): %h", DUT.sequencer_inst.r_data_img);
            
            // 4. האם המידע חוזר לכניסה של ה-Sequencer (אחרי ה-MUX)?
            // זה הבדיקה ל-Loopback ב-Top
            $display("    4. Sequencer INPUT  (tx_r_data): %h", DUT.sequencer_inst.tx_r_data);
            
            if (DUT.sequencer_inst.r_data_img !== 0 && DUT.sequencer_inst.tx_r_data === 0)
                $display("    *** CRITICAL FAIL: Data leaves Sequencer but doesn't come back! Check TOP wiring! ***");
            else if (DUT.sequencer_inst.r_data_img === 0)
                $display("    *** FAIL: Sequencer logic is blocking the data (Output is 0). ***");
            else
                $display("    *** SUCCESS: Internal Data Path is CLEAR! ***");
            $display("----------------------------------------------------------\n");
        end
    end

    // =========================================================================
    // 4. תהליך הבדיקה
    // =========================================================================
    initial begin
        RX_LINE = 1;
        rst_n = 0;
        #200;
        rst_n = 1;
        #1000;
        
        $display("\n=== STARTING IMG REGISTER DEBUG ===\n");

        // שלב א': כתיבה לרגיסטר הסטטוס
        // IMG_READY = 1 (Bit 20)
        // Data = 0x00100000
        write_reg(ADDR_IMG_STATUS, 32'h00100000);
        #5000;

        // שלב ב': קריאה מרגיסטר הסטטוס
        // אנו מצפים לראות את ה-SPY מדפיס את המידע
        read_reg(ADDR_IMG_STATUS);
        #10000;

        // שלב ג': בדיקת רגיסטר Monitor (שאמור להיות 0 או ערך התחלתי)
        read_reg(ADDR_IMG_MON);
        #10000;

        $display("\n=== TEST FINISHED ===");
        $finish;
    end

endmodule