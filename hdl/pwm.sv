`timescale 1ns / 1ps
`default_nettype none

// 50% duty cycle PWM generator
module pwm #(
    parameter PERIOD_IN_CLOCK_CYCLES = 2500, // 40 kHz period with 100 MHz clock
    parameter DEFAULT_OFFSET = 0
)
(
    input  wire clk_in,
    input  wire rst_in,
    output logic sig_out
);

    // Calculate half-period for a 50% duty cycle
    localparam HALF_PERIOD_IN_CLOCK_CYCLES = PERIOD_IN_CLOCK_CYCLES >> 1; // Divide by 2

    // Counter to track clock cycles
    logic [$clog2(PERIOD_IN_CLOCK_CYCLES)-1:0] count;

    // Counter instance
    evt_counter evt_counter #(
        MAX_COUNT(PERIOD_IN_CLOCK_CYCLES),
        DEFAULT_OFFSET(DEFAULT_OFFSET)
    )
    (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .evt_in(clk_in),
        .count_out(count)
    );

    // PWM signal generation: Output high for half the period
    always_comb begin
        sig_out = (count < HALF_PERIOD_IN_CLOCK_CYCLES); // High during the first half of the period
    end

endmodule

`default_nettype wire
