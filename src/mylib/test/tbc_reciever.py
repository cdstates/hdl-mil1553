import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, NextTimeStep, Timer
from cocotb_tools.runner import get_runner
import os
import sys

# Import test utilities
from test_tools import *


# ----------------------------------------------------------------------------
# Helper Functions
# ----------------------------------------------------------------------------

async def reset_dut(dut):
    """Reset the DUT"""
    dut.i_reset.value = 1
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    dut.i_reset.value = 0
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)


async def init_dut(dut):
    """Initialize DUT inputs to safe defaults"""
    dut.i_en.value = 0
    dut.i_data_in.value = 0
    dut.i_data_ready.value = 0
    dut.i_fail_clear.value = 0
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    

def print_dut_state(dut):
    """Print the internal state of the DUT for debugging"""
    try:
        state = dut.current_state.value
        dut._log.info(f"DUT State: state={state}")
        dut._log.info(f"  Outputs: valid={dut.o_data_valid.value}, fail={dut.o_fail_flag.value}")
        dut._log.info(f"  Data out: type={dut.o_data_out.word_type.value}, word=0x{dut.o_data_out.data_word.value:04X}")
    except Exception as e:
        dut._log.warning(f"Could not read internal state: {e}")




# ---------------------------------------------------------------------------
# Test Cases
# ----------------------------------------------------------------------------



@cocotb.test()
async def test_receiver_reset(dut):
    """Test basic reset functionality"""
    
    dut._log.info("="*60)
    dut._log.info("Test: Receiver Reset")
    dut._log.info("="*60)
    
    # Create clock
    clock = Clock(dut.i_clk, 10, "ns")  # 100 MHz
    clock.start(start_high=False)
    await RisingEdge(dut.i_clk)
    
    # Apply reset
    await reset_dut(dut)
    await init_dut(dut)
    
    # Check initial state
    await ReadOnly()
    assert dut.o_data_valid.value == 0, "o_data_valid should be low after reset"
    assert dut.o_fail_flag.value == 0, "o_fail_flag should be low after reset"
    
    dut._log.info("✓ Reset test PASSED")



@cocotb.test()
async def test_receiver_idle(dut):
    """Test receiver remains in idle with no input"""
    
    dut._log.info("="*60)
    dut._log.info("Test: Receiver Idle State")
    dut._log.info("="*60)
    
    # Create clock
    clock = Clock(dut.i_clk, 10, "ns")
    clock.start(start_high=False)
    await RisingEdge(dut.i_clk)
    
    # Reset and initialize
    await reset_dut(dut)
    await init_dut(dut)
    
    # Enable receiver but send no data
    dut.i_en.value = 1
    dut.i_data_in.value = 0
    
    # Wait several cycles
    for _ in range(100):
        await RisingEdge(dut.i_clk)
    
    # Verify still idle
    await ReadOnly()
    assert dut.o_data_valid.value == 0, "Should not have valid output"
    assert dut.o_fail_flag.value == 0, "Should not have fail flag"
    
    dut._log.info("✓ Idle test PASSED")
    



class SignalWriter:
    
    def __init__(self, name: str, values: list[int], delays_ns: list[int]):
        """Initialize signal writer
        
        Args:
            name: Descriptive name for logging
            signal: DUT signal to write to
            values: List of values to write
            delays_ns: List of delays in nanoseconds (one per value)
        """
        self.name = name
        self.values = values
        self.delays_ns = delays_ns
        
        if len(values) != len(delays_ns):
            raise ValueError(f"values and delays_ns must have same length: {len(values)} vs {len(delays_ns)}")


    def __str__(self):
        return f"SignalWriter(name={self.name}, values={self.values}, delays={self.delays_ns})"
    

            

        




def generate_values_sequence(is_cmd_word: bool, data: int, initial_zero_count=20) -> list[int]:
    """Generate the full value sequence for a MIL-1553 word transmission"""
    values = []
    
    # Pad with initial zeros
    values += [0] * initial_zero_count
    
    # Generate sync pattern
    if is_cmd_word:
        values += generate_sync_pattern(True)
    else:
        values += generate_sync_pattern(False)
    
    # Generate data bits
    data_bits = msb_int_2_bit_list(data, 16)
    values += data_bits
    
    # Generate parity bit
    parity_value = calculate_odd_parity(data_bits);
    values += generate_manchester_chip(parity_value)
    
    debug(f"Given data: 0x{data:04X}, bits: {data_bits}, parity: {parity_value}")
    debug(f"Generated values sequence: {values}")
    
    return values

def generate_delays_sequence(num_initial_zeroes=20, base_duration_ns=500) -> list[int]:
	"""Generate the full delays sequence for a MIL-1553 word transmission"""
	delays = []
	
	# Initial zeros
	delays += [base_duration_ns] * num_initial_zeroes
	
	# Sync pattern (6 chips)
	delays += [base_duration_ns] * 6 * 2
	
	# Data bits (16 bits)
	delays += [base_duration_ns] * 16 * 2
	
	# Parity bit (1 bit)
	delays += [base_duration_ns] * 1 * 2
	
	debug(f"Generated delays sequence: {delays}")
	
	return delays


async def send_signals(dut, values: list[int], delays_ns: list[int]):
	"""Send a sequence of values to the DUT input signal with specified delays"""
	
	if len(values) != len(delays_ns):
		raise ValueError("values and delays_ns must have the same length")
    
	for i, (value, delay) in enumerate(zip(values, delays_ns)):

		dut.i_data_in.value = value

		await Timer(delay, units='ns')
          

@cocotb.test()
async def test_signal_writer(dut):
	"""Test the SignalWriter with a sample sequence"""
	# log = cocotb.logging.getLogger("SignalWriterTest")
	
	# Generate a sample sequence
	values = generate_values_sequence(is_cmd_word=True, data=0x1234)
	delays = generate_delays_sequence()


	# Create clock - runs independently
	clock = Clock(dut.i_clk, 10, "ns")  # 100 MHz
	clock.start(start_high=False)
	await RisingEdge(dut.i_clk)
     
	# Reset and initialize
	await reset_dut(dut)
	await init_dut(dut)
	dut.i_en.value = 1
     
	writer_task = cocotb.start_soon(send_signals(dut, values, delays))
     
	for i in range(len(values) * 50 + 100):  # Wait enough cycles
		await RisingEdge(dut.i_clk)
        
		# Check for completion
		await ReadOnly()
		if dut.o_data_valid.value == 1:
			dut._log.info(f"Output valid detected at cycle {i}")
			break
          
		await NextTimeStep()
        
		if i % 100 == 0:
			print_dut_state(dut)
    
    # Wait for writer to complete
	await writer_task



def test_reciever_runner():
    """Runner function for pytest"""
    sim = "verilator"
    proj_path = "/home/cody/workspace/mil_adapter"
    print(f"Project Path: {proj_path}")
    
    # Enable waveform tracing
    os.environ["TRACES"] = "1"
    os.environ["COCOTB_LOG_LEVEL"] = "INFO"
    
    runner = get_runner(sim)
    runner.build(
        sources=[
            f"{proj_path}/src/mylib/lib_1553.sv",
            f"{proj_path}/src/mylib/signal_synchronizer.sv",
            f"{proj_path}/src/mylib/reciever_prefix.sv",
            f"{proj_path}/src/mylib/reciever_data.sv",
            f"{proj_path}/src/mylib/up_counter.sv",
            f"{proj_path}/src/mylib/edge_detector.sv",
            f"{proj_path}/src/mylib/window_filter.sv",
            f"{proj_path}/src/mylib/reciever.sv",
        ],
        hdl_toplevel="reciever",
        always=True,
        build_args=[
            "--trace-fst",
            "--trace-structs",
            # "--trace-depth", "99",
            # "--assert",              # Enable assertions
            # "-Wall",
            # "-Wno-WIDTHTRUNC",
            # "-Wno-UNUSED",
            # "+define+VERILATOR",
        ],
        parameters={
            "MasterClockFreq_Hz": 100_000_000,  # 100 MHz
            "BitRate_Hz": 1_000_000,            # 1 MHz
            "EnableWindowFilter": 1,             # Enable timing window initially
            "DUR_AFTER_LAST_CHIP_NS": 1000,     # 1000 ns
            "EN_COUNT_RESET_ON_CHIP_END": 0     # Disable count reset on chip end
        }
    )
    
    runner.test(
        hdl_toplevel="reciever",
        test_module="tbc_reciever",
    )


if __name__ == "__main__":
    test_reciever_runner()
    











