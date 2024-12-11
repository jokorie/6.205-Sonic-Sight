`default_nettype none

module transmit_beamformer #(
    parameter integer PERIOD_DURATION = 16777216,         // TODO: Default
    parameter integer BURST_DURATION = 524288,          // TODO: Default
    parameter integer NUM_TRANSMITTERS = 2,          // Number of transmitters
    parameter integer ELEMENT_SPACING = 9,          // Spacing between transmitters in mm
    parameter integer SPEED_OF_SOUND = 343000,      // Speed of sound in mm/s
    parameter integer TARGET_FREQ = 40000,          // Target frequency in Hz
    parameter integer CLK_FREQ = 100000000,         // System clock frequency in Hz
    parameter integer SIN_WIDTH = 17               // Bit width for sine values
)(
    input wire clk_in,                               // System clock
    input wire rst_in,                            // Active-low reset signal
    input wire [SIN_WIDTH-1:0] sin_value, // Sine value for beam_angle
    input wire sign_bit,
    output logic [NUM_TRANSMITTERS-1:0] tx_out       // Output signals for transmitters
);

    // Calculate the delay per transmitter component in clock cycles
    localparam DELAY_WIDTH = 12;              // Bit width for dynamic delays used in default offset of pwm

    localparam ULTRA_SONIC_WAVE_PERIOD_IN_CLOCK_CYCLES = 2500;
    localparam ULTRA_SONIC_WAVE_HALF_PERIOD_IN_CLOCK_CYCLES = 1250;

    localparam DELAY_PER_TRANSMITTER_COMP = (ELEMENT_SPACING * CLK_FREQ / SPEED_OF_SOUND) % ULTRA_SONIC_WAVE_PERIOD_IN_CLOCK_CYCLES;


    logic [NUM_TRANSMITTERS-1:0] counting;
    logic [DELAY_WIDTH-1:0] default_offset [NUM_TRANSMITTERS-1:0];

    // //  -------------------------- HARD CODED ----------------------------------
    // logic [DELAY_WIDTH-1:0] default_offset_0_sign;
    // logic [DELAY_WIDTH-1:0] default_offset_1_sign;
    // logic [DELAY_WIDTH-1:0] default_offset_0_no_sign;
    // logic [DELAY_WIDTH-1:0] default_offset_0_no_sign;
    // //  -------------------------- HARD CODED ----------------------------------

    // Generate PWM instances for each transmitter
    genvar i;
    generate
        for (i = 0; i < NUM_TRANSMITTERS; i++) begin : GEN_TRANSMITTER            
            // Calculate delay based on sine value
            // if want to propogate to left vs right. the ordering of which transmitter goes first toggles
            always_comb begin
                // Calculate delay based on sine value and sign_bit
                if (sign_bit) begin // if propogating angle to left. trigger rightmost transmitter first
                    default_offset[i] = ((DELAY_PER_TRANSMITTER_COMP * (NUM_TRANSMITTERS - i - 1) * sin_value) >> (SIN_WIDTH-1)); // multiplying by 59 dividing by 60. maybe increase the bit width of sin_value and incrase vals by 1
                end else begin // if propogating angle to right. trigger left most transmitter first
                    default_offset[i] = ((DELAY_PER_TRANSMITTER_COMP * i * sin_value) >> (SIN_WIDTH-1)); // potentially dangerous. shouldnt be to many operations because a and b are relatively closde
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
