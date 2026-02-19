import defs_pkg::*;

module scaling_factor (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        blue_nor_green,   // 1=Blue, 0=Green
    input  logic [GAMMA_OUTPUT-1:0]  color_vec,  // From Gamma (0-1023)
    output logic [PWM_LEN-1:0] scale_factor_out  // Expanded to 12-bit to hold value ~2680
);

    // Internal variable needs to be large enough for (1023 << 9) ≈ 524,000
    // 20 bits are enough (up to ~1,000,000)
    logic [19:0] factor;

    assign factor = (blue_nor_green) ? 
            // CASE BLUE (Factor ~2.62): Needs Boost
            // (In * 512) + (In * 128) + (In * 32)
            20'd0 + ((color_vec << 9) + (color_vec << 7) + (color_vec << 5)) :
            
            // CASE GREEN (Factor ~0.51): Needs Reduction
            // (In * 128) + (In * 2) + 1
            20'd0 + ((color_vec << 7) + (color_vec << 1) + 1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scale_factor_out <= {PWM_LEN{1'b0}};
        end else begin
            // We divide by 256 by taking bits [19:8] instead of [17:8]
            // This fits the result into the new 12-bit output
            scale_factor_out <= factor[19:19-PWM_LEN];
        end
    end

endmodule
