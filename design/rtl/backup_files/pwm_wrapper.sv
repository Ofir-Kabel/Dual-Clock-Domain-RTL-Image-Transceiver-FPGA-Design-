`timescale 1ns / 1ps

import defs_pkg::*;

module pwm_wrapper (
    input logic clk,
    input logic rst_n,
    input logic [PWM_LEN-1:0] red_duty_cycle,
    input logic [PWM_LEN-1:0] green_duty_cycle,
    input logic [PWM_LEN-1:0] blue_duty_cycle,
    input logic pwm_en,
    input logic wr_en,
    input logic [31:0] w_data,
    input logic [BYTE_LEN-1:0] addr_low,
    output logic [31:0] r_data,
    output logic red_pwm_out,
    output logic green_pwm_out,
    output logic blue_pwm_out
);

  //-------------------------------------

  // localparam SLEEP_INDX_H = 31;
  // localparam SLEEP_INDX_L = 16;
  // localparam TIME_INDX_H = 15;
  // localparam TIME_INDX_L = 0;

  // localparam FREQ_INDX_H = 14;
  // localparam FREQ_INDX_L = 2;
  // localparam MAG_INDX_H = 1;
  // localparam MAG_INDX_L = 0;

  //---------------------------------------

  pwm red_pwm_inst (
      .clk(clk),
      .rst_n(rst_n),
      .duty_cycle(red_duty_cycle),
      .max_pwm_out(pwm_red_r[FREQ_INDX_H:FREQ_INDX_L]),
      .magnitude(pwm_red_r[MAG_INDX_H:MAG_INDX_L]),
      .pwm_out(red_pwm_out)
  );

  pwm green_pwm_inst (
      .clk(clk),
      .rst_n(rst_n),
      .duty_cycle(green_duty_cycle),
      .max_pwm_out(pwm_green_r[FREQ_INDX_H:FREQ_INDX_L]),
      .magnitude(pwm_green_r[MAG_INDX_H:MAG_INDX_L]),
      .pwm_out(green_pwm_out)
  );

  pwm blue_pwm_inst (
      .clk(clk),
      .rst_n(rst_n),
      .max_pwm_out(pwm_blue_r[FREQ_INDX_H:FREQ_INDX_L]),
      .duty_cycle(blue_duty_cycle),
      .magnitude(pwm_blue_r[MAG_INDX_H:MAG_INDX_L]),
      .pwm_out(blue_pwm_out)
  );

  //-----------------------------------------------

  pwm_cfg_r pwm_cfg_r, pwm_cfg_r_v;
  pwm_color_r pwm_red_r, pwm_red_r_v;
  pwm_color_r pwm_green_r, pwm_green_r_v;
  pwm_color_r pwm_blue_r, pwm_blue_r_v;

  localparam CFG_ADDR = 8'h0;
  localparam RED_ADDR = 8'h4;
  localparam GREEN_ADDR = 8'h8;
  localparam BLUE_ADDR = 8'hC;

  always_comb begin
    pwm_cfg_r_v   = w_data;
    pwm_red_r_v   = w_data;
    pwm_green_r_v = w_data;
    pwm_blue_r_v  = w_data;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pwm_cfg_r   <= '0;
      pwm_red_r   <= '0;
      pwm_green_r <= '0;
      pwm_blue_r  <= '0;
    end else if (wr_en && pwm_en) begin
      case (addr_low)
        CFG_ADDR: begin
          // pwm_cfg_r[SLEEP_INDX_H:SLEEP_INDX_L] <= w_data[SLEEP_INDX_H:SLEEP_INDX_L];
          // pwm_cfg_r[TIME_INDX_H:TIME_INDX_L]   <= w_data[TIME_INDX_H:TIME_INDX_L];
          pwm_cfg_r.reserved   <= '0;
          pwm_cfg_r.sleep_time <= pwm_cfg_r_v.sleep_time;
          pwm_cfg_r.time_slots <= pwm_cfg_r_v.time_slots;
        end
        RED_ADDR: begin
          // pwm_red_r[FREQ_INDX_H:FREQ_INDX_L] <= w_data[FREQ_INDX_H:FREQ_INDX_L];
          // pwm_red_r[MAG_INDX_H:MAG_INDX_L]   <= w_data[MAG_INDX_H:MAG_INDX_L];
          pwm_red_r.reserved <= '0;
          pwm_red_r.freq <= pwm_red_r_v.freq;
          pwm_red_r.magnitude <= pwm_red_r_v.magnitude;
        end
        GREEN_ADDR: begin
          // pwm_green_r[FREQ_INDX_H:FREQ_INDX_L] <= w_data[FREQ_INDX_H:FREQ_INDX_L];
          // pwm_green_r[MAG_INDX_H:MAG_INDX_L]   <= w_data[MAG_INDX_H:MAG_INDX_L];
          pwm_green_r.reserved <= '0;
          pwm_green_r.freq <= pwm_green_r_v.freq;
          pwm_green_r.magnitude <= pwm_green_r_v.magnitude;
        end
        BLUE_ADDR: begin
          // pwm_blue_r[FREQ_INDX_H:FREQ_INDX_L] <= w_data[FREQ_INDX_H:FREQ_INDX_L];
          // pwm_blue_r[MAG_INDX_H:MAG_INDX_L]   <= w_data[MAG_INDX_H:MAG_INDX_L];
          pwm_blue_r.reserved <= '0;
          pwm_blue_r.freq <= pwm_blue_r_v.freq;
          pwm_blue_r.magnitude <= pwm_blue_r_v.magnitude;
        end
        default: begin
          pwm_cfg_r   <= pwm_cfg_r;
          pwm_red_r   <= pwm_red_r;
          pwm_green_r <= pwm_green_r;
          pwm_blue_r  <= pwm_blue_r;
        end
      endcase
    end
  end

  // always_comb begin
  //   if (!wr_en && pwm_en) begin
  //     r_data = '0;
  //     unique case (addr_low)
  //       CFG_ADDR: begin
  //         r_data[SLEEP_INDX_H:SLEEP_INDX_L] = pwm_cfg_r[SLEEP_INDX_H:SLEEP_INDX_L];
  //         r_data[TIME_INDX_H:TIME_INDX_L]   = pwm_cfg_r[TIME_INDX_H:TIME_INDX_L];
  //       end
  //       RED_ADDR: begin
  //         r_data[FREQ_INDX_H:FREQ_INDX_L] = pwm_red_r[FREQ_INDX_H:FREQ_INDX_L];
  //         r_data[MAG_INDX_H:MAG_INDX_L]   = pwm_red_r[MAG_INDX_H:MAG_INDX_L];
  //       end
  //       GREEN_ADDR: begin
  //         r_data[FREQ_INDX_H:FREQ_INDX_L] = pwm_green_r[FREQ_INDX_H:FREQ_INDX_L];
  //         r_data[MAG_INDX_H:MAG_INDX_L]   = pwm_green_r[MAG_INDX_H:MAG_INDX_L];
  //       end
  //       BLUE_ADDR: begin
  //         r_data[FREQ_INDX_H:FREQ_INDX_L] = pwm_blue_r[FREQ_INDX_H:FREQ_INDX_L];
  //         r_data[MAG_INDX_H:MAG_INDX_L]   = pwm_blue_r[MAG_INDX_H:MAG_INDX_L];
  //       end
  //       default: r_data = '0;
  //     endcase
  //   end else r_data = '0;
  // end

  always_comb begin
    if (!wr_en && pwm_en) begin
      r_data = '0;
      unique case (addr_low)
        CFG_ADDR: begin
          r_data = pwm_cfg_r;
        end
        RED_ADDR: begin
          r_data = pwm_red_r;
        end
        GREEN_ADDR: begin
          r_data = pwm_green_r;
        end
        BLUE_ADDR: begin
          r_data = pwm_blue_r;
        end
        default: r_data = '0;
      endcase
    end else r_data = '0;
  end

endmodule
