`timescale 1ns / 1ps
`include "top_pkg.svh" 

module tb_seq_pixel;

    // ==========================================
    // 1. הגדרת אותות ושעונים
    // ==========================================
    localparam CLK_PERIOD = 10; // 100MHz

    // אותות כניסה (חייבים להיות reg/logic כדי שנוכל לשלוט בהם)
    logic clk;
    logic rst_n;
    
    // סימולציה של Msg Parser
    logic wr_pixel;
    logic [23:0] i_pixel_data;
    logic [23:0] addr;
    
    // סימולציה של TX MAC
    logic tx_mac_ready;
    logic tx_mac_done;

    // כניסות נוספות ל-Sequencer (נאפס אותן כדי למנוע X)
    logic btnc_r;
    logic wr_en;
    logic img_sel_r;
    logic [31:0] w_data;
    logic read_cmd;
    logic [31:0] r_data_msg;

    // יציאות (Wires)
    wire [TX_FRAME_LEN-1:0] tx_mac_vec;
    wire tx_mac_str;
    wire o_rts;
    
    // יציאות הזיכרון (רק כדי לראות ב-Wave)
    wire mem_done;
    wire [WORD_WIDTH-1:0] o_red, o_green, o_blue;

    // ==========================================
    // 2. חיבור הרכיבים (DUTs)
    // ==========================================
    
    // --- Sequencer ---
    sequencer DUT_SEQ (
        // System
        .clk(clk),
        .rst_n(rst_n),
        .w_clk(clk),     // בטסט פשוט נחבר את כולם לאותו שעון
        .w_rst_n(rst_n),
        .r_clk(clk),
        .r_rst_n(rst_n),
        
        // Inputs we drive
        .wr_pixel(wr_pixel),
        .i_pixel_data(i_pixel_data),
        .addr(addr),
        .tx_mac_ready(tx_mac_ready),
        .tx_mac_done(tx_mac_done),
        
        // Unused inputs (Must be tied to 0!)
        .btnc_r(btnc_r),
        .wr_en(wr_en),
        .img_sel_r(img_sel_r),
        .w_data(w_data),
        .read_cmd(read_cmd),
        .r_data_msg(r_data_msg),
        
        // Outputs
        .tx_mac_vec(tx_mac_vec),
        .tx_mac_str(tx_mac_str),
        .o_rts(o_rts),
        
        // יציאות אחרות (אם יש) נשאיר פתוחות
        .r_data_fifo(),
        .r_data_img(),
        .ready(),
        .read(),
        .trans(),
        .comp()
    );

    // ==========================================
    // 3. יצירת שעון
    // ==========================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ==========================================
    // 4. התסריט (Stimulus)
    // ==========================================
    initial begin
        // --- שלב א: אתחול מוחלט (מניעת X) ---
        rst_n = 0;         // ריסט פעיל
        wr_pixel = 0;
        i_pixel_data = 0;
        addr = 0;
        tx_mac_ready = 1;  // ה-MAC מוכן
        tx_mac_done = 0;
        
        // אפוס כניסות לא בשימוש
        btnc_r = 0;
        wr_en = 0;
        img_sel_r = 0;
        w_data = 0;
        read_cmd = 0;
        r_data_msg = 0;

        // החזקת הריסט למספיק זמן
        $display("[TB] Applying Reset...");
        repeat(10) @(posedge clk);
        rst_n = 1;         // שחרור ריסט
        repeat(10) @(posedge clk);
        $display("[TB] Reset Released.");

        // --- שלב ב: כתיבת פיקסל ---
        $display("[TB] Sending Pixel Write Request...");
        
        // 1. הכנת המידע (כתובת 0, צבע סגול)
        addr = 24'h000000;
        i_pixel_data = 24'hFF00FF; 
        
        // 2. הפעלת הטריגר (Pulse)
        @(posedge clk);
        wr_pixel = 1;
        @(posedge clk);
        wr_pixel = 0;
        
        // --- שלב ג: המתנה לתוצאות ---
        $display("[TB] Waiting for Sequencer Response...");

        // נחכה לראות אם tx_mac_str עולה ל-1
        // (זה אומר שה-Sequencer בנה הודעה ורוצה לשלוח אותה)
        wait(tx_mac_str == 1);
        
        $display("[TB] SUCCESS! Sequencer triggered tx_mac_str.");
        $display("[TB] Data to send: %h", tx_mac_vec);
        
        // בדיקה שההודעה מתחילה ב-'{' (0x7B) ונגמרת ב-'}' (0x7D)
        // שים לב: המיקומים תלויים ב-TX_FRAME_LEN שלך
        
        // --- שלב ד: סיום הטרנזקציה ---
        @(posedge clk);
        tx_mac_ready = 0; // ה-MAC עסוק בשליחה
        
        repeat(20) @(posedge clk); // זמן שידור מדומיין
        
        tx_mac_done = 1;  // ה-MAC סיים
        @(posedge clk);
        tx_mac_done = 0;
        tx_mac_ready = 1; // מוכן שוב

        repeat(10) @(posedge clk);
        $display("[TB] Test Finished Successfully.");
        $finish;
    end

endmodule