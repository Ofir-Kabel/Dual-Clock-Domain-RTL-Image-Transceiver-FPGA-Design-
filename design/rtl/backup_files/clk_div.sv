`timescale 1ns/1ns

module clk_div#(parameter CLK_OUT_FREQ = 500)(
    input logic clk,
    input logic rst_n,
    output logic clk_pulse_out
);

localparam MAX_COUNT = 100_000_000/CLK_OUT_FREQ;
logic [17:0] counter = 17'd0;
logic clk_en;

always_ff @(negedge clk or negedge rst_n) begin
    if(!rst_n)begin
        counter <=  17'd0;
        clk_en <= 1'b0;
    end else begin
        counter<=counter+1;
        if(counter == MAX_COUNT - 1)begin 
            clk_en<=1'b1;
            counter<=17'd0;
        end
        else begin
            clk_en <= 1'b0;
            counter <= counter + 1;
        end
    end
end

assign clk_pulse_out = (counter == 0 && clk_en)? 1'b1:1'b0;
endmodule

