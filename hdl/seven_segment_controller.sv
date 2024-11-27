`timescale 1ns / 1ps
`default_nettype none

module seven_segment_controller #(
  parameter COUNT_PERIOD = 100000
  )
  (
    input wire clk_in,                   // System clock input
    input wire rst_in,                   // Active-high reset signal
    input wire trigger_in,               // Trigger to move from LOADING to READY state
    input wire [15:0] distance_in,       // 16-bit distance value input
    output logic [6:0] cat_out,          // Segment control output for a-g segments
    output logic [7:0] an_out            // Anode control output for selecting display
  );

  // State definitions
  parameter LOADING = 1'b0;
  parameter READY   = 1'b1;

  // Internal signals
  logic state_reg, state_next;           // Current and next state (1-bit)
  logic [2:0] segment_index;             // Index for current active display (0 to 7)
  logic [31:0] segment_counter;          // Counter to manage display multiplexing
  logic [3:0] sel_values;                // 4-bit value to be displayed on active segment
  logic [6:0] led_out;                   // Output segment data from bto7s

  // State transition logic (sequential)
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state_reg <= LOADING;             // Start in LOADING state after reset
    end else begin
      state_reg <= state_next;          // Move to the next state
    end
  end

  // State transition conditions (combinational)
  always_comb begin
    state_next = state_reg;             // Default to hold state

    case (state_reg)
      LOADING: begin
        if (trigger_in) begin
          state_next = READY;           // Transition to READY when trigger is received
        end
      end

      READY: begin
        // Remain in READY state until reset
        state_next = READY;
      end
    endcase
  end

    logic [2:0] distance_0;
    logic [2:0] distance_1;
    logic [2:0] distance_2;
    logic [2:0] distance_3;

    assign distance_0 = distance_in[3:0];
    assign distance_1 = distance_in[7:4];
    assign distance_2 = distance_in[11:8];
    assign distance_3 = distance_in[15:12];

  // Display logic (combinational)
  always_comb begin
    case (state_reg)
      LOADING: begin
        sel_values = 4'b1010; // Represents '-' character for each display
      end
      READY: begin
        // Select the appropriate 4-bit segment value based on the active anode
        case (segment_index)
          3'd0: sel_values = distance_0;
          3'd1: sel_values = distance_1;
          3'd2: sel_values = distance_2;
          3'd3: sel_values = distance_3;
          default: sel_values = 4'b0000; // No value for unused displays
        endcase
      end
      default: begin
        sel_values = 4'b0000;  // Default to nothing
      end
    endcase
  end

  // Convert 4-bit value to seven-segment output using a helper module
  bto7s mbto7s (.x_in(sel_values), .s_out(led_out));

  // Invert outputs for common anode configuration
  assign cat_out = ~led_out; 
  assign an_out = ~(8'b00000001 << segment_index); // One-hot encoding for the active anode

  // Always_ff block for managing multiplexing of the displays
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      segment_index <= 3'd0;           // Start with the first display active
      segment_counter <= 32'd0;
    end else begin
      if (segment_counter == COUNT_PERIOD) begin
        segment_counter <= 32'd0;
        segment_index <= segment_index + 1;
        if (segment_index == 3'd7)
          segment_index <= 3'd0;       // Wrap around to the first segment
      end else begin
        segment_counter <= segment_counter + 1;
      end
    end
  end
endmodule

`default_nettype wire
