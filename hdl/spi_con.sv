`timescale 1ns / 1ps
`default_nettype none

module spi_con
     #(parameter DATA_WIDTH = 8,
       parameter DATA_CLK_PERIOD = 100
      )
      (input wire   clk_in,
       input wire   rst_in,
       input wire   trigger_in,
       output logic [DATA_WIDTH-1:0] data_out,
       output logic data_valid_out, //high when output data is present.

       input wire   chip_data_in,  // (CIPO) ~ build up data from adc in data_out
       output logic chip_clk_out,  // (DCLK)
       output logic chip_sel_out   // (CS)
      );
      localparam DCLK_PERIOD = (DATA_CLK_PERIOD[0] & 1'b1) ? DATA_CLK_PERIOD-1 : DATA_CLK_PERIOD;
     
      logic [$clog2(DATA_WIDTH):0] series_count;
      logic [$clog2(DCLK_PERIOD):0] period_count;

    
      always_ff @(posedge clk_in) begin
	      data_valid_out <= 0;
	      if (rst_in) begin // reset output signals
          data_out <= 0;
          data_valid_out <= 0;
          chip_clk_out <= 0;
          chip_sel_out <= 1;
        end else if (trigger_in && chip_sel_out) begin // begin transaction if CS is still high
          chip_sel_out <= 0; // set CS low
          period_count <= 1'b1;
          series_count <= 1'b0;
        end else if (~chip_sel_out) begin // in middle of transmitting data
          if(period_count === DCLK_PERIOD>>1) begin // rising edge
            chip_clk_out <= 1'b1; // set DCLK to high
            data_out <= {data_out[DATA_WIDTH-2:0], chip_data_in}; // read CIPO
            series_count <= series_count + 1; // count
            period_count <= period_count + 1; // count dclk cycle
          end else if (period_count === DCLK_PERIOD) begin // falling edge
            if (series_count == DATA_WIDTH) begin
              chip_sel_out <= 1; // set CS high
              chip_clk_out <= 0; // set DCLK low
              data_valid_out <= 1; // set data ready to read
              series_count <= 0; // reset
            end else begin
              chip_clk_out <= 1'b1; // set DCLK to high
              period_count <= 1; // reset period
            end
          end else begin period_count <= period_count +1; end
        end	
      end // end of always ff

endmodule

`default_nettype wire
