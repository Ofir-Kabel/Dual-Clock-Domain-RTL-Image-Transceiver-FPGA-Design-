package common_pkg;
    timeunit 1ns;
    timeprecision 1ns;

    // General Architecture Constants
    localparam int WORD_WIDTH = 32;
    localparam int BYTE_LEN   = 8;
    
    // System Frequency (Used for calculations everywhere)
    localparam int CLK_FREQ   = 100_000_000; 

    // Common Types
    typedef logic [WORD_WIDTH-1:0] word_t;
    typedef logic [BYTE_LEN-1:0]   byte_t;

    typedef struct packed {
        logic [31:24] data_h_d1;
        logic [23:16] data_h_d0;
        logic [15:8] data_l_d1;
        logic [7:0] data_l_d0;
    } r_data_msg_t;
endpackage