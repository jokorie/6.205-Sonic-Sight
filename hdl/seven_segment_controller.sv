`timescale 1ns / 1ps
`default_nettype none

module seven_segment_controller #(parameter COUNT_PERIOD = 100000)
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
  logic [7:0] segment_state;             // Current active display
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

  // Display logic (combinational)
  always_comb begin
    case (state_reg)
      LOADING: begin
          sel_values = 4'b1010; // Represents '-' character for each display
      end
      READY: begin
        // If valid flag is set, display the distance; otherwise display dashes
          // Select the appropriate 4-bit segment value based on the active anode
          case (segment_state)
            8'b0000_0001: sel_values = distance_in[3:0];
            8'b0000_0010: sel_values = distance_in[7:4];
            8'b0000_0100: sel_values = distance_in[11:8];
            8'b0000_1000: sel_values = distance_in[15:12];
            default: sel_values = 4'b0000; // No value (for unused displays)
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
  assign an_out = ~segment_state;

  // Always_ff block for managing multiplexing of the displays
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      segment_state <= 8'b0000_0001;     // Start with the first display active
      segment_counter <= 32'd0;
    end else begin
      if (segment_counter == COUNT_PERIOD) begin
        segment_counter <= 32'd0;
        segment_state <= {segment_state[6:0], segment_state[7]}; // Rotate active display
      end else begin
        segment_counter <= segment_counter + 1;
      end
    end
  end
endmodule

// Module to convert 4-bit input to seven-segment display output
module bto7s(input wire [3:0] x_in, output logic [6:0] s_out);
  always_comb begin
    case (x_in)
      4'h0: s_out = 7'b0111111; // 0
      4'h1: s_out = 7'b0000110; // 1
      4'h2: s_out = 7'b1011011; // 2
      4'h3: s_out = 7'b1001111; // 3
      4'h4: s_out = 7'b1100110; // 4
      4'h5: s_out = 7'b1101101; // 5
      4'h6: s_out = 7'b1111101; // 6
      4'h7: s_out = 7'b0000111; // 7
      4'h8: s_out = 7'b1111111; // 8
      4'h9: s_out = 7'b1101111; // 9
      4'hA: s_out = 7'b1110111; // Dash ('-')
      default: s_out = 7'b0000000; // Default to all segments off
    endcase
  end
endmodule

`default_nettype wire
