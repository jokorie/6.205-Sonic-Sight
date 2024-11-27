`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module top_level (
  input wire clk_100mhz,                   // 100 MHz onboard clock
  input wire [3:0] btn,                    // All four momentary button switches
  output logic [6:0] ss_c,                 // Cathode controls for the segments of the seven-segment display
  output logic [7:0] ss_an,                 // Anode control for selecting display
  output logic [3:0] transmitters_input
);

  localparam PERIOD_DURATION = 16777216; // 2^24 in clock cycles 
  localparam BURST_DURATION = 524288; // 2^19 in clock cycles   
  localparam ECHO_THRESHOLD = 5000; // Example threshold for detection
  localparam SIN_WIDTH = 16;               // Bit width for sine values
  localparam ANGLE_WIDTH = 7;              // Bit width for beam angle input
  localparam NUM_TRANSDUCERS = 4;
  localparam CYCLES_PER_TRIGGER  = 100; // Clock Cycles between 1MHz trigger
  localparam ADC_DATA_WIDTH = 16;
  localparam ADC_DATA_CLK_PERIOD = 5;


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
      .rst_in(sys_rst),
      .default_offset(0),
      .sig_out(active_pulse)
  );

  assign burst_start = active_pulse && ~prev_active_pulse;

  always_ff @(posedge clk_100mhz) begin
    prev_active_pulse <= active_pulse;
  end

  logic [$clog2(PERIOD_DURATION)-1:0] time_since_emission;

  evt_counter  #(
    .MAX_COUNT(PERIOD_DURATION)
  ) time_counter
  (
      .clk_in(clk_in),
      .rst_in(sys_rst || burst_start), // conditions to reset burst
      .evt_in(clk_in),
      .count_out(time_since_emission)
  );


  logic signed [ANGLE_WIDTH-1:0] beam_angle
  assign beam_angle = 1'sb0; // static beam forming perpendicular to board, in line with boresight
  // Move from [-30, 30]. Step 10 degrees


  logic [SIN_WIDTH-1:0] sin_theta; // Sine value for beam_angle
  logic sign_bit;
  sin_lut #(
      .SIN_WIDTH(SIN_WIDTH),
      .ANGLE_WIDTH(ANGLE_WIDTH)
  ) sin_lookup (
      .angle(beam_angle),
      .sin_value(sin_theta),
      .sign_bit(sign_bit)
  );


  // Transmit Beamforming Signals
  logic tx_out [NUM_TRANSDUCERS-1:0];        // Output signals for the four transmitters
  // Transmit Beamforming Instance
  transmit_beamformer tx_beamformer_inst (
    .clk(clk_100mhz),
    .rst_in(sys_rst || burst_start), // conditions to stop transmitting
    .sin_theta(sin_theta),
    .sign_bit(sig_bit),
    .tx_out(tx_out)
  );

  assign transmitters_input = (active_pulse)? tx_out: 0;

  // TODO: INCLUDE SPI MODULE
  logic [7:0]                trigger_count;
  logic                      spi_trigger;
  logic                      receiving;

  evt_counter counter_1MHz_trigger
   (.clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .period_in(CYCLES_PER_TRIGGER),
    .evt_in(clk_100mhz && !active_pulse),
    .count_out(trigger_count));

  assign spi_trigger = trigger_count == 0 && !active_pulse;

  logic [ADC_DATA_WIDTH-1:0] spi_read_data;
  logic                      spi_read_data_valid;

  spi_con
  #(  .DATA_WIDTH(ADC_DATA_WIDTH),
      .DATA_CLK_PERIOD(ADC_DATA_CLK_PERIOD)
  ) spi_controller
  (   .clk_in(clk_20mhz),
      .rst_in(sys_rst || burst_start),
      .trigger_in(spi_trigger),
      .data_out(spi_read_data),
      .data_valid_out(spi_read_data_valid),
      .chip_data_in(cipo), // sdata on adc
      .chip_clk_out(dclk), // sclk on adc
      .chip_sel_out(cs));   // CS on adc

  // Receive Beamforming Signals
  logic [15:0] adc_in [NUM_TRANSDUCERS-1:0];        // Digital inputs from the 4 ADCs
  logic [15:0] aggregated_waveform; // Aggregated output waveform from the receivers

  // Receive Beamforming Instance
  receive_beamform rx_beamform_inst (
    .clk(clk_100mhz),
    .rst_n(sys_rst || burst_start),
    .adc_in(adc_in),
    .sin_theta(sin_theta),
    .sign_bit(sig_bit),
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
    .rst_in(sys_rst || burst_start),
    .range_out(range_out),
    .valid_out(tof_valid_out),
    .tof_(tof_object_detected)
  );


  logic ready_velocity;
  logic [15:0] velocity_result;

  velocity velocity_calculator_inst (
    .clk_in(clk_in),
    .rst_in(sys_rst || burst_start),
    .echo_detected(echo_detected),
    .receiver_data(aggregated_waveform),
    .doppler_ready(ready_velocity),
    .velocity_result(velocity_result)
  );
  // Seven Segment Controller Instance
  seven_segment_controller controller (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst || burst_start),
    .trigger_in(tof_valid_out), // TODO: how do you want to handle undetected objects
    .distance_in(range_out),
    .cat_out(ss_c),
    .an_out(ss_an)
  );

endmodule

`default_nettype wire
