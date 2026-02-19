module uart_echo_test (
    input  logic clk,
    input  logic uart_rx_in, 
    output logic uart_tx_out 
);

    assign uart_tx_out = uart_rx_in;
endmodule