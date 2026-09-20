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

async def latch_counter(dut):
    """
    Capture the current 32-bit counter value into the shift register.

    All waits are long enough for the physical cell-level simulation
    to settle; this is intentionally not a zero-delay RTL test.
    """

    # Ensure latch is low before creating the rising edge.
    await set_inputs(
        dut,
        low=0,
        high=0,
        latch=0,
        counter0=0,
        counter1=0,
    )
    await settle()

    # Rising edge of latch.
    await set_inputs(
        dut,
        low=0,
        high=0,
        latch=1,
        counter0=0,
        counter1=0,
    )
    await settle()

    # Return latch low.
    await set_inputs(
        dut,
        low=0,
        high=0,
        latch=0,
        counter0=0,
        counter1=0,
    )
    await settle()


async def read_counter_byte(dut, byte):
    """
    Read one byte of the latched 32-bit counter.

    byte 0 = bits 7:0
    byte 1 = bits 15:8
    byte 2 = bits 23:16
    byte 3 = bits 31:24
    """

    assert 0 <= byte <= 3

    counter0 = byte & 1
    counter1 = (byte >> 1) & 1

    await set_inputs(
        dut,
        low=0,
        high=0,
        latch=0,
        counter0=counter0,
        counter1=counter1,
    )
    await settle()

    assert dut.uio_out.value.is_resolvable

    return int(dut.uio_out.value)


async def read_counter(dut):
    """Read all four bytes and reconstruct the 32-bit value."""

    value = 0

    for byte in range(4):
        value |= await read_counter_byte(dut, byte) << (8 * byte)

    return value


async def generate_counter_event(dut):
    """
    Generate one candidate discriminator event.

    Whether this produces exactly one counter increment should
    be established from the waveform/RTL behavior.
    """

    await set_inputs(
        dut,
        low=0,
        high=0,
        latch=0,
        counter0=0,
        counter1=0,
    )
    await settle()

    await set_inputs(
        dut,
        low=1,
        high=0,
        latch=0,
        counter0=0,
        counter1=0,
    )
    await settle()

    await set_inputs(
        dut,
        low=0,
        high=0,
        latch=0,
        counter0=0,
        counter1=0,
    )
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
        low=1,
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

    # Start from the known idle state.
    await set_inputs(
        dut,
        low=0,
        high=0,
        delay0=0,
        delay1=0,
    )

    await settle()

    assert int(dut.uo_out.value[0]) == 0, (
        f"Output is not idle after reset: "
        f"uo_out={dut.uo_out.value}"
    )

    # Apply a low-threshold pulse.
    await set_inputs(
        dut,
        low=1,
        high=0,
        delay0=0,
        delay1=0,
    )

    await settle()

    # Remove the low threshold.
    await set_inputs(
        dut,
        low=0,
        high=0,
        delay0=0,
        delay1=0,
    )

    await settle()

    # For now, verify that the discriminator output is
    # deterministic rather than assuming the pulse must
    # generate an event.
    assert dut.uo_out.value[0].is_resolvable, (
        f"Discriminator output became unknown: "
        f"uo_out={dut.uo_out.value}"
    )

    dut._log.info(
        "Discriminator output after low pulse = %d",
        int(dut.uo_out.value[0]),
    )

# ============================================================
# TEST 6
# Counter functionality
# ============================================================

@cocotb.test()
async def test_counter(dut):

    await reset_dut(dut)

    # --------------------------------------------------------
    # Counter should start at zero.
    # --------------------------------------------------------

    await latch_counter(dut)

    value = await read_counter(dut)

    dut._log.info(
        "Counter after reset = 0x%08x",
        value,
    )

    assert value == 0, (
        f"Counter did not reset to zero: "
        f"0x{value:08x}"
    )

    # --------------------------------------------------------
    # Generate several events and verify counting.
    # --------------------------------------------------------

    for expected in range(1, 6):

        await generate_counter_event(dut)

        # The counter is a ripple counter, so give all stages
        # time to propagate before latching.
        await latch_counter(dut)

        value = await read_counter(dut)

        dut._log.info(
            "After event %d: counter = 0x%08x",
            expected,
            value,
        )

        assert value == expected, (
            f"Expected counter={expected}, "
            f"got 0x{value:08x}"
        )
# ============================================================
# TEST 7
# Counter byte multiplexer
# ============================================================

@cocotb.test()
async def test_counter_byte_mux(dut):

    await reset_dut(dut)

    # Generate one counter event.
    await generate_counter_event(dut)

    await latch_counter(dut)

    # Read the four bytes.
    byte0 = await read_counter_byte(dut, 0)
    byte1 = await read_counter_byte(dut, 1)
    byte2 = await read_counter_byte(dut, 2)
    byte3 = await read_counter_byte(dut, 3)

    dut._log.info(
        "Counter bytes: "
        "B3=%02x B2=%02x B1=%02x B0=%02x",
        byte3,
        byte2,
        byte1,
        byte0,
    )

    # Assuming one discriminator event increments the counter once.
    assert byte0 == 0x01
    assert byte1 == 0x00
    assert byte2 == 0x00
    assert byte3 == 0x00

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

# ============================================================
# TEST 10
# Counter reset after counting
# ============================================================

@cocotb.test()
async def test_counter_reset(dut):

    await reset_dut(dut)

    # Build up a non-zero count.
    for _ in range(3):
        await generate_counter_event(dut)

    await latch_counter(dut)

    before_reset = await read_counter(dut)

    dut._log.info(
        "Counter before second reset = 0x%08x",
        before_reset,
    )

    assert before_reset != 0, (
        "Counter never became non-zero"
    )

    # --------------------------------------------------------
    # Apply external reset.
    # --------------------------------------------------------

    dut.rst_n.value = 0
    await Timer(10, units="ns")

    dut.rst_n.value = 1
    await settle()

    # Capture counter after reset.
    await latch_counter(dut)

    after_reset = await read_counter(dut)

    dut._log.info(
        "Counter after second reset = 0x%08x",
        after_reset,
    )

    assert after_reset == 0, (
        f"Counter did not reset: "
        f"0x{after_reset:08x}"
    )
# ============================================================
# TEST 11
# Counter byte mux integration
# ============================================================

@cocotb.test()
async def test_counter_byte_mux(dut):
    await reset_dut(dut)

    # Generate exactly one counter event.
    await generate_counter_event(dut)

    # Capture the counter value into the shift register.
    await latch_counter(dut)

    # The waveform shows the counter transitioning 0 -> 1.
    expected = 0x00000001

    # Check the complete latched value first.
    actual = await read_counter(dut)
    dut._log.info(
        "Latched counter: expected=0x%08x actual=0x%08x",
        expected,
        actual,
    )
    assert actual == expected, (
        f"Latched counter mismatch: "
        f"expected 0x{expected:08x}, got 0x{actual:08x}"
    )

    # Now test each byte-selection combination.
    expected_bytes = [0x01, 0x00, 0x00, 0x00]

    for byte in range(4):
        actual_byte = await read_counter_byte(dut, byte)

        dut._log.info(
            "Counter byte %d: expected=0x%02x actual=0x%02x",
            byte,
            expected_bytes[byte],
            actual_byte,
        )

        assert actual_byte == expected_bytes[byte], (
            f"Counter byte {byte} mismatch: "
            f"expected 0x{expected_bytes[byte]:02x}, "
            f"got 0x{actual_byte:02x}"
        )
