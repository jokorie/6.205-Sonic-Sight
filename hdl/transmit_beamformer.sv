`timescale 1ns / 1ps
`default_nettype none

module transmit_beamformer #(
    parameter integer PERIOD_DURATION = ...,         // TODO: Default
    parameter integer BURST_DURATION = ...,          // TODO: Default
    parameter integer NUM_TRANSMITTERS = 4,          // Number of transmitters
    parameter integer ELEMENT_SPACING = 5,          // Spacing between transmitters in mm
    parameter integer SPEED_OF_SOUND = 343000,      // Speed of sound in mm/s
    parameter integer TARGET_FREQ = 40000,          // Target frequency in Hz
    parameter integer CLK_FREQ = 100000000,         // System clock frequency in Hz
    parameter integer SIN_WIDTH = 16,               // Bit width for sine values
    parameter integer ANGLE_WIDTH = 7,              // Bit width for beam angle input
    parameter integer DELAY_WIDTH = 16              // Bit width for dynamic delays
)(
    input  logic clk,                               // System clock
    input  logic rst_in,                            // Active-low reset signal
    input  logic [ANGLE_WIDTH-1:0] beam_angle,      // Beamforming angle (index for LUT)
    output logic tx_out [NUM_TRANSMITTERS-1:0]      // Output signals for transmitters
);

    // Calculate the delay per transmitter in clock cycles
    localparam integer DELAY_PER_TRANSMITTER = ELEMENT_SPACING * CLK_FREQ / SPEED_OF_SOUND;

    // Sine LUT instantiation (returns unsigned sine values)
    logic [SIN_WIDTH-1:0] sin_theta; // Sine value for beam_angle
    sin_lut #(
        .SIN_WIDTH(SIN_WIDTH),
        .ANGLE_WIDTH(ANGLE_WIDTH)
    ) sin_lookup (
        .angle(beam_angle),
        .sin_value(sin_theta)
    );

    // Generate PWM instances for each transmitter
    genvar i;
    generate
        for (i = 0; i < NUM_TRANSMITTERS; i++) begin : GEN_TRANSMITTER
            logic [DELAY_WIDTH-1:0] default_offset;
            
            // Calculate delay based on sine value
            assign default_offset = (DELAY_PER_TRANSMITTER * i * sin_theta) >> (SIN_WIDTH - 1); // TODO: check math

            // Instantiate PWM module
            pwm #(
                .PERIOD_IN_CLOCK_CYCLES(PERIOD_DURATION),
                .DUTY_CYCLE_ON(BURST_DURATION)
            ) wave_generator (
                .clk_in(clk),
                .rst_in(rst_in),
                .default_offset(default_offset),
                .sig_out(tx_out[i])
            );
        end
    endgenerate

endmodule

`default_nettype wire
