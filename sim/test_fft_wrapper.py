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


def generate_waveform(num_samples, amplitude, frequency, sampling_rate):
    """Generate a sinusoidal waveform for testing."""
    t_step = 1 / sampling_rate
    return [
        int(amplitude * math.sin(2 * math.pi * frequency * i * t_step)) for i in range(num_samples)
    ]


@cocotb.test()
async def test_fft_wrapper(dut):
    """Test the fft_wrapper module."""
    await cocotb.start(generate_clock(dut.clk_in))

    # Reset the DUT
    dut.rst_in.value = 1
    dut.ce.value = 0
    dut.sample_in.value = 0
    await RisingEdge(dut.clk_in)
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await FallingEdge(dut.clk_in)

    # Test parameters
    sample_rate = 1000000  # 1000000 Msps
    fft_size = 2048      # 2048-point FFT
    test_frequency = 50000  # Test tone at 40 kHz
    amplitude = 32767     # Max amplitude for 16-bit signed data
    num_samples = fft_size  # Number of samples in one FFT frame

    # Generate test waveform
    waveform = generate_waveform(num_samples, amplitude, test_frequency, sample_rate)

    # Feed waveform samples into the DUT
    for sample in waveform:
        real_part = sample
        imag_part = 0  # No imaginary component in this test
        packed_sample = (real_part << 16) | (imag_part & 0xFFFF)
        dut.sample_in.value = packed_sample
        dut.ce.value = 1
        await RisingEdge(dut.clk_in)

    # Wait for FFT processing to complete
    peak_detected = False
    for _ in range(10000):  # Timeout after a large number of clock cycles
        dut.ce.value = 1
        await RisingEdge(dut.clk_in)
        if dut.peak_valid.value:
            peak_detected = True
            break

    assert peak_detected, "FFT did not produce a valid peak frequency output."

    # Check the peak frequency
    expected_peak_frequency = test_frequency
    measured_peak_frequency = int(dut.peak_frequency.value)
    tolerance = (sample_rate / fft_size) / 2  # Allowable error: half the bin width

    assert abs(measured_peak_frequency - expected_peak_frequency) <= tolerance, \
        f"Expected peak frequency {expected_peak_frequency} Hz, got {measured_peak_frequency} Hz."

    cocotb.log.info(f"Test passed: Peak frequency detected correctly as {measured_peak_frequency} Hz.")

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
        proj_path / "hdl" / "fft_wrapper.sv"
    ]

    # Build arguments for compiling the design
    build_test_args = ["-Wall"]  # Add more build arguments if necessary

    # Override parameters at build time
    parameters = {}

    sources += list((proj_path / "hdl" / "fft-core").glob("*.v"))
    
    for hex in (proj_path / "hdl" / "fft-core").glob("*.hex"):
        shutil.copy(str(hex), "sim_build")

    # Get the appropriate runner based on the chosen simulator
    runner = get_runner(sim)

    # Build step to compile the design with overridden parameters
    runner.build(
        sources=sources,
        hdl_toplevel="fft_wrapper",  # Top level HDL module
        always=True,
        build_args=build_test_args,
        parameters=parameters,  # Pass parameter overrides here
        timescale=('1ns', '1ps'),  # Timescale settings (1ns time unit, 1ps precision)
        waves=True  # Generate waveform files for debugging
    )

    # Run the test(s)
    run_test_args = []  # Specify any additional test arguments if needed
    runner.test(
        hdl_toplevel="fft_wrapper",  # Top level HDL module
        test_module="test_fft_wrapper",  # Python test module containing test(s)
        test_args=run_test_args,
        waves=True  # Enable waveform dumping
    )


if __name__ == "__main__":
    runner()
