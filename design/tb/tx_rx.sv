`timescale 1ns / 1ps

// הנחה: הקובץ top_pkg.svh קיים בפרויקט ומכיל את ההגדרות של RX_CLK_FREQ ו-BR16
// אם הוא לא קיים, יש להגדיר את הפרמטרים הללו ידנית או לכלול את הקובץ.
`include "top_pkg.svh"

module tb_rx;

    // ==========================================
    // הגדרת סיגנלים
    // ==========================================
    logic clk;
    logic rst_n;
    logic i_rx_line;
    
    // יציאות מה-DUT
    logic [7:0] o_rx_phy_vec;
    logic o_rx_phy_done;
    logic o_rx_mac_str;

    // ==========================================
    // פרמטרים לסימולציה
    // ==========================================
    localparam CLK_PERIOD = 4; // 100MHz Clock (10ns)
    
    // חישוב זמן ביט עבור Baud Rate של 115200 (כ-8.68 מיקרו שניות)
    // הערה: וודא שזה תואם להגדרות ב-top_pkg.svh שלך!
    localparam integer BAUD_RATE = 5_000_000; // 5Mbps, מהיר לסימולציה
    localparam integer BIT_PERIOD_NS = 1000000000 / BAUD_RATE; 

    // ==========================================
    // יצירת שעון (Clock Generation)
    // ==========================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ==========================================
    // חיבור ה-DUT (Device Under Test)
    // ==========================================
    Rx_phy_v0 uut (
        .clk(clk),
        .rst_n(rst_n),
        .i_rx_line(i_rx_line),
        .o_rx_phy_vec(o_rx_phy_vec),
        .o_rx_phy_done(o_rx_phy_done),
        .o_rx_mac_str(o_rx_mac_str)
    );

    // ==========================================
    // Task: שליחת בייט ב-UART
    // ==========================================
    // פונקציה זו מדמה את הצד המשדר (המחשב)
    task send_uart_byte(input logic [7:0] data);
        integer i;
        begin
            // 1. Start Bit (Low)
            i_rx_line = 1'b0;
            #(BIT_PERIOD_NS);
            
            // 2. Data Bits (0 to 7) - LSB First
            for (i = 0; i < 8; i = i + 1) begin
                i_rx_line = data[i];
                #(BIT_PERIOD_NS);
            end
            
            // 3. Stop Bit (High)
            i_rx_line = 1'b1;
            #(BIT_PERIOD_NS);
            
            // // מרווח קטן בין בייטים (אופציונלי)
            // #(BIT_PERIOD_NS * 2); 
        end
    endtask

    // ==========================================
    // הבלוק הראשי (Stimulus)
    // ==========================================
    initial begin
        // אתחול לקבצי Waveform (אם צריך)
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_rx);

        // 1. אתחול סיגנלים
        rst_n = 0;
        i_rx_line = 1; // קו UART במנוחה הוא '1' (High)
        
        // 2. שחרור Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        $display("Starting Simulation...");

        // 3. שליחת בייט ראשון: 0x55 (בינארי 01010101)
        // זהו דפוס טוב לבדיקת תזמונים כי הוא מחליף בין 0 ל-1
        $display("Sending Byte: 0x55");
        send_uart_byte(8'h55);

        // בדיקה שהתקבל נכון
        if (o_rx_phy_vec == 8'h55 && o_rx_phy_done) 
            $display("SUCCESS: Received 0x55 correctly.");
        else 
            $display("ERROR: Expected 0x55, got 0x%h", o_rx_phy_vec);

        
        // 4. המתנה קצרה ושליחת בייט שני: 0xA3
        #(1000); 
        $display("Sending Byte: 0xA3");
        send_uart_byte(8'hA3);

        // בדיקה שהתקבל נכון
        if (o_rx_phy_vec == 8'hA3 && o_rx_phy_done) 
            $display("SUCCESS: Received 0xA3 correctly.");
        else 
            $display("ERROR: Expected 0xA3, got 0x%h", o_rx_phy_vec);


        // 5. סיום סימולציה
        #(1000);
        $display("Simulation Finished.");
        $finish;
    end

endmodule