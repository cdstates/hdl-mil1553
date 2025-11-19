package lib_1553;


`ifndef __LIB_1553_SV__         // include guard to make xsim happy
`define __LIB_1553_SV__

// ----------------------------------------------------------------------------
// Compiler Directives
// ----------------------------------------------------------------------------

// Enable simple Manchester decode logic by checkiing only
//    a single bit of the Manchester pair. This assumes that 
//    a check for invalid pairs (00 or 11) is done elsewhere; 
//    preferably in parallel to decoding to avoid slowing down 
//    the decode process.
//    @See Decode_Manchester_Chips function below.
`define ENABLE_SIMPLE_MANCHESTER_DECODE_LOGIC 1

`define MASTER_CLK_FREQ_HZ     100_000_000  // 100 MHz
`define MANCHESTER_BIT_RATE_HZ 1_000_000    // 1 Mbps
`define RX_CLOCK_TOLERANCE_EARLY_NS 50    // 50 ns
`define RX_CLOCK_TOLERANCE_LATE_NS  50    // 50 ns

`define RX_POST_MSG_POST_INTERMISSION_NS 500_000  // 500 us

// ----------------------------------------------------------------------------
// Manchester Encoding/Decoding Constants
// ----------------------------------------------------------------------------

    // Manchester encoding constants
    // Percieved as: [First bit received, Second bit received]
    //           or: [FFirst bit transmitted, Second bit transmitted]
    localparam logic [1:0] MANCHESTER_0 = 2'b01;
    localparam logic [1:0] MANCHESTER_1 = 2'b10;


// ----------------------------------------------------------------------------
// MIL-STD-1553 Structs/Types
// ----------------------------------------------------------------------------

    localparam int unsigned  M1553_NUM_SYNC_BITS   = 3;  // 1.5 + 1.5 
    localparam int unsigned  M1553_NUM_DATA_BITS   = 16;
    localparam int unsigned  M1553_NUM_PARITY_BITS = 1;

    typedef enum logic {
        CMD_WORD  = 1'b0,
        DATA_WORD = 1'b1
    } word_type_t;

    typedef logic [M1553_NUM_DATA_BITS-1:0] word_t;

    typedef struct packed {
        logic timeout_f;
        logic window_noise_f;
        logic manchester_f;
        logic parity_f;
    } rx_fail_flags_t;


// ----------------------------------------------------------------------------
// MIL-STD-1553/Manchester Functions
// ----------------------------------------------------------------------------

    // Manchester decode function
    // Decodes a pair of Manchester chips into a single data bit
	function automatic logic Decode_Manchester_Chips(input logic [1:0] manchester_chips);

`ifdef ENABLE_SIMPLE_MANCHESTER_DECODE_LOGIC
		if (manchester_chips == MANCHESTER_0) begin
			return 1'b0;  // 01 = '0'
		end
		else if (manchester_chips == MANCHESTER_1) begin
			return 1'b1;  // 10 = '1'
		end
		else begin
			return 1'b0;  // Invalid, default to 0
		end
`else
        if (manchester_chips[1] == MANCHESTER_0[1]) begin
            return 1'b0;  // 01 = '0'
        end
        else if (manchester_chips[1] == MANCHESTER_1[1]) begin
            return 1'b1;  // 10 = '1'
        end
        else begin
            return 1'b0;  // Invalid, default to 0
        end
`endif
    endfunction : Decode_Manchester_Chips


    // Manchester encode function
    // 
    function automatic logic [1:0] Encode_Manchester_Symbol(input logic manchester_symbol);
        if (manchester_symbol == 1'b0) begin
            return MANCHESTER_0;  // '0' = 01
        end
        else begin
            return MANCHESTER_1;  // '1' = 10
        end
    endfunction : Encode_Manchester_Symbol


// ----------------------------------------------------------------------------
// Timing Constants (in clock cycles)
// ----------------------------------------------------------------------------



    // Clock period calculation
    localparam int unsigned CLK_PERIOD_NS = 1_000_000_000 / `MASTER_CLK_FREQ_HZ;

    // Manchester clock period calculation
    localparam int unsigned MAN_CLK_PERIOD_NS = 1_000_000_000 / `MANCHESTER_BIT_RATE_HZ;

    // Chip period calculation (half bit period)
    localparam int unsigned CHIP_PERIOD_NS = MAN_CLK_PERIOD_NS / 2;
    
    // Convert nanoseconds to clock cycles
    localparam int unsigned CYCLES_PER_CHIP       = CHIP_PERIOD_NS / CLK_PERIOD_NS;
    localparam int unsigned CYCLES_PER_HALF_CHIP  = CYCLES_PER_CHIP / 2;
    localparam int unsigned CYCLES_PER_SYMBOL     = CYCLES_PER_CHIP * 2;
    localparam int unsigned CYCLES_PER_SYNC       = CYCLES_PER_CHIP * 6;  // 3 chips per half-sync
    
    // Timing tolerance windows (in clock cycles)
    localparam int unsigned CYCLES_TOLERANCE_LATE  = `RX_CLOCK_TOLERANCE_LATE_NS  / CLK_PERIOD_NS;
    localparam int unsigned CYCLES_TOLERANCE_EARLY = `RX_CLOCK_TOLERANCE_EARLY_NS / CLK_PERIOD_NS;

    // Maximum timer durations
    // DWord-1 and CWord-0: SYNC (6 chips) + first data chip (1) + late tolerance
    localparam int unsigned CYCLES_TIMER_MAX = CYCLES_PER_SYNC 
                                             + CYCLES_PER_CHIP 
                                             + CYCLES_TOLERANCE_LATE;
    
    // Filter must allow one extra cycle for synchronization
    localparam int unsigned CYCLE_SYNC_BUFFER = 7;
    localparam int unsigned CYCLES_FILTER_MAX = CYCLES_TIMER_MAX + CYCLE_SYNC_BUFFER;
    
    // Counter bit widths
    localparam int unsigned TIMER_COUNTER_WIDTH = $clog2(CYCLES_TIMER_MAX + 1);

    // Waiting after last chip duration
    localparam int unsigned CYCLES_INTERMISION_WAIT = `RX_POST_MSG_POST_INTERMISSION_NS / CLK_PERIOD_NS;



`endif // __LIB_1553_SV__


endpackage : lib_1553

