`timescale 1ns / 1ps
`default_nettype none

module transmit_beamformer #(
    parameter integer PERIOD_DURATION = 16777216,         // TODO: Default
    parameter integer BURST_DURATION = 524288,          // TODO: Default
    parameter integer NUM_TRANSMITTERS = 4,          // Number of transmitters
    parameter integer ELEMENT_SPACING = 9,          // Spacing between transmitters in mm
    parameter integer SPEED_OF_SOUND = 343000,      // Speed of sound in mm/s
    parameter integer TARGET_FREQ = 40000,          // Target frequency in Hz
    parameter integer CLK_FREQ = 100000000,         // System clock frequency in Hz
    parameter integer SIN_WIDTH = 16,               // Bit width for sine values
    parameter integer DELAY_WIDTH = 16              // Bit width for dynamic delays
)(
    input  logic clk,                               // System clock
    input  logic rst_in,                            // Active-low reset signal
    input  logic [SIN_WIDTH-1:0] sin_theta, // Sine value for beam_angle
    input  logic sign_bit,
    output logic tx_out [NUM_TRANSMITTERS-1:0]      // Output signals for transmitters
);

    // Calculate the delay per transmitter component in clock cycles
    localparam integer DELAY_PER_TRANSMITTER_COMP = ELEMENT_SPACING * CLK_FREQ / SPEED_OF_SOUND;

    // Generate PWM instances for each transmitter
    genvar i;
    generate
        for (i = 0; i < NUM_TRANSMITTERS; i++) begin : GEN_TRANSMITTER
            logic [DELAY_WIDTH-1:0] default_offset;
            
            // Calculate delay based on sine value
            // if want to propogate to left vs right. the ordering of which transmitter goes first toggles
            assign default_offset = (sign_bit)?
                (DELAY_PER_TRANSMITTER_COMP * (NUM_TRANSMITTERS - i) * sin_theta) >> (SIN_WIDTH - 1):
                (DELAY_PER_TRANSMITTER_COMP * i * sin_theta) >> (SIN_WIDTH - 1); // TODO: check math

            // Instantiate PWM module
            // Need to actually wiggle the wave high low at 40 khz freq
            pwm wave_generator (
                .clk_in(clk),
                .rst_in(rst_in),
                .default_offset(default_offset),
                .sig_out(tx_out[i])
            );
        end
    endgenerate

endmodule

`default_nettype wire
