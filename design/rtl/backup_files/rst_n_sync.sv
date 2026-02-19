`timescale 1ns/1ps


module rst_n_sync (
    input logic clk,
    input logic rst_n,
    output logic rst_n_sync
);

logic ff0_sync;
logic ff1_sync;

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
            ff0_sync <= 0;
    ff1_sync <= 0;
    end else begin
            ff0_sync <= 1;
            ff1_sync <= ff0_sync;
    end
end

assign rst_n_sync = ff1_sync;
endmodule