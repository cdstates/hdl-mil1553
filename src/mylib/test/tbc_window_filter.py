import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb_tools.runner import get_runner


min_range = 4
max_range = 10
counter_size = 8


@cocotb.test()
async def test_window_filter_basic(dut):
    """Test basic window filtering functionality"""
    
    # Start clock
    clock = Clock(dut.i_clk, 10, "ns")
    clock.start()
    
    # Reset
    dut.i_reset.value = 1
    dut.i_counter_value.value = 0
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    dut.i_reset.value = 0
    await RisingEdge(dut.i_clk)
    
    # Test below minimum (should be invalid)
    dut.i_counter_value.value = min_range - 1
    await RisingEdge(dut.i_clk)
    assert dut.o_valid.value == 0, f"[T1] Expected invalid at counter={min_range - 1}, got {dut.o_valid.value}"
    
    # Test at minimum (should be valid)
    dut.i_counter_value.value = min_range
    await RisingEdge(dut.i_clk)
    assert dut.o_valid.value == 1, f"[T2] Expected valid at counter={min_range} (MIN), got {dut.o_valid.value}"
    
    # Test in range (should be valid)
    dut.i_counter_value.value = (min_range + max_range) // 2
    await RisingEdge(dut.i_clk)
    assert dut.o_valid.value == 1, f"[T3] Expected valid at counter={(min_range + max_range) // 2}, got {dut.o_valid.value}"
    
    # Test at maximum (should be valid)
    dut.i_counter_value.value = max_range
    await RisingEdge(dut.i_clk)
    assert dut.o_valid.value == 1, f"[T4] Expected valid at counter={max_range} (MAX), got {dut.o_valid.value}"
    
    # Test above maximum (should be invalid)
    dut.i_counter_value.value = max_range + 1
    await RisingEdge(dut.i_clk)
    assert dut.o_valid.value == 0, f"[T5] Expected invalid at counter={max_range + 1}, got {dut.o_valid.value}"


@cocotb.test()
async def test_window_filter_boundaries(dut):
    """Test boundary conditions"""
    
    clock = Clock(dut.i_clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.i_reset.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_reset.value = 0
    await RisingEdge(dut.i_clk)
    
    # Test all values from 0 to max counter size
    max_val = (2 ** counter_size) - 1  # Assuming 8-bit counter
    
    for val in range(max_val + 1):
        dut.i_counter_value.value = val
        await RisingEdge(dut.i_clk)
        
        expected_valid = 1 if (min_range <= val <= max_range) else 0
        actual_valid = int(dut.o_valid.value)
        
        assert actual_valid == expected_valid, \
            f"[T6] Counter={val}: Expected valid={expected_valid}, got {actual_valid}"

@cocotb.test()
async def test_window_filter_sweep(dut):
    """Sweep through counter values with clock"""
    
    clock = Clock(dut.i_clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.i_reset.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_reset.value = 0
    
    # Sweep up
    for i in range(16):
        dut.i_counter_value.value = i
        await RisingEdge(dut.i_clk)
        dut._log.info(f"[T7] Counter={i}, Valid={dut.o_valid.value}")
    
    # Sweep down
    for i in range(15, -1, -1):
        dut.i_counter_value.value = i
        await RisingEdge(dut.i_clk)
        dut._log.info(f"[T8] Counter={i}, Valid={dut.o_valid.value}")


def test_window_filter_runner():
    """Runner function for pytest"""
    sim = "verilator"  # or "icarus", "questa", etc.
    proj_path = "/home/cody/workspace/mil_adapter"
    print(f"Project Path: {proj_path}")
    
    runner = get_runner(sim)
    runner.build(
        verilog_sources=[f"{proj_path}/src/mylib/window_filter.sv"],
        hdl_toplevel="window_filter",
        always=True,
        parameters={
            "MIN_VALUE": min_range,
            "MAX_VALUE": max_range,
            "COUNTER_SIZE": counter_size
        },
        waves=True,
        build_args=["--trace-fst", "--trace-structs"]
    )
    
    runner.test(
        hdl_toplevel="window_filter",
        test_module="tbc_window_filter",
    )


if __name__ == "__main__":
    test_window_filter_runner()