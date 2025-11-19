//-----------------------------------------------------------------------------
// Title      : MIL-STD-1553 Data Word Receiver
// Project    : MIL-STD-1553 Adapter
//-----------------------------------------------------------------------------
// File       : reciever_data.sv
// Author     : Cody
// Company    : 
// Created    : 2024-11-11
// Last update: 2024-11-11
// Platform   : 
// Standard   : SystemVerilog
// Test Bench : tbc_reciever_data.py
//-----------------------------------------------------------------------------
// Description: 
// This module implements a Manchester data word decoder for MIL-STD-1553
// protocol. It performs:
//   - Insertion of pre-decoded data bit from prefix decoder (tested)
//   - Manchester pair decoding (16-bit data word) (tested)
//   - Manchester encoding error detection (tested)
//   - FSM-based state management (IDLE, INSERT_PRE_BIT, DECODE_DATA, FAIL, DONE)
//   - Status outputs (busy, done, fail flags) (tested)
//
// The receiver expects synchronized serial input with valid signals and
// operates on a bit-pair basis to decode Manchester-encoded data.
//-----------------------------------------------------------------------------
// Copyright (c) 2024 
//-----------------------------------------------------------------------------
// Revisions  :
// Date        Version  Author  Description
// 2024-11-11  1.0      Cody    Created
// 2025-11-25  1.1      Cody    Test updates and fixes - cocotb integration
//-----------------------------------------------------------------------------

module reciever_data (

	input 	logic        i_clk,           // System Clock
	input 	logic        i_reset,   	  // System Reset

	input 	logic        i_rx_in,      	  // Serial Input Bit
	input 	logic        i_rx_valid,   	  // Input Bit Valid Signal
	input 	logic        i_clear,      	  // Clear internal state

	input 	logic        i_pre_data_bit,  // Decoded Data Bit from Prefix Decoder. (Necessary evil)

	output 	logic        o_busy,   		  // High when decoding in progress
	output 	logic        o_done,   		  // High when data reception complete
	output 	logic        o_fail,   		  // High when data reception failed

	output 	logic        o_parity_rx,     // Received Parity Bit
	output  logic        o_parity_calc,   // Calculated Parity Bit from accumulated ones in data

	output 	lib_1553::word_t  o_data_word      // Received Data Word
);

	import lib_1553::*;


    // Parameters
    localparam int unsigned WORD_WIDTH = M1553_NUM_DATA_BITS + M1553_NUM_PARITY_BITS;
    localparam int unsigned IDX_WIDTH  = $clog2(WORD_WIDTH + 1);

    localparam logic [IDX_WIDTH-1:0] IDX_MAX = IDX_WIDTH'(WORD_WIDTH) + 1'b1;	// Tested to work. Not sure why it does...

    // Data buffer and indexing
    logic [WORD_WIDTH-1:0] data_buffer;
    logic [IDX_WIDTH-1:0]  bit_idx;

    // Manchester decoding state
    logic manchester_chip_first;  // First chip of Manchester pair
    logic chip_idx;               // 0 = first chip, 1 = second chip

    // Failure detection
    logic manchester_error;

	// Parity calculation
	logic parity_rolling_counter;


    typedef enum logic [2:0] {
        IDLE,					// Waiting for data
        INSERT_PRE_BIT,         // Insert pre-decoded data bit from prefix decoder. Inc. bit index.
        DECODE_DATA,            // Decode remaining 15 symbols and 1 parity symbol. Keep track of parity.
        FAIL,                   // Report failure to parent module
        DONE                    // Report success to parent module
    } state_t;

	state_t current_state;
	state_t next_state;


// ----------------------------------------------------------------------------
// Next State Logic
// ----------------------------------------------------------------------------

	always_comb begin

		next_state = IDLE;

		if (i_reset || i_clear) begin
			next_state = IDLE;
		end
		else begin
			case (current_state)
				IDLE: 
					next_state = (i_rx_valid) ? INSERT_PRE_BIT : IDLE;
				INSERT_PRE_BIT: 
				    next_state = DECODE_DATA;
				DECODE_DATA: 
				    next_state = (manchester_error) ? FAIL : 
								 (bit_idx == IDX_MAX && chip_idx == 1'b1) ? DONE : DECODE_DATA;
				FAIL:
					next_state = IDLE;
				DONE:
					next_state = IDLE;
				default:
					$fatal("Invalid State in Data Receiver FSM");
			endcase
		end
	end


// ----------------------------------------------------------------------------
// Current State & Decoding Logic
// ----------------------------------------------------------------------------

	always_ff @(posedge i_clk) begin

		current_state <= next_state;

		case (next_state)

			IDLE: begin
				data_buffer <= '0;	// TODO Test with don't cares ('x)
				bit_idx     <= '0;  // TODO Test with don't cares ('x)
				chip_idx    <= '0;
				manchester_error <= '0;
				parity_rolling_counter <= '0;
			end

			INSERT_PRE_BIT: begin
				data_buffer 		<= {data_buffer[WORD_WIDTH-2:0], i_pre_data_bit};
				bit_idx     		<= IDX_WIDTH'(1);
				chip_idx     		<= '0;
				manchester_error	<= '0;
				parity_rolling_counter <= parity_rolling_counter ^ i_pre_data_bit;
				$info("Inserted Prefix Data Bit: %0b", i_pre_data_bit);
			end

			DECODE_DATA: begin
				if (i_rx_valid) begin
					if (chip_idx == 1'b1) begin
						// Receive second chip of Manchester pair
						data_buffer      <= {data_buffer[WORD_WIDTH-2:0], Decode_Manchester_Chips({manchester_chip_first, i_rx_in})};
						bit_idx          <= bit_idx + 1'b1;
						chip_idx         <= 1'b0;
						manchester_error       <= (manchester_chip_first == i_rx_in); // Invalid if both bits are the same
						parity_rolling_counter <= parity_rolling_counter ^ Decode_Manchester_Chips({manchester_chip_first, i_rx_in});

						$info("Received Manchester Pair: %0b", Decode_Manchester_Chips({manchester_chip_first, i_rx_in}));
						if (manchester_chip_first == i_rx_in) begin
							$error("Manchester Decoding Error Detected: %0b%0b", manchester_chip_first, i_rx_in);
						end

					end
					else begin : Manchester_First_Bit_Rx
		                // Receive first chip of Manchester pair
						manchester_chip_first <= i_rx_in;
						chip_idx <= 1'b1;
					end
				end
				else begin
					data_buffer            <= data_buffer;
					bit_idx                <= bit_idx;
					chip_idx               <= chip_idx;
					parity_rolling_counter <= parity_rolling_counter;
					manchester_error       <= 1'b0;
				end
			end

			FAIL: begin $error("Manchester encoding failure recorded"); end // Do nothing
			DONE: begin $info("Data Reception Complete"); end // Do nothing // Do nothing.
			default : $fatal("Invalid State in Data Receiver FSM");
		endcase
	end


// ----------------------------------------------------------------------------
// Output Assignments
// ----------------------------------------------------------------------------

	assign o_data_word    = data_buffer[16:1];
	assign o_parity_rx   =  data_buffer[0];
	assign o_parity_calc  = parity_rolling_counter;
    assign o_busy         = (current_state == INSERT_PRE_BIT) || (current_state == DECODE_DATA);
    assign o_done         = (current_state == DONE);
    assign o_fail         = (current_state == FAIL);


endmodule
