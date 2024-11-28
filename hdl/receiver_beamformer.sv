`timescale 1ns / 1ps
`default_nettype none

module receive_beamform #(
    parameter integer PERIOD_DURATION = 16777216,         // TODO: Default
    parameter integer BURST_DURATION = 524288,          // TODO: Default
    parameter integer NUM_RECEIVERS = 4,          // Number of transmitters
    parameter integer BUFFER_SIZE = 40,        // Size of the circular buffer (sufficient for delays with margin)
    parameter integer ELEMENT_SPACING = 9,          // Spacing between transmitters in mm
    parameter integer SPEED_OF_SOUND = 343000,      // Speed of sound in mm/s
    parameter integer TARGET_FREQ = 40000,          // Target frequency in Hz
    parameter integer CLK_FREQ = 100000000,
    parameter integer SAMPLING_RATE = 1000000,         // System clock frequency in Hz
    parameter integer SIN_WIDTH = 16,               // Bit width for sine values
    parameter integer DELAY_WIDTH = 16              // Bit width for dynamic delays
)(
    input logic clk,                        // System clock
    input logic rst_n,                      // Active-low reset signal
    input logic [15:0] adc_in [3:0], // Digital inputs from 4 ADCs
    input  logic [SIN_WIDTH-1:0] sin_theta, // Sine value for beam_angle
    input  logic sign_bit,
    output logic [15:0] aggregated_waveform // Aggregated output waveform
);

    localparam integer MAX_COUNT = CLK_FREQ / SAMPLING_RATE;

    // Internal Signals
    logic signed [15:0] wave_buffer [NUM_RECEIVERS-1:0][0:BUFFER_SIZE-1]; // Buffers for each receiver
    logic [4:0] write_index;                                 // Write index for the circular buffer (5-bit for up to 32 entries)
    logic [4:0] read_index [NUM_RECEIVERS-1:0];              // Read indices for each receiver
    logic signed [31:0] combined_waveform;                   // Summation of delayed signals (32-bit to handle overflow)

    localparam integer SAMPLE_DELAY_PER_RECEIVER_COMP = ELEMENT_SPACING * SAMPLING_RATE / SPEED_OF_SOUND;

    logic [$clog2(MAX_COUNT)-1] sampling_count;
    evt_counter #(
        .MAX_COUNT(MAX_COUNT) // clock freq / sampling rate. // TODO: check to see is correct
    ) sampling_counter
    (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .evt_in(clk_in),
        .default_offset(0),
        .count_out(sampling_count)
    );

    logic sample_now;
    assign sample_now = sampling_count == 0;

    // Always block for writing ADC inputs to their respective buffers
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            write_index <= 5'd0;
        end else begin
            if (sample_now) begin
                // Write the current adc_in values to their respective buffers
                for (int i = 0; i < NUM_RECEIVERS; i++) begin
                    wave_buffer[i][write_index] <= adc_in[i];
                end

                // Increment write index, wrap around if necessary
                if (write_index == BUFFER_SIZE - 1)
                    write_index <= 5'd0;
                else
                    write_index <= write_index + 1;
            end
        end
    end



    // Always block for calculating the aggregated waveform
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            aggregated_waveform <= 16'd0;
        end else begin
            // Calculate the read index for each receiver based on delay
            for (int i = 0; i < NUM_RECEIVERS; i++) begin
                logic [DELAY_WIDTH:0] delay_samples;
                delay_samples = $rtoi((sign_bit)?
                    (SAMPLE_DELAY_PER_RECEIVER_COMP * (NUM_RECEIVERS - i) * sin_theta) >> (SIN_WIDTH - 1):
                    (SAMPLE_DELAY_PER_RECEIVER_COMP * i * sin_theta) >> (SIN_WIDTH - 1)); // TODO: check math

                if (write_index >= delay_samples)
                    read_index[i] = write_index - delay_samples;
                else
                    read_index[i] = BUFFER_SIZE + write_index - delay_samples;
            end

            // Sum the delayed signals to produce the aggregated waveform
            combined_waveform = 0;  // Start with zero
            for (int i = 0; i < NUM_RECEIVERS; i++) begin
                combined_waveform += wave_buffer[i][read_index[i]];
            end

            // Scale down the combined waveform to fit into 16 bits if necessary
            aggregated_waveform <= combined_waveform >> 2; // Divide by NUM_RECEIVERS
        end
    end

endmodule

`default_nettype wire
