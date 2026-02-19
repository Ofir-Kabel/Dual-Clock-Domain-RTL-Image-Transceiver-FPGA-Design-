`timescale 1ns/1ns
`include "top_pkg.svh"


module Tx_phy_v0(
    input logic clk,
    input logic rst_n,
    input logic tx_phy_str,
    input logic [7:0] data_in,
    input logic [7:0] delay_ms,
    
    output logic tx_line,
    output logic byte_ready,
    output logic byte_done,
    output logic led_toggle 
);

typedef enum logic[1:0] {IDLE,BUSY,FINISH,PAUSE} tx_pyh_fsm_t;
tx_pyh_fsm_t pst,nst;

localparam BR_COUNTER_MAX = TRX_CLK_FREQ/TX_BR;

logic [$clog2(BR_COUNTER_MAX)-1:0] br_counter;
logic [24:0] pause_counter;
logic [3:0] bit_counter;
logic [9:0] tx_reg;   //{1'b1 , data , 1'b0}

//--------------------------------
//          Tx Phy FSM
//---------------------------------

//pst block
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        pst<=IDLE;
    else
        pst<=nst;
end

//nst block
always_comb begin
    case(pst)
    IDLE:begin
        nst = (tx_phy_str)? BUSY : IDLE;
    end
    BUSY:begin
        nst = (bit_counter == 4'd10)? FINISH : BUSY;
    end
    FINISH:begin
        nst = IDLE; //(delay_ms)? PAUSE : IDLE;
    end
    PAUSE:begin
        nst = (pause_counter == delay_ms)? IDLE : PAUSE;  
    end
    default: nst = IDLE;  
    endcase
end

logic even_parity = (^data_in)? 1'b0 : 1'b1; //calculate parity bit

//operation block
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        br_counter <= 'd0;
        pause_counter <= 'd0;
        byte_ready <= 1'b1;  
        byte_done <= 1'b0;
        tx_reg <= 10'b1000000000;
        tx_line <= 1'b1;
        bit_counter <= 3'd0;
        led_toggle <= 1'b0;
    end else
        case (nst)
            IDLE:begin
                br_counter <= 'd0;
                pause_counter <= 'd0;
                bit_counter <= 'd0;
                byte_done <= 1'b0;    
                tx_reg <= {1'b1,data_in,1'b0};
                byte_ready <= 1'b1; 
                tx_line <= 1'b1;  
            end
            BUSY:begin
                pause_counter <= 'd0;
                byte_ready <= 1'b0;
                byte_done <= 1'b0;  
                br_counter <= br_counter + 1;
                tx_line <= tx_reg[bit_counter];
                if(br_counter == (BR_COUNTER_MAX))begin 
                    br_counter <= 'd0;
                    bit_counter <= bit_counter + 1;
                end
            end
            FINISH:begin
                tx_line <= 1'b1;
                bit_counter <= 3'd0;
                byte_ready <= 1'b0;  
                byte_done <= 1'b1;  
            end
            PAUSE:begin 
                byte_ready <= 1'b0;
                if(pause_counter == delay_ms) byte_done <= 1'b1;  
                pause_counter <= pause_counter + 1;
            end
            default:begin
                tx_line <= 1'b1;
                bit_counter <= 3'd0;
                br_counter <= 'd0;
                pause_counter <= 'd0;
                byte_ready <= 1'b0;
                byte_done <= 1'b0;
            end
        endcase
end

//--------------------------------------------------------------

endmodule