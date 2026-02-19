`timescale 1ns / 1ps

module tb_fifo_hysteresis;

  // ===========================================================================
  // 1. PARAMETERS & SIGNALS
  // ===========================================================================
  localparam FIFO_DEPTH = 32;
  localparam DATA_WIDTH = 32;
  localparam BYTE_LEN   = 8;
  
  // -- Clocks & Resets --
  logic w_clk, w_rst_n;
  logic r_clk, r_rst_n;

  // -- Write Interface --
  logic push;
  logic [DATA_WIDTH-1:0] i_data;
  wire o_full_w;
  wire o_almost_full_w; // This is our Flow Control flag

  // -- Read Interface --
  logic pop;
  wire [DATA_WIDTH-1:0] o_data;
  wire o_empty_r;
  wire o_almost_empty_r;
  wire o_half_full;

  // -- Config Interface --
  logic wr_en;
  logic sel_fifo_r;
  logic [BYTE_LEN-1:0] addr_low;
  logic [DATA_WIDTH-1:0] w_data;
  wire [DATA_WIDTH-1:0] r_data;

  // -- Scoreboard --
  logic [DATA_WIDTH-1:0] expected_q [$];
  int error_count = 0;

  // ===========================================================================
  // 2. DUT INSTANTIATION
  // ===========================================================================
  fifo_async dut (
    .w_clk(w_clk), .w_rst_n(w_rst_n),
    .r_clk(r_clk), .r_rst_n(r_rst_n),
    .push(push),
    .i_data(i_data),
    .o_full_w(o_full_w),
    .o_almost_full_w(o_almost_full_w),
    .pop(pop),
    .o_data(o_data),
    .o_empty_r(o_empty_r),
    .o_almost_empty_r(o_almost_empty_r),
    .o_half_full(o_half_full),
    .wr_en(wr_en), .sel_fifo_r(sel_fifo_r),
    .addr_low(addr_low), .w_data(w_data), .r_data(r_data)
  );

  // ===========================================================================
  // 3. CLOCK GENERATION
  // ===========================================================================
  initial w_clk = 0; always #5 w_clk = ~w_clk; // 100MHz
  initial r_clk = 0; always #7 r_clk = ~r_clk; // ~71MHz (Async)
    initial push = !o_almost_full_w; // ~71MHz (Async)

  // ===========================================================================
  // 4. TASKS
  // ===========================================================================

  task apply_reset();
    $display("\n[TB] --- Master Reset ---");
    w_rst_n = 0; r_rst_n = 0;
     pop = 0; wr_en = 0; i_data = 0;
    expected_q.delete();
    #100;
    w_rst_n = 1; r_rst_n = 1;
    #100;
  endtask

  // --- Task: Test Hysteresis Loop (Respecting o_almost_full_w) ---
  task test_hysteresis_loop();
    $display("\n=============================================");
    $display(" TEST: HYSTERESIS LOOP (Flow Control Check) ");
    $display("=============================================");
    $display("[TB] Step 1: Filling until o_almost_full_w asserts...");

    // 1. Fill until Almost Full
    while (!o_almost_full_w) begin
      @(posedge w_clk);
      
      i_data = $urandom();
      expected_q.push_back(i_data);
      @(posedge w_clk);
    
    end
    $display("[TB] -> Stop! o_almost_full_w is HIGH. Queue size: %0d", expected_q.size());

    // 2. Try to drain slightly and see if flag stays high (Hysteresis check)
    $display("[TB] Step 2: Draining 5 items. Expecting o_almost_full_w to STAY HIGH (Latching).");
    repeat(5) begin
        @(posedge r_clk);
        pop = 1;
        @(posedge r_clk);
        pop = 0;
        #1; // Wait for logic update
    end
    
    // Check signal in Write Domain (might need sync delay)
    repeat(4) @(posedge w_clk); 
    
    if (o_almost_full_w) 
        $display("[TB-PASS] Good! o_almost_full_w stayed HIGH despite draining (Hysteresis active).");
    else begin
        $error("[TB-FAIL] o_almost_full_w dropped too early! Hysteresis logic (wait_write) might be broken.");
        error_count++;
    end

    // 3. Drain until Almost Empty (Release point)
    $display("[TB] Step 3: Draining until o_almost_empty_r asserts...");
    while (!o_almost_empty_r && expected_q.size() > 0) begin // Safety break on size
        @(posedge r_clk);
      
        @(posedge r_clk);
      
        // Verify data logic omitted here for brevity, focus on flags
    end
    
    $display("[TB] -> Reached Almost Empty. Checking if Write Lock releases...");
    
    // Allow CDC sync (Empty R -> Wait Write W)
    repeat(10) @(posedge w_clk);

    if (!o_almost_full_w)
        $display("[TB-PASS] o_almost_full_w released! Writing can resume.");
    else begin
        $error("[TB-FAIL] o_almost_full_w stuck HIGH even after Empty!");
        error_count++;
    end
  endtask

  // --- Task: Test Physical Overflow (Ignoring Flow Control) ---
  task test_physical_overflow();
    $display("\n=============================================");
    $display(" TEST: PHYSICAL OVERFLOW (Push to the Edge) ");
    $display("=============================================");
    $display("[TB] Ignoring o_almost_full_w and pushing until o_full_w...");

    // Keep pushing until physically full
    while (!o_full_w) begin
        @(posedge w_clk);
       
        i_data = 32'hFFFF_FFFF; 
        @(posedge w_clk);
        push = 0;
    end
    
    $display("[TB] -> FIFO is Physically FULL (o_full_w = 1).");
    
    // Try one illegal write
    @(posedge w_clk);
 i_data = 32'hDEAD_DEAD;
    @(posedge w_clk);
   
    $display("[TB] Attempted write while o_full_w. Should be ignored.");
  endtask

  // ===========================================================================
  // 5. MAIN PROCESS
  // ===========================================================================
  initial begin
    apply_reset();

    // 1. Check the Hysteresis Logic (The "Protocol" view)
    test_hysteresis_loop();

    // Reset before next test
    apply_reset();

    // 2. Check the Physical Limits (The "Hardware" view)
    test_physical_overflow();

    // 3. Report
    $display("\n---------------------------------------");
    if (error_count == 0) $display("[TB] ALL TESTS PASSED");
    else $display("[TB] FAILED with %0d errors", error_count);
    $display("---------------------------------------");
    $finish;
  end

endmodule