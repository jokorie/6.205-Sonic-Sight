import cocotb
import os
import sys
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
async def test_pwm_basic(dut):
    """Basic Test for pwm module - Verify correct signal generation."""
    # Start the clock
    await cocotb.start(generate_clock(dut.clk_in))

    # Reset the DUT
    dut.rst_in.value = 1
    dut.default_offset.value = 0
    await Timer(20, units="ns")
    dut.rst_in.value = 0
    await Timer(20, units="ns")

    # Parameters
    period_cycles = 2500  # PERIOD_IN_CLOCK_CYCLES
    duty_cycle_on = 1250  # DUTY_CYCLE_ON

    # Verify PWM signal for one full period
    high_count = 0
    low_count = 0

    for _ in range(period_cycles):
        await RisingEdge(dut.clk_in)
        if dut.sig_out.value == 1:
            high_count += 1
        else:
            low_count += 1

    # Check high and low times
    assert high_count == duty_cycle_on, f"Expected {duty_cycle_on} high cycles, got {high_count}"
    assert low_count == period_cycles - duty_cycle_on, \
        f"Expected {period_cycles - duty_cycle_on} low cycles, got {low_count}"

    cocotb.log.info("Basic PWM test passed: Correct duty cycle.")

@cocotb.test()
async def test_pwm_with_offset(dut):
    """Test for pwm module - Verify behavior with default_offset as phase offset."""
    # Start the clock
    await cocotb.start(generate_clock(dut.clk_in))

    # Parameters
    period_cycles = 2500  # Total period in clock cycles
    duty_cycle_on = 1250   # Number of cycles the signal is high
    offset = 30          # Offset into the period (in cycles)

    # Apply the default offset
    dut.default_offset.value = offset

    # Reset the DUT
    dut.rst_in.value = 1
    
    await RisingEdge(dut.clk_in)
    
    dut.rst_in.value = 0

    # Expected Behavior:
    # - First period: high for (duty_cycle_on - offset) cycles, then low for the remainder.
    # - Subsequent periods: Alternates between high (duty_cycle_on cycles) and low.
    
    num_periods_to_check = 3
    
    for global_cycle in range(1, num_periods_to_check * period_cycles):
        await RisingEdge(dut.clk_in)
        
        in_period_count = (global_cycle + offset) % period_cycles
        if in_period_count < duty_cycle_on:
            expected_high = True
        else:
            expected_high = False
            
        await FallingEdge(dut.clk_in)
            
        if expected_high:
            assert dut.sig_out.value == 1, \
                f"Cycle {global_cycle}: Expected high, got low"
        else:
            assert dut.sig_out.value == 0, \
                f"Cycle {global_cycle}: Expected low, got high"

    cocotb.log.info(f"PWM test with offset {offset} passed: Signal matches expected behavior.")

@cocotb.test()
async def test_pwm_full_period(dut):
    """Test for pwm module - Verify signal repeats correctly over multiple periods."""
    # Start the clock
    await cocotb.start(generate_clock(dut.clk_in))

    # Reset the DUT
    dut.rst_in.value = 1
    dut.default_offset.value = 0
    await Timer(20, units="ns")
    dut.rst_in.value = 0
    await Timer(20, units="ns")

    # Parameters
    period_cycles = 2500  # PERIOD_IN_CLOCK_CYCLES
    duty_cycle_on = 1250  # DUTY_CYCLE_ON
    num_periods = 3

    # Check multiple periods
    for period in range(num_periods):
        high_count = 0
        low_count = 0

        for _ in range(period_cycles):
            await RisingEdge(dut.clk_in)
            if dut.sig_out.value == 1:
                high_count += 1
            else:
                low_count += 1

        # Verify high and low counts for the period
        assert high_count == duty_cycle_on, \
            f"Period {period}: Expected {duty_cycle_on} high cycles, got {high_count}"
        assert low_count == period_cycles - duty_cycle_on, \
            f"Period {period}: Expected {period_cycles - duty_cycle_on} low cycles, got {low_count}"

    cocotb.log.info(f"PWM test over {num_periods} periods passed: Signal repeats correctly.")

def runner():
    """Simulate the pwm module using the Python runner."""
    
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")  # Set simulator, defaults to Icarus Verilog if not specified
    proj_path = Path(__file__).resolve().parent.parent  # Path to the project directory

    # Add paths to sys.path for module access if needed
    sys.path.append(str(proj_path / "sim"))
    sys.path.append(str(proj_path / "hdl"))

    # HDL source files required for the simulation
    sources = [
        proj_path / "hdl" / "evt_counter.sv",  # Required for the counter
        proj_path / "hdl" / "pwm.sv"
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
        hdl_toplevel="pwm",  # Top level HDL module
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),  # Timescale settings (1ns time unit, 1ps precision)
        waves=True  # Generate waveform files for debugging
    )

    # Run the test(s)
    run_test_args = []  # Specify any additional test arguments if needed
    runner.test(
        hdl_toplevel="pwm",  # Top level HDL module
        test_module="test_pwm",  # Python test module containing test(s)
        test_args=run_test_args,
        waves=True  # Enable waveform dumping
    )

if __name__ == "__main__":
    runner()
