`timescale 1ns / 1ps
`default_nettype none

// 50% duty cycle PWM generator
module pwm #(
    parameter PERIOD_IN_CLOCK_CYCLES = 2500, // 40 kHz period with 100 MHz clock
    parameter DUTY_CYCLE_ON = 1250,
    parameter DEFAULT_OFFSET = 0
)
(
    input  wire clk_in,
    input  wire rst_in,
    output logic sig_out
);

    // Counter to track clock cycles
    logic [$clog2(PERIOD_IN_CLOCK_CYCLES)-1:0] count;

    // Counter instance
    evt_counter #(
        MAX_COUNT(PERIOD_IN_CLOCK_CYCLES),
        DEFAULT_OFFSET(DEFAULT_OFFSET)
    ) counter
    (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .evt_in(clk_in),
        .count_out(count)
    );

    // PWM signal generation: Output high for half the period
    always_comb begin
        sig_out = (count < DUTY_CYCLE_ON); // High during the first half of the period
    end

endmodule

`default_nettype wire
