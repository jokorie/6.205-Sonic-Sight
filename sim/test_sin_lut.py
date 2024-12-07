import cocotb
import os
import sys
import math
from pathlib import Path
from cocotb.triggers import Timer
from cocotb.runner import get_runner

TOLERANCE = 10
SCALE = 65535

@cocotb.test()
async def test_sin_lut_basic(dut):
    """Basic Test for sin_lut module - Verify LUT values and sign behavior."""
    # Test a range of angles to verify the LUT values and sign bit
    for angle in range(-90, 90):  # sin angle off boresight
        dut.angle.value = angle  # Set the angle
        await Timer(10, units="ns")  # Allow time for output to propagate

        # Expected values
        expected_sign_bit = 1 if angle < 0 else 0  # Sign bit is high for angles > 90
        expected_sin_value = abs(int(math.sin(math.radians(angle)) * SCALE))
        
        actual_sin_value = int(dut.sin_value.value)
        actual_sign_bit = dut.sign_bit.value

        # Assertions
        assert actual_sign_bit == expected_sign_bit, \
            f"Angle {angle}: Expected sign_bit={expected_sign_bit}, got {actual_sign_bit}"
        assert abs(actual_sin_value - expected_sin_value) < TOLERANCE, \
            f"Angle {angle}: Expected sin_value={expected_sin_value}, got {actual_sign_bit}"

    cocotb.log.info("Basic sin_lut test passed: LUT values and sign bits match expected behavior.")

def runner():
    """Simulate the sin_lut module using the Python runner."""
    
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")  # Set simulator, defaults to Icarus Verilog if not specified
    proj_path = Path(__file__).resolve().parent.parent  # Path to the project directory

    # Add paths to sys.path for module access if needed
    sys.path.append(str(proj_path / "sim"))
    sys.path.append(str(proj_path / "hdl"))

    # HDL source files required for the simulation
    sources = [
        proj_path / "hdl" / "sin_lut.sv"
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
        hdl_toplevel="sin_lut",  # Top level HDL module
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),  # Timescale settings (1ns time unit, 1ps precision)
        waves=True  # Generate waveform files for debugging
    )

    # Run the test(s)
    run_test_args = []  # Specify any additional test arguments if needed
    runner.test(
        hdl_toplevel="sin_lut",  # Top level HDL module
        test_module="test_sin_lut",  # Python test module containing test(s)
        test_args=run_test_args,
        waves=True  # Enable waveform dumping
    )

if __name__ == "__main__":
    runner()
