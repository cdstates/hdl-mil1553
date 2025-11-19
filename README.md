# MIL-STD-1553 Transceiver - CocoTB Testing Experimentation

An experimental project exploring **cocotb-based verification** of SystemVerilog HDL modules for a MIL-STD-1553 Manchester-encoded transceiver implementation. This project combines modern Python-based testing methodologies with traditional FPGA development workflows targeting Xilinx Vivado.

## Project Overview

This repository contains SystemVerilog implementations of:
- **Manchester Receiver** - Digital PLL-based receiver with timing window filtering
- **Manchester Transmitter** - Protocol-compliant transceiver core
- **Filtering and Control Cores** - Edge detection, window filtering, timers, and synchronizers
- **Protocol Library** - MIL-STD-1553 definitions and data structures

The primary focus is on **testing SystemVerilog code using cocotb**, demonstrating how Python-based test benches can effectively verify complex HDL designs while maintaining compatibility with Vivado project workflows.

## Key Features

### Testing Framework
- **cocotb** verification environment for all major modules
- **Verilator** simulation backend for fast execution
- Python-based test utilities for Manchester encoding/decoding
- Comprehensive test coverage including edge cases and timing violations

### Hardware Implementation
- Parameterized Manchester receiver with configurable timing windows
- Digital PLL self-synchronization to incoming transitions
- Command/Data word detection and decoding
- Parity verification and error detection
- Valid/ready handshaking protocol

### Design Methodology
- SystemVerilog modules designed for both simulation and synthesis
- Vivado-compatible project structure
- Hierarchical module organization
- Reusable timing and filtering components

## Repository Structure

```
mil_adapter/
├── src/mylib/                    # SystemVerilog source files
│   ├── reciever.sv              # Main Manchester receiver
│   ├── transciever.sv           # Manchester transmitter
│   ├── reciever_prefix.sv       # Sync pattern detection
│   ├── reciever_data.sv         # Data decoding logic
│   ├── window_filter.sv         # Timing window validator
│   ├── edge_detector.sv         # Edge detection module
│   ├── timer.sv                 # Configurable timer
│   ├── up_counter.sv            # Up counter
│   ├── down_counter.sv          # Down counter
│   ├── signal_synchronizer.sv   # Clock domain crossing
│   ├── lib_1553.sv              # MIL-STD-1553 definitions
│   └── test/                    # Cocotb test benches
│       ├── tbc_reciever.py      # Receiver test suite
│       ├── tbc_reciever_prefix.py
│       ├── tbc_reciever_data.py
│       ├── tbc_edge_detector.py
│       ├── tbc_window_filter.py
│       ├── tbc_down_counter.py
│       └── test_tools.py        # Test utilities
├── vivado/                      # Vivado project files
│   └── mil1553/
└── sim_build/                   # Simulation build artifacts
```

## Getting Started

### Prerequisites

**For Testing (Linux/WSL recommended):**
```bash
# Install Verilator
sudo apt-get update
sudo apt-get install verilator

# Install Python dependencies
python3 -m venv venv
source venv/bin/activate
pip install cocotb cocotb-test
```

**For Synthesis:**
- Xilinx Vivado (tested with 2024.x)

### Running Tests

Navigate to the test directory and run individual test benches:

```bash
cd src/mylib/test
python tbc_reciever.py          # Test Manchester receiver
python tbc_window_filter.py     # Test timing window filter
python tbc_edge_detector.py     # Test edge detector
```

Test results are generated in `sim_build/` with waveform dumps (`.fst` files) for debugging.

### Viewing Waveforms

```bash
# Install GTKWave
sudo apt-get install gtkwave

# View simulation waveforms
gtkwave sim_build/dump.fst
```

## MIL-STD-1553 Protocol Basics

**Manchester Encoding:**
- Logic `1`: Low-to-High transition (chip pattern `01`)
- Logic `0`: High-to-Low transition (chip pattern `10`)
- Bit rate: 1 Mbps (typical)
- Symbol period: 1 µs (2 chips × 500 ns each)

**Word Structure:**
- 3-chip sync pattern (Command/Status or Data word identifier)
- 16 data bits (Manchester encoded)
- 1 parity bit (odd parity)

## Testing Philosophy

This project demonstrates:

1. **Python-First Testing** - Leverage Python's ecosystem for complex test scenarios
2. **Fast Iteration** - Verilator provides rapid simulation feedback
3. **Readable Tests** - cocotb's async/await syntax creates clear, maintainable tests
4. **Vivado Compatibility** - Design remains synthesizable and Vivado-friendly

### Example Test Structure

```python
@cocotb.test()
async def test_valid_command_word(dut):
    """Test reception of valid Command/Status word"""
    
    # Setup
    clock = Clock(dut.i_clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    
    # Generate Manchester-encoded test pattern
    chips = encode_manchester_word(0x1234, word_type="command")
    
    # Apply stimulus
    await send_manchester_chips(dut, chips)
    
    # Verify outputs
    assert dut.o_data_valid.value == 1
    assert dut.o_data_word.value == 0x1234
```

## Vivado Integration

SystemVerilog modules can be directly imported into Vivado projects:

1. Add source files from `src/mylib/` to your Vivado project
2. Set top module and configure synthesis settings
3. Run synthesis and implementation as normal

The cocotb tests serve as pre-synthesis verification, catching issues early in the design cycle.

## Current Status

### ✅ Completed
- Core receiver architecture
- Manchester decoding logic
- Timing window filtering
- Edge detection and synchronization
- Basic cocotb test infrastructure

### 🚧 In Progress
- Transmitter implementation
- Full protocol compliance testing
- Timing violation characterization
- Vivado synthesis validation

### 📋 Planned
- Bus controller logic
- Remote terminal functionality
- Multi-word message handling
- FPGA hardware testing

## Contributing

This is an experimental project for learning cocotb and HDL verification methodologies. Suggestions and improvements are welcome!

## License

This project is for educational and experimental purposes.

## References

- [MIL-STD-1553 Tutorial](https://www.milstd1553.com/)
- [cocotb Documentation](https://docs.cocotb.org/)
- [Verilator Documentation](https://verilator.org/)
- [Manchester Encoding](https://en.wikipedia.org/wiki/Manchester_code)

---

**Note:** This is an active learning project. Code structure and testing approaches may evolve as best practices are discovered.
