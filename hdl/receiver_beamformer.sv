`timescale 1ns / 1ps
`default_nettype none

module receive_beamform (
    input logic clk,                        // System clock
    input logic rst_n,                      // Active-low reset signal
    input logic [15:0] adc_in [3:0], // Digital inputs from 4 ADCs
    output logic [15:0] aggregated_waveform // Aggregated output waveform
);

    // Parameters for delay values (use localparam instead)
    localparam integer NUM_RECEIVERS = 4;       // Number of receivers (ADC inputs)
    localparam integer BUFFER_SIZE = 32;        // Size of the circular buffer (sufficient for delays with margin)

    // Delay samples array for each receiver
    integer delay_samples [NUM_RECEIVERS-1:0];

    // Internal Signals
    logic signed [15:0] wave_buffer [NUM_RECEIVERS-1:0][0:BUFFER_SIZE-1]; // Buffers for each receiver
    logic [4:0] write_index;                                 // Write index for the circular buffer (5-bit for up to 32 entries)
    logic [4:0] read_index [NUM_RECEIVERS-1:0];              // Read indices for each receiver
    logic signed [31:0] combined_waveform;                   // Summation of delayed signals (32-bit to handle overflow)

    // Initial block to calculate delay values for each receiver
    initial begin
        delay_samples[0] = 0;
        delay_samples[1] = 2;
        delay_samples[2] = 4;
        delay_samples[3] = 6;
    end

    // Always block for writing ADC inputs to their respective buffers
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            write_index <= 5'd0;
        end else begin
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

    // Always block for calculating the aggregated waveform
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            aggregated_waveform <= 16'd0;
        end else begin
            // Calculate the read index for each receiver based on delay
            for (int i = 0; i < NUM_RECEIVERS; i++) begin
                if (write_index >= delay_samples[i])
                    read_index[i] = write_index - delay_samples[i];
                else
                    read_index[i] = BUFFER_SIZE + write_index - delay_samples[i];
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
