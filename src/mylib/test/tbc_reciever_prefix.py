import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, NextTimeStep, ReadOnly, RisingEdge, Timer
from cocotb_tools.runner import get_runner
import os



COMMAND_WORD = 0    
DATA_WORD    = 1

EXPECTED_IDX = 7    




def generate_sync_pattern(is_command_word):
    """Generate sync pattern for command or data word"""
    if is_command_word:
        return [1, 1, 1, 0, 0, 0]  # Command Word Sync
    else:
        return [1, 0, 1, 0, 0, 1]  # Data Word Sync


def generate_manchester_chip(bit):
    """Generate Manchester encoded chip for a given bit (0 or 1)
       From t=0 point of view, the first half of the bit period is the first element"""
    if bit == 1:
        return [1, 0]  # '1' -> High to Low
    else:
        return [0, 1]  # '0' -> Low to High


def generate_manchester_word(sync_type, data_bits):
    """Generate Manchester encoded word with specified sync and first data bit"""
    sync_bits   = []
    chip_array  = []
    parity_bits = []
    if sync_type == COMMAND_WORD:
        sync_bits += [1, 1, 1, 0, 0, 0]  # Command Word Sync
    elif sync_type == DATA_WORD:
        sync_bits += [0, 0, 0, 1, 1, 1]  # Data Word Sync
    else:
        raise ValueError("Invalid sync_type. Use 'command' or 'data'.")
    temp_odd_parity = 0
    for bit in data_bits:
        chip_array += generate_manchester_chip(bit)
        temp_odd_parity ^= bit
    parity_bits = generate_manchester_chip(temp_odd_parity)

    print(f"Generated from {sync_type} word: {data_bits}")
    print(f"  Sync bits: {sync_bits}")
    print(f"  Data bits: {data_bits}")
    print(f"  Chip array: {chip_array}")
    print(f"  Parity bits: {temp_odd_parity} := {parity_bits}")

    total = sync_bits + chip_array + parity_bits
    total_len = len(total)
    prefix = total[0:6+2]
    print(f"Expected Prefix Pattern : {prefix}")

    return total



def print_bit_buffer(dut, enum_idx):
    """Helper function to print bit buffer as string"""
    # Get uint value
    uns_int = dut.buffer.value.to_unsigned()
    # Convert to binary string
    bin_str = f"{uns_int:b}"
    idx_cur = dut.idx.value.to_unsigned()

    print(f"[Buffer] idx_cur={idx_cur} | enum={enum_idx} | buffer={bin_str}")

    if dut.o_done.value == 1:
        print(f"[Buffer] >>>>> DONE asserted {dut.o_word_type.value} <<<<<")
        if dut.o_word_type.value == COMMAND_WORD:
            print(f"[Buffer] Command Word Received | Data Bit={dut.o_data_bit.value}")
        else:
            print(f"[Buffer] Data Word Received | Data Bit={dut.o_data_bit.value}")

    if dut.o_fail.value == 1:
        print(f"[Buffer] >>>>> FAIL asserted <<<<<")




async def perform_test(dut, chip_array, expected_done_idx, expected_word_type, expected_data_bit, expect_to_fail):
    """Perform test by feeding in chips and checking outputs"""

    # Start clock
    clock = Clock(dut.i_clk, 10, "ns")
    clock.start(start_high=False)
    await RisingEdge(dut.i_clk)

    # Initialize inputs
    dut.i_rx_in.value    = 0
    dut.i_rx_valid.value = 0
    dut.i_clear.value    = 0

    # Reset DUT
    dut.i_reset.value = 1
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)

    # Release reset
    dut.i_reset.value = 0
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)

    # Tell DUT to start receiving
    dut.i_rx_valid.value = 1
    dut.i_rx_in.value    = chip_array[len(chip_array)-1]

    # Initial buffer print
    print_bit_buffer(dut, -1)
    
    # Feed in chips
    for i, chip in enumerate(chip_array):
        # Set input chip
        dut.i_rx_in.value = chip
        # Wait for clock edge
        await RisingEdge(dut.i_clk)
        # Read-only phase to capture outputs
        await ReadOnly()
        print_bit_buffer(dut, i)
        # Resume step based clock cycles

        # Check for fail signal
        if dut.o_fail.value == 1:
            print(f"[Test] o_fail asserted at chip index {i}")
            print(f"o_fail   : {dut.o_fail.value}")
            print_bit_buffer(dut, i)
            assert expect_to_fail == True, f"[Test] Unexpected o_fail at index {i}"
            # If we expected a fail, we can exit early
            break

        # Check for done signal
        if dut.o_done.value == 1:
            print(f"[Test] o_done asserted at chip index {i}")
            assert i == expected_done_idx, f"[Test] Expected o_done at index {expected_done_idx}, got {i}"
            assert dut.o_word_type.value == expected_word_type, f"[Test] Expected word type {expected_word_type}, got {dut.o_word_type.value}"
            assert dut.o_data_bit.value == expected_data_bit, f"[Test] Expected data bit {expected_data_bit}, got {dut.o_data_bit.value}"
            break
        await NextTimeStep()
    # Check if we missed a failure
    if expect_to_fail:
        assert dut.o_fail.value == 1, "[Test] Expected o_fail but it was not asserted"


@cocotb.test()
async def test_valid_command_word_reception(dut):
    """Test reception of a valid command word"""

    # Initiate test parameters
    test_type = COMMAND_WORD    
    data_bits = [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]  # Example 16 data bits

    chip_array = generate_manchester_word(test_type, data_bits)

    await perform_test(dut, chip_array,
                expected_done_idx = EXPECTED_IDX,
                expected_word_type = COMMAND_WORD, 
                expected_data_bit = 1,
                expect_to_fail = False
    )

@cocotb.test()
async def test_valid_data_word_reception(dut):
    """Test reception of a valid data word"""

    # Initiate test parameters
    test_type = DATA_WORD    
    data_bits = [1,1,1,1] # Only need first data bit for this test

    chip_array = generate_manchester_word(test_type, data_bits)

    await perform_test(dut, chip_array,
                expected_done_idx = EXPECTED_IDX,
                expected_word_type = DATA_WORD, 
                expected_data_bit = 1,
                expect_to_fail = False
    )

@cocotb.test()
async def test_invalid_sync_rejection(dut):
    """Test rejection of invalid sync patterns"""
    # To be implemented
    
    test_type = DATA_WORD    
    data_bits = [1,1,1,1] # Only need first data bit for this test

    chip_array = generate_manchester_word(test_type, data_bits)

    # Introduce an error in the sync pattern
    chip_array[2] = not chip_array[2]  # Flip a bit in the sync pattern

    await perform_test(dut, chip_array,
                expected_done_idx = 7,
                expected_word_type = DATA_WORD, 
                expected_data_bit = 0,
                expect_to_fail = True
    )


@cocotb.test()
async def test_invalid_cmd_word_data_rejection(dut):
    """Test rejection of invalid data bits (parity error)"""
    # To be implemented
    
    test_type = COMMAND_WORD    
    data_bits = [1, 0, 1, 0, 1, 0, 1]

    chip_array = generate_manchester_word(test_type, data_bits)

    # Introduce an error in the data bits
    chip_array[6] = 0 
    chip_array[7] = 0

    await perform_test(dut, chip_array,
                expected_done_idx = 7,
                expected_word_type = DATA_WORD, 
                expected_data_bit = 0,
                expect_to_fail = True
    )

@cocotb.test()
async def test_invalid_data_word_data_rejection(dut):
    """Test rejection of invalid data bits (parity error)"""
    # To be implemented
    
    test_type = DATA_WORD    
    data_bits = [1,1,1,1] # Only need first data bit for this test

    chip_array = generate_manchester_word(test_type, data_bits)

    # Introduce an error in the data bits
    chip_array[6] = 0 
    chip_array[7] = 0

    await perform_test(dut, chip_array,
                expected_done_idx = 7,
                expected_word_type = DATA_WORD, 
                expected_data_bit = 0,
                expect_to_fail = True
    )



def test_reciever_prefix_runner():
    """Runner function for pytest"""
    sim = "verilator"
    proj_path = "/home/cody/workspace/mil_adapter"
    print(f"Project Path: {proj_path}")
    
    # Enable waveform tracing
    os.environ["TRACES"] = "1"
    
    runner = get_runner(sim)
    runner.build(
        sources=[
            f"{proj_path}/src/mylib/reciever_prefix.sv",
            # Add any dependencies here
        ],
        hdl_toplevel="reciever_prefix",
        always=True,
        build_args=["--trace-fst", "--trace-structs"]
    )
    
    runner.test(
        hdl_toplevel="reciever_prefix",
        test_module="tbc_reciever_prefix",
    )


if __name__ == "__main__":
    test_reciever_prefix_runner()