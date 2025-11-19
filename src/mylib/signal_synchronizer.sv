module signal_synchronizer (

    input   logic   i_clk   ,   // System clock
    input   logic   i_signal,   // Input signal to be synchronized

    output  logic   o_signal    // Synchronized output signal

);

    logic [2:0] sync_chain = '0; // 3-stage synchronization chain

    always_ff @ (posedge i_clk) begin
        sync_chain <= {sync_chain[1:0], i_signal};
    end

    always_comb o_signal = sync_chain[2]; // MSB is the synchronized signal

endmodule // signal_synchronizer
