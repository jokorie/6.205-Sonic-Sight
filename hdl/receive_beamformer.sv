`default_nettype none

module receive_beamformer #(
    parameter integer PERIOD_DURATION = 16777216,         // TODO: Default
    parameter integer BURST_DURATION = 524288,          // TODO: Default
    parameter integer NUM_RECEIVERS = 2,          // Number of transmitters
    parameter integer BUFFER_SIZE = 80,        // Size of the circular buffer (sufficient for delays with margin). Thought. store the buffer size with perfect size such that wraps nicely
    parameter integer ELEMENT_SPACING = 9,          // Spacing between transmitters in mm
    parameter integer SPEED_OF_SOUND = 343000,      // Speed of sound in mm/s
    parameter integer TARGET_FREQ = 40000,          // Target frequency in Hz
    parameter integer CLK_FREQ = 100000000,
    parameter integer SAMPLING_RATE = 1000000,         // System clock frequency in Hz
    parameter integer SIN_WIDTH = 17,               // Bit width for sine values
    parameter integer DELAY_WIDTH = 16              // Bit width for dynamic delays
)(
    input logic clk_in,                        // System clock
    input logic rst_in,                      // Active-low reset signal
    input logic [15:0] adc_in [1:0], // Digital inputs from 4 ADCs
    input  logic [SIN_WIDTH-1:0] sin_theta, // Sine value for beam_angle
    input  logic sign_bit,
    input  logic data_valid_in,            // ADC Ready Input
    output logic [15:0] aggregated_waveform // Aggregated output waveform
);

    // Intentioinally, whole system operates on a cycle lag because easier to let incoming wave enter into the buffer

    localparam MAX_COUNT = CLK_FREQ / SAMPLING_RATE;
    localparam SAMPLE_DELAY_PER_RECEIVER_COMP = ELEMENT_SPACING * SAMPLING_RATE / SPEED_OF_SOUND;
    localparam INDEX_WIDTH = $clog2(BUFFER_SIZE);


    // Internal Signals
    logic [15:0] wave_buffer [NUM_RECEIVERS-1:0][BUFFER_SIZE-1:0]; // Buffers for each receiver
    logic [INDEX_WIDTH-1:0] next_write_index;                                 // Write index for the circular buffer (5-bit for up to 32 entries)
    logic [INDEX_WIDTH-1:0] curr_read_index [NUM_RECEIVERS-1:0];              // Read indices for each receiver
    logic [31:0] combined_waveform;                   // Summation of delayed signals (32-bit to handle overflow)

    logic [DELAY_WIDTH-1:0] delay_samples [NUM_RECEIVERS-1:0];
    always_comb begin
        for (int i = 0; i < NUM_RECEIVERS; i++) begin
            if (sign_bit) begin // if receiving wave from left, delay left most receiver most
                delay_samples[i] = ((SAMPLE_DELAY_PER_RECEIVER_COMP * (NUM_RECEIVERS - i - 1) * sin_theta) >> (SIN_WIDTH - 1)) % BUFFER_SIZE;
            end else begin // if receiving wave from right, delay right most receiver most
                delay_samples[i] = ((SAMPLE_DELAY_PER_RECEIVER_COMP * i * sin_theta) >> (SIN_WIDTH - 1)) % BUFFER_SIZE;
            end

            if (next_write_index > delay_samples[i]) begin
                curr_read_index[i] = next_write_index - delay_samples[i] - 1;
            end else begin
                curr_read_index[i] = BUFFER_SIZE + next_write_index - delay_samples[i] - 1;
            end
        end

        // ------------------- HARDCODED ----------------------------
        combined_waveform = (
                wave_buffer[0][curr_read_index[0]] + 
                wave_buffer[1][curr_read_index[1]]
            ) >> 1;
        // ------------------- HARDCODED ----------------------------
        aggregated_waveform = combined_waveform;
    end


    // Always block for writing ADC inputs to their respective buffers
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            next_write_index <= 5'd0;
            for (int i = 0; i < NUM_RECEIVERS; i++) begin
                for (int j = 0; j < BUFFER_SIZE; j++) begin
                    wave_buffer[i][j] = 0; // clears the wave buffer for next cycle
                end
            end
        end else begin
            if (data_valid_in) begin
                // Write the current adc_in values to their respective buffers
                for (int i = 0; i < NUM_RECEIVERS; i++) begin // keep in always ff
                    wave_buffer[i][next_write_index] <= adc_in[i];
                end

                if (next_write_index == BUFFER_SIZE - 1)
                    next_write_index <= 5'd0;
                else
                    next_write_index <= next_write_index + 1;
            end
        end
    end

endmodule

`default_nettype wire