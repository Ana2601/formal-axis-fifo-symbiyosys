# Formal Verification of an AXI-Stream FIFO (SVA + SymbiYosys)

[![CI](https://github.com/Ana2601/formal-axis-fifo-symbiyosys/actions/workflows/ci.yml/badge.svg)](https://github.com/Ana2601/formal-axis-fifo-symbiyosys/actions/workflows/ci.yml)

Model-checking proof that the AXI-Stream FIFO from [cocotb-axis-fifo-verification](https://github.com/Ana2601/cocotb-axis-fifo-verification) is safe under **every** possible input sequence, not just the ones a testbench happens to drive. M1-native.

## What is proven (`tb/fifo_formal_tb.sv`)

| # | Property |
|---|---|
| P1 | no overflow: occupancy always in 0…DEPTH |
| P2 | a write is refused (`tready = 0`) whenever the FIFO is full |
| P3 | occupancy changes by at most one per cycle |
| P4 | full and empty are mutually exclusive |
| P5 | `tready` is exactly `!full` |
| P6 | the registered output only holds a word that is still counted (no pop underflow); this is also the inductive invariant that closes the proof |

All inputs are `$anyseq`: the solver picks a fresh value every cycle, so arbitrary traffic and back-pressure patterns are covered.

## Results (measured)

| Task | Engine | Result |
|---|---|---|
| `bmc` (depth 20) | smtbmc / z3 | PASS |
| `prove` (k-induction) | smtbmc / z3 | **PASS**: holds in every reachable state (about 2 s) |
| Mutation check | | a FIFO that never goes empty after a pop makes both tasks **FAIL** (caught by P6) |

## Notes from hardening

- The clock is a top-level input of the formal harness. An `always #5 clk = ~clk` generator is ignored by synthesis and formal tools, which would leave the clock stuck and every property vacuously true.
- Inputs were changed from `$anyconst` (frozen for the whole trace) to `$anyseq`.
- P6 was added: without it the safety properties are true but not inductive, and k-induction cannot close.

## Run

```bash
sby -f fifo.sby          # runs bmc + prove
```

## Files

```
rtl/axis_fifo.sv          DUT (same FIFO as cocotb-axis-fifo-verification)
tb/fifo_formal_tb.sv      formal harness + SVA properties
fifo.sby                  SymbiYosys tasks (bmc, prove)
```

See also [writeback-dcache-formal](https://github.com/Ana2601/writeback-dcache-formal) (formally proven write-back cache) and [cdc-async-fifo-formal](https://github.com/Ana2601/cdc-async-fifo-formal) (multi-clock proof of an async FIFO).

## Setup

- [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) (Icarus Verilog, Verilator, Yosys, SymbiYosys)
- z3 (`brew install z3` / `apt install z3`)

```bash
sby -f fifo.sby
```

The same commands run in CI on every push (`.github/workflows/ci.yml`).
