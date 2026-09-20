# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer


async def reset_dut(dut):
    """Reset the design to a known state."""

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    # Clock is not actually used by the current discriminator logic,
    # but keep it running because it is part of the Tiny Tapeout interface.
    await Timer(100, unit="ns")

    dut.rst_n.value = 1

    # Allow the reset to propagate through the standard cells.
    await Timer(10, unit="ns")


@cocotb.test()
async def test_low_without_high(dut):
    """
    ui_in[0] goes high and ui_in[1] remains low.

    Expected:
        When ui_in[0] goes low again, the discriminator output
        should become 1.
    """

    dut._log.info("Test: low threshold triggered without high threshold")

    # Start the Tiny Tapeout clock.
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())

    await reset_dut(dut)

    # ---------------------------------------------------------
    # Detection window starts:
    #
    # ui_in[0] = 1
    # ui_in[1] = 0
    # ---------------------------------------------------------

    dut._log.info("Raising ui_in[0]")

    # ui_in[3:2] = 00 -> shortest delay path
    # ui_in[1]   = 0
    # ui_in[0]   = 1
    dut.ui_in.value = 0b00000001

    # Wait for the low-threshold delay gate and DFF to react.
    await Timer(10, unit="ns")

    # Make absolutely sure ui_in[1] never became high.
    assert int(dut.ui_in.value) & 0b00000010 == 0

    # ---------------------------------------------------------
    # End detection window:
    #
    # ui_in[0] goes from 1 -> 0.
    #
    # This falling edge causes internal_rst_n to transition
    # and clocks dff_output.
    # ---------------------------------------------------------

    dut._log.info("Falling ui_in[0]")

    dut.ui_in.value = 0b00000000

    # Allow:
    #   ui_in[0] -> internal_rst
    #             -> internal_rst_n
    #             -> dff_output
    #
    # to propagate through the standard cells.
    await Timer(10, unit="ns")

    dut._log.info(f"uo_out = {dut.uo_out.value}")

    # Only bit 0 is used by your current RTL.
    assert dut.uo_out.value == 1, (
        f"Expected uo_out = 1 after ui_in[0] falling edge, "
        f"got {dut.uo_out.value}"
    )


@cocotb.test()
async def test_high_during_window(dut):
    """
    ui_in[0] goes high, but ui_in[1] also goes high before
    ui_in[0] goes low.

    Expected:
        The coincidence/rejection logic should prevent the
        output from becoming 1.
    """

    dut._log.info("Test: high threshold occurs during detection window")

    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())

    await reset_dut(dut)

    # Start detection window.
    dut._log.info("Raising ui_in[0]")

    dut.ui_in.value = 0b00000001

    await Timer(10, unit="ns")

    # Trigger high threshold while ui_in[0] is still high.
    dut._log.info("Raising ui_in[1]")

    dut.ui_in.value = 0b00000011

    await Timer(10, unit="ns")

    # End detection window by falling ui_in[0].
    dut._log.info("Falling ui_in[0]")

    dut.ui_in.value = 0b00000010

    await Timer(10, unit="ns")

    dut._log.info(f"uo_out = {dut.uo_out.value}")

    # Since ui_in[1] was triggered during the window,
    # coincidence_cont_q should not indicate a valid event.
    assert dut.uo_out.value == 0, (
        f"Expected uo_out = 0 when ui_in[1] triggers during "
        f"the ui_in[0] window, got {dut.uo_out.value}"
    )
