`timescale 1ns/1ns
`include "top_pkg.svh"

module disp_decoder #(parameter MAX_DIGITS_DISP = 8)(
    input logic rst_n,
    input logic [7:0] shift_out,
    input logic [MAX_DIGITS_DISP*4-1:0] din,
    output logic [6:0] SEG7,
    output logic dot
);

logic [3:0] disp_dig;
logic space;

always_comb begin
    if (!rst_n) begin
        disp_dig = 4'b0000;
        dot = 1'b1; 
    end else begin
        unique case(shift_out)
            8'b11111110: begin
                disp_dig = din[3:0];    // '0'
                dot = 1'b1;
            end
            8'b11111101: begin
                disp_dig = din[7:4];    // '1'
                dot = 1'b1;
            end
            8'b11111011: begin
                disp_dig = din[11:8];   // '2'
                dot = 1'b0;
            end
            8'b11110111: begin
                disp_dig = din[15:12];  // '3'
                dot = 1'b1;              // dot ????? ???? ??
            end
            8'b11101111: begin
                disp_dig = din[19:16];  // '4'
                dot = 1'b0;
            end
            8'b11011111: begin
                disp_dig = din[23:20];  // '5'
                dot = 1'b1;
            end
            8'b10111111: begin
                disp_dig = din[27:24];  // '6'
                dot = 1'b0;
            end
            8'b01111111: begin
                disp_dig = din[31:28];  // '7'
                dot = 1'b1;
            end
            default: begin
                disp_dig = 4'b0000;
                dot = 1'b1;
            end
        endcase
    end
end

// //creating -- 8DIGIT: RX ROW,COL,--,PIXEL
// assign space = ((shift_out ==  8'b11111011 || shift_out ==  8'b11110111) && trans_type);

always_comb begin
    if(!rst_n)
        SEG7 = 7'b1111111;
    // else if(space)
    //     SEG7 = 7'b1111110;
    else
        unique case(disp_dig)
            4'h0: SEG7 = 7'b0000001; // '0'
            4'h1: SEG7 = 7'b1001111; // '1'
            4'h2: SEG7 = 7'b0010010; // '2'
            4'h3: SEG7 = 7'b0000110; // '3'
            4'h4: SEG7 = 7'b1001100; // '4'
            4'h5: SEG7 = 7'b0100100; // '5'
            4'h6: SEG7 = 7'b0100000; // '6'
            4'h7: SEG7 = 7'b0001111; // '7'
            4'h8: SEG7 = 7'b0000000; // '8'
            4'h9: SEG7 = 7'b0000100; // '9'
            4'hA: SEG7 = 7'b0001000; // 'A'
            4'hB: SEG7 = 7'b1100000; // 'b'
            4'hC: SEG7 = 7'b0110001; // 'C'
            4'hD: SEG7 = 7'b1000010; // 'd'
            4'hE: SEG7 = 7'b0110000; // 'E'
            4'hF: SEG7 = 7'b0111000; // 'F'
            default: SEG7 = 7'b1111111; // all off
        endcase
end


endmodule


