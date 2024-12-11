`default_nettype none

// Can track MAX_COUNT counts. Does not include MAX_COUNT
module evt_counter #(
    parameter MAX_COUNT = 2147483647 // some power of 2. prolly 2^32
)
  ( input wire           clk_in,
    input wire           rst_in,
    input wire           evt_in,
    input wire[$clog2(MAX_COUNT)-1:0] default_offset,
    output logic[$clog2(MAX_COUNT)-1:0] count_out // Adjust bit-width dynamically
  );

  // Initialize count_out
  always_ff @(posedge clk_in) begin

    if (rst_in) begin
      count_out <= default_offset;
    end else if (evt_in) begin
      if (count_out == (MAX_COUNT - 1)) begin
        count_out <= 0;
      end else begin
        count_out <= count_out + 1;
      end
    end
  end

endmodule

`default_nettype wire
