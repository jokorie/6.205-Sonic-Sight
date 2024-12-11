`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module top_level (
  input wire clk_100mhz,                   // 100 MHz onboard clock
  input wire cipo0,
  input wire cipo1,
  input wire [3:0] btn,                    // All four momentary button switches
  input wire [15:0] sw, //all 16 input slide switches
  output logic [3:0] ss0_an,//anode control for upper four digits of seven-seg display
  output logic [3:0] ss1_an,//anode control for lower four digits of seven-seg display
  output logic [6:0] ss0_c, //cathode controls for the segments of upper four digits
  output logic [6:0] ss1_c, //cathode controls for the segments of lower four digits
  output logic [1:0] transmitters_input,
  output wire dclk0,
  output wire dclk1,
  output wire cs0,
  output wire cs1,
  output logic [2:0]  rgb0,
  output logic [2:0]  rgb1
);

  localparam PERIOD_DURATION = 16777216;   // 2^24 in clock cycles a little under 2 tenths of seconds
  localparam BURST_DURATION = 524288;      // 2^19 in clock cycles   
  // localparam ECHO_THRESHOLD = 5000;        // Example threshold for detection
  localparam ECHO_THRESHOLD = 0;        // Example threshold for detection
  localparam SIN_WIDTH = 17;               // Bit width for sine values
  localparam ANGLE_WIDTH = 8;              // Bit width for beam angle input
  localparam NUM_TRANSMITTERS = 2;
  localparam CYCLES_PER_TRIGGER  = 100;    // Clock Cycles between 1MHz trigger
  localparam ADC_DATA_WIDTH = 16;
  localparam ADC_DATA_CLK_PERIOD = 5;

  // shut up those RGBs
  assign rgb0 = 0;
  assign rgb1 = 0;

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
      .clk_in(clk_100mhz),
      .rst_in(sys_rst),
      .default_offset(0),
      .sig_out(active_pulse)
  );

  always_ff @(posedge clk_100mhz) begin
    if (sys_rst) begin
      prev_active_pulse <= 0;
    end else begin
      prev_active_pulse <= active_pulse;
    end
  end

  assign burst_start = active_pulse && !prev_active_pulse;

  logic [$clog2(PERIOD_DURATION)-1:0] time_since_emission;

  evt_counter  #(
    .MAX_COUNT(PERIOD_DURATION)
  ) time_counter
  (
      .clk_in(clk_100mhz),
      .rst_in(burst_start), // conditions to reset burst
      .evt_in(1'b1),
      .count_out(time_since_emission)
  );


logic signed [ANGLE_WIDTH-1:0] beam_angle;
logic angle_going_right;

  // Move from [-30, 30]. Step 10 degrees
always_ff @(posedge clk_100mhz) begin
    if (burst_start) begin
        beam_angle <= 8'sb0;         // Reset the angle to 0
        angle_going_right <= 1;      // Start moving in the positive direction
    end else begin
        if (angle_going_right) begin
            if (beam_angle == 8'sd30) begin
                beam_angle <= 8'sd20;        // Step back to 20 to reverse smoothly
                angle_going_right <= 0;      // Reverse direction
            end else begin
                beam_angle <= beam_angle + 8'sd10; // Increment angle
            end
        end else begin // Moving left
            if (beam_angle == -8'sd30) begin // Check for -30 limit
                beam_angle <= -8'sd20;       // Step forward to -20 to reverse smoothly
                angle_going_right <= 1;      // Reverse direction
            end else begin
                beam_angle <= beam_angle - 8'sd10; // Decrement angle
            end
        end
    end
end


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
  logic [NUM_TRANSMITTERS-1:0] tx_out;        // output signals for beamforming module
  // Transmit Beamforming Instance
  transmit_beamformer tx_beamformer_inst (
    .clk_in(clk_100mhz),
    .rst_in(burst_start), // conditions to stop transmitting
    .sin_value(sin_value),
    .sign_bit(sign_bit),
    .tx_out(tx_out)
  );

  assign transmitters_input = (active_pulse)? tx_out: 0;

  // TODO: INCLUDE SPI MODULE
  logic [6:0]                spi_trigger_count;
  logic                      spi_trigger;

  evt_counter  
  #(.MAX_COUNT(CYCLES_PER_TRIGGER)
    ) counter_1MHz_trigger 
    (
    .clk_in(clk_100mhz),
    .rst_in(burst_start),
    .evt_in(!active_pulse),
    .count_out(spi_trigger_count)
  );

  assign spi_trigger = spi_trigger_count == 0 && !active_pulse;

  logic [ADC_DATA_WIDTH-1:0] spi_read_data_0;
  logic [ADC_DATA_WIDTH-1:0] spi_read_data_1;
  logic                      spi_read_data_valid_0;
  logic                      spi_read_data_valid_1;


  spi_con
  #(  .DATA_WIDTH(ADC_DATA_WIDTH),
      .DATA_CLK_PERIOD(ADC_DATA_CLK_PERIOD)
  ) spi_controller_0
  (   .clk_in(clk_100mhz),
      .rst_in(burst_start),
      .trigger_in(spi_trigger),
      .data_out(spi_read_data_0),
      .data_valid_out(spi_read_data_valid_0),
      .chip_data_in(cipo0), // sdata on adc
      .chip_clk_out(dclk0), // sclk on adc
      .chip_sel_out(cs0));   // CS on adc

  spi_con
  #(  .DATA_WIDTH(ADC_DATA_WIDTH),
      .DATA_CLK_PERIOD(ADC_DATA_CLK_PERIOD)
  ) spi_controller_1
  (   .clk_in(clk_100mhz),
      .rst_in(burst_start),
      .trigger_in(spi_trigger),
      .data_out(spi_read_data_1),
      .data_valid_out(spi_read_data_valid_1),
      .chip_data_in(cipo1), // sdata on adc
      .chip_clk_out(dclk1), // sclk on adc
      .chip_sel_out(cs1));   // CS on adc

  // Receive Beamforming Signals
  logic [15:0] adc_in [NUM_TRANSMITTERS-1:0];        // Digital inputs from the 2 ADCs

  // ------------------- HARDCODED ----------------------------
  assign adc_in[0] = {6'b0, spi_read_data_0[11:2]};
  assign adc_in[1] = {6'b0, spi_read_data_1[11:2]};
  // ------------------- HARDCODED ----------------------------

  logic [15:0] aggregated_waveform; // Aggregated output waveform from the receivers

  // Receive Beamforming Instance
  receive_beamformer rx_beamform_inst (
    .clk_in(clk_100mhz),
    .rst_in(burst_start),
    .adc_in(adc_in),
    .sin_theta(sin_value),
    .sign_bit(sign_bit),
    .data_valid_in(spi_read_data_valid_0), // should tech be in sync w other read data valid
    .aggregated_waveform(aggregated_waveform)
  );


  // Echo Detection Signal
  logic echo_detected;
  logic [15:0] buffered_aggregated_waveform;

  always_ff @(posedge clk_100mhz) begin
    if (burst_start) begin
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
    .rst_in(burst_start),
    .range_out(range_out),
    .valid_out(tof_valid_out)
  );

  logic ready_velocity;
  logic [15:0] velocity_result;
  logic towards_observer;

  velocity velocity_calculator_inst (
    .clk_in(clk_100mhz),
    .rst_in(burst_start),
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

  logic [6:0] ss_c;

  logic temp_ready = 1;
  logic [15:0] temp_dist = 100;
  logic [15:0] temp_velocity = 100;
  logic temp_towards = 0;
  
 seven_segment_controller ssc
  (
    .clk_in(clk_100mhz),                   // System clock input
    .rst_in(burst_start),                   // Active-high reset signal
    .trigger_in(temp_ready),               // Trigger to move from LOADING to READY state
    .distance_in(temp_dist),       // Distance in cm
    .velocity_in(temp_velocity),       // Velocity in m/s (absolute value)
    .towards_observer(temp_towards),         // Direction of velocity: 1 for "-", 0 for "+"
    .angle_in(beam_angle),           // Angle value in degrees (0-360)
    .cat_out(ss_c),          // Segment control output for a-g segments
    .an_out({ss0_an, ss1_an})            // Anode control output for selecting display
  );

  assign ss0_c = ss_c;
  assign ss1_c = ss_c;

endmodule

`default_nettype wire
