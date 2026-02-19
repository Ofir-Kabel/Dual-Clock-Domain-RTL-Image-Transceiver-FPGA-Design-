`timescale 1ns / 1ps
`include "top_pkg.svh"

module pixel_mem_v0 (
    input logic        clk,
    input logic        rst_n,
    input logic        i_almost_full,
    input logic        comp,
    input logic        img_ready,
    input logic        img_read,
    input logic        wr_pixel,       // Pulse: New pixel arrived
    input logic [23:0] i_pixel_data,   // {R, G, B} 8-bit each

    output logic [MEM_WIDTH-1:0] o_red_data,    // 32-bit word output
    output logic [MEM_WIDTH-1:0] o_green_data,
    output logic [MEM_WIDTH-1:0] o_blue_data,

    output logic pixel_pkt_load,
    output logic o_done_wr
);

  logic fifo_read_en;

  // --------------------------------------------------------
  // Memory Arrays (Block RAM inferred)
  // --------------------------------------------------------
  logic [WORD_WIDTH-1:0] red_rom[0 : MEM_MAX_ROW + 4];
  logic [WORD_WIDTH-1:0] green_rom[0 : MEM_MAX_ROW + 4];
  logic [WORD_WIDTH-1:0] blue_rom[0 : MEM_MAX_ROW + 4];
  logic [WORD_WIDTH-1:0] red_mem, green_mem, blue_mem;

  initial begin
    $readmemh(PIXEL_MEM_RED, red_rom);
    $readmemh(PIXEL_MEM_GREEN, green_rom);
    $readmemh(PIXEL_MEM_BLUE, blue_rom);
  end

  // --------------------------------------------------------
  // Internal Signals
  // --------------------------------------------------------
  logic [MEM_WIDTH-1:0] red_temp, green_temp, blue_temp;
  logic [                    2:0] pixel_cnt;  // 0..3 counter
  logic [$clog2(MEM_MAX_ROW)+1:0] write_addr;

  logic [                    1:0] cycle_cnt;
  logic [$clog2(MEM_MAX_ROW)+1:0] read_addr;

  logic                           wr_pulse;
  logic                           stage1;
  logic                           img_loaded;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) stage1 <= 0;
    else stage1 <= wr_pixel;
  end

  assign wr_pulse = wr_pixel & ~stage1;  // Detect rising edge of wr_pixel

  // --------------------------------------------------------
  // Main Process
  // --------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      o_red_data     <= '0;
      o_green_data   <= '0;
      o_blue_data    <= '0;
      cycle_cnt      <= '0;
      pixel_pkt_load <= 0;
      read_addr      <= '0;

      red_temp       <= '0;
      green_temp     <= '0;
      blue_temp      <= '0;
      write_addr     <= '0;
      pixel_cnt      <= '0;

    end else begin

      // ===========================
      // 1. WRITE LOGIC (Accumulate)
      // ===========================

      if (wr_pulse) begin
        case (pixel_cnt)
          2'd0: begin
            red_temp[31:24] <= i_pixel_data[23:16];
            green_temp[31:24] <= i_pixel_data[15:8];
            blue_temp[31:24] <= i_pixel_data[7:0];
            pixel_cnt <= 2'd1;
          end
          2'd1: begin
            red_temp[23:16] <= i_pixel_data[23:16];
            green_temp[23:16] <= i_pixel_data[15:8];
            blue_temp[23:16] <= i_pixel_data[7:0];
            pixel_cnt <= 2'd2;
          end
          2'd2: begin
            red_temp[15:8]    <= i_pixel_data[23:16];
            green_temp[15:8]  <= i_pixel_data[15:8];
            blue_temp[15:8]   <= i_pixel_data[7:0];
            pixel_cnt <= 2'd3;
          end
          2'd3: begin
            red_temp   <= '0;
            green_temp <= '0;
            blue_temp  <= '0;
            write_addr <= write_addr + 1;
            pixel_cnt  <= 2'd0;
          end
        endcase
      end

      // ===========================
      // 2. READ LOGIC (Burst)
      // ===========================
      if (!i_almost_full && fifo_read_en) begin
        if (cycle_cnt == 3) begin
          o_red_data     <= red_rom[read_addr];
          o_green_data   <= green_rom[read_addr];
          o_blue_data    <= blue_rom[read_addr];

          pixel_pkt_load <= 1;
          read_addr      <= read_addr + 1;
          cycle_cnt      <= 0;
        end else begin
          cycle_cnt      <= cycle_cnt + 1;
          pixel_pkt_load <= 0;
        end
      end else begin
        pixel_pkt_load <= 0;
      end

      if (comp) read_addr <= '0;
      if (img_read) write_addr <= '0;
    end
  end

  always_ff @(posedge clk) begin
    if (pixel_cnt == 2'd3 && wr_pulse) begin
      red_rom[write_addr]   <= {red_temp[31:8], i_pixel_data[23:16]};
      green_rom[write_addr] <= {green_temp[31:8], i_pixel_data[15:8]};
      blue_rom[write_addr]  <= {blue_temp[31:8], i_pixel_data[7:0]};
      red_mem  <= {red_temp[31:8], i_pixel_data[23:16]};
      green_mem <= {green_temp[31:8], i_pixel_data[15:8]};
      blue_mem  <= {blue_temp[31:8], i_pixel_data[7:0]};
    end
  end

  assign o_done_wr = (write_addr == MEM_MAX_ROW - 1);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) fifo_read_en <= 0;
    else if (img_ready) fifo_read_en <= 1'b1;
    else if (comp) fifo_read_en <= 0;
  end


endmodule
