`default_nettype none

module velocity #(
    parameter EMITTED_FREQUENCY = 40000
) (
    input        wire clk_in,                 // System clock
    input        wire rst_in,                 // System reset
    input        wire receiver_data_valid_in, // ...........
    input        wire [15:0] receiver_data,   // 16-bit real receiver input
    output       logic doppler_ready,          // Ready signal for doppler_velocity module
    output       logic [15:0] velocity_result,  // Output velocity from doppler_velocity
    output       logic stored_towards_observer
);
    // ./fftgen -n 16 -m 36 -f 2048

    // Speed of sound in air (m/s)
    parameter SPEED_OF_SOUND = 343;

    // Internal signals
    logic [31:0] fft_input;           // Packed input to the FFT module
    logic        fft_valid;           // Valid signal for FFT input
    logic [33:0] fft_output;          // Packed FFT output
    logic signed [17:0] fft_real;            // Real part of FFT output
    logic signed [17:0] fft_imag;            // Imaginary part of FFT output
    logic        fft_sync;            // Sync signal from FFT
    logic [31:0] max_magnitude;       // Stores the maximum magnitude
    logic        processing_done;     // Indicates end of FFT processing
    logic [48:0] magnitude;
    logic [31:0] peak_frequency;
    logic peak_valid;

    assign fft_input = {receiver_data, 16'h0000};
 

    fft_wrapper fft (
        .clk_in(clk_in),           
        .rst_in(rst_in),         
        .ce(receiver_data_valid_in),            
        .sample_in(fft_input),     
        .peak_frequency(peak_frequency),
        .peak_valid(peak_valid)     
    );

    // Internal register to store velocity
    logic error_out;
    logic [31:0] velocity_calc;
    logic [31:0] numerator;

    logic towards_observer;
    assign towards_observer = peak_frequency < EMITTED_FREQUENCY;
    assign numerator = (towards_observer)? 
                        (EMITTED_FREQUENCY - peak_frequency) * SPEED_OF_SOUND:
                        (peak_frequency - EMITTED_FREQUENCY) * SPEED_OF_SOUND;


    always_ff @(posedge clk_in) begin
        if (rst_in) stored_towards_observer <= 0;
        if (peak_valid) stored_towards_observer <= towards_observer;
    end

    // Doppler formula: velocity = (Δf / f_emit) * speed_of_sound
    // Δf = peak_frequency - EMITTED_FREQUENCY
    divider #(.WIDTH(32))
       velocity_div (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(numerator),
        .divisor_in(peak_frequency),
        .data_valid_in(peak_valid),
        .quotient_out(velocity_calc),
        .remainder_out(),
        .data_valid_out(doppler_ready),
        .error_out(error_out),
        .busy_out()
    );
    
    assign velocity_result = velocity_calc[15:0];

endmodule

`default_nettype wire
