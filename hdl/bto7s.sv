`default_nettype none

// Module to convert 4-bit input to seven-segment display output
module bto7s(
  input wire [4:0] x_in, 
  output logic [6:0] s_out
);
  always_comb begin
    case (x_in)
      5'h0: s_out = 7'b0111111; // 0
      5'h1: s_out = 7'b0000110; // 1
      5'h2: s_out = 7'b1011011; // 2
      5'h3: s_out = 7'b1001111; // 3
      5'h4: s_out = 7'b1100110; // 4
      5'h5: s_out = 7'b1101101; // 5
      5'h6: s_out = 7'b1111101; // 6
      5'h7: s_out = 7'b0000111; // 7
      5'h8: s_out = 7'b1111111; // 8
      5'h9: s_out = 7'b1101111; // 9
      5'hA: s_out = 7'b1110111; // A
      5'hB: s_out = 7'b1111100; // B (uppercase, can also be 7'b0111111 for lowercase 'b')
      5'hC: s_out = 7'b0111001; // C
      5'hD: s_out = 7'b1011110; // D (uppercase, can also be 7'b0011111 for lowercase 'd')
      5'hE: s_out = 7'b1111001; // E
      5'hF: s_out = 7'b1110001; // F
      5'h10: s_out = 7'b1000000;
      default: s_out = 7'b0000000;
    endcase
  end
endmodule

`default_nettype wire
