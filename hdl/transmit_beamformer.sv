`default_nettype none

module transmit_beamformer #(
    parameter integer PERIOD_DURATION = 16777216,         // TODO: Default
    parameter integer BURST_DURATION = 524288,          // TODO: Default
    parameter integer NUM_TRANSMITTERS = 4,          // Number of transmitters
    parameter integer ELEMENT_SPACING = 9,          // Spacing between transmitters in mm
    parameter integer SPEED_OF_SOUND = 343000,      // Speed of sound in mm/s
    parameter integer TARGET_FREQ = 40000,          // Target frequency in Hz
    parameter integer CLK_FREQ = 100000000,         // System clock frequency in Hz
    parameter integer SIN_WIDTH = 17               // Bit width for sine values
)(
    input  logic clk_in,                               // System clock
    input  logic rst_in,                            // Active-low reset signal
    input  logic [SIN_WIDTH-1:0] sin_theta, // Sine value for beam_angle
    input  logic sign_bit,
    output logic [NUM_TRANSMITTERS-1:0] tx_out       // Output signals for transmitters
);

    // Calculate the delay per transmitter component in clock cycles
    localparam DELAY_WIDTH = 12;              // Bit width for dynamic delays used in default offset of pwm

    localparam DELAY_PER_TRANSMITTER_COMP = ELEMENT_SPACING * CLK_FREQ / SPEED_OF_SOUND;

    localparam ULTRA_SONIC_WAVE_PERIOD_IN_CLOCK_CYCLES = 2500;
    localparam ULTRA_SONIC_WAVE_HALF_PERIOD_IN_CLOCK_CYCLES = 1250;

    logic [NUM_TRANSMITTERS-1:0] counting;
    logic [DELAY_WIDTH-1:0] default_offset [NUM_TRANSMITTERS-1:0];

    logic [DELAY_WIDTH-1:0] default_offset_0;
    logic [DELAY_WIDTH-1:0] default_offset_1;
    logic [DELAY_WIDTH-1:0] default_offset_2;
    logic [DELAY_WIDTH-1:0] default_offset_3;

    always_comb begin
        if (sign_bit) begin
            default_offset_0 = ((DELAY_PER_TRANSMITTER_COMP * (NUM_TRANSMITTERS - 0) * sin_theta) >> (SIN_WIDTH-1)) % 2500;
            default_offset_1 = ((DELAY_PER_TRANSMITTER_COMP * (NUM_TRANSMITTERS - 1) * sin_theta) >> (SIN_WIDTH-1)) % 2500;
            default_offset_2 = ((DELAY_PER_TRANSMITTER_COMP * (NUM_TRANSMITTERS - 2) * sin_theta) >> (SIN_WIDTH-1)) % 2500;
            default_offset_3 = ((DELAY_PER_TRANSMITTER_COMP * (NUM_TRANSMITTERS - 3) * sin_theta) >> (SIN_WIDTH-1)) % 2500;
        end else begin
            default_offset_0 = ((DELAY_PER_TRANSMITTER_COMP * 0 * sin_theta) >> (SIN_WIDTH-1)) % 2500;
            default_offset_1 = ((DELAY_PER_TRANSMITTER_COMP * 1 * sin_theta) >> (SIN_WIDTH-1)) % 2500;
            default_offset_2 = ((DELAY_PER_TRANSMITTER_COMP * 2 * sin_theta) >> (SIN_WIDTH-1)) % 2500;
            default_offset_3 = ((DELAY_PER_TRANSMITTER_COMP * 3 * sin_theta) >> (SIN_WIDTH-1)) % 2500;
        end
    end

    // Generate PWM instances for each transmitter
    genvar i;
    generate
        for (i = 0; i < NUM_TRANSMITTERS; i++) begin : GEN_TRANSMITTER            
            // Calculate delay based on sine value
            // if want to propogate to left vs right. the ordering of which transmitter goes first toggles
            always_comb begin
            // Calculate delay based on sine value and sign_bit
            if (sign_bit) begin
                default_offset[i] = ((DELAY_PER_TRANSMITTER_COMP * (NUM_TRANSMITTERS - i) * sin_theta) >> (SIN_WIDTH-1)) % ULTRA_SONIC_WAVE_PERIOD_IN_CLOCK_CYCLES; // multiplying by 59 dividing by 60. maybe increase the bit width of sin_theta and incrase vals by 1
            end else begin
                default_offset[i] = ((DELAY_PER_TRANSMITTER_COMP * i * sin_theta) >> (SIN_WIDTH-1)) % ULTRA_SONIC_WAVE_PERIOD_IN_CLOCK_CYCLES; // potentially dangerous. shouldnt be to many operations because a and b are relatively closde
            end
        end
            // Instantiate PWM module
            // Need to actually wiggle the wave high low at 40 khz freq
            pwm #(
                .PERIOD_IN_CLOCK_CYCLES(ULTRA_SONIC_WAVE_PERIOD_IN_CLOCK_CYCLES),
                .DUTY_CYCLE_ON(ULTRA_SONIC_WAVE_HALF_PERIOD_IN_CLOCK_CYCLES)
            ) wave_generator (
                .clk_in(clk_in),
                .rst_in(rst_in),
                .default_offset(default_offset[i]),
                .sig_out(tx_out[i])
            );
        end
    endgenerate

endmodule

`default_nettype wire
