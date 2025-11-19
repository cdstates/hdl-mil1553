import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb_tools.runner import get_runner
import os


# Test parameters
cycle_count = 17
counter_width = 3

def read_uint(signal):
	"""Helper function to read unsigned integer value from a signal"""
	return signal.value.to_unsigned()

def get_count(dut):
	"""Helper function to get current count value from DUT"""
	return read_uint(dut.o_count)

def is_done(dut):
	"""Helper function to check if done signal is asserted"""
	return dut.o_done.value == 1

def is_busy(dut):
	"""Helper function to check if busy signal is asserted"""
	return dut.o_busy.value == 1


@cocotb.test()
async def test_down_counter_basic(dut):
    """Test basic countdown functionality"""
    
    # Start clock
    clock = Clock(dut.i_clk, 10, unit="ns")
    clock.start(start_high=False)
    await RisingEdge(dut.i_clk)
    
    # Initialize inputs
    dut.i_clear.value = 0
    dut.i_en.value = 0
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    # Clear the counter (load initial value)
    dut.i_clear.value = 1
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    # Verify counter loaded
    assert get_count(dut) == cycle_count, f"[T0] Expected count={cycle_count} after clear, got {get_count(dut)}"
    # Check initial state
    assert get_count(dut) == cycle_count, f"[T1] Expected count={cycle_count}, got {get_count(dut)}"
    assert is_busy(dut),                  f"[T1] Expected o_busy=1, got {is_busy(dut)}"
    assert not is_done(dut),              f"[T1] Expected o_done=0, got {is_done(dut)}"


@cocotb.test()
async def test_down_counter_countdown(dut):
    """Test countdown operation"""
    
    clock = Clock(dut.i_clk, 10, unit="ns")
    clock.start(start_high=False)
    await RisingEdge(dut.i_clk)
	
	# Initialize
    dut.i_clear.value = 1		# Load initial value
    dut.i_en.value = 0          # Disable counting
    await RisingEdge(dut.i_clk) # Let load take effect
    dut.i_clear.value = 0       # Release clear
    await RisingEdge(dut.i_clk) # Next clock
	
    # Enable counting
    dut.i_en.value = 1
	
	# Count down completely
    for expected_count in range(cycle_count, -1, -1):
        await RisingEdge(dut.i_clk)
        assert dut.o_count.value == expected_count , f"[T2] Expected count={expected_count}, got {dut.o_count.value}"


@cocotb.test()
async def test_down_counter_clear_during_count(dut):
    """Test clear signal during countdown"""
    
    clock = Clock(dut.i_clk, 10, unit="ns")
    clock.start(start_high=False)
    await RisingEdge(dut.i_clk)

    # Initialize
    dut.i_clear.value = 1
    dut.i_en.value = 0
    await RisingEdge(dut.i_clk)
    dut.i_clear.value = 0
    await RisingEdge(dut.i_clk)
    
    # Count down partway
    dut.i_en.value = 1
    for i in range(8):
        await RisingEdge(dut.i_clk)
    
    mid_count = get_count(dut)
    dut._log.info(f"[T8] Mid-countdown: count={mid_count}")
    
    # Apply clear during countdown
    dut.i_clear.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_clear.value = 0
    await RisingEdge(dut.i_clk)
    
    # Verify counter reloaded
    assert get_count(dut) == cycle_count, f"[T8] Expected count reset to {cycle_count}, got {get_count(dut)}"
    assert dut.o_busy.value == 1, f"[T8] Expected o_busy=1 after clear"
    assert dut.o_done.value == 0, f"[T8] Expected o_done=0 after clear"


@cocotb.test()
async def test_down_counter_boundary(dut):
    """Test boundary conditions"""
    
    clock = Clock(dut.i_clk, 10, unit="ns")
    clock.start(start_high=False)
    await RisingEdge(dut.i_clk)
    
    # Initialize
    dut.i_clear.value = 1
    dut.i_en.value = 0
    await RisingEdge(dut.i_clk)
    dut.i_clear.value = 0
    await RisingEdge(dut.i_clk)
    
    # Test transition from 1 to 0
    dut.i_en.value = 1
    for i in range(cycle_count):
        await RisingEdge(dut.i_clk)
    
    # Should be at count=1
    assert get_count(dut) == 1, f"[T10] Expected count=1, got {get_count(dut)}"
    assert dut.o_busy.value == 1, f"[T10] Expected o_busy=1 at count=1"
    assert dut.o_done.value == 0, f"[T10] Expected o_done=0 at count=1"
    
    # Next cycle should go to 0
    await RisingEdge(dut.i_clk)
    assert get_count(dut) == 0, f"[T10] Expected count=0, got {get_count(dut)}"
    assert dut.o_busy.value == 0, f"[T10] Expected o_busy=0 at count=0"
    assert dut.o_done.value == 1, f"[T10] Expected o_done=1 at count=0"


@cocotb.test()
async def test_down_counter_clear_priority(dut):
    """Test that clear has priority over enable"""
    
    clock = Clock(dut.i_clk, 10, unit="ns")
    clock.start(start_high=False)
    await RisingEdge(dut.i_clk)
    
    # Initialize
    dut.i_clear.value = 0
    dut.i_en.value = 0
    await RisingEdge(dut.i_clk)
    
    # Apply both clear and enable simultaneously
    dut.i_clear.value = 1
    dut.i_en.value = 1
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    
    # Clear should take priority
    assert get_count(dut) == cycle_count, f"[T11] Clear should have priority, expected count={cycle_count}"
    
    dut.i_clear.value = 0
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    
    # Now enable should work
    assert get_count(dut) == cycle_count - 1, f"[T11] After clear released, should count down"


def test_down_counter_runner():
    """Runner function for pytest"""
    sim = "verilator"
    proj_path = "/home/cody/workspace/mil_adapter"
    print(f"Project Path: {proj_path}")
    
    # Enable waveform tracing
    os.environ["TRACES"] = "1"
    
    runner = get_runner(sim)
    runner.build(
        sources=[f"{proj_path}/src/mylib/down_counter.sv"],
        hdl_toplevel="down_counter",
        always=True,
        parameters={
            "CYCLE_COUNT": cycle_count,
            "COUNTER_WIDTH": counter_width
        },
        build_args=["--trace-fst", "--trace-structs"]
    )
    
    runner.test(
        hdl_toplevel="down_counter",
        test_module="tbc_down_counter",
    )


if __name__ == "__main__":
    test_down_counter_runner()