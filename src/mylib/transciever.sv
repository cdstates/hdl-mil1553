
module transciever (

	input  logic         i_clk,          // System Clock
	input  logic         i_reset,        // System Reset

	lib_1553::word_t i_data_word,
	lib_1553::word_type_t i_word_type,

	input logic i_en,

	output logic o_serial_out
);

import lib_1553::*;


	localparam int unsigned TOTAL_SYMBOLS = M1553_NUM_SYNC_BITS + M1553_NUM_DATA_BITS + M1553_NUM_PARITY_BITS;
	localparam int unsigned TOTAL_CHIPS   = TOTAL_SYMBOLS * 2;  // 2 chips per symbol
	localparam int unsigned CHIP_COUNTER_WIDTH = $clog2(TOTAL_CHIPS + 1);

	logic [TOTAL_CHIPS-1:0] chips_buffer;
	logic [CHIP_COUNTER_WIDTH-1:0] chips_idx;


	// State Machine
	typedef enum logic [1:0] {
		IDLE,
		LOAD,
		CALC_PARITY,
		TRANSMIT,
		DONE,
	} state_t;

	state_t current_state, next_state;

	



endmodule : transciever