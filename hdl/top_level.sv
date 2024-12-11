`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module top_level (
  input wire clk_100mhz,                   // 100 MHz onboard clock
  input wire cipo,
  input wire [3:0] btn,                    // All four momentary button switches
  input wire [15:0] sw, //all 16 input slide switches
  output logic [3:0] ss0_an,//anode control for upper four digits of seven-seg display
  output logic [3:0] ss1_an,//anode control for lower four digits of seven-seg display
  output logic [6:0] ss0_c, //cathode controls for the segments of upper four digits
  output logic [6:0] ss1_c, //cathode controls for the segments of lower four digits
  output logic [3:0] transmitters_input,
  output wire dclk,
  output wire cs
);

  localparam PERIOD_DURATION = 16777216; // 2^24 in clock cycles a little under 2 tenths of seconds
  localparam BURST_DURATION = 524288; // 2^19 in clock cycles   
  localparam ECHO_THRESHOLD = 5000; // Example threshold for detection
  localparam SIN_WIDTH = 17;               // Bit width for sine values
  localparam ANGLE_WIDTH = 8;              // Bit width for beam angle input
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


  logic signed [ANGLE_WIDTH-1:0] beam_angle;
  assign beam_angle = 1'sb0; // static beam forming perpendicular to board, in line with boresight
  // Move from [-30, 30]. Step 10 degrees


  logic [SIN_WIDTH-1:0] sin_value; // Sine value for beam_angle
  logic sign_bit;
  sin_lut #(
      .SIN_WIDTH(SIN_WIDTH),
      .ANGLE_WIDTH(ANGLE_WIDTH)
  ) sin_lookup (
      .angle(beam_angle), // degrees off boresight
      .sin_value(sin_value),
      .sign_bit(sign_bit) // high if value is negative, low otw
  );


  // Transmit Beamforming Signals
  logic [NUM_TRANSDUCERS-1:0] tx_out;        // output signals for beamforming module
  // Transmit Beamforming Instance
  transmit_beamformer tx_beamformer_inst (
    .clk(clk_100mhz),
    .rst_in(sys_rst || burst_start), // conditions to stop transmitting
    .sin_value(sin_value),
    .sign_bit(sig_bit),
    .tx_out(tx_out)
  );

  assign transmitters_input = (active_pulse)? tx_out: 0;

  // TODO: INCLUDE SPI MODULE
  logic [7:0]                spi_trigger_count;
  logic                      spi_trigger;
  logic                      receiving;

  evt_counter counter_1MHz_trigger (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst || burst_start),
    .period_in(CYCLES_PER_TRIGGER),
    .evt_in(clk_100mhz && !active_pulse),
    .count_out(spi_trigger_count)
  );

  assign spi_trigger = spi_trigger_count == 0 && !active_pulse;

  logic [ADC_DATA_WIDTH-1:0] spi_read_data;
  logic                      spi_read_data_valid;

  spi_con
  #(  .DATA_WIDTH(ADC_DATA_WIDTH),
      .DATA_CLK_PERIOD(ADC_DATA_CLK_PERIOD)
  ) spi_controller
  (   .clk_in(clk_100mhz),
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
  receive_beamformer rx_beamform_inst (
    .clk(clk_100mhz),
    .rst_n(sys_rst || burst_start),
    .adc_in(adc_in),
    .sin_theta(sin_value),
    .sign_bit(sig_bit),
    .data_valid_in(spi_read_data_valid), // cannot be fpga clock
    .aggregated_waveform(aggregated_waveform)
  );


  // Echo Detection Signal
  logic echo_detected;
  logic [15:0] buffered_aggregated_waveform;

  always_ff @(posedge clk_100mhz) begin
    if (sys_rst || burst_start) begin
      echo_detected <= 0;
      buffered_aggregated_waveform <= 0;
    end
    else begin
      buffered_aggregated_waveform <= aggregated_waveform;
      if (aggregated_waveform > ECHO_THRESHOLD) begin
        echo_detected <= 1;
      end
    end
  end

  
  logic [15:0] range_out;
  logic tof_valid_out;

  time_of_flight tof (
    .time_since_emission(time_since_emission),
    .echo_detected(echo_detected),
    .clk_in(clk_100mhz),
    .rst_in(sys_rst || burst_start),
    .range_out(range_out),
    .valid_out(tof_valid_out)
  );

  logic ready_velocity;
  logic [15:0] velocity_result;
  logic towards_observer;

  velocity velocity_calculator_inst (
    .clk_in(clk_in),
    .rst_in(sys_rst || burst_start),
    .echo_detected(echo_detected),
    .receiver_data(buffered_aggregated_waveform),
    .doppler_ready(ready_velocity),
    .velocity_result(velocity_result),
    .stored_towards_observer(towards_observer)
  );

  logic stored_tof_ready;
  logic [15:0] stored_tof_range_out;
  logic stored_velocity_ready;
  logic [15:0] stored_velocity_result;
  logic stored_towards_observer;

  always_ff @(posedge clk_100mhz) begin
    if (sys_rst || burst_start) begin
      stored_tof_ready <= 0;
      stored_tof_range_out <= 0;
      stored_velocity_ready <= 0;
      stored_velocity_result <= 0;
      stored_towards_observer <= 0;
    end else begin
      if (tof_valid_out) begin
        stored_tof_ready <= 1;
        stored_tof_range_out <= range_out;
      end
      if (ready_velocity) begin
        stored_velocity_ready <= 1;
        stored_velocity_result <= velocity_result;
        stored_towards_observer <= towards_observer;
      end
    end
  end

  
  
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
