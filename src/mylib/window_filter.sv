//-----------------------------------------------------------------------------
// Title      : Window Filter
// Project    : MIL-STD-1553 Adapter
//-----------------------------------------------------------------------------
// File       : window_filter.sv
// Author     : Cody
// Company    : 
// Created    : 2024-11-11
// Last update: 2024-11-11
// Platform   : 
// Standard   : SystemVerilog
// Test Bench : 
//-----------------------------------------------------------------------------
// Description: 
// This module implements a parameterized window filter that validates whether
// an input counter value falls within a specified range. It performs:
//   - Range checking against MIN_VALUE and MAX_VALUE parameters
//   - Output validation signal generation
//   - Parameter sanity checking at elaboration time
//   - Debug display of parameter values
//
// The module accepts a counter value via i_counter_value and asserts o_valid
// when the value is within the inclusive range [MIN_VALUE, MAX_VALUE].
// Compile-time checks ensure valid parameter configuration.
//-----------------------------------------------------------------------------
// Copyright (c) 2024 
//-----------------------------------------------------------------------------
// Revisions  :
// Date        Version  Author  Description
// 2024-11-11  1.0      Cody    Created
//-----------------------------------------------------------------------------

module window_filter #(
    parameter MIN_VALUE = 1,    // If set to 0, verilator gives a warning of constant comparison
    parameter MAX_VALUE = 2,
    parameter COUNTER_SIZE = 2
) (
    input  logic [COUNTER_SIZE-1:0] i_counter_value,    // Input counter value to check
    output logic o_valid                                // Asserted if i_counter_value is within [MIN_VALUE, MAX_VALUE]
);

    // Type/Length Casts
    localparam [COUNTER_SIZE-1:0] min_val = MIN_VALUE[COUNTER_SIZE-1:0];
    localparam [COUNTER_SIZE-1:0] max_val = MAX_VALUE[COUNTER_SIZE-1:0];

    // Output Logic   
    assign o_valid = (i_counter_value >= min_val) && (i_counter_value <= max_val);


// ----------------------------------------------------------------------------
// Assertions/Compile Sanity Checks
// ----------------------------------------------------------------------------

    initial begin
        $display("window_filter: MIN_VALUE=%0d, MAX_VALUE=%0d, COUNTER_SIZE=%0d", MIN_VALUE, MAX_VALUE, COUNTER_SIZE);
        $display("window_filter: Generated local params min_val=%0d, max_val=%0d", min_val, max_val);
    end

    generate
        if (MIN_VALUE >= MAX_VALUE) begin : min_max_check
            $fatal(1, "window_filter: MIN_VALUE must be less than MAX_VALUE");
        end

        if (COUNTER_SIZE <= 0) begin : counter_size_check
            $fatal(1, "window_filter: COUNTER_SIZE must be greater than 0");
        end

        if (MAX_VALUE >= (2**COUNTER_SIZE)) begin : max_value_check
            $fatal(1, "window_filter: MAX_VALUE exceeds COUNTER_SIZE range");
        end

        if (MIN_VALUE >= (2**COUNTER_SIZE)) begin : min_value_check
            $fatal(1, "window_filter: MIN_VALUE exceeds COUNTER_SIZE range");
        end
    endgenerate

endmodule
