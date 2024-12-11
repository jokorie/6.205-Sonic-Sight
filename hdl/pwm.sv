`default_nettype none

module pwm #(
    parameter PERIOD_IN_CLOCK_CYCLES = 2500, // 40 kHz period with 100 MHz clock
    parameter DUTY_CYCLE_ON = 1250
)
(
    input  wire clk_in,
    input  wire rst_in,
    input wire[$clog2(PERIOD_IN_CLOCK_CYCLES)-1:0] default_offset,
    output logic sig_out
);

    // Counter to track clock cycles
    logic [$clog2(PERIOD_IN_CLOCK_CYCLES)-1:0] count;
    // Counter instance
    evt_counter #(
        .MAX_COUNT(PERIOD_IN_CLOCK_CYCLES)
    ) counter
    (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .evt_in(1'b1),
        .default_offset(default_offset),
        .count_out(count)
    );

    // PWM signal generation: Output high for half the period
    assign sig_out = (count < DUTY_CYCLE_ON); // High during the first half of the period

endmodule

`default_nettype wire
