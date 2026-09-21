# Cocotb Testbench

This directory contains the cocotb testbench for the signal discriminator.

The testbench is designed for both functional verification and timing-aware simulation using the IHP SG13G2 standard-cell models.

## Test Philosophy

The design contains physical standard-cell delays and a 32-bit ripple counter. Therefore, the testbench does **not** assume zero-delay behavior.

A common settling time is used throughout the tests:

```python
SETTLE_NS = 20
```

After changing an input, the testbench normally waits for this period before sampling an output.

The delay is particularly important for the ripple counter, where a carry may need to propagate through multiple flip-flop stages before the final output is stable.

## Test Helpers

The testbench provides several helper functions to keep the individual tests simple.

### `reset_dut(dut)`

Resets the complete design and initializes the input signals.

```python
await reset_dut(dut)
```

### `set_inputs(...)`

Sets the individual `ui_in` control bits:

```python
await set_inputs(
    dut,
    low=0,
    high=0,
    delay0=0,
    delay1=0,
    latch=0,
    counter0=0,
    counter1=0,
)
```

### `generate_counter_event(dut)`

Generates a low-threshold transition that produces one counter event.

```python
await generate_counter_event(dut)
```

This is intentionally done through the normal discriminator logic instead of directly manipulating the counter.

### `latch_counter(dut)`

Captures the current counter value into the shift register.

```python
await latch_counter(dut)
```

### `read_counter_byte(dut, byte)`

Reads one of the four latched counter bytes.

```python
value = await read_counter_byte(dut, 0)
```

### `read_counter(dut)`

Reads all four bytes and reconstructs the complete 32-bit counter value.

```python
value = await read_counter(dut)
```

## Test Coverage

The testbench currently covers the following areas.

### Reset

Verifies that the design outputs are deterministic after reset and that the counter starts at zero.

### Threshold transitions

Tests the low and high threshold inputs independently and verifies that the resulting outputs are stable and resolvable.

### Delay selection

Exercises all four combinations of the delay-selection inputs.

### Counter functionality

Generates counter events and verifies that the counter increments correctly.

For example:

```text
0 → 1 → 2 → 3 → ...
```

### Counter latch and readout

The counter is latched and then read back through the four-byte output multiplexer.

The testbench verifies both the complete 32-bit value and the individual bytes.

For example:

```text
Counter = 0x00000001

byte 0 = 0x01
byte 1 = 0x00
byte 2 = 0x00
byte 3 = 0x00
```

### Counter reset

The counter is allowed to accumulate events, then reset is asserted and the test verifies that the counter returns to zero.

### Ripple-counter carry boundaries

The counter is tested using the real event-generation path rather than directly forcing internal counter bits.

The current slow carry test exercises the lower 17 bits and verifies important carry transitions:

```text
0x000000FE → 0x000000FF
0x000000FF → 0x00000100

0x0000FFFE → 0x0000FFFF
0x0000FFFF → 0x00010000
0x00010000 → 0x00010001
```

This is deliberately a slow test. The counter must actually receive every event between the boundary values, allowing the physical ripple chain to operate normally.

## Timing Considerations

Avoid using very short arbitrary delays as general-purpose settling delays.

For example, this should not normally be used as a replacement for the standard settling time:

```python
await Timer(1, units="ns")
```

Short delays are useful when intentionally investigating propagation behavior, but the normal functional tests should allow the standard-cell model enough time to settle.

The dedicated debug test may intentionally sample the design at several points in time to observe physical propagation.

## Running the Tests

Run the cocotb testbench using the project's configured simulator/Makefile:

```bash
make
```

Individual tests can also be selected using the cocotb test-selection mechanism supported by the project's simulator configuration.

## Adding New Tests

When adding a test:

1. Reset the DUT at the beginning.
2. Change inputs through the existing helper functions where possible.
3. Allow sufficient settling time after input changes.
4. Avoid accessing internal implementation details unless the test specifically targets them.
5. Prefer testing the complete physical signal path.
6. Use explicit assertions with useful expected/actual values.

For example:

```python
assert actual == expected, (
    f"Expected 0x{expected:08x}, got 0x{actual:08x}"
)
```

This makes gate-level simulation failures significantly easier to diagnose.
