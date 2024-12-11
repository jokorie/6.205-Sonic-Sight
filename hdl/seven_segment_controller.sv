`default_nettype none
module seven_segment_controller #(parameter COUNT_PERIOD = 100000)
  (
    input wire clk_in,                   // System clock input
    input wire rst_in,                   // Active-high reset signal
    input wire trigger_in,               // Trigger to move from LOADING to READY state
    input wire [15:0] distance_in,       // Distance in cm
    input wire [15:0] velocity_in,       // Velocity in m/s (absolute value)
    input wire towards_observer,         // Direction of velocity: 1 for "-", 0 for "+"
    input wire [7:0] angle_in,           // Angle value in degrees (0-360)
    output logic [6:0] cat_out,          // Segment control output for a-g segments
    output logic [7:0] an_out            // Anode control output for selecting display
  );

  localparam dash_sel_value = 16;
  localparam empty_sel_value = 17;
 
  logic [7:0]   segment_state;
  logic [31:0]  segment_counter;
  logic [4:0]   sel_values;
  logic [6:0]   led_out;

  logic [3:0] upper_dist_bits;
  logic [3:0] lower_dist_bits;

  assign upper_dist_bits = distance_in[7:4];
  assign lower_dist_bits = distance_in[3:0];

  logic signed [9:0] signed_result; // size is determined as sufficient
  logic [8:0] cos_angle;

  logic signed [8:0] base;

  assign signed_result = 9'sd90 - angle;

  assign cos_angle = $unsigned(signed_result);
  // Map input angle to LUT value

  logic [3:0] upper_angle_bits;
  logic [3:0] lower_angle_bits;

  assign upper_angle_bits = cos_angle[7:4];
  assign lower_angle_bits = cos_angle[3:0];
 
  //TODO: wire up sel_values (-> x_in) with your input, val_in
  //Note that x_in is a 4 bit input, and val_in is 32 bits wide
  //Adjust accordingly, based on what you know re. which digits
  //are displayed when...
  always_comb begin
    case (segment_state)
      8'b0000_0001: sel_values = lower_angle_bits;
      8'b0000_0010: sel_values = upper_angle_bits;
      8'b0000_0100: sel_values = empty_sel_value; // should always be set to a point
      8'b0000_1000: sel_values = lower_dist_bits;
      8'b0001_0000: sel_values = upper_dist_bits;
      8'b0010_0000: sel_values = empty_sel_value;
      8'b0100_0000: sel_values = velocity_in; // type mismatch
      8'b1000_0000: sel_values = (towards_observer)? empty_sel_value: dash_sel_value;
    endcase
  end
  
  bto7s mbto7s (.x_in(sel_values), .s_out(led_out));
  assign cat_out = ~led_out; //<--note this inversion is needed
  assign an_out = ~segment_state; //note this inversion is needed
 
  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      segment_state <= 8'b0000_0001;
      segment_counter <= 32'b0;
    end else begin
      if (segment_counter == COUNT_PERIOD) begin
        segment_counter <= 32'd0;
        segment_state <= {segment_state[6:0],segment_state[7]};
      end else begin
        segment_counter <= segment_counter +1;
      end
    end
  end
endmodule // seven_segment_controller