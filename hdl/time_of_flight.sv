`default_nettype none

module time_of_flight (
    input wire [31:0] time_since_emission, // Time since emission in clock cycles
    input wire        echo_detected,       // Signal indicating the reflected pulse has been received
    input wire        clk_in,              // 100 MHz clock for precise timing
    input wire        rst_in,              // Active-high reset signal
    output logic [15:0] range_out,           // Calculated distance output in centimeters
    output logic        valid_out           // Output validity flag
);

    // Parameters
    parameter SPEED_OF_SOUND   = 34300;    // Speed of sound in cm/s

    // Internal Signals
    logic [31:0] numerator;               // Computed numerator for distance calculation
    logic [31:0] div_output;              // Output of the divider module
    logic error_out;                      // Error flag from divider module
    logic div_valid_out;
    logic prev_echo_detected;

    // Measurement Control Logic
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            // Reset internal signals
            prev_echo_detected <= 1'b0;
            valid_out <= 0;
            range_out <= 0;
        end else begin
            prev_echo_detected <= echo_detected;
            if (div_valid_out && !error_out) begin
                valid_out <= 1;
                range_out <= div_output[15:0];
            end
        end
    end

    // Distance Calculation
    assign numerator = SPEED_OF_SOUND * time_since_emission;

    // Divider Instantiation
    divider #(.WIDTH(32)) tof_div (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(numerator),
        .divisor_in(200000000),       // 2 * clock cyles per secondConversion factor for 100 MHz clock
        .data_valid_in(echo_detected & !prev_echo_detected), 
        .quotient_out(div_output),
        .remainder_out(),             // Ignored remainder
        .data_valid_out(div_valid_out),
        .error_out(error_out),
        .busy_out()
    );

endmodule

`default_nettype wire
