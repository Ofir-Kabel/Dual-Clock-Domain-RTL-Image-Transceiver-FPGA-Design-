package pixel_mem_pkg;
        localparam int DATA_WIDTH = 8;
    // localparam string PIXEL_MEM_RED     = "debug_red_hex.mem";
    // localparam string PIXEL_MEM_GREEN   = "debug_green_hex.mem";
    // localparam string PIXEL_MEM_BLUE    = "debug_blue_hex.mem";

    localparam string PIXEL_MEM_RED     = "red_hex.mem";
    localparam string PIXEL_MEM_GREEN   = "green_hex.mem";
    localparam string PIXEL_MEM_BLUE    = "blue_hex.mem";

    
    // localparam string PIXEL_MEM_RED     = "debug_gradient.mem";
    // localparam string PIXEL_MEM_GREEN   = "debug_gradient.mem";
    // localparam string PIXEL_MEM_BLUE    = "debug_gradient.mem";


    localparam int MEM_WIDTH = 32;
    localparam int IMG_H = 256;
    localparam int IMG_W = 256;
    localparam int ROW_WIDTH = $clog2(IMG_H);
    localparam int COL_WIDTH = $clog2(IMG_W);
    localparam int MEM_MAX_ROW = (IMG_H * IMG_W)/4;
endpackage