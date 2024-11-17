`timescale 1ns / 1ps
`default_nettype none

module time_of_flight (
    input logic trigger_in,             // Start trigger for ToF calculation
    input logic echo_detected,          // Signal indicating the reflected pulse has been received
    input logic clk,                    // 100 MHz clock for precise timing
    input logic rst_in,                 // Active-high reset signal
    output logic [15:0] range_out,      // Calculated distance output in centimeters
    output logic valid_out,             // Output validity flag
    output logic no_object_detected     // Flag indicating no object detected within the time window
);

    // Parameters
    parameter SPEED_OF_SOUND = 34300;   // Speed of sound in cm/s (converted from 343 m/s to 34300 cm/s)
    parameter MAX_TIME_WINDOW = 500000; // Maximum time window in clock cycles (500000 cycles = 5 ms for 100 MHz clock)

    // Internal Signals
    logic [31:0] time_counter;          // 32-bit counter to measure the time delay in clock cycles
    logic measurement_active;           // Flag to indicate if measurement is in progress

    // Always block for ToF measurement
    always_ff @(posedge clk) begin
        if (rst_in) begin
            // Reset internal signals
            time_counter <= 32'd0;
            measurement_active <= 1'b0;
            range_out <= 16'd0;
            valid_out <= 1'b0;
            no_object_detected <= 1'b0;
        end else begin
            // Trigger input: Start measuring time
            if (!measurement_active) begin
                if (trigger_in) begin
                    measurement_active <= 1'b1;
                    time_counter <= 32'd1;
                    valid_out <= 1'b0;
                    no_object_detected <= 1'b0;
                end
            end else begin
                // Measure the time delay until echo is detected
                time_counter <= time_counter + 1;

                // Stop measuring when echo is detected
                if (echo_detected) begin
                    measurement_active <= 1'b0;

                    // Calculate distance in centimeters
                    // Distance = (time_counter * (1 / clock_frequency) * SPEED_OF_SOUND) / 2
                    // clock_frequency is 100 MHz -> time per cycle = 10 ns = 0.00000001 seconds
                    range_out <= (time_counter * SPEED_OF_SOUND) / (2 * 10000000); // output in centimeters
                    valid_out <= 1'b1;
                    no_object_detected <= 1'b0;
                end
                // Check if maximum time window has been exceeded
                else if (time_counter >= MAX_TIME_WINDOW) begin
                    measurement_active <= 1'b0;
                    valid_out <= 1'b0;
                    no_object_detected <= 1'b1; // Indicate that no object was detected in time
                end
            end
        end
    end
endmodule

`default_nettype wire



// divider #(.WIDTH(32))
//        div_x (
//         .clk_in(clk_in),
//         .rst_in(rst_in),
//         .dividend_in(num_agg_x),
//         .divisor_in(count),
//         .data_valid_in(tabulate_in),
//         .quotient_out(quotient_out_x),
//         .remainder_out(),
//         .data_valid_out(div_data_valid_out_x),
//         .error_out(error_out_x),
//         .busy_out()
//     );
