module velocity (
    input        logic clk_in,        // System clock
    input        logic rst_in,        // System reset
    input        logic echo_detected,    // Valid signal for receiver input
    input        logic [15:0] receiver_data,    // 16-bit real receiver input
    output       logic doppler_ready,    // Ready signal for doppler_velocity module
    output       logic [15:0] velocity_result   // Output velocity from doppler_velocity
);

    // Internal signals
    logic [31:0] fft_input;           // Packed input to the FFT module
    logic        fft_valid;           // Valid signal for FFT input
    logic [31:0] fft_output;          // Packed FFT output
    logic [15:0] fft_real;            // Real part of FFT output
    logic [15:0] fft_imag;            // Imaginary part of FFT output
    logic        fft_sync;            // Sync signal from FFT
    logic [15:0] peak_frequency;      // Tracks the bin with maximum magnitude
    logic [31:0] max_magnitude;       // Stores the maximum magnitude
    logic        processing_done;     // Indicates end of FFT processing
    logic [31:0] magnitude;

    // Registers for FFT input and valid signal
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            fft_input <= 32'b0;
            fft_valid <= 1'b0;
        end else begin
            if (echo_detected) begin
                fft_input <= {receiver_data, 16'h0000}; // Real + Imaginary zero-padded
                fft_valid <= 1'b1;
            end else begin
                fft_valid <= 1'b0;
            end
        end
    end

    // Instantiate FFT module
    fftmain fft_inst (
        .i_clk(clk_in),
        .i_reset(rst_in),
        .i_ce(fft_valid),
        .i_sample(fft_input),
        .o_result(fft_output),
        .o_sync(fft_sync)
    );

    // Unpack FFT output
    assign fft_real = fft_output[31:16];
    assign fft_imag = fft_output[15:0];

    // Compute the magnitude: |real|^2 + |imag|^2
    assign magnitude = fft_real * fft_real + fft_imag * fft_imag;

    // Track peak frequency bin
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            peak_frequency <= 16'b0;
            max_magnitude <= 32'b0;
            processing_done <= 1'b0;
        end else begin
            if (fft_valid) begin
                // Update peak frequency bin if magnitude is greater
                if (magnitude > max_magnitude) begin
                    max_magnitude <= magnitude;
                    peak_frequency <= fft_real; // Store real part as peak frequency
                end
            end

            // Check if FFT processing is done
            if (fft_sync) begin
                processing_done <= 1'b1;
            end
        end
    end

    // Instantiate doppler_velocity module
    logic [15:0] doppler_velocity_result;

    // TODO: might be multiple cycles when we add the divider module
    doppler_velocity #(
        .EMITTED_FREQUENCY(40000)  // Ultrasonic frequency in Hz
    ) doppler_inst (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .start_calc(fft_sync),      // Trigger calculation at the start of FFT frame
        .peak_frequency(peak_frequency),
        .velocity(doppler_velocity_result)
    );


    // Output signals
    assign doppler_ready = processing_done;  // Doppler module ready signal
    assign velocity_result = doppler_velocity_result;

endmodule
