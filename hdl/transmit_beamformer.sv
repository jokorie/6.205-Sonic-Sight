`timescale 1ns / 1ps
`default_nettype none

module transmit_beamformer #(
    parameter integer NUM_TRANSMITTERS = 4,          // Number of transmitters
    parameter integer ELEMENT_SPACING = 5,          // Spacing between transmitters in mm
    parameter integer SPEED_OF_SOUND = 343000,      // Speed of sound in mm/s
    parameter integer TARGET_FREQ = 40000,          // Target frequency in Hz
    parameter integer CLK_FREQ = 100000000          // System clock frequency in Hz
)(
    input  logic clk,                               // System clock
    input  logic rst_in,                            // Active-low reset signal
    output logic tx_out [NUM_TRANSMITTERS-1:0]      // Output signals for transmitters
);

    // Calculate the delay per transmitter in clock cycles
    localparam integer DELAY_PER_TRANSMITTER = ELEMENT_SPACING * CLK_FREQ / SPEED_OF_SOUND;

    // Generate PWM instances for each transmitter
    genvar i;
    generate
        for (i = 0; i < NUM_TRANSMITTERS; i++) begin : GEN_TRANSMITTER
            pwm #(
                .DEFAULT_OFFSET(DELAY_PER_TRANSMITTER * i) // Cumulative delay
            ) wave_generator (
                .clk_in(clk),
                .rst_in(rst_in),
                .sig_out(tx_out[i])
            );
        end
    endgenerate

endmodule

`default_nettype wire
