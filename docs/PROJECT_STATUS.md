# Project Status

Last updated: 2026-05-15

This file is the first context entry for future work. Read this before scanning RTL or testbench files.

## Current Baseline

The project is an educational RV32I CPU and small SoC integration project. The current main system is:

```text
rv32i_cached_system_top
  rv32i_pipe_core
  rv32i_icache
  rv32i_dcache
  rv32i_mem_bus
  external ROM / SRAM / MMIO models
```

## Completed

- RV32I single-cycle baseline core.
- Five-stage pipeline core with forwarding, load-use stall, memory wait-state handling, branch/jump flush, and performance counters.
- Minimal machine-mode trap/CSR path:
  - `mtvec`, `mepc`, `mcause`
  - `mstatus.MIE/MPIE`, `mie.MTIE`, `mip.MTIP`
  - `ecall`, `ebreak`, illegal instruction traps
  - `mret`
  - precise commit at MEM/WB.
- Blocking 2-way I-cache with 4-word cache line.
- Blocking 2-way D-cache with 4-word cache line, write-through, no-write-allocate, and default MMIO uncached bypass.
- Internal blocking memory bus:
  - I-cache and D-cache masters
  - ROM, SRAM, MMIO slaves
  - D-priority arbitration
  - decode error responses.
- Cached system top wrapper.
- MMIO timer peripheral with `mtime`, `mtimecmp`, `ctrl`, and `timer_irq`.
- Machine timer interrupt flow through CSR/trap and `mret`.
- D-side load/store access fault through `d_error`.
- I-side instruction access fault through `i_error`.
- Presentation-quality architecture SVG: `docs/figures/rv32i_cached_system_architecture.svg`.

## Verification Status Summary

Detailed status is tracked in `docs/VERIFICATION_MATRIX.md`.

User-confirmed VCS PASS has been reported for all directed tests currently listed in `docs/VERIFICATION_MATRIX.md`, including memory bus and I-side instruction access fault.

## Active Design Assumptions

- RV32I only, 32-bit fixed-width instructions.
- No compressed instruction support.
- Machine mode only.
- No virtual memory or page faults.
- Caches and bus are blocking.
- No outstanding transactions.
- No burst protocol support.
- MMIO is accessed through the bus at `0x4000_0000`.

## Next Candidate Work

1. Add UART MMIO.
2. Add simple-bus-to-AHB-lite adapter.
3. Add simple-bus-to-AXI-lite adapter.
4. Add optional misaligned load/store traps.
5. Expand CSR instruction coverage if needed.

## Context Rules

For future Codex sessions:

1. Read this file first.
2. Then read `docs/INTERFACE_INDEX.md`.
3. Then read only the relevant RTL/testbench files for the task.
4. Update this file and `docs/VERIFICATION_MATRIX.md` after every completed feature.
