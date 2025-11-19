
COMMAND_WORD = 0    
DATA_WORD    = 1


ENABLE_VERBOSE_LOGGING = True
 
def debug(msg: str):
	if ENABLE_VERBOSE_LOGGING:
		print(msg)



def debug_list(msg: str, lst: list):
	if ENABLE_VERBOSE_LOGGING:
		print(f"{msg}: " + ''.join(str(bit) for bit in lst))



def calculate_odd_parity(data : list[int] | int) -> bool:
	bit_list = []
	if isinstance(data, int):
		bit_list = msb_int_2_bit_list(data, 16)
	else:
		bit_list = data

	return sum(bit_list) % 2 == 1


def msb_int_2_bit_list(value: int, bit_length: int = 0) -> list[int]:
	"""Convert an integer to a list of bits (MSB first)"""
	bit_list = []
	if bit_length == 0:
		bit_length = value.bit_length()
	
	elif bit_length < value.bit_length():
		raise ValueError("bit_length is too small for the given value")

	for i in range(bit_length - 1, -1, -1):
		bit_list.append((value >> i) & 1)
	return bit_list


def msb_bit_list_2_int(bit_list: list[int]) -> int:
	"""Convert a list of bits (MSB first) to an integer"""
	value = 0
	bit_length = len(bit_list)
	for i in range(bit_length):
		value |= (bit_list[i] << (bit_length - 1 - i))
	return value


# Test int_to_bit_array

# print(f"int_to_bit_array_lsb_first(3) = {msb_int_2_bit_list(3)}")  # Expected: [1, 1]
# print(f"int_to_bit_array_lsb_first(8) = {msb_int_2_bit_list(8, 5)}")  # Expected: [0, 0, 0, 1]
# print(f"int_to_bit_array_lsb_first(255, 16) = {msb_int_2_bit_list(255, 16)}")  # Expected: [1, 1, 1, 1, 1, 1, 1, 1]


# print(f"bit_array_to_int_lsb_first([1, 1]) = {msb_bit_list_2_int([1, 1])}")  # Expected: 3

# print(f"bit_array_to_int_lsb_first([0, 0, 0, 1]) = {msb_bit_list_2_int([0, 0, 0, 1])}")  # Expected: 8





def generate_sync_pattern(is_command_word : bool) -> list[int]:
    """Generate sync pattern for command or data word"""
    if is_command_word:
        return [1, 1, 1, 0, 0, 0]  # Command Word Sync
    else:
        return [0, 0, 0, 1, 1, 1]  # Data Word Sync
	


	
def generate_manchester_chip(bit):
    """Generate Manchester encoded chip for a given bit (0 or 1)
       From t=0 point of view, the first half of the bit period is the first element"""
    if bit == 1:
        return [1, 0]  # '1' -> High to Low
    else:
        return [0, 1]  # '0' -> Low to High
    



