module m1553_timer #(

    parameter int unsigned MaxValue = 1000, // Initial timer value in clock cycles

    parameter int unsigned SubTarget_1 = 0, // Optional sub-targets. Cycles since started.
    parameter int unsigned SubTarget_2 = 0, //  - '0' to disable. A "==" comparison is made against the current count.

    parameter int unsigned RangeMin_1 = 0, // Optional ranges. Cycles since started.
    parameter int unsigned RangeMax_1 = 0, //  - Two values define a range. '0' to disable.
    //  - A ">=" and "<=" comparison is made against the current count.
    parameter int unsigned RangeMin_2 = 0, //  - Rules := min < max, max > 0
    parameter int unsigned RangeMax_2 = 0,

    localparam int unsigned MaxValue_Width = $clog2(MaxValue)

) (
    // Clock
    input var logic i_clk, // System clock

    // Control
    input var logic i_clear, // Clear/Reset timer
    input var logic i_en   , // Enable timer

    // Output
    output var logic [MaxValue_Width-1:0] o_count, // Current count value

    // General Outputs
    output var logic o_done, // Timer done

    // Output flags
    output var logic o_sub_target_reached_1, // Target 1 reached
    output var logic o_sub_target_reached_2, // Target 2 reached
    output var logic o_in_range_1          , // In range 1
    output var logic // In range 2
     o_in_range_2      

);

    // ----------------------------------------------------------------------------
    //  Instantiation of down_counter
    // ----------------------------------------------------------------------------

    logic [MaxValue_Width-1:0] count;
    logic                      _busy;
    logic                      _done;

    m1553_down_counter #(
        .InitialValue (MaxValue)
    ) m_down_counter (
        .i_clk   (i_clk  ),
        .i_clear (i_clear),
        .i_en    (i_en   ),
        .o_count (count  ),
        .o_busy  (_busy  ), // Unused
        .o_done  (_done   // Unused
        )    );

    // ----------------------------------------------------------------------------
    //  Simple output assignments
    // ----------------------------------------------------------------------------

    always_comb o_count = count;
    always_comb o_done  = (count == 0);


    // ----------------------------------------------------------------------------
    //  Sub-target and range checking - Optionnal outputs
    // ----------------------------------------------------------------------------

    localparam int unsigned sub_t_1     = SubTarget_1 - MaxValue; // Values adjusted to down_counter counting scheme
    localparam int unsigned sub_t_2     = SubTarget_2 - MaxValue;
    localparam int unsigned range_min_1 = RangeMin_1 - MaxValue;
    localparam int unsigned range_max_1 = RangeMax_1 - MaxValue;
    localparam int unsigned range_min_2 = RangeMin_2 - MaxValue;
    localparam int unsigned range_max_2 = RangeMax_2 - MaxValue;

    always_comb o_sub_target_reached_1 = ((isSubTargetValid(SubTarget_1, "SubTarget_1")) ? ( (count == sub_t_1) ) : ( 0 ));
    always_comb o_sub_target_reached_2 = ((isSubTargetValid(SubTarget_2, "SubTarget_2")) ? ( (count == sub_t_2) ) : ( 0 ));

    always_comb o_in_range_1 = ((isRangeValid(RangeMin_1, RangeMax_1, "Range_1")) ? ( ((count <= range_max_1) && (count >= range_min_1)) ) : ( 0 ));

    always_comb o_in_range_2 = ((isRangeValid(RangeMin_2, RangeMax_2, "Range_2")) ? ( ((count <= range_max_2) && (count >= range_min_2)) ) : ( 0 ));



    // ----------------------------------------------------------------------------
    //  Local helper functions
    // ----------------------------------------------------------------------------

    /*
	* Validates a sub-target. Returns true if valid, false if not.
	*/
    function automatic logic isSubTargetValid(
        input var int unsigned sub_target,
        input var string       name      
    ) ;
        if ((sub_target == 0)) begin // Zero indicates to not use this sub-target. Not an error.
            return 1'b0;
        end
        if ((sub_target > MaxValue)) begin
            $fatal("Timer|%s: SubTarget value (%0d) cannot be greater than MaxValue (%0d).", name, sub_target, MaxValue);
            return 1'b0;
        end
        return 1'b1;
    endfunction

    /*
	* Validates a range. Returns true if valid, false if not.
	*/
    function automatic logic isRangeValid(
        input var int unsigned range_min,
        input var int unsigned range_max,
        input var string       name     
    ) ;
        if ((range_max == 0)) begin
            if ((range_min != 0)) begin
                $fatal("Timer|%s: RangeMax is zero (disabled) but RangeMin is non-zero (%0d).", name, range_min);
            end
            return 1'b0; // Zero indicates to not use this range. Not an error,
        end
        if ((range_max == range_min)) begin // Zero-Zero was handled above
            $fatal("Timer|%s: RangeMin and RangeMax cannot be equal (%0d).", name, range_min);
            return 1'b0;
        end
        if ((range_max > MaxValue)) begin
            $fatal("Timer|%s: RangeMax value (%0d) cannot be greater than MaxValue (%0d).", name, range_max, MaxValue);
            return 1'b0;
        end
        if ((range_min >= range_max)) begin
            $fatal("Timer|%s: RangeMin value (%0d) must be less than RangeMax value (%0d).", name, range_min, range_max);
            return 1'b0;
        end
        return 1'b1;
    endfunction // endfunction

endmodule // endmodule : timer
//# sourceMappingURL=timer.sv.map
