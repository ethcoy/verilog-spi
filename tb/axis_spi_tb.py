import cocotb

import os
import random

from cocotb import simulator
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Event, Timer

from cocotb_test.simulator import run

@cocotb.test()
async def axis_spi(dut):
    dut.i_rst.value = 0
    dut.i_clk.value = 0
    
    dut.s_axis_tdata.value = 0x81
    dut.s_axis_tvalid.value = 1
    
    dut.m_axis_tready.value = 1
    
    dut.i_spi_cipo.value = 1
    
    dut.i_clk_polarity.value = 1
    dut.i_clk_phase.value = 1
    
    dut.i_prescale.value = 4
    
    await Timer(100, unit='ns')
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    await Timer(2000, unit='ns')

parameters = {}
parameters['c_DATA_WIDTH'] = 8

if __name__ == "__main__":
	run(verilog_sources = [
            './../rtl/axis_spi.v',
        ],
        includes = [
        ],
        toplevel = "axis_spi",
        module = "axis_spi_tb",
        parameters = parameters,
        sim_build = "sim_build/",
        timescale = "1ns/1ps",
        force_compile = True,
        seed = int(0),
        waves = 1,
    )
