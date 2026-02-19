`timescale 1ns / 1ps
`include "top_pkg.svh"

module pixel_mem (
    input logic clk,
    input logic rst_n,
    input logic i_almost_full,
    input logic comp,
    input logic wr_pixel,
    input logic [3*BYTE_LEN-1:0] i_pixel_addr,
    input logic [3*BYTE_LEN-1:0] i_pixel_data,
    
    output logic [WORD_WIDTH-1:0] o_red_data,
    output logic [WORD_WIDTH-1:0] o_green_data,
    output logic [WORD_WIDTH-1:0] o_blue_data,
    
    output logic pixel_pkt_load,
    output logic [9:0] row_index,
    output logic [9:0] col_index,
    output logic o_done
);

  // קבועי�? לחיתוך המילה (Word slicing)
  localparam int PIXEL_INX_0_H = 4 * BYTE_LEN - 1;
  localparam int PIXEL_INX_0_L = 3 * BYTE_LEN;
  localparam int PIXEL_INX_1_H = 3 * BYTE_LEN - 1;
  localparam int PIXEL_INX_1_L = 2 * BYTE_LEN;
  localparam int PIXEL_INX_2_H = 2 * BYTE_LEN - 1;
  localparam int PIXEL_INX_2_L = BYTE_LEN;
  localparam int PIXEL_INX_3_H = BYTE_LEN - 1;
  localparam int PIXEL_INX_3_L = 0;

  // הגדרת הזיכרון
  logic [WORD_WIDTH-1:0] red_rom   [0 : MEM_MAX_ROW + 4];
  logic [WORD_WIDTH-1:0] green_rom [0 : MEM_MAX_ROW + 4];
  logic [WORD_WIDTH-1:0] blue_rom  [0 : MEM_MAX_ROW + 4];


  // משתני עזר
  logic [1:0] cycle_cnt;
  logic [$clog2(MEM_MAX_ROW)+1:0] read_addr; // שיניתי �?ת הש�? ל-read_addr למען הבהירות
  
  // לוגיקה לחישוב כתובת כתיבה
  logic [31:0] col_temp;
  logic [1:0] col_mod;
  logic [$clog2(MEM_MAX_ROW)+1:0] write_addr; // הכתובת בזיכרון ש�?ליה כותבי�?

  // טעינת תמונה התחלתית (�?ופציונלי)
  initial begin
    $readmemh(PIXEL_MEM_RED, red_rom);
    $readmemh(PIXEL_MEM_GREEN, green_rom);
    $readmemh(PIXEL_MEM_BLUE, blue_rom);
  end

  // =================================================================
  // לוגיקה צירופית לחישוב כתובות
  // =================================================================
  assign col_temp = (i_pixel_addr >> 2);
  assign col_mod  = col_temp[1:0];
  
  // המרת כתובת לינ�?רית (פיקסלי�?) לכתובת זיכרון (שורות של 4 פיקסלי�?)
  assign write_addr = i_pixel_addr[3*BYTE_LEN-1:2]; 

  // =================================================================
  // לוגיקה סינכרונית (כתיבה וקרי�?ה)
  // =================================================================
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      o_red_data     <= '0;
      o_green_data   <= '0;
      o_blue_data    <= '0;
      cycle_cnt      <= '0;
      pixel_pkt_load <= 0;
      read_addr      <= '0;
      
      o_done         <= 0;
      row_index      <= '0;
      col_index      <= '0;
    end else begin
      
      // ------------------------------------
      // Priority 1: Write Single Pixel
      // ------------------------------------
      if (wr_pixel) begin
        unique case (col_mod)
          2'b00: begin
            red_rom[write_addr][PIXEL_INX_0_H:PIXEL_INX_0_L]   <= i_pixel_data[3*BYTE_LEN-1:2*BYTE_LEN];
            green_rom[write_addr][PIXEL_INX_0_H:PIXEL_INX_0_L] <= i_pixel_data[2*BYTE_LEN-1:BYTE_LEN];
            blue_rom[write_addr][PIXEL_INX_0_H:PIXEL_INX_0_L]  <= i_pixel_data[BYTE_LEN-1:0];
          end
          2'b01: begin
            red_rom[write_addr][PIXEL_INX_1_H:PIXEL_INX_1_L]   <= i_pixel_data[3*BYTE_LEN-1:2*BYTE_LEN];
            green_rom[write_addr][PIXEL_INX_1_H:PIXEL_INX_1_L] <= i_pixel_data[2*BYTE_LEN-1:BYTE_LEN];
            blue_rom[write_addr][PIXEL_INX_1_H:PIXEL_INX_1_L]  <= i_pixel_data[BYTE_LEN-1:0];
          end
          2'b10: begin
            red_rom[write_addr][PIXEL_INX_2_H:PIXEL_INX_2_L]   <= i_pixel_data[3*BYTE_LEN-1:2*BYTE_LEN];
            green_rom[write_addr][PIXEL_INX_2_H:PIXEL_INX_2_L] <= i_pixel_data[2*BYTE_LEN-1:BYTE_LEN];
            blue_rom[write_addr][PIXEL_INX_2_H:PIXEL_INX_2_L]  <= i_pixel_data[BYTE_LEN-1:0];
          end
          2'b11: begin
            red_rom[write_addr][PIXEL_INX_3_H:PIXEL_INX_3_L]   <= i_pixel_data[3*BYTE_LEN-1:2*BYTE_LEN];
            green_rom[write_addr][PIXEL_INX_3_H:PIXEL_INX_3_L] <= i_pixel_data[2*BYTE_LEN-1:BYTE_LEN];
            blue_rom[write_addr][PIXEL_INX_3_H:PIXEL_INX_3_L]  <= i_pixel_data[BYTE_LEN-1:0];
          end
        endcase

        o_done    <= 1'b1;
        row_index <= i_pixel_addr[ROW_WIDTH+COL_WIDTH-1:COL_WIDTH];
        col_index <= i_pixel_addr[COL_WIDTH-1:0];

      end else begin
        o_done    <= 1'b0;
        row_index <= '0;
        col_index <= '0;

        // ------------------------------------
        // Priority 2: Burst Read Logic
        // ------------------------------------
        if (!i_almost_full) begin
          if (cycle_cnt == 3) begin
            o_red_data   <= red_rom[read_addr];
            o_green_data <= green_rom[read_addr];
            o_blue_data  <= blue_rom[read_addr];

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
      end

      // ------------------------------------
      // Reset Read Address on Completion
      // ------------------------------------
      if (comp) begin
        read_addr <= '0;
      end
      
    end
  end

endmodule

// `timescale 1ns / 1ps
// `include "top_pkg.svh"

// module pixel_mem (
//     input logic clk,
//     input logic rst_n,
//     input logic i_almost_full,
//     input logic comp,
//     input logic wr_pixel,
//     input logic [3*BYTE_LEN-1:0] i_pixel_addr,
//     input logic [3*BYTE_LEN-1:0] i_pixel_data,
//     output logic [WORD_WIDTH-1:0] o_red_data,
//     output logic [WORD_WIDTH-1:0] o_green_data,
//     output logic [WORD_WIDTH-1:0] o_blue_data,
//     output logic pixel_pkt_load,
//     output logic [ROW_WIDTH-1:0] row_index,
//     output logic [COL_WIDTH-1:0] col_index,
//     output logic o_done
// );

//   localparam int PIXEL_INX_0_H = 4 * BYTE_LEN - 1;
//   localparam int PIXEL_INX_0_L = 3 * BYTE_LEN;
//   localparam int PIXEL_INX_1_H = 3 * BYTE_LEN - 1;
//   localparam int PIXEL_INX_1_L = 2 * BYTE_LEN;
//   localparam int PIXEL_INX_2_H = 2 * BYTE_LEN - 1;
//   localparam int PIXEL_INX_2_L = BYTE_LEN;
//   localparam int PIXEL_INX_3_H = BYTE_LEN - 1;
//   localparam int PIXEL_INX_3_L = 0;

//   logic [WORD_WIDTH-1:0] red_rom   [0 : MEM_MAX_ROW + 4];
//   logic [WORD_WIDTH-1:0] green_rom [0 : MEM_MAX_ROW + 4];
//   logic [WORD_WIDTH-1:0] blue_rom  [0 : MEM_MAX_ROW + 4];

//   logic [1:0] cycle_cnt;
//   logic [$clog2(MEM_MAX_ROW)+1:0] addr;
//   logic [23:0] col_temp;
//   logic [1:0] col_mod;


//   initial begin
//     $readmemh(PIXEL_MEM_RED, red_rom);
//     $readmemh(PIXEL_MEM_GREEN, green_rom);
//     $readmemh(PIXEL_MEM_BLUE, blue_rom);
//   end
//   // =================================================================


//   always_ff @(posedge clk) begin
//     if (!rst_n) begin
//       o_red_data     <= '0;
//       o_green_data   <= '0;
//       o_blue_data    <= '0;
//       cycle_cnt      <= '0;
//       pixel_pkt_load <= 0;
//       addr           <= '0;
//     end else 
//        if (wr_pixel) begin
//       unique case (col_mod)
//         2'b00: begin
//           red_rom[i_pixel_addr[PIXEL_INX_0_H:PIXEL_INX_0_L]]   <= i_pixel_data[3*BYTE_LEN-1:2*BYTE_LEN];
//           green_rom[i_pixel_addr[PIXEL_INX_0_H:PIXEL_INX_0_L]] <= i_pixel_data[2*BYTE_LEN-1:BYTE_LEN];
//           blue_rom[i_pixel_addr[PIXEL_INX_0_H:PIXEL_INX_0_L]] <= i_pixel_data[BYTE_LEN-1:0];
//         end
//         2'b01: begin
//           red_rom[i_pixel_addr[PIXEL_INX_1_H:PIXEL_INX_1_L]]   <= i_pixel_data[3*BYTE_LEN-1:2*BYTE_LEN];
//           green_rom[i_pixel_addr[PIXEL_INX_1_H:PIXEL_INX_1_L]] <= i_pixel_data[2*BYTE_LEN-1:BYTE_LEN];
//           blue_rom[i_pixel_addr[PIXEL_INX_1_H:PIXEL_INX_1_L]] <= i_pixel_data[BYTE_LEN-1:0];
//         end
//         2'b10: begin
//           red_rom[i_pixel_addr[PIXEL_INX_2_H:PIXEL_INX_2_L]]   <= i_pixel_data[3*BYTE_LEN-1:2*BYTE_LEN];
//           green_rom[i_pixel_addr[PIXEL_INX_2_H:PIXEL_INX_2_L]] <= i_pixel_data[2*BYTE_LEN-1:BYTE_LEN];
//           blue_rom[i_pixel_addr[PIXEL_INX_2_H:PIXEL_INX_2_L]] <= i_pixel_data[BYTE_LEN-1:0];
//         end
//         2'b11: begin
//           red_rom[i_pixel_addr[PIXEL_INX_3_H:PIXEL_INX_3_L]]   <= i_pixel_data[3*BYTE_LEN-1:2*BYTE_LEN];
//           green_rom[i_pixel_addr[PIXEL_INX_3_H:PIXEL_INX_3_L]] <= i_pixel_data[2*BYTE_LEN-1:BYTE_LEN];
//           blue_rom[i_pixel_addr[PIXEL_INX_3_H:PIXEL_INX_3_L]] <= i_pixel_data[BYTE_LEN-1:0];
//         end
//       endcase

//       o_done    <= 1'b1;
//       row_index <= i_pixel_addr[ROW_WIDTH+COL_WIDTH-1:COL_WIDTH];
//       col_index <= i_pixel_addr[COL_WIDTH-1:0];

//     end else begin
//       o_done    <= 1'b0;
//       row_index <= '0;
//       col_index <= '0;
//     end else if (!i_almost_full && !o_done) begin
//       if (cycle_cnt == 3) begin
//         o_red_data <= red_rom[addr];
//         o_green_data <= green_rom[addr];
//         o_blue_data <= blue_rom[addr];

//         pixel_pkt_load <= 1;
//         addr <= addr + 1;
//         cycle_cnt <= 0;
//       end else begin
//         cycle_cnt      <= cycle_cnt + 1;
//         addr           <= addr;
//         pixel_pkt_load <= 0;
//       end
//     end else begin
//       if (comp) addr <= '0;
//       pixel_pkt_load <= 0;
//     end
//     end
  

//   // הלוגיקה הצירופית נש�?רת בחוץ
//   assign col_temp = (i_pixel_addr >> 2);
//   assign col_mod  = col_temp[1:0];

// endmodule





