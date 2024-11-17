`timescale 1ns / 1ps
`default_nettype none

module wave_generator (
    input logic clk,                // System clock (assumed to be much higher than 40 kHz)
    input logic rst_n,              // Active-low reset signal
    output logic signed [15:0] wave_out  // 16-bit signed output waveform
);

    // Parameters
    parameter CLK_FREQ = 100000000;   // System clock frequency in Hz (e.g., 50 MHz)
    parameter TARGET_FREQ = 40000;   // Target wave frequency in Hz (40 kHz)
    parameter COUNTER_MAX = CLK_FREQ / (2 * TARGET_FREQ); // Calculate max counter value for 40 kHz

    // Internal signals
    logic [31:0] counter;           // Counter for clock division
    logic signed [15:0] sine_lut [0:31];  // Lookup table for 16-bit sine wave values (32 points)
    logic [4:0] lut_index;          // Index for the lookup table

    // Generate a lookup table with 32 samples of a 16-bit sine wave (precomputed values)
    initial begin
        sine_lut[0]  = 16'sd0;
        sine_lut[1]  = 16'sd3212;
        sine_lut[2]  = 16'sd6392;
        sine_lut[3]  = 16'sd9511;
        sine_lut[4]  = 16'sd12539;
        sine_lut[5]  = 16'sd15446;
        sine_lut[6]  = 16'sd18204;
        sine_lut[7]  = 16'sd20787;
        sine_lut[8]  = 16'sd23170;
        sine_lut[9]  = 16'sd25329;
        sine_lut[10] = 16'sd27245;
        sine_lut[11] = 16'sd28898;
        sine_lut[12] = 16'sd30273;
        sine_lut[13] = 16'sd31356;
        sine_lut[14] = 16'sd32137;
        sine_lut[15] = 16'sd32593;
        sine_lut[16] = 16'sd32767;
        sine_lut[17] = 16'sd32593;
        sine_lut[18] = 16'sd32137;
        sine_lut[19] = 16'sd31356;
        sine_lut[20] = 16'sd30273;
        sine_lut[21] = 16'sd28898;
        sine_lut[22] = 16'sd27245;
        sine_lut[23] = 16'sd25329;
        sine_lut[24] = 16'sd23170;
        sine_lut[25] = 16'sd20787;
        sine_lut[26] = 16'sd18204;
        sine_lut[27] = 16'sd15446;
        sine_lut[28] = 16'sd12539;
        sine_lut[29] = 16'sd9511;
        sine_lut[30] = 16'sd6392;
        sine_lut[31] = 16'sd3212;
    end

    // Always block to generate the 40 kHz wave
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            counter <= 32'd0;
            lut_index <= 5'd0;
            wave_out <= 16'sd0;
        end else begin
            if (counter >= COUNTER_MAX - 1) begin // how frequently we update the values
                counter <= 32'd0;
                wave_out <= sine_lut[lut_index];
                if (lut_index == 5'd31) begin
                    lut_index <= 5'd0;
                end else begin
                    lut_index <= lut_index + 1;
                end
            end else begin
                counter <= counter + 1;
            end
        end
    end

endmodule

`default_nettype wire