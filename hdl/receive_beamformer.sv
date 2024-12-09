`default_nettype none

module receive_beamformer #(
    parameter integer PERIOD_DURATION = 16777216,         // TODO: Default
    parameter integer BURST_DURATION = 524288,          // TODO: Default
    parameter integer NUM_RECEIVERS = 4,          // Number of transmitters
    parameter integer BUFFER_SIZE = 32,        // Size of the circular buffer (sufficient for delays with margin)
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
    input logic [15:0] adc_in [3:0], // Digital inputs from 4 ADCs
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
    logic [INDEX_WIDTH-1:0] write_index;                                 // Write index for the circular buffer (5-bit for up to 32 entries)
    logic [INDEX_WIDTH-1:0] read_index [NUM_RECEIVERS-1:0];              // Read indices for each receiver
    logic [31:0] combined_waveform;                   // Summation of delayed signals (32-bit to handle overflow)

    logic [DELAY_WIDTH-1:0] delay_samples [NUM_RECEIVERS-1:0];


    logic [15:0] recent_wave_buffer_0;
    logic [15:0] recent_wave_buffer_1;
    logic [15:0] recent_wave_buffer_2;
    logic [15:0] recent_wave_buffer_3;

    // Always block for writing ADC inputs to their respective buffers
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            write_index <= 5'd0;
            for (int i = 0; i < NUM_RECEIVERS; i++) begin
                // delay_samples[i] = 0;
                // read_index[i] = 0;
                for (int j = 0; j < BUFFER_SIZE; j++) begin
                    wave_buffer[i][j] = 0; // clears the wave buffer for next cycle
                end
            end
        end else begin
            if (data_valid_in) begin

                

                // Write the current adc_in values to their respective buffers
                for (int i = 0; i < NUM_RECEIVERS; i++) begin
                    wave_buffer[i][write_index] <= adc_in[i];

                    // write index: where I should write in this very moment
                end

                // Increment write index, wrap around if necessary
                if (write_index == BUFFER_SIZE - 1)
                    write_index <= 5'd0;
                else
                    write_index <= write_index + 1;
            end
        end
    end

    logic [DELAY_WIDTH-1:0] delay_samples_0;
    logic [DELAY_WIDTH-1:0] delay_samples_1;
    logic [DELAY_WIDTH-1:0] delay_samples_2;
    logic [DELAY_WIDTH-1:0] delay_samples_3;

    logic [15:0] wave_comp_0;
    logic [15:0] wave_comp_1;
    logic [15:0] wave_comp_2;
    logic [15:0] wave_comp_3;


    always_comb begin
        for (int i = 0; i < NUM_RECEIVERS; i++) begin
            if (sign_bit) begin
                delay_samples[i] = ((SAMPLE_DELAY_PER_RECEIVER_COMP * (NUM_RECEIVERS - i) * sin_theta) >> (SIN_WIDTH - 1)) % BUFFER_SIZE;
            end else begin
                delay_samples[i] = ((SAMPLE_DELAY_PER_RECEIVER_COMP * i * sin_theta) >> (SIN_WIDTH - 1)) % BUFFER_SIZE;
            end

            if (write_index > delay_samples[i]) begin
                read_index[i] = write_index - delay_samples[i] - 1; // maybe updating this too late? this should be updated for the next iteration loop
            end else begin
                read_index[i] = BUFFER_SIZE + write_index - delay_samples[i] - 1; // because after a valid sample received. write idx immediately updated. would work if not so
            end
        end

        delay_samples_0 = ((SAMPLE_DELAY_PER_RECEIVER_COMP * 0 * sin_theta) >> (SIN_WIDTH - 1)) % BUFFER_SIZE;
        delay_samples_1 = ((SAMPLE_DELAY_PER_RECEIVER_COMP * 1 * sin_theta) >> (SIN_WIDTH - 1)) % BUFFER_SIZE;
        delay_samples_2 = ((SAMPLE_DELAY_PER_RECEIVER_COMP * 2 * sin_theta) >> (SIN_WIDTH - 1)) % BUFFER_SIZE;
        delay_samples_3 = ((SAMPLE_DELAY_PER_RECEIVER_COMP * 3 * sin_theta) >> (SIN_WIDTH - 1)) % BUFFER_SIZE;
            
        read_index_0 = read_index[0];
        read_index_1 = read_index[1];
        read_index_2 = read_index[2];
        read_index_3 = read_index[3];

        wave_comp_0 = wave_buffer[0][read_index[0]];
        wave_comp_1 = wave_buffer[1][read_index[1]];
        wave_comp_2 = wave_buffer[2][read_index[2]];
        wave_comp_3 = wave_buffer[3][read_index[3]];

        recent_wave_buffer_0 = adc_in[0];
        recent_wave_buffer_1 = adc_in[1];
        recent_wave_buffer_2 = adc_in[2];
        recent_wave_buffer_3 = adc_in[3];

    end

    logic [INDEX_WIDTH-1:0] read_index_0;
    logic [INDEX_WIDTH-1:0] read_index_1;
    logic [INDEX_WIDTH-1:0] read_index_2;
    logic [INDEX_WIDTH-1:0] read_index_3;





    // Always block for calculating the aggregated waveform
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            aggregated_waveform <= 16'd0;
        end else begin

            // Scale down the combined waveform to fit into 16 bits if necessary
            aggregated_waveform <= (
                wave_buffer[0][read_index[0]] + 
                wave_buffer[1][read_index[1]] +
                wave_buffer[2][read_index[2]] +
                wave_buffer[3][read_index[3]]
            ) >> 2; // Divide by NUM_RECEIVERS
        end
    end

endmodule

`default_nettype wire