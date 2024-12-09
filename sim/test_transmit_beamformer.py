import cocotb
import os
import sys
import math
from pathlib import Path
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

def calculate_expected_offset(tx_idx, sin_theta, sign_bit, period_cycles):
    """Calculate the expected offset for a transmitter."""
    DELAY_PER_TRANSMITTER_COMP = (9 * 100_000_000) // 343_000  # Example calculation
    base_offset = (DELAY_PER_TRANSMITTER_COMP * tx_idx * sin_theta) >> 15  # SIN_WIDTH = 16
    if sign_bit:
        base_offset = period_cycles - base_offset
    return base_offset % period_cycles


async def generate_clock(clock_wire):
    """Generates a clock signal on the given wire."""
    while True:
        clock_wire.value = 0
        await Timer(5, units="ns")  # Low for 5 ns
        clock_wire.value = 1
        await Timer(5, units="ns")  # High for 5 ns


# @cocotb.test()
async def test_transmit_basic(dut):
    """Basic Test for pwm module - Verify correct signal generation."""
    # Start the clock
    await cocotb.start(generate_clock(dut.clk_in))
    
    dut.sin_theta.value = 0
    dut.sign_bit = 0

    # Reset the DUT
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 1
    await FallingEdge(dut.clk_in)
    
    dut.rst_in.value = 0    


    # Parameters
    period_cycles = 2500  # PERIOD_IN_CLOCK_CYCLES
    duty_cycle_on = 1250  # DUTY_CYCLE_ON
    
    num_transmitters = len(dut.tx_out)

    for global_cycle in range(2*period_cycles):
        await RisingEdge(dut.clk_in)
        
        if (global_cycle%period_cycles) < duty_cycle_on:
            expected_high = True
        else:
            expected_high = False
                    
        for tx in range(num_transmitters):
            if expected_high:
                assert dut.tx_out[tx].value == 1, \
                    f"Cycle {global_cycle}: Expected high, got low"
            else:
                assert dut.tx_out[tx].value == 0, \
                    f"Cycle {global_cycle}: Expected low, got high"


    cocotb.log.info("Basic PWM test passed: Correct duty cycle.")

# @cocotb.test()
async def test_transmit_basic_full_beamforming(dut):
    """Basic Test for pwm module - Verify correct signal generation."""
    # Start the clock
    await cocotb.start(generate_clock(dut.clk_in))
    
    dut.sin_theta.value = 65536
    dut.sign_bit.value = 0

    # Reset the DUT
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 1
    await FallingEdge(dut.clk_in)
    
    dut.rst_in.value = 0    


    # Parameters
    period_cycles = 2500  # PERIOD_IN_CLOCK_CYCLES
    duty_cycle_on = 1250  # DUTY_CYCLE_ON
    
    num_transmitters = len(dut.tx_out)
    
    offset_comp = 9 * 100000000 // 343000

    for global_cycle in range(2*period_cycles):
        await RisingEdge(dut.clk_in)
         
        for tx in range(num_transmitters):
            
            if (dut.sign_bit.value):
                offset = offset_comp * (num_transmitters - tx)
            else:
                offset = offset_comp * tx
                
            in_period_cycle = (global_cycle + offset) % period_cycles
                
            if in_period_cycle < duty_cycle_on:
                expected_high = True
            else:
                expected_high = False
                    
            if expected_high:
                assert dut.tx_out[tx].value == 1, \
                    f"Transmitter #{tx}\n\
                        Global Cycle {global_cycle}: \n\
                        In Period Cycle {in_period_cycle}: \n\
                            Expected high, got low"
            else:
                assert dut.tx_out[tx].value == 0, \
                    f"Transmitter #{tx}\n\
                        Global Cycle {global_cycle}: \n\
                        In Period Cycle {in_period_cycle}: \n\
                            Expected low, got high"


    cocotb.log.info("Basic PWM test passed: Correct duty cycle.")

@cocotb.test()
async def test_transmit_basic_partial_beamforming(dut):
    """Basic Test for pwm module - Verify correct signal generation."""
    # Start the clock
    await cocotb.start(generate_clock(dut.clk_in))
    
    dut.sin_theta.value = 59395 # 65 degrees off boresight
    dut.sign_bit.value = 0

    # Reset the DUT
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 1
    await FallingEdge(dut.clk_in)
    
    dut.rst_in.value = 0    


    # Parameters
    period_cycles = 2500  # PERIOD_IN_CLOCK_CYCLES
    duty_cycle_on = 1250  # DUTY_CYCLE_ON
    
    max_sin_value = 65536
    
    num_transmitters = len(dut.tx_out)
    
    offset_comp = 9 * 100000000 // 343000
    
    sin_value = int(math.sin(math.radians(65)) * max_sin_value)
    

    for global_cycle in range(2*period_cycles):
        await RisingEdge(dut.clk_in)
         
        for tx in range(num_transmitters):
            
            if (dut.sign_bit.value):
                offset = offset_comp * (num_transmitters - tx) * sin_value // max_sin_value
            else:
                offset = offset_comp * tx * sin_value // max_sin_value
                
            in_period_cycle = (global_cycle + offset) % period_cycles
                
            if in_period_cycle < duty_cycle_on:
                expected_high = True
            else:
                expected_high = False
                    
            if expected_high:
                assert dut.tx_out[tx].value == 1, \
                    f"Transmitter #{tx}\n\
                        Global Cycle {global_cycle}: \n\
                        In Period Cycle {in_period_cycle}: \n\
                            Expected high, got low"
            else:
                assert dut.tx_out[tx].value == 0, \
                    f"Transmitter #{tx}\n\
                        Global Cycle {global_cycle}: \n\
                        In Period Cycle {in_period_cycle}: \n\
                            Expected low, got high"


    cocotb.log.info("Basic PWM test passed: Correct duty cycle.")



# @cocotb.test()
async def test_transmit_beamformer_basic(dut):
    """Basic Test for transmit_beamformer - Verify correct signal generation."""
    # Start the clock
    await cocotb.start(generate_clock(dut.clk))

    # Reset the DUT
    dut.rst_in.value = 1
    dut.sin_theta.value = 65535  # Set sin_theta to max positive
    dut.sign_bit.value = 0  # Test rightward propagation
    await Timer(20, units="ns")
    dut.rst_in.value = 0
    await Timer(20, units="ns")

    # Parameters
    num_transmitters = len(dut.tx_out)
    period_cycles = 2500  # Expected period of the PWM
    duty_cycle_on = 1250  # Expected high time
    offset_factor = 10  # Simplified for demonstration

    # Verify each transmitter's signal with expected offsets
    for transmitter in range(num_transmitters):
        high_count = 0
        low_count = 0
        offset = offset_factor * transmitter  # Simplified offset calculation

        for cycle in range(period_cycles):
            await RisingEdge(dut.clk)
            signal = dut.tx_out[transmitter].value

            if cycle < duty_cycle_on - offset:
                expected_signal = 1
            else:
                expected_signal = 0

            assert signal == expected_signal, \
                f"Transmitter {transmitter}, Cycle {cycle}: Expected {expected_signal}, got {signal}"

            if signal == 1:
                high_count += 1
            else:
                low_count += 1

        # Check total high and low counts
        assert high_count + low_count == period_cycles, \
            f"Transmitter {transmitter}: Total cycle mismatch"
        cocotb.log.info(f"Transmitter {transmitter} signal validated successfully.")


# @cocotb.test()
async def test_transmit_beamformer_with_sign_change(dut):
    """Test transmit_beamformer - Verify behavior with sign_bit change."""
    # Start the clock
    await cocotb.start(generate_clock(dut.clk))

    # Reset the DUT
    dut.rst_in.value = 1
    await Timer(20, units="ns")
    dut.rst_in.value = 0
    await Timer(20, units="ns")

    # Test leftward propagation
    dut.sin_theta.value = 32767  # Max sine value
    dut.sign_bit.value = 1  # Test leftward propagation
    await Timer(1000, units="ns")  # Allow signals to propagate

    # Verify offset ordering for leftward propagation
    for transmitter in range(len(dut.tx_out) - 1):
        assert dut.tx_out[transmitter].value >= dut.tx_out[transmitter + 1].value, \
            f"Expected leftward propagation order for transmitter {transmitter}"

    cocotb.log.info("Leftward propagation test passed.")

    # Test rightward propagation
    dut.sign_bit.value = 0  # Test rightward propagation
    await Timer(1000, units="ns")  # Allow signals to propagate

    # Verify offset ordering for rightward propagation
    for transmitter in range(len(dut.tx_out) - 1):
        assert dut.tx_out[transmitter].value <= dut.tx_out[transmitter + 1].value, \
            f"Expected rightward propagation order for transmitter {transmitter}"

    cocotb.log.info("Rightward propagation test passed.")


def runner():
    """Simulate the transmit_beamformer module using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")  # Set simulator, defaults to Icarus Verilog if not specified
    proj_path = Path(__file__).resolve().parent.parent  # Path to the project directory

    # Add paths to sys.path for module access if needed
    sys.path.append(str(proj_path / "sim"))
    sys.path.append(str(proj_path / "hdl"))

    # HDL source files required for the simulation
    sources = [
        proj_path / "hdl" / "transmit_beamformer.sv",
        proj_path / "hdl" / "pwm.sv",
        proj_path / "hdl" / "evt_counter.sv"
    ]

    # Build arguments for compiling the design
    build_test_args = ["-Wall"]  # Add more build arguments if necessary

    # Override parameters at build time
    parameters = {
        # "NUM_TRANSMITTERS": 4,       # Example: Change the number of transmitters
        # "ELEMENT_SPACING": 10,       # Example: Increase element spacing
        # "TARGET_FREQ": 40000         # Example: Set a different target frequency
    }

    # Get the appropriate runner based on the chosen simulator
    runner = get_runner(sim)

    # Build step to compile the design with overridden parameters
    runner.build(
        sources=sources,
        hdl_toplevel="transmit_beamformer",  # Top level HDL module
        always=True,
        build_args=build_test_args,
        parameters=parameters,  # Pass parameter overrides here
        timescale=('1ns', '1ps'),  # Timescale settings (1ns time unit, 1ps precision)
        waves=True  # Generate waveform files for debugging
    )

    # Run the test(s)
    run_test_args = []  # Specify any additional test arguments if needed
    runner.test(
        hdl_toplevel="transmit_beamformer",  # Top level HDL module
        test_module="test_transmit_beamformer",  # Python test module containing test(s)
        test_args=run_test_args,
        waves=True  # Enable waveform dumping
    )


if __name__ == "__main__":
    runner()
