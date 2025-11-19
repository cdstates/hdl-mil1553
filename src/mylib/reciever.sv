//-----------------------------------------------------------------------------
// Title      : MIL-STD-1553 Manchester Receiver
// Project    : MIL-STD-1553 Adapter
//-----------------------------------------------------------------------------
// File       : reciever.sv
// Author     : Cody
// Company    : 
// Created    : 2024-11-11
// Last update: 2024-11-11
// Platform   : 
// Standard   : SystemVerilog
// Test Bench : tbc_reciever.py
//-----------------------------------------------------------------------------
// Description: 
// This module implements a Manchester-encoded receiver for MIL-STD-1553
// protocol. It performs:
//   - Signal synchronization and edge detection
//   - Timing window filtering for valid Manchester transitions
//   - Prefix pattern detection (Command/Data word sync)
//   - Manchester symbol decoding (16 data bits + parity)
//   - Parity verification
//   - Data output with handshaking (valid/ready protocol)
//
// The receiver operates as a digital PLL, self-synchronizing to incoming
// Manchester transitions within configurable timing windows.
//
// Common terminolgy:
//    Bit Rate         : Manchester bit rate (1 Mbps typical for MIL-STD-1553)
//    Symbol           : Manchester symbol (2 chips per symbol). Represents one data bit.
//    Chip             : Half of a Manchester symbol (high or low level).
//    Prefix-Portion   : Initial sync pattern (6 chips) indicating start of Command/Data word.
//                         - Followed by a single symbol.
//    Data-Portion     : 15 remaining symbols of data bits + 1 parity symbol.
//    Post-Intermission: Idle period after message reception before next message can start.
//-----------------------------------------------------------------------------
// Copyright (c) 2024 
//-----------------------------------------------------------------------------
// Revisions  :
// Date        Version  Author  Description
// 2024-11-11  1.0      Cody    Created
//-----------------------------------------------------------------------------



module reciever #(
    parameter int unsigned MASTER_CLK_FREQ_HZ = 100_000_000,  // Master clock frequency in Hz
    parameter int unsigned MAN_BIT_RATE_HZ    = 1_000_000  ,  // Bit rate in Hz
    parameter logic        EN_WINDOW_FILTER   = 1'b0       ,  // Enable time window filtering
    parameter int unsigned WINDOW_LATE_NS     = 50         ,  // Time window late tolerance in nanoseconds
    parameter int unsigned WINDOW_EARLY_NS    = 50         ,  // Time window early tolerance in nanoseconds

    parameter int unsigned DUR_AFTER_LAST_CHIP_NS = 1000   ,  // Duration to wait after last chip before resetting receiver.
                                                              //    - if a high signal occurs, a failure flag is raised.
    parameter logic        EN_COUNT_RESET_ON_CHIP_END = 1'b0  // TRUE = Don't let the counter wait past EXACTLY one chip period. 
                                                              //      - Early edges will still reset the counter based on window filtering
) (

    input   logic    i_clk,          // System clock
    input   logic    i_reset,        // System reset

    input   logic    i_en,           // Enable receiver

    input   logic    i_data_in,      // Manchester encoded data input

    output  logic    o_data_valid,   // Data output valid signal. Indicates new data is available.
    input   logic    i_data_ready,   // Data output ready signal. Indicates parent module has accepted data.

    input   logic    i_fail_clear,   // Clear fail state signal. Indicates parent module has acknowledged fail state.
    output  logic    o_fail_flag,     // Fail flag output. Indicates receiver is in fail state.

    output  lib_1553::word_t      o_data_word,         // Received data output
    output  lib_1553::word_type_t o_word_type,    // Received word type output
    output  lib_1553::rx_fail_flags_t o_fail_flags    // Detailed fail flags output
);

import lib_1553::*;

// ----------------------------------------------------------------------------
// Receiver Timing Parameters
// ----------------------------------------------------------------------------

    initial begin
        $info("MIL-STD-1553 Timing Parameters:");
        $info("  Clock Period (ns): %0d", CLK_PERIOD_NS);
        $info("  Chip Period (ns): %0d", CHIP_PERIOD_NS);
        $info("  Cycles per Chip: %0d", CYCLES_PER_CHIP);
        $info("  Cycles per Half Chip: %0d", CYCLES_PER_HALF_CHIP);
        $info("  Cycles per Symbol: %0d", CYCLES_PER_SYMBOL);
        $info("  Cycles per Sync: %0d", CYCLES_PER_SYNC);
        $info("  Cycles Tolerance Late: %0d", CYCLES_TOLERANCE_LATE);
        $info("  Cycles Tolerance Early: %0d", CYCLES_TOLERANCE_EARLY);
        $info("  Cycles Timer Max: %0d", CYCLES_TIMER_MAX);
        $info("  Cycles Filter Max: %0d", CYCLES_FILTER_MAX);
        $info("  Timer Counter Width: %0d", TIMER_COUNTER_WIDTH);
        $info("  Cycles Intermission Wait: %0d", CYCLES_INTERMISION_WAIT);
    end
 

// ----------------------------------------------------------------------------
// Receiver State Machine
// ----------------------------------------------------------------------------

    typedef enum logic [3:0] {
        IDLE,               // Wait for initial high signal
        PREFIX,             // Allow reciever_prefix to determine word type and first symbol
        DATA,               // Recieve remaining 15 data symbols + 1 parity symbol
        POST_INTERMISSION,  // Wait for intermission period after message reception
        FAIL,               // Fail state. Wait for parent module to assert i_fail_clear
        DONE                // Message receieved successfully. Wait for i_data_ready from parent module.
    } rx_state_t;

    rx_state_t current_state = IDLE;        // Current state register
    rx_state_t next_state;                  // Next state combinational logic


// ----------------------------------------------------------------------------
// Syncrhonize asynchronous input signal
// ----------------------------------------------------------------------------

    logic sync_signal;          // Most recent synchronized signal

    signal_synchronizer signal_synchronizer_uut (
        .i_clk    (i_clk      ),
        .i_signal (i_data_in  ),
        .o_signal (sync_signal)
    );


// ----------------------------------------------------------------------------
// Central Fail/Clear Logic
// ----------------------------------------------------------------------------

    var logic clear_all; 

    always_comb clear_all = window_fail             // Edge detected outside valid timing windows
                            || timer_timedout_fail  // Timer exceeded max duration without edge
                            || i_fail_clear;        // Parent module cleared fail state

    logic fail_any;         // Any sub-module fail. Should clear all sub-module fails when cleared.

    always_comb fail_any = prefix_fail    // From reciever_prefix
                           || data_fail;  // From reciever_data

// ----------------------------------------------------------------------------
// Edge Detection - Tested
// ----------------------------------------------------------------------------

    logic edge_changed;
    logic _unused_edge_prev_r;
    logic _unused_edge_next_r;
    logic _unused_edge_risen;
    logic _unused_edge_fallen;

    edge_detector edge_detector_uut (
        .i_clk           (i_clk       ),
        .i_signal        (sync_signal ), // Input signal is #2 delayed
        .o_edge_detected (edge_changed), // Edge detected output is #3 delayed
        .o_rising_edge   (_unused_edge_risen  ),
        .o_falling_edge  (_unused_edge_fallen ),
        .o_prev_signal   (_unused_edge_prev_r),
        .o_curr_signal   (_unused_edge_next_r)
    );

    function logic Is_Edge_Detected(); 
        return edge_changed; 
    endfunction

// ----------------------------------------------------------------------------
// Timer Module = Digital PLL Basic, Widndow Filtering, and Intermission Timing
// ----------------------------------------------------------------------------

    var logic timer_clear;

    logic timer_timedout_fail;
    logic [TIMER_COUNTER_WIDTH-1:0]  timer_count;

    logic _unused_o_done;

    up_counter #(
        .CYCLE_COUNT   (CYCLES_FILTER_MAX),  
        .COUNTER_WIDTH (TIMER_COUNTER_WIDTH)
    ) timer_utt (
        .i_clk    (i_clk               ),
        .i_en     (1'b1                ),
        .i_clear  (timer_clear         ),
        .o_count  (timer_count         ),
        .o_busy   (_unused_o_done      ),
        .o_done   (timer_timedout_fail )
    );

    always_ff @(posedge i_clk) begin
        if (next_state == POST_INTERMISSION) begin
            // In intermission state, only clear timer after intermission is over
            timer_clear <= Is_Post_Msg_Intermission_Over() ? 1'b1 : 1'b0;
        end
        else begin
            // In all other states, clear timer on edge detection, fail, or at chip end if enabled
            timer_clear <= (edge_changed                    // Acts as a digital PLL   
                            || fail_any                     // Side effect of waiting for parent module to clear fail latch
                            || (EN_COUNT_RESET_ON_CHIP_END  // Takes priority over edge detection. Removes some DPLL behavior on slightly late edges
                                && Is_At_Chip_End())) 
                                ? 1'b1 : 1'b0;
        end
    end


    function logic Is_At_Chip_Center();
        return (timer_count == TIMER_COUNTER_WIDTH'(CYCLES_PER_HALF_CHIP));
    endfunction

    function logic Is_At_Chip_End();
        return (timer_count == TIMER_COUNTER_WIDTH'(CYCLES_PER_CHIP));
    endfunction

    function logic Is_Post_Msg_Intermission_Over();
        return (timer_count >= TIMER_COUNTER_WIDTH'(CYCLES_INTERMISION_WAIT));
    endfunction


// ----------------------------------------------------------------------------
// Manchester'ed Clock-Enable Signal - PLL like behavior
// ----------------------------------------------------------------------------


    logic window_chip_valid;
    logic window_symbol_valid;
    logic window_sync_valid;
    logic window_sync2_valid;

    logic window_any_valid;       always_comb window_any_valid   = window_chip_valid || window_symbol_valid || window_sync_valid || window_sync2_valid;
    // logic window_chips_valid;     always_comb window_chips_valid = window_chip_valid || window_sync_valid;


    logic window_fail;            always_comb window_fail = EN_WINDOW_FILTER        // TODO Increase strictness to only allow windows for
                                                            && !window_any_valid    //       the exact expected symbols type per rx_state_t
                                                            && Is_Edge_Detected();

    window_filter #(                                                   
        .MIN_VALUE       (CYCLES_PER_CHIP - CYCLES_TOLERANCE_EARLY),    // Window for 500ns +/- tolerance
        .MAX_VALUE       (CYCLES_PER_CHIP + CYCLES_TOLERANCE_LATE ),
        .COUNTER_SIZE    (TIMER_COUNTER_WIDTH)
    ) window_chip_valid_uut (
        .i_counter_value (timer_count       ),
        .o_valid         (window_chip_valid )
    );

    window_filter #(                                                          
        .MIN_VALUE       (CYCLES_PER_CHIP * 2 - CYCLES_TOLERANCE_EARLY),  // Window for 1000ns +/- tolerance
        .MAX_VALUE       (CYCLES_PER_CHIP * 2 + CYCLES_TOLERANCE_LATE ),
        .COUNTER_SIZE    (TIMER_COUNTER_WIDTH)
    ) window_symbol_valid_uut (
        .i_counter_value (timer_count        ),
        .o_valid         (window_symbol_valid)
    );

    window_filter #(                                                   
        .MIN_VALUE       (CYCLES_PER_CHIP * 3 - CYCLES_TOLERANCE_EARLY),  // Window for 1500ns +/- tolerances
        .MAX_VALUE       (CYCLES_PER_CHIP * 3 + CYCLES_TOLERANCE_LATE ),  // Only allowed for sync pattern
        .COUNTER_SIZE    (TIMER_COUNTER_WIDTH)
    ) window_sync_valid_uut (
        .i_counter_value (timer_count       ),
        .o_valid         (window_sync_valid )
    );

    window_filter #(                                                    
        .MIN_VALUE       (CYCLES_PER_CHIP * 4 - CYCLES_TOLERANCE_EARLY),    // Window for 2000ns +/- tolerance                         
        .MAX_VALUE       (CYCLES_PER_CHIP * 4 + CYCLES_TOLERANCE_LATE ),    // Only allowed for a Command-Status word with MSB of 0 ('01' manchester)
        .COUNTER_SIZE    (TIMER_COUNTER_WIDTH)                              //     or Data word with MSB of 1 ('10' manchester)
    ) window_sync2_valid_uut (
        .i_counter_value (timer_count       ),
        .o_valid         (window_sync2_valid)
    );

// ----------------------------------------------------------------------------
// Filtering timer
// ----------------------------------------------------------------------------


always_comb begin
    // Default assignment
    next_state = current_state;

    if (i_reset || clear_all) begin
        next_state = FAIL;
    end
    else begin
        case (current_state)

            IDLE: begin 
                if (i_en && Is_Edge_Detected() && window_any_valid) begin
                    next_state = PREFIX;
                end
            end

            PREFIX: begin
                if (prefix_fail) begin
                    next_state = FAIL;
                end
                else if (prefix_done) begin
                    next_state = DATA;
                end
            end

            DATA: begin
                if (data_fail) begin
                    next_state = FAIL;
                end
                else if (data_done) begin
                    next_state = CALC_PARITY;
                end
            end

            POST_INTERMISSION: begin
                if (Is_Post_Msg_Intermission_Over()) begin
                    next_state = DONE;
                end
            end

            FAIL: begin
                if (i_fail_clear) begin
                    next_state = IDLE;
                end
            end

            DONE: begin
                if (i_data_ready) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;

        endcase 
    end
end


// ----------------------------------------------------------------------------
//  Prefix Reciever/Decoder Module : 6 symbol chips + 2 data chips (eventual MSB)
// ----------------------------------------------------------------------------

    var logic prefix_data_in;        always_comb prefix_data_in = sync_signal;  // TODO TEST to make sure its not a clock behind
    var logic prefix_data_valid;

    logic prefix_done;
    logic prefix_fail;
    logic prefix_busy;
    lib_1553::word_type_t prefix_word_type;
    logic prefix_data_bit;                   // Goes to data_reciever_uut.i_pre_data_bit

    reciever_prefix prefix_reciver_uut (
        .i_clk         (i_clk            ),
        .i_reset       (i_reset          ),
        .i_rx_in       (prefix_data_in   ),
        .i_rx_valid    (prefix_data_valid),
        .i_clear       (clear_all ),
        .o_busy        (prefix_busy      ),
        .o_done        (prefix_done      ),
        .o_fail        (prefix_fail      ),
        .o_word_type   (prefix_word_type ),
        .o_data_bit    (prefix_data_bit  )
    );

// ----------------------------------------------------------------------------
//  Remaininig Data Reciever/Decoder Module
// ----------------------------------------------------------------------------

    logic data_d_in;
    logic data_d_valid;

    logic data_done;
    logic data_fail;
    logic data_busy;
    lib_1553::word_t data_word;

    logic data_parity_rx;
    logic data_parity_calc;

    reciever_data data_reciver_uut (
        .i_clk         (i_clk           ),
        .i_reset       (i_reset         ),
        .i_rx_in       (data_d_in       ),
        .i_rx_valid    (data_d_valid    ), 
        .i_clear       (clear_all       ),  // TEST
        .i_pre_data_bit(prefix_data_bit ),
        .o_busy        (data_busy       ),
        .o_done        (data_done       ),
        .o_fail        (data_fail       ),
        .o_data_word   (data_word       ),
        .o_parity_rx   (data_parity_rx ),
        .o_parity_calc (data_parity_calc)
    );

// ----------------------------------------------------------------------------
// Sampling logic
// ----------------------------------------------------------------------------

    always_ff @(posedge i_clk) begin
        if (next_state == PREFIX) begin
            if (Is_At_Chip_Center()) begin : Prefix_Sample_At_Center_ff
                prefix_data_valid <= 1'b1;
                $info("RECIEVER: Sampling prefix bit: %b at time %0t", sync_signal, $time);
            end
            else begin
                prefix_data_valid <= 1'b0;
            end
        end
        else if (next_state == DATA) begin
            if (Is_At_Chip_Center()) begin : Data_Sample_At_Center_ff
                data_d_in    <= sync_signal;
                data_d_valid <= 1'b1;
                $info("RECIEVER: Sampling data bit: %b at time %0t", sync_signal, $time);
            end
            else begin
                data_d_valid <= 1'b0;
            end
        end
    end



// ----------------------------------------------------------------------------
// Output Logic
// ----------------------------------------------------------------------------

    // Type/Struct buffers (to make xsim happy)
    lib_1553::rx_fail_flags_t _fail_flags;

    assign _fail_flags.prefix_fail     = prefix_fail;
    assign _fail_flags.data_fail       = data_fail;
    assign _fail_flags.parity_fail     = (current_state == VERIFY_PARITY) && (data_parity_rx != data_parity_calc);
    assign _fail_flags.window_fail     = window_fail;
    assign _fail_flags.timer_timeout   = timer_timedout_fail;


    always_comb o_data_valid = (current_state == DONE || current_state == POST_INTERMISSION);
    always_comb o_fail_flag  = (current_state == FAIL);


    always_comb o_data_word  = data_word;
    always_comb o_word_type  = prefix_word_type;
    always_comb o_fail_flags = _fail_flags;



endmodule : reciever
