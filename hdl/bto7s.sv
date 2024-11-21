`timescale 1ns / 1ps
`default_nettype none

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
