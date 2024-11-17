`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module top_level(
  input wire clk_100mhz,                   // 100 MHz onboard clock
  input wire [3:0] btn,                    // All four momentary button switches
  output logic [6:0] ss_c,                 // Cathode controls for the segments of the seven-segment display
  output logic [7:0] ss_an                 // Anode control for selecting display
);

  // System Reset
  logic sys_rst;
  assign sys_rst = btn[0];

  // Wave Generation Signals
  logic signed [15:0] wave_out;            // Wave output from the wave generator

  // Transmit Beamforming Signals
  logic signed [15:0] tx_out [3:0];        // Output signals for the four transmitters

  // Receive Beamforming Signals
  logic signed [15:0] adc_in [3:0];        // Digital inputs from the 4 ADCs
  logic signed [15:0] aggregated_waveform; // Aggregated output waveform from the receivers

  // Seven Segment Display Signals
  logic [15:0] distance_value;             // Distance value to be displayed on the seven-segment display
  logic trigger_in;                        // Trigger signal for the seven-segment controller

  // Wave Generator Instance
  wave_generator wave_gen_inst (
    .clk(clk_100mhz),
    .rst_n(~sys_rst),
    .wave_out(wave_out)
  );

  // Transmit Beamforming Instance
  transmit_beamformer tx_beamformer_inst (
    .clk(clk_100mhz),
    .rst_n(~sys_rst),
    .wave_in(wave_out),
    .tx_out(tx_out)
  );

  // Receive Beamforming Instance
  receive_beamform rx_beamform_inst (
    .clk(clk_100mhz),
    .rst_n(~sys_rst),
    .adc_in(adc_in),
    .aggregated_waveform(aggregated_waveform)
  );

  // Trigger Input for Seven-Segment Display (use btn[1] as trigger input)
  assign trigger_in = btn[1];

  // Distance Calculation (Dummy Example)
  // Assuming the aggregated waveform directly represents the distance value.
  // You may need to add your own distance calculation based on the ToF.
  assign distance_value = aggregated_waveform;

  // Seven Segment Controller Instance
  seven_segment_controller mssc (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .trigger_in(trigger_in),
    .distance_in(distance_value),
    .cat_out(ss_c),
    .an_out(ss_an)
  );

endmodule

`default_nettype wire
