//-----------------------------------------------------------------------------
// Title      : MIL-STD-1553 Prefix Receiver
// Project    : MIL-STD-1553 Adapter
//-----------------------------------------------------------------------------
// File       : reciever_prefix.sv
// Author     : Cody
// Company    : 
// Created    : 2024-11-11
// Last update: 2024-11-11
// Platform   : 
// Standard   : SystemVerilog
// Test Bench : 
//-----------------------------------------------------------------------------
// Description: 
// This module implements a prefix pattern detector for MIL-STD-1553
// Manchester-encoded words. It performs:
//   - Serial bit buffering (8 bits)
//   - Sync pattern recognition (Command: 111_000, Data: 000_111)
//   - Manchester data bit validation (01 or 10)
//   - Word type identification (Command vs Data word)
//   - Data bit extraction from Manchester encoding
//
// The module receives serial bits via i_rx_in/i_rx_valid interface and
// signals completion via o_done when 8 bits are collected. It outputs
// o_fail if the received pattern doesn't match valid sync patterns.
//-----------------------------------------------------------------------------
// Copyright (c) 2024 
//-----------------------------------------------------------------------------
// Revisions  :
// Date        Version  Author  Description
// 2024-11-11  1.0      Cody    Created
// 2025-11-25  1.1      Cody    Test updates and fixes - cocotb integration
//-----------------------------------------------------------------------------

module reciever_prefix  (
	input	logic 	i_clk,		// System Clock
	input	logic	i_reset,    // System Reset

	input	logic	i_rx_in,	// Serial Input Bit
	input   logic   i_rx_valid, // Input Bit Valid Signal
	input   logic   i_clear,    // Clear internal state

	output	logic	o_busy,     // High when decodinng in progress
	output	logic	o_done,     // High when prefix reception complete
	output  logic	o_fail,     // High when prefix reception failed

	output	logic 	o_word_type, // 0 = Command Word, 1 = Data Word, 
	output 	logic 	o_data_bit   // Decoded Data Bit. Will be the MSB of the received word eventually.
);

    localparam int unsigned BUFFER_WIDTH = 8;
    localparam int unsigned IDX_SIZE = $clog2(BUFFER_WIDTH + 1);
    localparam logic [IDX_SIZE-1:0] IDX_MAX = IDX_SIZE'(BUFFER_WIDTH);

    logic [BUFFER_WIDTH-1:0] buffer = '0;
    logic [IDX_SIZE-1:0]     idx    = '0;

    // Extract sync and data portions
    logic [5:0] sync_pattern;  // Bits [7:2]
    logic [1:0] data_bits;     // Bits [1:0]
    
    assign sync_pattern = buffer[7:2];
    assign data_bits    = buffer[1:0];

    // Check sync patterns
    logic is_cmd_sync;
    logic is_data_sync;
    logic is_valid_data_bits;
    
    assign is_cmd_sync        = (sync_pattern == 6'b111_000);
    assign is_data_sync       = (sync_pattern == 6'b000_111);
    assign is_valid_data_bits = (data_bits == 2'b01) || (data_bits == 2'b10);

    always_ff @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            buffer <= '0;
            idx    <= '0;
        end
        else if (i_clear) begin
            buffer <= '0;
            idx    <= '0;
        end
        else if (i_rx_valid) begin
            buffer <= {buffer[BUFFER_WIDTH-2:0], i_rx_in};
            idx    <= idx + 1'b1;
        end
    end

    // Output assignments
    assign o_word_type = is_data_sync;              // 1 = Data Word, 0 = Command Word
    assign o_data_bit  = data_bits[1];              // Manchester: 01='0', 10='1'
    assign o_fail      = o_done && !((is_cmd_sync || is_data_sync) && is_valid_data_bits);
    
    assign o_busy = (idx < IDX_MAX);
    assign o_done = (idx == IDX_MAX);

endmodule 

