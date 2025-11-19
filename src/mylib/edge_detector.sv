//-----------------------------------------------------------------------------
// Title      : Edge Detector
// Project    : MIL-STD-1553 Adapter
//-----------------------------------------------------------------------------
// File       : edge_detector.sv
// Author     : Cody
// Company    : 
// Created    : 2024-11-11
// Last update: 2024-11-11
// Platform   : 
// Standard   : SystemVerilog
// Test Bench : tbc_edge_detector.py
//-----------------------------------------------------------------------------
// Description: 
// This module implements an edge detector for signal transitions.
// It performs:
//   - Signal synchronization across clock domains
//   - Rising edge detection
//   - Falling edge detection
//   - General edge detection (rising or falling)
//   - Output of previous and current signal states
//
// The detector uses two flip-flops to synchronize the input signal
// and detect transitions between consecutive clock cycles.
//-----------------------------------------------------------------------------
// Copyright (c) 2024 
//-----------------------------------------------------------------------------
// Revisions  :
// Date        Version  Author  Description
// 2024-11-11  1.0      Cody    Created
//-----------------------------------------------------------------------------


module edge_detector (

// Input signals
    input   logic   i_clk,              // System clock
    input   logic   i_signal,           // Input signal

// Output signals
    output  logic   o_edge_detected,    // High for one clock cycle on any edge (optional)

    output  logic   o_rising_edge,      // High for one clock cycle on rising edge (optional)
    output  logic   o_falling_edge,     // High for one clock cycle on falling edge (optional)

    output  logic   o_prev_signal,      // Previous state of input signal (optional)
    output  logic   o_curr_signal       // Current state of input signal  (optional)
);

    logic signal_prev;
    logic signal_curr;

    always_ff @ (posedge i_clk) begin
        signal_prev <= signal_curr;
        signal_curr <= i_signal;
    end

    logic rising_edge;      // Added to prevent outputs being driven by optional outputs
    logic falling_edge;

    always_comb rising_edge  = (signal_prev == 1'b0) && (signal_curr == 1'b1);
    always_comb falling_edge = (signal_prev == 1'b1) && (signal_curr == 1'b0);

    assign o_rising_edge  = rising_edge;
    assign o_falling_edge = falling_edge;
    assign o_edge_detected = rising_edge || falling_edge; 

    assign o_prev_signal = signal_prev;
    assign o_curr_signal = signal_curr;

endmodule // m1553_edge_detector

