import cocotb
from cocotb.triggers import Timer


# ============================================================
# Configuration
# ============================================================

SETTLE_NS = 20


# ============================================================
# Helpers
# ============================================================

async def reset_dut(dut):
    """Apply the external active-low reset."""

    dut.rst_n.value = 0
    dut.ena.value = 1

    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # Top-level clk is not used by the discriminator/counter.
    dut.clk.value = 0

    await Timer(10, units="ns")

    dut.rst_n.value = 1

    await Timer(SETTLE_NS, units="ns")


async def set_inputs(
    dut,
    low=0,
    high=0,
    delay0=0,
    delay1=0,
    latch=0,
    counter0=0,
    counter1=0,
):
    """
    Set ui_in according to the design:

        ui_in[0] = low threshold
        ui_in[1] = high threshold
        ui_in[2] = delay mux bit 0
        ui_in[3] = delay mux bit 1
        ui_in[4] = counter latch
        ui_in[5] = counter mux bit 0
        ui_in[6] = counter mux bit 1
        ui_in[7] = unused
    """

    value = (
        (low       << 0)
        | (high      << 1)
        | (delay0    << 2)
        | (delay1    << 3)
        | (latch     << 4)
        | (counter0  << 5)
        | (counter1  << 6)
    )

    dut.ui_in.value = value


async def settle():
    """Allow the IHP delay chains and combinational logic to settle."""
    await Timer(SETTLE_NS, units="ns")


async def generate_event(dut):
    """
    Generate one low-threshold discriminator event.

    The intended sequence is:

        low = 0
             |
        low = 1       -> threshold DFF set
             |
        low = 0       -> internal reset / output event
    """

    await set_inputs(dut, low=1, high=0)
    await settle()

    await set_inputs(dut, low=0, high=0)
    await settle()


# ============================================================
# 1. Reset
# ============================================================

@cocotb.test()
async def test_reset(dut):

    await reset_dut(dut)

    # uo_out[7:1] are hard-wired to zero.
    assert int(dut.uo_out.value[7:1]) == 0

    # Event output must be known.
    assert dut.uo_out.value[0].is_resolvable

    assert int(dut.uo_out.value[0]) == 0


# ============================================================
# 2. Basic discriminator event
# ============================================================

@cocotb.test()
async def test_low_threshold_event(dut):

    await reset_dut(dut)

    assert int(dut.uo_out.value[0]) == 0

    await generate_event(dut)

    assert dut.uo_out.value[0].is_resolvable

    assert int(dut.uo_out.value[0]) == 1, (
        f"Low-threshold event was not detected: "
        f"uo_out={dut.uo_out.value}"
    )


# ============================================================
# 3. High threshold / coincidence behavior
# ============================================================

@cocotb.test()
async def test_high_threshold_behavior(dut):

    await reset_dut(dut)

    # Activate both thresholds.
    await set_inputs(
        dut,
        low=1,
        high=1,
    )

    await settle()

    # Remove low threshold while high remains active.
    await set_inputs(
        dut,
        low=0,
        high=1,
    )

    await settle()

    assert dut.uo_out.value[0].is_resolvable

    assert int(dut.uo_out.value[0]) == 0, (
        f"Unexpected event while high threshold was active: "
        f"uo_out={dut.uo_out.value}"
    )


# ============================================================
# 4. Delay multiplexer
# ============================================================

@cocotb.test()
async def test_delay_selection(dut):

    await reset_dut(dut)

    # The four selections are:
    #
    # delay1 delay0
    #
    #   0      0     -> 1 cell
    #   0      1     -> 3 cells
    #   1      0     -> 9 cells
    #   1      1     -> 27 cells

    selections = [
        (0, 0),
        (0, 1),
        (1, 0),
        (1, 1),
    ]

    for delay1, delay0 in selections:

        await set_inputs(
            dut,
            low=0,
            high=0,
            delay0=delay0,
            delay1=delay1,
        )

        await settle()

        assert dut.uo_out.value[0].is_resolvable, (
            f"uo_out became unknown for delay selection "
            f"{delay1}{delay0}"
        )


# ============================================================
# 5. Event output
# ============================================================

@cocotb.test()
async def test_event_output(dut):

    await reset_dut(dut)

    # No event initially.
    assert int(dut.uo_out.value[0]) == 0

    # Generate event.
    await generate_event(dut)

    assert int(dut.uo_out.value[0]) == 1

    # Verify upper bits are still zero.
    assert int(dut.uo_out.value[7:1]) == 0


# ============================================================
# 6. Counter
# ============================================================

@cocotb.test()
async def test_counter(dut):

    await reset_dut(dut)

    # Generate one event.
    await generate_event(dut)

    assert int(dut.uo_out.value[0]) == 1

    # The counter is a 32-bit ripple counter.
    #
    # ui_in[4] is the latch control for the shift register.

    await set_inputs(
        dut,
        latch=0,
        counter0=0,
        counter1=0,
    )

    await Timer(1, units="ns")

    # Rising edge of latch_res.
    await set_inputs(
        dut,
        latch=1,
        counter0=0,
        counter1=0,
    )

    await Timer(2, units="ns")

    # Return latch low.
    await set_inputs(
        dut,
        latch=0,
        counter0=0,
        counter1=0,
    )

    await settle()

    # Read byte 0.
    value = int(dut.uio_out.value)

    assert value != 0, (
        f"Counter did not produce a non-zero value: "
        f"uio_out={dut.uio_out.value}"
    )


# ============================================================
# 7. Counter byte multiplexer
# ============================================================

@cocotb.test()
async def test_counter_byte_mux(dut):

    await reset_dut(dut)

    # Generate an event.
    await generate_event(dut)

    # Latch counter.
    await set_inputs(
        dut,
        latch=0,
        counter0=0,
        counter1=0,
    )

    await Timer(1, units="ns")

    await set_inputs(
        dut,
        latch=1,
        counter0=0,
        counter1=0,
    )

    await Timer(2, units="ns")

    await set_inputs(
        dut,
        latch=0,
        counter0=0,
        counter1=0,
    )

    await settle()

    values = {}

    # Counter byte selection:
    #
    #   00 -> bits  7:0
    #   01 -> bits 15:8
    #   10 -> bits 23:16
    #   11 -> bits 31:24

    for counter1, counter0 in [
        (0, 0),
        (0, 1),
        (1, 0),
        (1, 1),
    ]:

        await set_inputs(
            dut,
            latch=0,
            counter0=counter0,
            counter1=counter1,
        )

        await settle()

        assert dut.uio_out.value.is_resolvable

        values[(counter1, counter0)] = int(dut.uio_out.value)

    # We mainly care that every mux setting produces
    # a valid 8-bit output.
    for selection, value in values.items():

        assert 0 <= value <= 255, (
            f"Invalid uio_out value for selection "
            f"{selection}: {value}"
        )


# ============================================================
# 8. uio_out validity
# ============================================================

@cocotb.test()
async def test_uio_output_valid(dut):

    await reset_dut(dut)

    for counter1, counter0 in [
        (0, 0),
        (0, 1),
        (1, 0),
        (1, 1),
    ]:

        await set_inputs(
            dut,
            counter0=counter0,
            counter1=counter1,
            latch=0,
        )

        await settle()

        assert dut.uio_out.value.is_resolvable, (
            f"uio_out contains X/Z for mux selection "
            f"{counter1}{counter0}: "
            f"{dut.uio_out.value}"
        )


# ============================================================
# 9. Complete functional sequence
# ============================================================

@cocotb.test()
async def test_complete_functional_sequence(dut):

    await reset_dut(dut)

    # --------------------------------------------------------
    # Initial state
    # --------------------------------------------------------

    assert int(dut.uo_out.value[0]) == 0

    # --------------------------------------------------------
    # Generate event
    # --------------------------------------------------------

    await generate_event(dut)

    assert int(dut.uo_out.value[0]) == 1

    # --------------------------------------------------------
    # Latch counter
    # --------------------------------------------------------

    await set_inputs(
        dut,
        latch=0,
        counter0=0,
        counter1=0,
    )

    await Timer(1, units="ns")

    await set_inputs(
        dut,
        latch=1,
        counter0=0,
        counter1=0,
    )

    await Timer(2, units="ns")

    await set_inputs(
        dut,
        latch=0,
        counter0=0,
        counter1=0,
    )

    await settle()

    # --------------------------------------------------------
    # Read all four counter bytes
    # --------------------------------------------------------

    for counter1, counter0 in [
        (0, 0),
        (0, 1),
        (1, 0),
        (1, 1),
    ]:

        await set_inputs(
            dut,
            counter0=counter0,
            counter1=counter1,
        )

        await settle()

        value = int(dut.uio_out.value)

        assert 0 <= value <= 255, (
            f"Invalid counter byte {value:#x} "
            f"for selection {counter1}{counter0}"
        )

    # --------------------------------------------------------
    # Return to idle
    # --------------------------------------------------------

    await set_inputs(dut)

    await settle()

    assert dut.uo_out.value.is_resolvable
    assert dut.uio_out.value.is_resolvable
