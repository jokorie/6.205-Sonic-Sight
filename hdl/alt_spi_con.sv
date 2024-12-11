module spi_con
     #(parameter DATA_WIDTH = 8,
       parameter DATA_CLK_PERIOD = 100
      )
      (input wire   clk_in, //system clock (100 MHz)
       input wire   rst_in, //reset in signal
       input wire   [DATA_WIDTH-1:0] data_in, //data to send
       input wire   trigger_in, //start a transaction
       output logic [DATA_WIDTH-1:0] data_out, //data received!
       output logic data_valid_out, //high when output data is present.
 
       output logic chip_data_out, //(COPI)
       input wire   chip_data_in, //(CIPO)
       output logic chip_clk_out, //(DCLK)
       output logic chip_sel_out // (CS)
      );

  localparam new_data_clk_period = (DATA_CLK_PERIOD & 1'b1)? DATA_CLK_PERIOD - 1: DATA_CLK_PERIOD;
  localparam new_half_data_clk_period = new_data_clk_period >> 1;

  logic [DATA_WIDTH-2:0] stored_data_in;
  logic [DATA_WIDTH-1:0] stored_data_out;
  logic [$clog2(new_data_clk_period):0] period_count;
  logic [$clog2(DATA_WIDTH)+1:0] data_count; // data transmitted
  
  always_ff@(posedge clk_in) begin 
    if (rst_in) begin // might not need all 
        chip_data_out <= 0;
        chip_clk_out <= 0;
        chip_sel_out <= 1;
        period_count <= 0;
        data_out <= 0;
        data_valid_out <= 0;
        data_count <= 0;
        stored_data_in <= 0;
        stored_data_out <= 0;
    end else begin 
        // handle initialization of process
        if (trigger_in && chip_sel_out) begin
            chip_sel_out <= 0; // CS --> 0
            period_count <= 0; // TODO: correct? what if new data clk period == 1
            stored_data_in <= data_in[DATA_WIDTH-2:0];
            data_count <= 0;
            chip_data_out <= data_in[DATA_WIDTH-1];

        end else if (!chip_sel_out) begin
            period_count <= (period_count == (new_data_clk_period - 1))? 0: period_count + 1;
            data_count <= (period_count == (new_half_data_clk_period - 1))? data_count + 1: data_count;

            // on rising edge
            if (period_count == (new_half_data_clk_period - 1)) begin
                stored_data_out <= {stored_data_out[DATA_WIDTH-2:0], chip_data_in};
                chip_clk_out <= 1;

            // on falling edge
            end else if (period_count == (new_data_clk_period - 1)) begin
                chip_clk_out <= 0;
                // termination
                if (data_count == (DATA_WIDTH)) begin // should be data width
                    data_out <= stored_data_out;
                    data_valid_out <= 1;
                    chip_sel_out <= 1;

                end else begin 
                    chip_data_out <= stored_data_in[DATA_WIDTH-2];
                    stored_data_in <= stored_data_in << 1;                    
                end
            end
        end else begin
            data_valid_out <= 0;
        end
    end 
  end
 
endmodule