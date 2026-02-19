`timescale 1ns / 1ps

module pixel_mem #(
    parameter int DATA_WIDTH = 8,
    parameter string PIXEL_MEM_RED = "red_hex.mem",
    parameter string PIXEL_MEM_GREEN = "green_hex.mem",
    parameter string PIXEL_MEM_BLUE  = "blue_hex.mem",
    parameter int IMG_H = 256,
    parameter int IMG_W = 256,
    parameter int PIXEL_NUM = (IMG_H * IMG_W)/4
) (
    input logic clk,
    input logic rst_n,
    input logic i_almost_full,
    input  logic [9:0]              i_img_size, // שים לב: זה צריך להיות רחב מספיק לכתובת
    output logic [4*DATA_WIDTH-1:0] o_red_data,
    output logic [4*DATA_WIDTH-1:0] o_green_data,
    output logic [4*DATA_WIDTH-1:0] o_blue_data,
    output logic pixel_pkt_load,
    output logic o_done
);

  // הוספת Padding (+4) כדי למנוע קריסה בגישה ל-addr+3 בסוף הזיכרון
  logic [DATA_WIDTH-1:0] red_rom   [0 : PIXEL_NUM + 4];
  logic [DATA_WIDTH-1:0] green_rom [0 : PIXEL_NUM + 4];
  logic [DATA_WIDTH-1:0] blue_rom  [0 : PIXEL_NUM + 4];

  logic [1:0] cycle_cnt;
  // רוחב הכתובת מחושב אוטומטית לפי כמות הפיקסלים
  logic [$clog2(PIXEL_NUM)+1:0] addr;

  // =================================================================
  // יצירת תוכן הזיכרון באופן ידני (ללא קבצים)
  // =================================================================
  initial begin

    $readmemh(PIXEL_MEM_RED, red_rom);
    $readmemh(PIXEL_MEM_GREEN, green_rom);
    $readmemh(PIXEL_MEM_BLUE, blue_rom);
    // integer i;
    // for (i = 0; i < PIXEL_NUM + 4; i = i + 1) begin
    //     red_rom[i]   = 8'h00;
    //     green_rom[i] = 8'h00;
    //     blue_rom[i]  = 8'h00;
    // end

    // for (i = 0; i < PIXEL_NUM; i = i + 1) begin
    //     red_rom[i]   = i[7:0]; 
    //     if ((i % 32) < 16) 
    //         green_rom[i] = 8'hFF; 
    //     else 
    //         green_rom[i] = 8'h00; 
    //     if (i < (PIXEL_NUM / 2)) 
    //         blue_rom[i] = 8'h80; 
    //     else 
    //         blue_rom[i] = 8'h00;
    // end
  end
  // =================================================================

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      o_red_data     <= '0;
      o_green_data   <= '0;
      o_blue_data    <= '0;
      cycle_cnt      <= '0;
      pixel_pkt_load <= 0;
      addr           <= '0;
    end else if (!i_almost_full && !o_done) begin
      if (cycle_cnt == 3) begin
        o_red_data <= {red_rom[addr], red_rom[addr+1], red_rom[addr+2], red_rom[addr+3]};
        o_green_data <= {green_rom[addr], green_rom[addr+1], green_rom[addr+2], green_rom[addr+3]};
        o_blue_data <= {blue_rom[addr], blue_rom[addr+1], blue_rom[addr+2], blue_rom[addr+3]};

        pixel_pkt_load <= 1;
        addr <= addr + 4;
        cycle_cnt <= 0;
      end else begin
        cycle_cnt      <= cycle_cnt + 1;
        addr           <= addr;
        pixel_pkt_load <= 0;
      end
    end else begin
      pixel_pkt_load <= 0;
    end
  end

  assign o_done = (addr >= PIXEL_NUM) ? 1'b1 : 1'b0;

endmodule



