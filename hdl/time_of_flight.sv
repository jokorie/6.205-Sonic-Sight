`timescale 1ns / 1ps
`default_nettype none

module time_of_flight (
    input logic [31:0] time_since_emission,             // Start trigger for ToF calculation
    input logic echo_detected,          // Signal indicating the reflected pulse has been received
    input logic clk_in,                    // 100 MHz clock for precise timing
    input logic rst_in,                 // Active-high reset signal
    output logic [15:0] range_out,      // Calculated distance output in centimeters
    output logic valid_out,             // Output validity flag
    output logic object_detected     // Flag indicating object detected within the time window
);

    // Parameters
    parameter SPEED_OF_SOUND = 34300;   // Speed of sound in cm/s (converted from 343 m/s to 34300 cm/s)
    parameter MAX_TIME_WINDOW = 500000; // Maximum time window in clock cycles (500000 cycles = 5 ms for 100 MHz clock)

    
    // Internal Signals
    logic measurement_active;           // Flag to indicate if measurement is in progress

    // Always block for ToF measurement
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            // Reset internal signals
            measurement_active <= 1'b1;
            range_out <= 16'd0;
            valid_out <= 1'b0;
            object_detected <= 1'b0;
        end else begin
            if (measurement_active) begin
                // Stop measuring when echo is detected
                if (echo_detected) begin
                    measurement_active <= 1'b0; // TODO: Need to figure out what were going to do with measurement activn
                    object_detected <= 1'b1;
 
                end
                // Check if maximum time window has been exceeded
                else if (time_since_emission >= MAX_TIME_WINDOW) begin
                    measurement_active <= 1'b0;
                    valid_out <= 1'b1;
                    object_detected <= 1'b0; // Indicate that no object was detected in time
                end
            end
        end
    end

    logic numerator [31:0];
    logic div_output [31:0];
    assign numerator = SPEED_OF_SOUND * time_since_emission;
    logic error_out;


    divider #(.WIDTH(32))
       tof_div (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(numerator),
        .divisor_in(200000000),
        .data_valid_in(echo_detected), // TODO: MAY NEED TO DELAY A CYCLE
        .quotient_out(div_output),
        .remainder_out(),
        .data_valid_out(valid_out),
        .error_out(error_out),
        .busy_out()
    );

    assign range_out = div_output[15:0];
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
