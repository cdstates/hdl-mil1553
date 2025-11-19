import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb_tools.runner import get_runner
import os


class DutWrapper:
	"""Wrapper class for the DUT to facilitate signal access"""
	def __init__(self, dut):
		self.dut = dut

	def Set_Signal(self, value):
		self.dut.i_signal.value = value
	
	def Get_Rising_Edge(self):
		return self.dut.o_rising_edge.value
	
	def Get_Falling_Edge(self):
		return self.dut.o_falling_edge.value
	
	def Get_Edge_Detected(self):
		return self.dut.o_edge_detected.value
	

@cocotb.test()
async def edge_detector_test(dut):
	"""Test edge_detector module"""
	
	# Create a 10ns period clock (100MHz)
	clock = Clock(dut.i_clk, 10, "ns")
	clock.start(start_high=False)
	await RisingEdge(dut.i_clk)
	
	dut._log.info("Starting edge_detector test")

	d = DutWrapper(dut)
	
	# Force repeated low signals
	for _ in range(5):
		d.Set_Signal(0)
		await RisingEdge(dut.i_clk)
		await RisingEdge(dut.i_clk)

	# Check that no edges are detected
	assert d.Get_Rising_Edge() == 0, "Rising edge should be detected"
	assert d.Get_Falling_Edge() == 0, "Falling edge should be 0"
	assert d.Get_Edge_Detected() == 0, "Edge detected output should be 1"

	# Test rising edge detection
	d.Set_Signal(1)
	await RisingEdge(dut.i_clk)
	await RisingEdge(dut.i_clk)

	assert d.Get_Rising_Edge() == 1, "Rising edge should be detected"
	assert d.Get_Falling_Edge() == 0, "Falling edge should be 0"
	assert d.Get_Edge_Detected() == 1, "Edge detected output should be 1"

	# Test repeated high signals do not cause multiple detections
	for _ in range(5):
		d.Set_Signal(1)
		await RisingEdge(dut.i_clk)
		await RisingEdge(dut.i_clk)
		assert d.Get_Rising_Edge() == 0, "Rising edge should be 0"
		assert d.Get_Falling_Edge() == 0, "Falling edge should be 0"
		assert d.Get_Edge_Detected() == 0, "Edge detected output should be 0"

	# Test falling edge detection
	d.Set_Signal(0)
	await RisingEdge(dut.i_clk)
	await RisingEdge(dut.i_clk)
	assert d.Get_Rising_Edge() == 0, "Rising edge should be 0"
	assert d.Get_Falling_Edge() == 1, "Falling edge should be detected"
	assert d.Get_Edge_Detected() == 1, "Edge detected output should be 1"

	# Test repeated low signals do not cause multiple detections
	for _ in range(5):
		d.Set_Signal(0)
		await RisingEdge(dut.i_clk)
		await RisingEdge(dut.i_clk)
		assert d.Get_Rising_Edge() == 0, "Rising edge should be 0"
		assert d.Get_Falling_Edge() == 0, "Falling edge should be 0"
		assert d.Get_Edge_Detected() == 0, "Edge detected output should be 0"


def test_edge_detector_runner():
    """Runner function for pytest"""
    sim = "verilator"
    proj_path = "/home/cody/workspace/mil_adapter"
    print(f"Project Path: {proj_path}")
    
    # Enable waveform tracing
    os.environ["TRACES"] = "1"
    
    runner = get_runner(sim)
    runner.build(
        sources=[f"{proj_path}/src/mylib/edge_detector.sv"],
        hdl_toplevel="edge_detector",
        always=True,
        waves=True,
        build_args=["--trace-fst", "--trace-structs"]
    )
    
    runner.test(
        hdl_toplevel="edge_detector",
        test_module="tbc_edge_detector",
    )


if __name__ == "__main__":
    test_edge_detector_runner()