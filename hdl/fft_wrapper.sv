`default_nettype none

module fft_wrapper #(
    parameter SAMPLE_RATE = 1000000,   // Sampling rate in Hz
    parameter FFT_SIZE = 2048        // Number of FFT points
) (
    input  logic                   clk_in,            // System clock
    input  logic                   rst_in,          // Synchronous rst_in
    input  logic                   ce,             // Clock enable for FFT input
    input  logic [31:0]            sample_in,      // Packed real and imaginary input
    output logic [31:0]            peak_frequency, // Peak frequency in Hz
    output logic                   peak_valid      // Valid signal for peak frequency
);

    // Internal signals
    logic                   fft_sync;            // FFT sync signal
    logic [43:0]     fft_result;          // Packed FFT output
    logic                   fft_active;           // FFT output valid
    logic signed [21:0]     fft_real, fft_imag;  // Unpacked real and imaginary parts
    logic [10:0]            current_index;       // Current FFT bin index
    logic [10:0]            max_index;           // Index of the peak bin
    logic [43:0]            magnitude_squared;   // Magnitude squared
    logic [43:0]            max_magnitude;       // Maximum magnitude squared

    // Instantiate the FFT module
    // once result ready should stream out cycle after cycle
    typedef enum {NOT_STARTED, STARTED, DONE} state_t;
    state_t state;

    logic true_ce;
    assign true_ce = (state == NOT_STARTED)? ce: (state == STARTED)? 1: 0;


    // stream in at sampling rate
    // stream out at clock rate
    fftmain fft_inst (
        .i_clk(clk_in),
        .i_reset(rst_in),
        .i_ce(true_ce),
        .i_sample(sample_in),
        .o_result(fft_result),
        .o_sync(fft_sync)
    );

    assign fft_real = $signed(fft_result[43:22]);
    assign fft_imag = $signed(fft_result[21:0]);

    logic [43:0] real_sq;
    logic [43:0] imag_sq;
    // logic [43:0] sum;
    // Magnitude squared computation
    always_comb begin
        real_sq = fft_real * fft_real;
        imag_sq = fft_imag * fft_imag;
        magnitude_squared = real_sq + imag_sq;
        // magnitude_squared = $signed(fft_real * fft_real) + $signed(fft_imag * fft_imag);
        peak_frequency = (max_index * SAMPLE_RATE) >> 11;
    end

    // Peak detection logic
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            max_magnitude <= 0;
            max_index <= 0;
            current_index <= 0;
            peak_valid <= 0;
            state <= NOT_STARTED;
        end else if (state == NOT_STARTED) begin
            if (fft_sync) begin // ok to neglect calculations for one cycle
                current_index <= current_index + 1;
                state <= STARTED;
            end
        end else if (state == STARTED) begin
            if (
                magnitude_squared > max_magnitude &&
                current_index > 40 && 
                current_index < 120
            ) begin // filters the search within reasonable range
                max_magnitude <= magnitude_squared;
                max_index <= current_index;
            end
            // Increment current index
            current_index <= current_index + 1; // W overflow
            if (current_index == 2047) begin
                peak_valid <= 1;
                state <= DONE;
            end
        end else begin // state == DONE
            peak_valid <= 0;
        end    
    end
endmodule

`default_nettype wire
