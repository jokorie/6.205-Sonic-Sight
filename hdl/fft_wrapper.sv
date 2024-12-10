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
    logic [43:0]            fft_result;          // Packed FFT output
    logic                   fft_active;           // FFT output valid
    logic signed [21:0]     fft_real, fft_imag;  // Unpacked real and imaginary parts
    logic [10:0]            in_stream_idx;       // Current FFT bin index
    logic [10:0]            out_stream_idx;       // Current FFT bin index
    logic [10:0]            max_index;           // Index of the peak bin
    logic [43:0]            magnitude_squared;   // Magnitude squared
    logic [43:0]            max_magnitude;       // Maximum magnitude squared

    // Instantiate the FFT module
    // once result ready should stream out cycle after cycle
    typedef enum {NOT_STARTED, STREAMING_IN, STREAMING_OUT, DONE} state_t;
    state_t state;

    logic done_streaming_in;
    logic true_ce;
    assign true_ce = ce || done_streaming_in;


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
            in_stream_idx <= 0;
            out_stream_idx <= 0;
            peak_valid <= 0;
            done_streaming_in <= 0;
            state <= NOT_STARTED;
        end 
        else if (state == NOT_STARTED) begin
            if (true_ce) begin // ok to neglect calculations for one cycle
                in_stream_idx <= in_stream_idx + 1;
                state <= STREAMING_IN;
            end
        end 
        else if (state == STREAMING_IN) begin
            if (true_ce) begin // true ce
                if (in_stream_idx == 2047) begin
                    done_streaming_in <= 1; // set effective ce to high
                end else begin
                    in_stream_idx <= in_stream_idx + 1;
                end

                if (fft_sync) begin
                    out_stream_idx <= out_stream_idx + 1;
                    state <= STREAMING_OUT;
                end
            end
        end
        else if (state == STREAMING_OUT) begin
            if (
                magnitude_squared > max_magnitude &&
                out_stream_idx > 40 && 
                out_stream_idx < 120
            ) begin // filters the search within reasonable range
                max_magnitude <= magnitude_squared;
                max_index <= out_stream_idx;
            end
            // Increment current index
            out_stream_idx <= out_stream_idx + 1; // W overflow
            if (out_stream_idx == 2047) begin
                peak_valid <= 1;
                state <= DONE;
            end
        end 
        else begin // state == DONE
            peak_valid <= 0;
        end    
    end
endmodule

`default_nettype wire
