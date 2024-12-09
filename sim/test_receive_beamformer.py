import cocotb
import os
import sys
import math
from pathlib import Path
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

NUM_RECEIVERS = 4

def in_bounds(idx, n):
    return idx < n

async def generate_clock(clock_wire):
    """Generates a clock signal on the given wire."""
    while True:
        clock_wire.value = 0
        await Timer(5, units="ns")  # Low for 5 ns
        clock_wire.value = 1
        await Timer(5, units="ns")  # High for 5 ns


import math

def generate_adc_waveforms(num_samples=10000, angle=0, amplitude=32767, frequency=40000, sampling_rate=1000000):
    """
    Generates ADC waveforms for a given angle off boresight, quantized with 16-bit precision.
    
    Parameters:
        num_samples (int): Number of samples to generate.
        angle (float): Angle off boresight in degrees.
        amplitude (int): Amplitude of the waveform (default 32767 for 16-bit precision).
        frequency (int): Frequency of the waveform in Hz.
        sampling_rate (int): Sampling rate in Hz.
    
    Returns:
        list[list[int]]: A 2D list of waveforms, one for each receiver, with 16-bit quantized values.
    """
    # Constants
    SPEED_OF_SOUND = 343_000  # mm/s
    ELEMENT_SPACING = 9       # mm
    NUM_RECEIVERS = 4
    
    # Calculate delay per receiver due to angle (sin of the angle affects propagation delay)
    delay_per_receiver = [
        ELEMENT_SPACING * i * math.sin(math.radians(angle)) / SPEED_OF_SOUND
        for i in range(NUM_RECEIVERS)
    ]

    # Calculate delay in terms of samples
    delay_samples = [math.floor(delay * sampling_rate) for delay in delay_per_receiver]

    # Generate waveforms
    waveforms = [[] for _ in range(NUM_RECEIVERS)]
    t_step = 1.0 / sampling_rate  # Time step for each sample

    for sample_idx in range(num_samples):
        time = sample_idx * t_step
        for receiver in range(NUM_RECEIVERS):
            # Apply time shift (delay) to each receiver
            delayed_time = time - (delay_samples[receiver] / sampling_rate) # how far back in time do we go
            value = amplitude * (math.sin(2 * math.pi * frequency * delayed_time) + 1)
            waveforms[receiver].append(int(value))  # Quantize to a nonnegative integer
    
    return waveforms, delay_samples


# @cocotb.test()
async def test_receive_beamform_basic(dut):
    """Basic functionality test for the receive_beamform module."""
    # tests when all receivers in sync
    # Start clock
    await cocotb.start(generate_clock(dut.clk_in))
    
    for rx in range(4):
        dut.adc_in[rx].value = 0
    
    dut.sin_theta.value = 0
    dut.sign_bit.value = 0

    # Reset the DUT
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 1
    await FallingEdge(dut.clk_in)
    
    dut.rst_in.value = 0  
    
    await RisingEdge(dut.clk_in)

    # Parameters
    num_samples = 100
    sampling_rate = 1_000_000
    amplitude = 32767  # Max amplitude for 16-bit signed
    frequency = 40000  # 40 kHz frequency
    buffer_size = 80

    # Generate ADC input waveforms
    adc_waveforms, delay_samples = generate_adc_waveforms(num_samples, 0, amplitude, frequency, sampling_rate)  
    
    # Feed ADC inputs into the DUT
    for sample_idx in range(num_samples):
        await FallingEdge(dut.clk_in)
        for i in range(4):  # Assuming 4 receivers
            # load the receivers
            dut.adc_in[i].value = adc_waveforms[i][sample_idx]
        dut.data_valid_in.value = 1  # Indicate data is valid
        await RisingEdge(dut.clk_in)
        await FallingEdge(dut.clk_in)
        
        dut.data_valid_in.value = 0  # Clear data valid after processing
        
        await RisingEdge(dut.clk_in) # need to wait an additonal cycle for proper aggregated waveform

        # Read and verify the output waveform
        if sample_idx > buffer_size:
            # Validate aggregated waveform (basic verification)
            expected_value = sum(
                adc_waveforms[i][(sample_idx - delay_samples[i])] # wrong
                for i in range(4)
            ) // 4  # Divide by 4 to normalize
            assert abs(int(str(dut.aggregated_waveform.value), 2) - expected_value) < 10, \
                f"Sample Idx {sample_idx}: Expected {expected_value}, got {int(str(dut.aggregated_waveform.value), 2)}"

        
        # Wait for one sampling period
        for _ in range(98): # remaining clk cycles in sampling period
            await RisingEdge(dut.clk_in)

    cocotb.log.info("Test passed: Basic functionality verified.")

@cocotb.test()
async def test_receive_beamform_basic(dut):
    """Basic functionality test for the receive_beamform module."""
    # tests when all receivers in sync
    # Start clock
    await cocotb.start(generate_clock(dut.clk_in))
    
    for rx in range(4):
        dut.adc_in[rx].value = 0
    
    dut.sin_theta.value = 65536
    dut.sign_bit.value = 0

    # Reset the DUT
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 1
    await FallingEdge(dut.clk_in)
    
    dut.rst_in.value = 0  
    
    await RisingEdge(dut.clk_in)

    # Parameters
    num_samples = 100
    sampling_rate = 1_000_000
    amplitude = 32767  # Max amplitude for 16-bit signed
    frequency = 40000  # 40 kHz frequency
    buffer_size = 80

    # Generate ADC input waveforms
    adc_waveforms, delay_samples = generate_adc_waveforms(num_samples, 90, amplitude, frequency, sampling_rate)  
    
    print(delay_samples)
    
    # Feed ADC inputs into the DUT
    for sample_idx in range(num_samples):
        await FallingEdge(dut.clk_in)
        for i in range(4):  # Assuming 4 receivers
            # load the receivers
            dut.adc_in[i].value = adc_waveforms[i][sample_idx]
        dut.data_valid_in.value = 1  # Indicate data is valid
        await RisingEdge(dut.clk_in)
        await FallingEdge(dut.clk_in)
        
        dut.data_valid_in.value = 0  # Clear data valid after processing
        
        await RisingEdge(dut.clk_in) # need to wait an additonal cycle for proper aggregated waveform

        # Read and verify the output waveform
        if sample_idx > buffer_size:
            # Validate aggregated waveform (basic verification)
            expected_value = sum(
                adc_waveforms[i][(sample_idx - delay_samples[i])] # wrong
                for i in range(4)
            ) // 4  # Divide by 4 to normalize
            assert abs(int(str(dut.aggregated_waveform.value), 2) - expected_value) < 10, \
                f"Sample Idx {sample_idx}: Expected {expected_value}, got {int(str(dut.aggregated_waveform.value), 2)}"

        
        # Wait for one sampling period
        for _ in range(98): # remaining clk cycles in sampling period
            await RisingEdge(dut.clk_in)

    cocotb.log.info("Test passed: Basic functionality verified.")


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
        proj_path / "hdl" / "receive_beamformer.sv"
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
        hdl_toplevel="receive_beamformer",  # Top level HDL module
        always=True,
        build_args=build_test_args,
        parameters=parameters,  # Pass parameter overrides here
        timescale=('1ns', '1ps'),  # Timescale settings (1ns time unit, 1ps precision)
        waves=True  # Generate waveform files for debugging
    )

    # Run the test(s)
    run_test_args = []  # Specify any additional test arguments if needed
    runner.test(
        hdl_toplevel="receive_beamformer",  # Top level HDL module
        test_module="test_receive_beamformer",  # Python test module containing test(s)
        test_args=run_test_args,
        waves=True  # Enable waveform dumping
    )


if __name__ == "__main__":
    runner()
