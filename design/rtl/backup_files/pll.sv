`timescale 1ns/1ps

module pll (
    input logic clk_1,
    input logic clk_2,
    input logic rst_n,
    input logic sel,
    output logic clk_out
);
    
logic ff0_clk1;
logic ff1_clk1;

logic ff0_clk2;
logic ff1_clk2;

logic sync1_o;
logic sync2_o;

logic and_sync_1_o;
logic and_sync_2_o;


always_ff @(posedge clk_1 or negedge rst_n) begin : CLK_1_SYNC
    if (!rst_n) begin
        ff0_clk1 <= 0;
        ff1_clk1 <= 0;
    end else  begin
    ff0_clk1 <= !sel && !sync2_o;
    ff1_clk1 <= ff0_clk1;
    end
end

always_ff @(posedge clk_2 or negedge rst_n) begin : CLK_2_SYNC
    if (!rst_n) begin
        ff0_clk2 <= 0;
        ff1_clk2 <= 0;
    end else begin
    ff0_clk2 <= sel && !sync1_o;
    ff1_clk2 <= ff0_clk2;
    end
    end

assign sync1_o = ff1_clk1;
assign sync2_o = ff1_clk2;

assign and_sync_1_o = (clk_1 && sync1_o);
assign and_sync_2_o = (clk_1 && sync2_o);

assign clk_out = and_sync_1_o || and_sync_2_o;

endmodule

module tb_pll ();

localparam  CLK_1_TP = 10;
localparam  CLK_2_TP = 86;

logic clk_1;
logic clk_2;
logic sel;
logic clk_out;

pll pll_inst(
.clk_1(clk_1),
.clk_2(clk_2),
.sel(sel),
.clk_out(clk_out)
);


initial begin
    clk_1 = 0;
    forever begin
        clk_1 = ~clk_1;
        #CLK_1_TP/2;
    end    
end

initial begin
    clk_2 = 0;
    forever begin
        clk_2 = ~clk_2;
        #CLK_2_TP/2;
    end    
end


endmodule
