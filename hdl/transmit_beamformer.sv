`timescale 1ns / 1ps
`default_nettype none

module transmit_beamformer #(
    parameter integer NUM_TRANSMITTERS = 4,          // Number of transmitters
    parameter integer CLK_FREQ = 50000000,           // System clock frequency in Hz (e.g., 50 MHz)
    parameter integer TARGET_FREQ = 40000,           // Target frequency of wave in Hz (40 kHz)
    parameter integer ELEMENT_SPACING = 5,           // Spacing between transmitters in mm
    parameter integer SPEED_OF_SOUND = 343000,       // Speed of sound in mm/s (343 m/s -> 343000 mm/s)
    parameter integer BUFFER_SIZE = 1024             // Size of the buffer for storing recent waveform values
)(
    input logic clk,                                 // System clock
    input logic rst_n,                               // Active-low reset signal
    input logic signed [15:0] wave_in,               // Input wave from wave generator
    output logic signed [15:0] tx_out [NUM_TRANSMITTERS]  // Output signals for the transmitters
);

    // Internal Signals

    // TODO: will probably need a BRAM for the wave_buffer
    logic signed [15:0] wave_buffer [0:BUFFER_SIZE-1]; // Buffer to store recent waveform values
    logic [9:0] write_index;                           // Write index for the circular buffer
    logic [9:0] read_index [NUM_TRANSMITTERS-1:0];     // Read indices for each transmitter

    // Calculated Parameters (Use `localparam` instead)
    localparam real WAVELENGTH = SPEED_OF_SOUND / TARGET_FREQ; // Wavelength of the 40 kHz signal in mm

    // Phase Delay Array
    integer phase_delay [NUM_TRANSMITTERS-1:0];

    // Initial block to calculate phase delays for each transmitter
    initial begin
        for (int i = 0; i < NUM_TRANSMITTERS; i++) begin
            phase_delay[i] = (ELEMENT_SPACING * i * 360) / WAVELENGTH;
        end
    end

    // Always block for writing to the buffer
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            write_index <= 10'd0;
        end else begin
            // Write current wave_in value to the buffer
            wave_buffer[write_index] <= wave_in;

            // Increment write index, wrap around if necessary
            if (write_index == BUFFER_SIZE - 1)
                write_index <= 10'd0;
            else
                write_index <= write_index + 1;
        end
    end

    // Always block for applying phase delays and setting output signals
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // Reset all transmitter outputs
            for (int i = 0; i < NUM_TRANSMITTERS; i++) begin
                tx_out[i] <= 16'd0;
            end
        end else begin
            // Calculate the read index for each transmitter and output the delayed waveform
            for (int i = 0; i < NUM_TRANSMITTERS; i++) begin
                if (write_index >= phase_delay[i])
                    read_index[i] = write_index - phase_delay[i];
                else
                    read_index[i] = BUFFER_SIZE + write_index - phase_delay[i];

                // Assign the delayed waveform value to the corresponding output
                tx_out[i] <= wave_buffer[read_index[i]];
            end
        end
    end

endmodule

`default_nettype wire
