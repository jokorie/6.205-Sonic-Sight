import cocotb
import os
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly, with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

@cocotb.test()
async def test_time_of_flight(dut):
    """ Testbench for the ToF_Calculation module """

    # Clock generation
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())  # 100 MHz clock

    # Reset the DUT
    dut.rst_in.value = 1
    dut.trigger_in.value = 0
    dut.echo_detected.value = 0

    await Timer(20, units="ns")
    dut.rst_in.value = 0
    await Timer(20, units="ns")
    dut.rst_in.value = 1
    await Timer(50, units="ns")

    # Test Case 1: Short distance
    # Trigger the ToF calculation
    dut.trigger_in.value = 1
    await RisingEdge(dut.clk)
    dut.trigger_in.value = 0

    # Simulate delay for echo to return
    await Timer(500, units="ns")  # Represents a round-trip time of 500 ns

    # Set echo detected signal
    dut.echo_detected.value = 1
    await RisingEdge(dut.clk)
    dut.echo_detected.value = 0

    # Wait for output to be valid
    await Timer(50, units="ns")

    # Check the output
    assert dut.valid_out.value == 1, "Test Case 1 Failed: valid_out should be high."
    range_output = dut.range_out.value
    cocotb.log.info(f"Test Case 1: Range Output = {range_output}")

    # Test Case 2: Longer distance
    # Trigger the ToF calculation again
    dut.trigger_in.value = 1
    await RisingEdge(dut.clk)
    dut.trigger_in.value = 0

    # Simulate a longer delay for the echo return
    await Timer(1000, units="ns")  # Represents a round-trip time of 1000 ns

    # Set echo detected signal
    dut.echo_detected.value = 1
    await RisingEdge(dut.clk)
    dut.echo_detected.value = 0

    # Wait for output to be valid
    await Timer(50, units="ns")

    # Check the output
    assert dut.valid_out.value == 1, "Test Case 2 Failed: valid_out should be high."
    range_output = dut.range_out.value
    cocotb.log.info(f"Test Case 2: Range Output = {range_output}")

    # Additional Test Case: Very short delay (near zero distance)
    dut.trigger_in.value = 1
    await RisingEdge(dut.clk)
    dut.trigger_in.value = 0

    await Timer(50, units="ns")  # Represents an almost immediate return (near zero distance)

    # Set echo detected signal
    dut.echo_detected.value = 1
    await RisingEdge(dut.clk)
    dut.echo_detected.value = 0

    # Wait for output to be valid
    await Timer(50, units="ns")

    # Check the output
    assert dut.valid_out.value == 1, "Test Case 3 Failed: valid_out should be high."
    range_output = dut.range_out.value
    cocotb.log.info(f"Test Case 3: Range Output (near zero) = {range_output}")


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "time_of_flight.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="time_of_flight",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="time_of_flight",
        test_module="test_time_of_flight",
        test_args=run_test_args,
        waves=True
    )


if __name__ == "__main__":
    is_runner()
