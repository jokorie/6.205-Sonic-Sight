`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module top_level(
  input wire clk_100mhz,                   // 100 MHz onboard clock
  input wire [3:0] btn,                    // All four momentary button switches
  output logic [6:0] ss_c,                 // Cathode controls for the segments of the seven-segment display
  output logic [7:0] ss_an                 // Anode control for selecting display
);

  localparam BURST_DURATION = 2147483648; // in clock cycles   // TODO: BURST DURATION OF PULSE

  // System Reset
  logic sys_rst;
  assign sys_rst = btn[0];

  logic burst_rst;
  assign burst_rst = sys_rst || (time_since_emission == 0);  // TODO validate later

  // Transmit Beamforming Signals
  logic signed tx_out [3:0];        // Output signals for the four transmitters

  // Receive Beamforming Signals
  logic signed [15:0] adc_in [3:0];        // Digital inputs from the 4 ADCs
  logic signed [15:0] aggregated_waveform; // Aggregated output waveform from the receivers
  
  logic [15:0] time_since_emission;

  evt_counter time_counter #(
    .MAX_COUNT(BURST_DURATION)
  )
  (
      .clk_in(clk_in),
      .rst_in(burst_rst),
      .evt_in(clk_in),
      .count_out(time_since_emission)
  );


  // Transmit Beamforming Instance
  transmit_beamformer tx_beamformer_inst (
    .clk(clk_100mhz),
    .rst_in(burst_rst),
    .tx_out(tx_out)
  );

  // Receive Beamforming Instance
  receive_beamform rx_beamform_inst (
    .clk(clk_100mhz),
    .rst_n(burst_rst),
    .adc_in(adc_in),
    .aggregated_waveform(aggregated_waveform)
  );

  // Echo Detection Signal
  logic echo_detected;
  localparam ECHO_THRESHOLD = 1000; // Example threshold for detection
  assign echo_detected = (aggregated_waveform > ECHO_THRESHOLD);

  
  logic [15:0] range_out;
  logic tof_valid_out;
  logic tof_object_detected;

  time_of_flight tof (
    .time_since_emission(time_since_emission),
    .echo_detected(echo_detected),
    .clk_in(clk_100mhz),
    .rst_in(burst_rst),
    .range_out(range_out),
    .valid_out(tof_valid_out),
    .tof_(tof_object_detected)
  )

  // Prepare FFT input: pack real and imaginary parts
  assign fft_input = {beamform_data, 16'h0000}; // Real = beamform_data, Imaginary = 0
  assign fft_valid = beamform_valid;           // Pass beamform valid signal to FFT

  // Instantiate FFT module
  fftmain fft_inst (
      .i_clk(clk_100mhz),
      .i_reset(burst_rst),
      .i_ce(fft_valid),         // FFT valid signal
      .i_sample(fft_input),     // Packed 32-bit FFT input
      .o_result(fft_output),    // Packed 32-bit FFT output
      .o_sync(fft_sync)         // Sync signal for FFT output
  );

  // Unpack FFT output: extract real and imaginary parts
  assign fft_real = fft_output[31:16];  // Upper 16 bits = Real part
  assign fft_imag = fft_output[15:0];   // Lower 16 bits = Imaginary part

  // Seven Segment Controller Instance
  seven_segment_controller controller (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .trigger_in(tof_valid_out), // TODO: how do you want to handle undetected objects
    .distance_in(range_out),
    .cat_out(ss_c),
    .an_out(ss_an)
  );

endmodule

`default_nettype wire
