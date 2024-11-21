module doppler_velocity #(
    parameter EMITTED_FREQUENCY = 40000  // Default emitted frequency in Hz
) (
    input          logic clk_in,          // System clock
    input          logic rst_in,          // System reset
    input          logic start_calc,      // Signal to start velocity calculation
    input          logic [15:0] peak_frequency,  // Peak frequency detected (Hz)
    output         logic [15:0] velocity         // Calculated velocity (m/s)
);

    // Speed of sound in air (m/s)
    localparam real SPEED_OF_SOUND = 343.0;

    // Internal register to store velocity
    logic [31:0] velocity_calc;

    // Calculate velocity on rising clock edge
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            velocity_calc <= 0;
        end else if (start_calc) begin
            // Doppler formula: velocity = (Δf / f_emit) * speed_of_sound
            // Δf = peak_frequency - EMITTED_FREQUENCY
            velocity_calc <= ((peak_frequency - EMITTED_FREQUENCY) * SPEED_OF_SOUND) / EMITTED_FREQUENCY;
        end
    end

    // Output the calculated velocity (truncate to 16 bits)
    assign velocity = velocity_calc[15:0];

endmodule
