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
    """Apply external active-low reset."""

    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
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
    ui_in assignment:

        bit 0 = low threshold
        bit 1 = high threshold
        bit 2 = delay select 0
        bit 3 = delay select 1
        bit 4 = counter latch
        bit 5 = counter select 0
        bit 6 = counter select 1
        bit 7 = unused
    """

    value = (
        (low << 0)
        | (high << 1)
        | (delay0 << 2)
        | (delay1 << 3)
        | (latch << 4)
        | (counter0 << 5)
        | (counter1 << 6)
    )

    dut.ui_in.value = value


async def settle():
    await Timer(SETTLE_NS, units="ns")


async def generate_low_transition(dut):
    """
    Apply a complete low-threshold pulse.

    This helper deliberately does not assume that the pulse
    necessarily produces an event. The individual tests decide
    what should happen.
    """

    await set_inputs(dut, low=0, high=0)
    await settle()

    await set_inputs(dut, low=1, high=0)
    await settle()

    await set_inputs(dut, low=0, high=0)
    await settle()


# ============================================================
# TEST 1
# Reset
# ============================================================

@cocotb.test()
async def test_reset(dut):

    await reset_dut(dut)

    assert dut.uo_out.value.is_resolvable

    # Event output should be inactive after reset.
    assert int(dut.uo_out.value[0]) == 0, (
        f"Unexpected output after reset: "
        f"uo_out={dut.uo_out.value}"
    )

    # Upper seven bits are tied low.
    assert int(dut.uo_out.value[7:1]) == 0, (
        f"Upper uo_out bits are not zero: "
        f"uo_out={dut.uo_out.value}"
    )


# ============================================================
# TEST 2
# Observe low-threshold transition
# ============================================================

@cocotb.test()
async def test_low_threshold_transition(dut):

    await reset_dut(dut)

    # Idle state.
    await set_inputs(
        dut,
        low=0,
        high=0,
    )

    await settle()

    assert int(dut.uo_out.value[0]) == 0

    # --------------------------------------------------------
    # Drive low threshold HIGH.
    # --------------------------------------------------------

    await set_inputs(
        dut,
        low=1,
        high=0,
    )

    await Timer(1, units="ns")

    dut._log.info(
        "low threshold HIGH: ui_in=%s uo_out=%s",
        dut.ui_in.value,
        dut.uo_out.value,
    )

    await settle()

    # --------------------------------------------------------
    # Drive low threshold LOW.
    # --------------------------------------------------------

    await set_inputs(
        dut,
        low=0,
        high=0,
    )

    await Timer(1, units="ns")

    dut._log.info(
        "low threshold LOW: ui_in=%s uo_out=%s",
        dut.ui_in.value,
        dut.uo_out.value,
    )

    await settle()

    dut._log.info(
        "after settling: uo_out=%s",
        dut.uo_out.value,
    )

    # We don't yet assert an event here.
    #
    # This test establishes that the complete input transition
    # can be simulated without producing X/Z.
    assert dut.uo_out.value.is_resolvable


# ============================================================
# TEST 3
# High-threshold behavior
# ============================================================

@cocotb.test()
async def test_high_threshold_behavior(dut):

    await reset_dut(dut)

    # Both thresholds inactive.
    await set_inputs(
        dut,
        low=0,
        high=0,
    )

    await settle()

    assert int(dut.uo_out.value[0]) == 0

    # Activate high threshold.
    await set_inputs(
        dut,
        low=0,
        high=1,
    )

    await settle()

    # Return high threshold low.
    await set_inputs(
        dut,
        low=0,
        high=0,
    )

    await settle()

    assert dut.uo_out.value.is_resolvable

    # A high-only transition must not create the low-threshold
    # event expected by the normal discriminator test.
    assert int(dut.uo_out.value[0]) == 0, (
        f"Unexpected event from high threshold: "
        f"uo_out={dut.uo_out.value}"
    )


# ============================================================
# TEST 4
# Delay mux
# ============================================================

@cocotb.test()
async def test_delay_selection(dut):

    await reset_dut(dut)

    # 00 -> 1 delay cell
    # 01 -> 3 delay cells
    # 10 -> 9 delay cells
    # 11 -> 27 delay cells

    for delay1, delay0 in [
        (0, 0),
        (0, 1),
        (1, 0),
        (1, 1),
    ]:

        await set_inputs(
            dut,
            low=0,
            high=0,
            delay0=delay0,
            delay1=delay1,
        )

        await settle()

        dut._log.info(
            "delay selection %d%d -> uo_out=%s",
            delay1,
            delay0,
            dut.uo_out.value,
        )

        assert dut.uo_out.value.is_resolvable, (
            f"uo_out became unknown with delay "
            f"selection {delay1}{delay0}"
        )


# ============================================================
# TEST 5
# Event output sanity
# ============================================================

@cocotb.test()
async def test_event_output(dut):

    await reset_dut(dut)

    # Start inactive.
    await set_inputs(
        dut,
        low=0,
        high=0,
    )

    await settle()

    assert int(dut.uo_out.value[0]) == 0

    # Apply low-threshold transition.
    await generate_low_transition(dut)

    # At this point we only require a known output.
    #
    # This intentionally does NOT assume that the transition
    # produces an event until the discriminator timing has
    # been confirmed.
    assert dut.uo_out.value[0].is_resolvable

    dut._log.info(
        "event output after low transition = %d",
        int(dut.uo_out.value[0]),
    )


# ============================================================
# TEST 6
# Counter/latch output
# ============================================================

@cocotb.test()
async def test_counter(dut):

    await reset_dut(dut)

    # First make sure the output interface is initialized.
    await set_inputs(
        dut,
        latch=0,
        counter0=0,
        counter1=0,
    )

    await settle()

    assert dut.uio_out.value.is_resolvable

    # --------------------------------------------------------
    # Latch current counter state.
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

    assert dut.uio_out.value.is_resolvable

    dut._log.info(
        "latched counter byte 0 = 0x%02x",
        int(dut.uio_out.value),
    )


# ============================================================
# TEST 7
# Counter byte multiplexer
# ============================================================

@cocotb.test()
async def test_counter_byte_mux(dut):

    await reset_dut(dut)

    values = {}

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

        assert dut.uio_out.value.is_resolvable

        value = int(dut.uio_out.value)

        values[(counter1, counter0)] = value

        dut._log.info(
            "counter mux %d%d -> 0x%02x",
            counter1,
            counter0,
            value,
        )

        assert 0 <= value <= 255


# ============================================================
# TEST 8
# uio output validity
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
            f"uio_out is unknown for mux "
            f"{counter1}{counter0}: "
            f"{dut.uio_out.value}"
        )


# ============================================================
# TEST 9
# Complete interface sanity
# ============================================================

@cocotb.test()
async def test_complete_interface(dut):

    await reset_dut(dut)

    # Initial state.
    await set_inputs(dut)

    await settle()

    assert dut.uo_out.value.is_resolvable
    assert dut.uio_out.value.is_resolvable

    # Exercise threshold inputs.
    await set_inputs(
        dut,
        low=1,
        high=0,
    )

    await settle()

    await set_inputs(
        dut,
        low=0,
        high=0,
    )

    await settle()

    # Exercise delay mux.
    await set_inputs(
        dut,
        delay0=1,
        delay1=1,
    )

    await settle()

    # Exercise counter mux.
    await set_inputs(
        dut,
        counter0=1,
        counter1=1,
    )

    await settle()

    assert dut.uo_out.value.is_resolvable
    assert dut.uio_out.value.is_resolvable

    # Return to idle.
    await set_inputs(dut)

    await settle()

    assert dut.uo_out.value.is_resolvable
    assert dut.uio_out.value.is_resolvable

@cocotb.test()
async def test_discriminator_debug(dut):

    await reset_dut(dut)

    # Start idle
    await set_inputs(dut, low=0, high=0)
    await settle()

    dut._log.info("=== IDLE ===")
    dut._log.info("ui_in   = %s", dut.ui_in.value)
    dut._log.info("uo_out  = %s", dut.uo_out.value)

    # --------------------------------------------------------
    # LOW threshold rising
    # --------------------------------------------------------

    await set_inputs(dut, low=1, high=0)

    await Timer(0.5, units="ns")

    dut._log.info("=== LOW HIGH, +0.5 ns ===")
    dut._log.info("uo_out = %s", dut.uo_out.value)

    await Timer(2, units="ns")

    dut._log.info("=== LOW HIGH, +2.5 ns ===")
    dut._log.info("uo_out = %s", dut.uo_out.value)

    await Timer(5, units="ns")

    dut._log.info("=== LOW HIGH, +7.5 ns ===")
    dut._log.info("uo_out = %s", dut.uo_out.value)

    await Timer(10, units="ns")

    dut._log.info("=== LOW HIGH, +17.5 ns ===")
    dut._log.info("uo_out = %s", dut.uo_out.value)

    # --------------------------------------------------------
    # LOW threshold falling
    # --------------------------------------------------------

    await set_inputs(dut, low=0, high=0)

    await Timer(0.5, units="ns")

    dut._log.info("=== LOW LOW, +0.5 ns ===")
    dut._log.info("uo_out = %s", dut.uo_out.value)

    await Timer(2, units="ns")

    dut._log.info("=== LOW LOW, +2.5 ns ===")
    dut._log.info("uo_out = %s", dut.uo_out.value)

    await Timer(5, units="ns")

    dut._log.info("=== LOW LOW, +7.5 ns ===")
    dut._log.info("uo_out = %s", dut.uo_out.value)

    await Timer(10, units="ns")

    dut._log.info("=== LOW LOW, +17.5 ns ===")
    dut._log.info("uo_out = %s", dut.uo_out.value)

    assert dut.uo_out.value.is_resolvable
