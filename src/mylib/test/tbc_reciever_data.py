import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, NextTimeStep, ReadOnly, RisingEdge, Timer
from cocotb_tools.runner import get_runner
import os
from test_tools import * 






# module reciever_data (
# 	input  logic        i_clk,        // System Clock
# 	input  logic        i_reset,      // System Reset

# 	input  logic        i_rx_in,      // Serial Input Bit
# 	input  logic        i_rx_valid,   // Input Bit Valid Signal
# 	input  logic        i_clear,      // Clear internal state

# 	input  logic 		i_pre_data_bit, // Decoded Data Bit from Prefix Decoder

# 	output logic        o_busy,       // High when decoding in progress
# 	output logic        o_done,       // High when data reception complete
# 	output logic        o_fail,       // High when data reception failed

# 	output logic [15:0]  o_data_word   // Received Data Byte
# );


class RecieverDataTestSignal:

	def __init__(self, name : str, pre_data_bit : int, data_bits : list[int] | int):
		self.pre_data_bit = pre_data_bit
		self.name = name
		if isinstance(data_bits, int):
			bit_length = 15
			self.data_bits = msb_int_2_bit_list(data_bits, bit_length)
		elif isinstance(data_bits, list): 
			self.data_bits = data_bits
		else:
			raise ValueError("data_bits must be either int or list[int]")
	
	def __str__(self):
		return f"RecieverDataTestSignal(name={self.name}, pre_data_bit={self.pre_data_bit}, data_bits={self.data_bits})"
	

	def get_pre_data_bit(self) -> int:
		return self.pre_data_bit
	

	def get_data_bits(self, append_pre_bit = True) -> list[int]:
		if append_pre_bit:
			return [self.pre_data_bit] + self.data_bits
		return self.data_bits
	

	def get_data_chips(self, append_pre_bit = True, append_parity = True) -> list[int]:
		"""Generate Manchester encoded chips for the data bits"""
		pre_bit_chips = []
		chip_array    = []
		parity_bits   = []
		temp_odd_parity = 0

		pre_bit_chips = generate_manchester_chip(self.pre_data_bit)

		for bit in self.data_bits:
			chip_array += generate_manchester_chip(bit)
			temp_odd_parity ^= bit

		parity_bits = generate_manchester_chip(temp_odd_parity)

		result = []
		if append_pre_bit:
			result += pre_bit_chips
		result += chip_array
		if append_parity:
			result += parity_bits
		return result
	

	def to_symbol_integer(self, append_pre_bit = True, append_parity = True) -> int:
		"""Convert the full chip array to an unsigned integer"""
		final_len = 15 + (1 if append_pre_bit else 0) + (1 if append_parity else 0)
		result = 0
		if append_pre_bit:
			result = self.pre_data_bit
			result <<= 1
			final_len -= 1

		for bit in self.data_bits:
			result = (result << 1) | bit
			final_len -= 1

		if append_parity:
			temp_odd_parity = self.pre_data_bit # always include pre bit in parity
			for bit in self.data_bits:
				temp_odd_parity ^= bit
			result = (result << 1) | temp_odd_parity
			final_len -= 1
		
		if final_len != 0:
			raise ValueError(f"Final length mismatch in to_symbol_integer {final_len}")
		
		return result








async def reset_dut(dut):
	"""Reset the DUT"""
	dut.i_reset.value = 1
	await RisingEdge(dut.i_clk)
	await RisingEdge(dut.i_clk)
	dut.i_reset.value = 0
	await RisingEdge(dut.i_clk)
	await RisingEdge(dut.i_clk)
     

async def init_dut(dut):
	"""Initialize the DUT"""
	dut.i_rx_in.value = 0
	dut.i_rx_valid.value = 0
	dut.i_clear.value = 0
	dut.i_pre_data_bit.value = 0
	await RisingEdge(dut.i_clk)
	await RisingEdge(dut.i_clk)
    

def print_dut_state(dut):
	"""Print the internal state of the DUT for debugging"""
	state     = dut.current_state.value.to_unsigned()
	bit_idx   = dut.bit_idx.value.to_unsigned()
	chip_idx  = dut.chip_idx.value
	data_word = dut.o_data_word.value.to_unsigned()
	fail      = dut.o_fail.value
      
	debug(f"DUT State: state={state}, bit_idx={bit_idx}, chip_idx={chip_idx}, data_word={data_word:b}, fail={fail}")


async def enumerate_through_list(dut, lst : list[int], expect_fail=False) -> bool:

	recorded_fail = False

	for i, chip in enumerate(lst):	# Exclude pre bit, include parity

		if dut.o_done.value == 1:
			debug(f"DUT signalled done early on index : {i}")
			recorded_fail = True
			break
			
		if local_chip_idx == 0:  
			dut.i_rx_in.value = chip
			dut.i_rx_valid.value = 1
			await RisingEdge(dut.i_clk)
			dut.i_rx_valid.value = 0
			await RisingEdge(dut.i_clk)

			await ReadOnly()
			print_dut_state(dut)
			# assert dut.chip_idx.value == 1, f"Chip 0 index mismatch at chip {i}"
			await NextTimeStep()
				
			local_chip_idx = 1

		else:

			dut.i_rx_in.value = chip
			dut.i_rx_valid.value = 1
			await RisingEdge(dut.i_clk)
			dut.i_rx_valid.value = 0
			await RisingEdge(dut.i_clk)

			await ReadOnly()
			print_dut_state(dut)
			# assert dut.chip_idx.value == 0, f"Chip 1 index mismatch at chip {i}"
			await NextTimeStep()

			local_chip_idx = 0
	
	return recorded_fail == expect_fail



@cocotb.test()
async def test_reciever_valid_data(dut):
	"""Test reciever_data with valid data word"""
      
	# Create a clock
	clock = Clock(dut.i_clk, 10, "ns")  # 10 ns period
	clock.start(start_high=False)
	await RisingEdge(dut.i_clk)

	# Reset and initialize DUT
	await reset_dut(dut)
	await init_dut(dut)

	test_signal = RecieverDataTestSignal(name="Valid Data Word Test",
										pre_data_bit = 0,
										data_bits    = 0x0002)


	# Set the first data bit for prefix decoder
	dut.i_pre_data_bit.value = test_signal.get_pre_data_bit()
    
	# Store the pre bit
	dut.i_rx_valid.value = 1
	await RisingEdge(dut.i_clk)
      
	# Make sure the pre bit is registered
	await ReadOnly()
	temp_word = dut.o_data_word.value
	debug(f"Temp Word (Pre-Bit Already Insterted): {temp_word}")
	assert temp_word[0] == test_signal.get_pre_data_bit(), "Prefix data bit not registered correctly"
	await NextTimeStep()
    
	# Stop valid signal before sending chips
	dut.i_rx_valid.value = 0
	await RisingEdge(dut.i_clk)
	await RisingEdge(dut.i_clk)
      
	local_chip_idx = 1	# Required to sync with DUT chip index
      
	# Feed in chips
	for i, chip in enumerate(test_signal.get_data_chips(False, True)):	# Exclude pre bit, include parity

		if dut.o_done.value == 1:
			debug(f"DUT signalled done early on index : {i}")
			break
            
		if local_chip_idx == 0:  
			dut.i_rx_in.value = chip
			dut.i_rx_valid.value = 1
			await RisingEdge(dut.i_clk)
			dut.i_rx_valid.value = 0
			await RisingEdge(dut.i_clk)

			await ReadOnly()
			print_dut_state(dut)
			# assert dut.chip_idx.value == 1, f"Chip 0 index mismatch at chip {i}"
			await NextTimeStep()
                
			local_chip_idx = 1
    
		else:

			dut.i_rx_in.value = chip
			dut.i_rx_valid.value = 1
			await RisingEdge(dut.i_clk)
			dut.i_rx_valid.value = 0
			await RisingEdge(dut.i_clk)

			await ReadOnly()
			print_dut_state(dut)
			# assert dut.chip_idx.value == 0, f"Chip 1 index mismatch at chip {i}"
			await NextTimeStep()

			local_chip_idx = 0

	rx_data_int = dut.o_data_word.value.to_unsigned()
	
	rx_data_array = msb_int_2_bit_list(rx_data_int, 1 + 16 + 1)		# Include pre bit and parity

	assert rx_data_int == test_signal.to_symbol_integer(True, True), \
		f"Received data integer {rx_data_int:018b} does not match expected {test_signal.to_symbol_integer(True, True):018b}"
		


	# print(f"Recieved Integer Data: {rx_data_int:018b}")
	# print(f"Expected Integer Data: {test_signal.to_symbol_integer(True, True):018b}")
	# print_dut_state(dut)

	# Check results


@cocotb.test()
async def test_reciever_reject_invalid_manchester_encoding(dut):

	"""Test reciever_data with invalid Manchester encoding"""
	  
	# Create a clock
	clock = Clock(dut.i_clk, 10, "ns")  # 10 ns period
	clock.start(start_high=False)
	await RisingEdge(dut.i_clk)

	# Reset and initialize DUT
	await reset_dut(dut)
	await init_dut(dut)

	test_signal = RecieverDataTestSignal(name="Invalid Manchester Encoding Test",
										pre_data_bit = 1,
										data_bits    = 0x0)  # Arbitrary data bits


	# Set the first data bit for prefix decoder
	dut.i_pre_data_bit.value = test_signal.get_pre_data_bit()
	
	# Store the pre bit
	dut.i_rx_valid.value = 1
	await RisingEdge(dut.i_clk)
	  
	# Make sure the pre bit is registered
	await ReadOnly()
	temp_word = dut.o_data_word.value
	debug(f"Temp Word (Pre-Bit Already Insterted): {temp_word}")
	assert temp_word[0] == test_signal.get_pre_data_bit(), "Prefix data bit not registered correctly"
	await NextTimeStep()
	
	# Stop valid signal before sending chips
	dut.i_rx_valid.value = 0
	await RisingEdge(dut.i_clk)
	await RisingEdge(dut.i_clk)
	  
	local_chip_idx = 1	# Required to sync with DUT chip index

	# Introduce an error in the Manchester encoding
	invalid_chips = test_signal.get_data_chips(False, True)  # Exclude pre bit, include parity
	
	# Flip one chip to create invalid Manchester encoding
	invalid_chips[8] = 0    # even index = first half of manchester pair
	invalid_chips[9] = 0     # odd index  = second half of manchester pair (should be 1 for valid encoding)

	debug(f"Invalid Chips: {invalid_chips}")

	failure_recorded = False

	# Feed in chips
	for i, chip in enumerate(invalid_chips):	# Exclude pre bit and parity

		if dut.o_fail.value == 1:
			debug(f"DUT signalled fail as expected on index : {i}")
			failure_recorded = True
			break
			
		if local_chip_idx == 0:  
			dut.i_rx_in.value = chip
			dut.i_rx_valid.value = 1
			await RisingEdge(dut.i_clk)
			dut.i_rx_valid.value = 0
			await RisingEdge(dut.i_clk)

			await ReadOnly()
			print_dut_state(dut)
			await NextTimeStep()
				
			local_chip_idx = 1
	
		else:

			dut.i_rx_in.value = chip
			dut.i_rx_valid.value = 1
			await RisingEdge(dut.i_clk)
			dut.i_rx_valid.value = 0
			await RisingEdge(dut.i_clk)

			await ReadOnly()
			print_dut_state(dut)
			# assert dut.chip_idx.value == 0, f"Chip 1 index mismatch at chip {i}"
			await NextTimeStep()

			local_chip_idx = 0

	assert failure_recorded == True, "DUT did not detect invalid Manchester encoding"


def test_reciever_data_runner():
    """Runner function for pytest"""
    sim = "verilator"
    proj_path = "/home/cody/workspace/mil_adapter"
    print(f"Project Path: {proj_path}")
    
    # Enable waveform tracing
    os.environ["TRACES"] = "1"
    
    runner = get_runner(sim)
    runner.build(
        sources=[f"{proj_path}/src/mylib/reciever_data.sv"],
        hdl_toplevel="reciever_data",
        always=True,
        build_args=["--trace-fst", "--trace-structs"]
    )
    
    runner.test(
        hdl_toplevel="reciever_data",
        test_module="tbc_reciever_data",
    )


if __name__ == "__main__":
    test_reciever_data_runner()