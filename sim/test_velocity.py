import cocotb
import os
import sys
import math
from pathlib import Path
import shutil
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

async def generate_clock(clock):
    """Generates a clock signal on the given wire."""
    while True:
        clock.value = 0
        await Timer(5, units="ns")  # Low for 5 ns
        clock.value = 1
        await Timer(5, units="ns")  # High for 5 ns

def generate_receiver_waveform(num_samples, amplitude, frequency, sampling_rate):
    """Generate a sinusoidal waveform to simulate receiver input."""
    t_step = 1 / sampling_rate
    return [int(amplitude * math.sin(2 * math.pi * frequency * i * t_step)) for i in range(num_samples)]

def calculate_expected_velocity(delta_f, peak_frequency, speed_of_sound=343):
    """Calculate the expected velocity using the Doppler formula."""
    # delta leaning peak
    return (delta_f / peak_frequency) * speed_of_sound

@cocotb.test()
async def test_velocity_with_defined_velocity(dut):
    """Test the velocity module with a defined velocity."""
    # Start clock
    await cocotb.start(generate_clock(dut.clk_in))

    # Reset DUT
    dut.rst_in.value = 1
    dut.receiver_data.value = 0
    dut.receiver_data_valid_in.value = 0
    await RisingEdge(dut.clk_in)
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await FallingEdge(dut.clk_in)

    # Parameters
    desired_velocity = 80  # Velocity in m/s
    emitted_frequency = 40000  # Emitted frequency in Hz
    speed_of_sound = 343  # Speed of sound in m/s
    amplitude = 32767  # Max amplitude for 16-bit signed data
    sampling_rate = 1_000_000  # 1 MHz sampling rate
    num_samples = 2048  # Number of samples to simulate

    # Calculate Doppler shift
    test_frequency = (emitted_frequency * speed_of_sound) / (speed_of_sound - desired_velocity) # Test frequency for an approaching object

    # Generate test waveform
    waveform = generate_receiver_waveform(num_samples, amplitude, test_frequency, sampling_rate)

    # Feed waveform into DUT
    for sample in waveform:
        dut.receiver_data_valid_in.value = 1
        dut.receiver_data.value = sample
        await RisingEdge(dut.clk_in)
        dut.receiver_data_valid_in.value = 0

        # Allow time for processing
        for _ in range(10):
            await RisingEdge(dut.clk_in)

    # Wait for FFT processing to complete
    peak_detected = False
    for _ in range(10000):  # Timeout after a large number of clock cycles
        await RisingEdge(dut.clk_in)
        if dut.doppler_ready.value:
            peak_detected = True
            break

    assert peak_detected, "FFT did not produce a valid peak frequency output."

    # Calculate the expected velocity
    expected_velocity = desired_velocity  # This is the velocity we defined initially
    measured_velocity = int(dut.velocity_result.value)

    # Log the results
    print(f"Desired velocity: {desired_velocity} m/s")
    print(f"Measured velocity: {measured_velocity} m/s")
    print()

    # Validate the result
    assert abs(measured_velocity - expected_velocity) < 2, \
        f"Expected velocity {expected_velocity}, but got {measured_velocity}"

    cocotb.log.info("Test passed: Velocity matches the defined value.")



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
        proj_path / "hdl" / "velocity.sv",
        proj_path / "hdl" / "divider.sv",
        proj_path / "hdl" / "fft_wrapper.sv"
    ]
    
    sources += list((proj_path / "hdl" / "fft-core").glob("*.v"))
    
    for hex in (proj_path / "hdl" / "fft-core").glob("*.hex"):
        shutil.copy(str(hex), "sim_build")

    # Build arguments for compiling the design
    build_test_args = ["-Wall"]  # Add more build arguments if necessary

    # Override parameters at build time
    parameters = {}

    # Get the appropriate runner based on the chosen simulator
    runner = get_runner(sim)

    # Build step to compile the design with overridden parameters
    runner.build(
        sources=sources,
        hdl_toplevel="velocity",  # Top level HDL module
        always=True,
        build_args=build_test_args,
        parameters=parameters,  # Pass parameter overrides here
        timescale=('1ns', '1ps'),  # Timescale settings (1ns time unit, 1ps precision)
        waves=True  # Generate waveform files for debugging
    )

    # Run the test(s)
    run_test_args = []  # Specify any additional test arguments if needed
    runner.test(
        hdl_toplevel="velocity",  # Top level HDL module
        test_module="test_velocity",  # Python test module containing test(s)
        test_args=run_test_args,
        waves=True  # Enable waveform dumping
    )


if __name__ == "__main__":
    runner()
