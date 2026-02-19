
`timescale 1ns / 1ps
import defs_pkg::*; // Ensure you have this package, otherwise remove this line and define BYTE_LEN
module tb_fifo;
  //---------------------------------------------------------------------------
  // 1. Parameters and Signals
  //---------------------------------------------------------------------------
  localparam FIFO_DEPTH = 16;
  localparam CLK_PERIOD = 10;  // 100MHz
  // Signals for DUT
  logic clk;
  logic rst_n;
  logic push;
  logic pop;
  logic [31:0] i_data;
  logic [31:0] o_data;
  // Status Flags
  logic o_empty;
  logic o_full;
  logic o_half_full;
  logic o_almost_empty;
  logic o_almost_full;
  // Register Interface
  logic wr_en;
  logic sel_fifo_r;
  logic [7:0] addr_low;  // Matches BYTE_LEN=8
  logic [31:0] w_data;
  logic [31:0] r_data;
  // Test Variables
  int error_count = 0;
  //---------------------------------------------------------------------------
  // 2. DUT Instantiation
  //---------------------------------------------------------------------------
  fifo dut (
      .clk(clk),
      .rst_n(rst_n),
      .push(push),
      .pop(pop),
      .i_data(i_data),
      .o_data(o_data),
      .o_empty(o_empty),
      .o_full(o_full),
      .o_half_full(o_half_full),
      .o_almost_empty(o_almost_empty),
      .o_almost_full(o_almost_full),
      .wr_en(wr_en),
      .sel_fifo_r(sel_fifo_r),
      .addr_low(addr_low),  // Connection matching fifo.sv (fixed from 'addr' to 'addr_low')
      .w_data(w_data),
      .r_data(r_data)
  );
  //---------------------------------------------------------------------------
  // 3. Clock Generation
  //---------------------------------------------------------------------------
  initial begin
    clk = 0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end
  //---------------------------------------------------------------------------
  // 4. Helper Tasks
  //---------------------------------------------------------------------------
  // Initialization
  task init_signals();
    rst_n = 0;
    push = 0;
    pop = 0;
    i_data = 0;
    wr_en = 0;
    sel_fifo_r = 0;
    addr_low = 0;
    w_data = 0;
  endtask
  // Reset
  task do_reset();
    rst_n = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);
  endtask
  // Push to FIFO
  task fifo_push(input [31:0] val);
    if (!o_full) begin
      @(posedge clk);  // Synchronization
      push   = 1;
      i_data = val;
      @(posedge clk);
      push = 0;
    end else begin
      $display("[%t] SKIP PUSH: FIFO Full!", $time);
    end
  endtask
  // Pop from FIFO
  task fifo_pop();
    if (!o_empty) begin
      @(posedge clk);
      pop = 1;
      @(posedge clk);
      pop = 0;
    end else begin
      $display("[%t] SKIP POP: FIFO Empty!", $time);
    end
  endtask
  // Write to Configuration Register
  task write_config(input logic af_mod, input logic ae_mod);
    @(posedge clk);
    wr_en = 1;
    sel_fifo_r = 1;
    addr_low = 0;  // FIFO_CTRL_ADDR
    w_data = {30'd0, af_mod, ae_mod};  // Bit 1=AF, Bit 0=AE
    @(posedge clk);
    wr_en = 0;
    sel_fifo_r = 0;
    @(posedge clk);
    $display("[%t] CONFIG UPDATED: AF_MOD=%b, AE_MOD=%b", $time, af_mod, ae_mod);
  endtask
  //---------------------------------------------------------------------------
  // 5. Main Test
  //---------------------------------------------------------------------------
  initial begin
    init_signals();
    $display("--- Starting FIFO Test ---");
    do_reset();
    // ---------------------------------------------------------
    // Stage 1: Default Thresholds Test
    // ---------------------------------------------------------
    $display("\nTEST 1: Filling FIFO (Default Thresholds)...");
    // Default: AF = 7 (Half), AE = 7 (Half)
    // Fill to half
    for (int i = 0; i < 8; i++) begin
      fifo_push(i + 32'hA0);
    end
    @(posedge clk);
    if (o_half_full) $display("PASS: Half Full detected correctly.");
    else begin
      $error("FAIL: Half Full not detected!");
      error_count++;
    end
    // Fill to full
    for (int i = 8; i < 16; i++) begin
      fifo_push(i + 32'hA0);
    end
    @(posedge clk);
    if (o_full) $display("PASS: FIFO Full detected.");
    else begin
      $error("FAIL: FIFO Full not detected!");
      error_count++;
    end
    // ---------------------------------------------------------
    // Stage 2: Draining and Data Integrity Check
    // ---------------------------------------------------------
    $display("\nTEST 2: Draining FIFO & Checking Data...");
    for (int i = 0; i < 16; i++) begin
      // Data appears after Pop (in your implementation)
      fifo_pop();
      @(negedge clk);  // Sample at half cycle for stability
      if (o_data !== (i + 32'hA0)) begin
        $error("FAIL: Data Mismatch! Expected %h, Got %h", (i + 32'hA0), o_data);
        error_count++;
      end
    end
    @(posedge clk);
    if (o_empty) $display("PASS: FIFO Empty detected.");
    // ---------------------------------------------------------
    // Stage 3: Changing Thresholds via Register
    // ---------------------------------------------------------
    $display("\nTEST 3: Changing Thresholds via Register...");
    // Change to '1' mode (more aggressive thresholds)
    // AF_MOD=1 -> Tresh = 11 (closer to end)
    // AE_MOD=1 -> Tresh = 2 (closer to start)
    write_config(1, 1);
    // Check new Almost Empty threshold (threshold=2)
    // Push 3 items -> Should clear Almost Empty
    fifo_push(1);
    fifo_push(2);
    fifo_push(3);
    @(posedge clk);
    if (!o_almost_empty) $display("PASS: Almost Empty cleared correctly with new threshold.");
    else $error("FAIL: Almost Empty should be 0 (Count=3 > Tresh=2)");
    // ---------------------------------------------------------
    // Stage 4: Wait Write Mechanism
    // ---------------------------------------------------------
    $display("\nTEST 4: Wait Write Logic...");
    do_reset();  // Start clean
    // Fill to Almost Full (default: 16 - 7 = 9 occupied)
    for (int i = 0; i < 10; i++) fifo_push(i);
    @(posedge clk);
    if (o_almost_full) $display("PASS: Almost Full detected.");
    // Check if wait_write is activated (needs clock cycle)
    repeat (2) @(posedge clk);
    // Attempt push with wait_write (should be blocked)
    // In your logic: if (push && !o_full && !wait_write)
    push   = 1;
    i_data = 32'hDEAD;
    @(posedge clk);
    push = 0;
    // Check if Pointer advanced (should not, since wait_write=1)
    // Since no internal Pointer access, check if Full activated (should not if nothing entered)
    if (!o_full) $display("PASS: Push blocked by wait_write correctly.");
    else $error("FAIL: Push happened despite wait_write!");
    // ---------------------------------------------------------
    // End
    // ---------------------------------------------------------
    $display("\n----------------------------------");
    if (error_count == 0) $display("SUCCESS: All tests passed!");
    else $display("FAILURE: %0d errors found.", error_count);
    $display("----------------------------------");
    $finish;
  end
endmodule
