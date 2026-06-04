"""

Copyright (c) 2026 Ethan Coyle

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

"""


import cocotb

import os
import random

from cocotb import simulator
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, Event, Timer

from cocotb_test.simulator import run

# ~ class SpiPeripheral:
    # ~ def __init__(self, dclk, copi, cipo, en):
        # ~ self.dclk = dclk
        # ~ self.copi = copi
        # ~ self.cipo = cipo
        # ~ self.en = en


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
    
    dut.i_prescale.value = 10
    dut.i_en_setup_time.value = 5
    dut.i_en_hold_time.value = 5
    dut.i_en_high_time.value = 5


    await Timer(100, unit='ns')
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    
    while (True):
        await RisingEdge(dut.i_clk)
        if (int(dut.m_axis_tvalid.value)):
            dut.s_axis_tdata.value = 0x44
            dut.i_spi_cipo.value = 0
            break
    
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
