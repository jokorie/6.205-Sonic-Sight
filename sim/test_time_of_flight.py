import cocotb
import os
import random
import sys
import logging
from pathlib import Path
from cocotb.triggers import Timer, RisingEdge
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

async def generate_clock(clock_wire):
	while True: # repeat forever
		clock_wire.value = 0
		await Timer(5,units="ns")
		clock_wire.value = 1
		await Timer(5,units="ns")
  
@cocotb.test()
async def test_time_of_flight_basic(dut):
    """Basic Test for Time of Flight module - Measuring a known distance"""
    # Clock generation
    await cocotb.start( generate_clock( dut.clk_in ) ) #launches clock
    # Reset the design
    await Timer(100, units="ns")
    dut.rst_in.value = 1
    await Timer(10, units="ns")
    dut.rst_in.value = 0
    await Timer(10, units="ns")

    # Start the ToF measurement
    dut.trigger_in.value = 1
    
    await RisingEdge(dut.clk_in)
    dut.trigger_in.value = 0

    # Wait for some time to simulate the distance
    # Simulate the time taken for sound to travel a certain distance and back.
    distance_cm = 10  # Simulate an object at 100 cm
    time_taken_ns = int((distance_cm * 2) / 34300 * 1e9)  # Round trip time in ns
            
    # Wait for the calculated time (assuming 10ns clock period)
    await Timer(time_taken_ns, units="ns")
    
    # Signal that the echo was detected
    dut.echo_detected.value = 1
    await RisingEdge(dut.clk_in)
    dut.echo_detected.value = 0

    # Wait for processing
    await RisingEdge(dut.valid_out)
    assert dut.valid_out.value == 1, "Valid output should be asserted"
    calculated_distance = int(dut.range_out.value)

    # Compare expected and actual distance
    expected_distance = distance_cm
    tolerance_cm = 1  # Allow for some error margin due to integer rounding
    assert (abs(calculated_distance - expected_distance) <= tolerance_cm and dut.object_detected.value == 1),  \
        f"Expected distance: {expected_distance}, Got: {calculated_distance}"

    cocotb.log.info(f"Basic ToF test passed. Distance: {calculated_distance} cm.")
    
    await Timer(100, units="ns")

@cocotb.test()
async def test_time_of_flight_timeout(dut):
    """Test for Time of Flight module - No echo received"""
    # Clock generation
    await cocotb.start( generate_clock( dut.clk_in ) ) #launches clock
    
    # Reset the design
    await Timer(100, units="ns")
    dut.rst_in.value = 1
    await Timer(10, units="ns")
    dut.rst_in.value = 0
    await Timer(10, units="ns")
    # Start the ToF measurement
    dut.trigger_in.value = 1
    await RisingEdge(dut.clk_in)
    dut.trigger_in.value = 0

    # Wait longer than any expected echo
    # timeout_ns = 5e6  # Simulate a long enough delay for timeout (e.g., 5 ms)
    # await Timer(timeout_ns, units="ns")
    # Wait for processing
    
    # doesnt check proper timeout after time period
    await RisingEdge(dut.valid_out)
    
    assert dut.valid_out.value == 1, "Valid output should be asserted"

    # Check if no valid output was produced (assuming module indicates this)
    assert ((dut.object_detected.value) == 0), "Valid output should not be asserted due to timeout"

    cocotb.log.info(f"Timeout test passed. No echo detected as expected.")

def runner():
    """Simulate the time_of_flight module using the Python runner."""
    
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")  # Set simulator, defaults to Icarus Verilog if not specified
    proj_path = Path(__file__).resolve().parent.parent  # Path to the project directory

    # Add paths to sys.path for module access if needed
    sys.path.append(str(proj_path / "sim" / "model"))
    sys.path.append(str(proj_path / "sim"))

    # HDL source files required for the simulation
    sources = [
        proj_path / "hdl" / "time_of_flight.sv",  # Add additional HDL files if required
        proj_path / "hdl" / "divider.sv"
    ]
    
    # Build arguments for compiling the design
    build_test_args = ["-Wall"]  # Add more build arguments if necessary

    # Design parameters
    parameters = {}  # Add any parameters if needed

    # Get the appropriate runner based on the chosen simulator
    runner = get_runner(sim)

    # Build step to compile the design
    runner.build(
        sources=sources,
        hdl_toplevel="time_of_flight",  # Top level HDL module
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),  # Timescale settings (1ns time unit, 1ps precision)
        waves=True  # Generate waveform files for debugging
    )

    # Run the test(s)
    run_test_args = []  # Specify any additional test arguments if needed
    runner.test(
        hdl_toplevel="time_of_flight",  # Top level HDL module
        test_module="test_time_of_flight",  # Python test module containing test(s)
        test_args=run_test_args,
        waves=True  # Enable waveform dumping
    )

if __name__ == "__main__":
    runner()