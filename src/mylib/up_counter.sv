
module up_counter #(
        parameter CYCLE_COUNT    = 16,
        parameter COUNTER_WIDTH  = $clog2(CYCLE_COUNT+1) 
    ) (

        input  logic                          i_clk  ,  // Clock input
        input  logic                          i_clear,  // Synchronous clear input
        input  logic                          i_en   ,  // Enable counting up

        output logic [COUNTER_WIDTH-1:0]      o_count,  // {optional} Current count value
        output logic                          o_busy ,  // {optional} High when counting up
        output logic                          o_done    // {optional} High when count reaches max
);


    localparam logic [COUNTER_WIDTH-1:0] INITIAL_VALUE = '0;
    localparam logic [COUNTER_WIDTH-1:0] MAX_VALUE     = COUNTER_WIDTH'(CYCLE_COUNT);

    logic [COUNTER_WIDTH-1:0] count;

    always_ff @ (posedge i_clk) begin
        if (i_clear) begin
            count <= INITIAL_VALUE;
        end
        else if (i_en) begin
            if (count != MAX_VALUE) begin
                count <= count + 1'b1;
            end
            else begin
                count <= MAX_VALUE;
            end
        end
    end

    assign o_count = count;
    assign o_busy  = (count != MAX_VALUE);
    assign o_done  = (count == MAX_VALUE);



// ----------------------------------------------------------------------------
// Assertions/Compile Checks
// ----------------------------------------------------------------------------

    
    // CYCLE_COUNT must be greater than 0
    initial begin

        $display("up_counter: CYCLE_COUNT = %0d", CYCLE_COUNT);
        $display("up_counter: COUNTER_WIDTH = %0d", COUNTER_WIDTH);
        $display("up_counter: INITIAL_VALUE = %0d", INITIAL_VALUE);
        $display("up_counter: MAX_VALUE = %0d", MAX_VALUE);

        // TESTED
        assert (CYCLE_COUNT > 0) else begin
            $fatal("up_counter: CYCLE_COUNT parameter must be greater than 0");
            $finish;
        end

        // TESTED
        assert (2 ** COUNTER_WIDTH >= CYCLE_COUNT) else begin
            $fatal("up_counter: COUNTER_WIDTH parameter is too small for the given CYCLE_COUNT");
            $finish;
        end
        
    end


endmodule // up_counter

