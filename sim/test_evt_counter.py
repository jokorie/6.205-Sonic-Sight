import cocotb
import os
import random
import sys
import logging
from pathlib import Path
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

async def generate_clock(clock_wire):
    """Generates a clock signal on the given wire."""
    while True:
        clock_wire.value = 0
        await Timer(5, units="ns")  # Low for 5 ns
        clock_wire.value = 1
        await Timer(5, units="ns")  # High for 5 ns

@cocotb.test()
async def test_evt_counter_basic(dut):
    """Basic Test for evt_counter module - Verifying count increments on events."""
    # Start the clock
    await cocotb.start(generate_clock(dut.clk_in))

    # Reset the DUT
    dut.rst_in.value = 1
    dut.evt_in.value = 0
    dut.default_offset.value = 0
    await Timer(20, units="ns")
    dut.rst_in.value = 0
    await Timer(20, units="ns")

    # Check initial count value
    assert dut.count_out.value == 0, f"Expected count_out=0 after reset, got {dut.count_out.value}"

    # Simulate an event and verify the count increments
    for i in range(1, 5):  # Generate 4 events
        dut.evt_in.value = 1
        await RisingEdge(dut.clk_in)
        dut.evt_in.value = 0
        await RisingEdge(dut.clk_in)
        assert dut.count_out.value == i, f"Expected count_out={i}, got {dut.count_out.value}"

    cocotb.log.info("Basic test passed: Count increments on events.")

@cocotb.test()
async def test_evt_counter_with_offset(dut):
    """Test for evt_counter module - Start from default_offset."""
    # Start the clock
    await cocotb.start(generate_clock(dut.clk_in))

    # Set a default offset
    offset = 10
    dut.default_offset.value = offset

    # Reset the DUT
    dut.rst_in.value = 1
    dut.evt_in.value = 0
    await Timer(20, units="ns")
    dut.rst_in.value = 0
    await Timer(20, units="ns")

    # Verify the count starts at default_offset
    assert dut.count_out.value == offset, f"Expected count_out={offset} after reset, got {dut.count_out.value}"

    # Simulate an event and verify the count increments
    for i in range(1, 4):  # Generate 3 events
        dut.evt_in.value = 1
        await RisingEdge(dut.clk_in)
        dut.evt_in.value = 0
        await RisingEdge(dut.clk_in)
        expected_count = offset + i
        assert dut.count_out.value == expected_count, f"Expected count_out={expected_count}, got {dut.count_out.value}"

    cocotb.log.info("Test with default offset passed: Count increments from offset.")

@cocotb.test()
async def test_evt_counter_max_wraparound(dut):
    """Test for evt_counter module - Verify wraparound at MAX_COUNT."""
    # Start the clock
    await cocotb.start(generate_clock(dut.clk_in))

    # Reset the DUT with default offset 0
    dut.default_offset.value = 0
    dut.rst_in.value = 1
    dut.evt_in.value = 0
    await Timer(20, units="ns")
    dut.rst_in.value = 0
    await Timer(20, units="ns")

    # Set count_out near MAX_COUNT - 1
    max_count = 2 ** dut.count_out.value.n_bits
    dut.count_out.value = max_count - 2
    
    print(max_count)

    # Generate events to exceed MAX_COUNT
    for i in range(2):
        await FallingEdge(dut.clk_in)
        dut.evt_in.value = 1
        await RisingEdge(dut.clk_in)
        await FallingEdge(dut.clk_in)
        dut.evt_in.value = 0
        await RisingEdge(dut.clk_in)

    # Verify wraparound to 0
    assert dut.count_out.value == 0, f"Expected count_out=0 after wraparound, got {dut.count_out.value}"

    cocotb.log.info("Max wraparound test passed: Counter wraps correctly.")

def runner():
    """Simulate the evt_counter module using the Python runner."""
    
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")  # Set simulator, defaults to Icarus Verilog if not specified
    proj_path = Path(__file__).resolve().parent.parent  # Path to the project directory

    # Add paths to sys.path for module access if needed
    sys.path.append(str(proj_path / "sim"))
    sys.path.append(str(proj_path / "hdl"))

    # HDL source files required for the simulation
    sources = [
        proj_path / "hdl" / "evt_counter.sv"
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
        hdl_toplevel="evt_counter",  # Top level HDL module
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),  # Timescale settings (1ns time unit, 1ps precision)
        waves=True  # Generate waveform files for debugging
    )

    # Run the test(s)
    run_test_args = []  # Specify any additional test arguments if needed
    runner.test(
        hdl_toplevel="evt_counter",  # Top level HDL module
        test_module="test_evt_counter",  # Python test module containing test(s)
        test_args=run_test_args,
        waves=True  # Enable waveform dumping
    )

if __name__ == "__main__":
    runner()
