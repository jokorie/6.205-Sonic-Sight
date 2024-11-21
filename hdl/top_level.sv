`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module top_level(
  input wire clk_100mhz,                   // 100 MHz onboard clock
  input wire [3:0] btn,                    // All four momentary button switches
  output logic [6:0] ss_c,                 // Cathode controls for the segments of the seven-segment display
  output logic [7:0] ss_an                 // Anode control for selecting display
);

  localparam PERIOD_DURATION = 2147483648; // in clock cycles 
  localparam BURST_DURATION = 1073741824; // in clock cycles   
  localparam ECHO_THRESHOLD = 5000; // Example threshold for detection


  // System Reset
  logic sys_rst;
  assign sys_rst = btn[0];

  logic prev_active_pulse;
  logic active_pulse;
  logic burst_start;
  pwm #(
      .PERIOD_IN_CLOCK_CYCLES(PERIOD_DURATION), // Cumulative delay
      .DUTY_CYCLE_ON(BURST_DURATION)
  ) pulse_cooldown (
      .clk_in(clk),
      .rst_in(rst_in),
      .sig_out(active_pulse)
  );

  assign burst_start = active_pulse && ~prev_active_pulse;

  always_ff @(posedge clk_100mhz) begin
    prev_active_pulse <= active_pulse;
  end

  logic [15:0] time_since_emission;

  evt_counter  #(
    .MAX_COUNT(BURST_DURATION)
  ) time_counter
  (
      .clk_in(clk_in),
      .rst_in(rst_in || burst_start), // conditions to reset burst
      .evt_in(clk_in),
      .count_out(time_since_emission)
  );


  // Transmit Beamforming Signals
  logic tx_out [3:0];        // Output signals for the four transmitters
  // Transmit Beamforming Instance
  transmit_beamformer tx_beamformer_inst (
    .clk(clk_100mhz),
    .rst_in(rst_in || burst_start), // conditions to stop transmitting
    .tx_out(tx_out)
  );

  logic transmitters_input [3:0]; // TODO: DYLAN THE INPUT SIGNAL TO THE TRANSMITTER
  assign transmitters_input = (active_pulse)? tx_out: 0;

  // Receive Beamforming Signals
  logic [15:0] adc_in [3:0];        // Digital inputs from the 4 ADCs
  logic [15:0] aggregated_waveform; // Aggregated output waveform from the receivers

  // Receive Beamforming Instance
  receive_beamform rx_beamform_inst (
    .clk(clk_100mhz),
    .rst_n(rst_in || burst_start),
    .adc_in(adc_in),
    .aggregated_waveform(aggregated_waveform)
  );


  // Echo Detection Signal
  logic echo_detected;
  assign echo_detected = (aggregated_waveform > ECHO_THRESHOLD);

  
  logic [15:0] range_out;
  logic tof_valid_out;
  logic tof_object_detected;

  time_of_flight tof (
    .time_since_emission(time_since_emission),
    .echo_detected(echo_detected),
    .clk_in(clk_100mhz),
    .rst_in(rst_in || burst_start),
    .range_out(range_out),
    .valid_out(tof_valid_out),
    .tof_(tof_object_detected)
  );


  logic ready_velocity;
  logic [15:0] velocity_result;

  velocity velocity_calculator_inst (
    .clk_in(clk_in),
    .rst_in(rst_in || burst_start),
    .echo_detected(echo_detected),
    .receiver_data(aggregated_waveform),
    .doppler_ready(ready_velocity),
    .velocity_result(velocity_result)
  );
  // Seven Segment Controller Instance
  seven_segment_controller controller (
    .clk_in(clk_100mhz),
    .rst_in(rst_in || burst_start),
    .trigger_in(tof_valid_out), // TODO: how do you want to handle undetected objects
    .distance_in(range_out),
    .cat_out(ss_c),
    .an_out(ss_an)
  );

endmodule

`default_nettype wire
