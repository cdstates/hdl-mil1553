module down_counter #(
        parameter CYCLE_COUNT    = 16,
        parameter COUNTER_WIDTH  = $clog2(CYCLE_COUNT+1) 
    ) (

        input  logic                          i_clk  ,  // Clock input
        input  logic                          i_clear,  // Synchronous clear input
        input  logic                          i_en   ,  // Enable counting down

        output logic [COUNTER_WIDTH-1:0]      o_count,  // {optional} Current count value
        output logic                          o_busy ,  // {optional} High when counting down
        output logic                          o_done    // {optional} High when count reaches zero
);


    localparam logic [COUNTER_WIDTH-1:0] INITIAL_VALUE = COUNTER_WIDTH'(CYCLE_COUNT);
    localparam logic [COUNTER_WIDTH-1:0] ZERO_VALUE    = '0;

    logic [COUNTER_WIDTH-1:0] count = '0;

    always_ff @ (posedge i_clk) begin
        if (i_clear) begin
            count <= INITIAL_VALUE;
        end
        else if (i_en) begin
            if (count != ZERO_VALUE) begin
                count--;
            end
            else begin
                count <= ZERO_VALUE;
            end
        end
    end

    assign o_count = count;
    assign o_busy  = (count != ZERO_VALUE);
    assign o_done  = (count == ZERO_VALUE);



// ----------------------------------------------------------------------------
// Assertions/Compile Checks
// ----------------------------------------------------------------------------

    
    // CYCLE_COUNT must be greater than 0
    initial begin

        $display("down_counter: CYCLE_COUNT = %0d", CYCLE_COUNT);
        $display("down_counter: COUNTER_WIDTH = %0d", COUNTER_WIDTH);
        $display("down_counter: INITIAL_VALUE = %0d", INITIAL_VALUE);
        $display("down_counter: ZERO_VALUE = %0d", ZERO_VALUE);

        // TESTED
        assert (CYCLE_COUNT > 0) else begin
            $fatal("down_counter: CYCLE_COUNT parameter must be greater than 0");
            $finish;
        end

        // TESTED
        assert (COUNTER_WIDTH ** 2 >= CYCLE_COUNT) else begin
            $fatal("down_counter: COUNTER_WIDTH parameter is too small for the given CYCLE_COUNT");
            $finish;
        end
        
    end


endmodule // down_counter

