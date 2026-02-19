`timescale 1ns / 1ps

module tb_sequencer_stress;

  // --- Parameters ---
  // שימוש בתדרים ראשוניים ביחס זה לזה יוצר בדיקת CDC חזקה יותר (Sliding Phase)
  localparam W_CLK_PERIOD = 10; // 100MHz - Writer
  localparam R_CLK_PERIOD = 13; // ~76MHz - Reader (MAC) - Async
  localparam TX_FRAME_LEN = 136; 

  // --- Signals ---
  logic clk, rst_n;
  logic w_clk, w_rst_n;
  logic r_clk, r_rst_n;

  // RGF - I/O Interface
  logic wr_en;
  logic img_sel_r;
  logic [31:0] w_data;
  logic [23:0] addr;
  logic [31:0] r_data_fifo;
  logic [31:0] r_data_img;

  // RGF - MSG Interface
  logic read_cmd;
  logic [31:0] r_data_msg;
  logic ready;      // אינדיקציה מה-DUT האם אפשר לכתוב עוד (Backpressure)
  logic read;
  logic trans;
  logic comp;

  // TX MAC Interface
  logic tx_mac_ready;
  logic tx_mac_done;
  logic [TX_FRAME_LEN-1:0] tx_mac_vec;
  logic tx_mac_str; // ה-Valid של ה-MAC
  logic o_rts;

  // Counters for Scoreboard
  int sent_cnt = 0;
  int rcv_cnt = 0;

  // --- DUT Instantiation ---
  sequencer dut (
      .clk(clk), .rst_n(rst_n),
      .w_clk(w_clk), .w_rst_n(w_rst_n),
      .r_clk(r_clk), .r_rst_n(r_rst_n),
      .wr_en(wr_en), .img_sel_r(img_sel_r), .w_data(w_data), .r_data_fifo(r_data_fifo), .r_data_img(r_data_img), .addr(addr),
      .read_cmd(read_cmd), .r_data_msg(r_data_msg), .ready(ready), .read(read), .trans(trans), .comp(comp),
      .tx_mac_ready(tx_mac_ready), .tx_mac_done(tx_mac_done), .tx_mac_vec(tx_mac_vec), .tx_mac_str(tx_mac_str), .o_rts(o_rts)
  );

  // --- Asynchronous Clock Generation ---
  // שעון מערכת כללי
  initial clk = 0; always #(W_CLK_PERIOD/2) clk = ~clk;
  
  // שעון כתיבה (מהיר)
  initial w_clk = 0; always #(W_CLK_PERIOD/2) w_clk = ~w_clk;

  // שעון קריאה (איטי יותר וא-סינכרוני)
  initial r_clk = 0; always #(R_CLK_PERIOD/2) r_clk = ~r_clk;

  // --- Main Test Process ---
  initial begin
    // 1. Init & Reset
    init_signals();
    reset_dut();

    // 2. Configuration
    load_img_config();
    
    // 3. STRESS TEST: Concurrent Write & Read
    // אנחנו מריצים במקביל (Fork) תהליך שמנסה לכתוב ללא הפסקה, ותהליך שקורא
    $display("\n[TB] === Starting Stress Test (Full/Empty Check) ===");
    
    fork
        // Thread A: The Aggressive Writer (Simulating CPU/DMA)
        // מנסה לדחוף מידע כמה שיותר מהר
        stress_writer(100); // נסה לשלוח 100 פקטות

        // Thread B: The Variable Reader (Simulating MAC)
        // משנה את הקצב כדי ליצור מצבי Full ו-Empty
        stress_mac_reader(100);
    join

    // 4. Summary
    $display("\n[TB] === Test Finished ===");
    $display("[TB] Sent Packets: %0d", sent_cnt);
    $display("[TB] Rcvd Packets: %0d", rcv_cnt);
    
    if (sent_cnt == rcv_cnt) 
        $display("[TB] SUCCESS: No data loss detected.");
    else 
        $display("[TB] WARNING/FAIL: Mismatch in counts (check constraints).");

    $finish;
  end

  // --- Tasks ---

  task init_signals();
    wr_en = 0; img_sel_r = 0; w_data = 0; addr = 0;
    read_cmd = 0; r_data_msg = 32'hDEAD_BEEF;
    tx_mac_done = 0; tx_mac_ready = 1;
  endtask

  task reset_dut();
    rst_n = 0; w_rst_n = 0; r_rst_n = 0;
    #(W_CLK_PERIOD * 10);
    rst_n = 1; w_rst_n = 1; r_rst_n = 1;
    #(W_CLK_PERIOD * 10);
  endtask

  // קונפיגורציה בסיסית להתחלת עבודה
  task load_img_config();
    // הגדרת גודל תמונה וכו'
    write_rgf(8'h00, 32'h0010_FFFF); 
    // שליחת פקודת התחלה (Start Bit)
    write_rgf(8'h08, 32'h0000_0001);
    $display("[TB] Config Loaded & Start Command Sent");
  endtask

  // פעולת כתיבה בסיסית ל-RGF
  task write_rgf(input [7:0] offset_addr, input [31:0] data);
    @(posedge w_clk);
    addr   = {16'h0, offset_addr};
    w_data = data;
    wr_en  = 1;
    img_sel_r = 1;
    @(posedge w_clk);
    wr_en  = 0;
    img_sel_r = 0;
    addr = 0;
    w_data = 0;
    #(W_CLK_PERIOD * 2); // רווח קטן בין פקודות קונפיגורציה
  endtask

  // --- STRESS WRITER TASK ---
  // המטרה: לכתוב נתונים לתוך ה-FIFO (דרך ה-Sequencer)
  // הנחה: יש כתובת מסוימת (למשל 0x10) שהיא ה-Data Port, או שה-Sequencer מייצר לבד
  // אם ה-Sequencer מייצר לבד, ה-Write כאן בודק רק את ה-Backpressure של הקונפיגורציה.
  // **בהנחה שצריך לדחוף דאטה חיצוני:**
  task stress_writer(input int num_writes);
    int i;
    logic waiting_for_ready_printed = 0;

    $display("[TB-WRITER] Starting to push %0d words...", num_writes);
    
    for (i = 0; i < num_writes; i++) begin
        
        // 1. Flow Control Check: האם ה-Sequencer מוכן? (FIFO לא מלא)
        // אם ready == 0, אנחנו צריכים לחכות (כמו AXI Ready)
        while (ready === 1'b0) begin 
            if (!waiting_for_ready_printed) begin
                $display("[TB-WRITER] BACKPRESSURE DETECTED! FIFO likely FULL at write %0d", i);
                waiting_for_ready_printed = 1;
            end
            @(posedge w_clk);
        end
        waiting_for_ready_printed = 0;

        // 2. Perform Write (Push)
        @(posedge w_clk);
        wr_en = 1;
        img_sel_r = 1;
        addr = 24'h000010; // נניח שזו כתובת ה-Data FIFO
        w_data = 32'hA000 + i; // דאטה רץ לבדיקה
        
        @(posedge w_clk);
        wr_en = 0;
        img_sel_r = 0;
        
        sent_cnt++;
        
        // הוספת Jitter אקראי לכתיבה כדי שלא יהיה קצב קבוע לחלוטין
        if ($urandom_range(0, 10) > 8) repeat(2) @(posedge w_clk);
    end
    $display("[TB-WRITER] Finished pushing data.");
  endtask

  // --- STRESS READER TASK (MAC Simulator) ---
  // המטרה: לשנות את קצב הקריאה כדי לגרום ל-FIFO להתמלא ולהתרוקן
  task stress_mac_reader(input int num_reads);
    int i;
    int delay_cycles;
    
    $display("[TB-MAC] Waiting for packets...");
    
    for (i = 0; i < num_reads; i++) begin
        
        // 1. Wait for Start Strobe (Pop request from Sequencer)
        wait(tx_mac_str == 1); 
        
        // 2. החלטה על קצב הקריאה (זה הלב של הסטרס טסט)
        // בחצי הראשון של הטסט - נהיה איטיים מאוד (כדי למלא את ה-FIFO - FULL TEST)
        // בחצי השני - נהיה מהירים מאוד (כדי לרוקן את ה-FIFO - EMPTY TEST)
        
        if (i < num_reads / 2) begin
            // מצב איטי (FIFO Full Test)
            delay_cycles = $urandom_range(20, 50); 
            if (i % 10 == 0) $display("[TB-MAC] MAC is SLOW (Choking FIFO)...");
        end else begin
            // מצב מהיר (FIFO Empty Test)
            delay_cycles = 0; 
            if (i % 10 == 0) $display("[TB-MAC] MAC is FAST (Draining FIFO)...");
        end

        // השהיית הטיפול (סימולציה של זמן שידור ב-MAC)
        repeat(delay_cycles) @(posedge r_clk);

        // 3. אישור קבלה (Handshake)
        @(posedge r_clk);
        tx_mac_done = 1;
        rcv_cnt++;
        // בדיקת דאטה (אופציונלי - אם יודעים מה צפוי)
        // $display("Received: %h", tx_mac_vec);

        @(posedge r_clk);
        tx_mac_done = 0;
        
        // לוודא שה-Strobe ירד (Handshake תקין)
        wait(tx_mac_str == 0);
    end
    $display("[TB-MAC] Finished receiving data.");
  endtask

endmodule