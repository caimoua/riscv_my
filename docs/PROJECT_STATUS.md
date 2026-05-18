# Project Status

Last updated: 2026-05-18

This file is the first context entry for future work. Read this before scanning RTL or testbench files.

## Current Baseline

The project is an educational RV32I CPU and small SoC integration project. The current main system is:

```text
rv32i_cached_system_top
  rv32i_pipe_core
  rv32i_icache
  rv32i_dcache
  rv32i_mem_bus
  external ROM / SRAM / MMIO peripherals
```

The preferred integration-style CPU subsystem boundary is now:

```text
rv32i_cached_ahb_master_top
  rv32i_pipe_core
  rv32i_icache
  rv32i_dcache
  rv32i_ahb_master_bus
  external AHB-Lite master interface
```

## Completed

- RV32I single-cycle baseline core.
- Five-stage pipeline core with forwarding, load-use stall, memory wait-state handling, branch/jump flush, and performance counters.
- Static branch prediction in `rv32i_pipe_core`:
  - aligned `JAL` predicted taken in IF
  - aligned backward B-type branches predicted taken in IF
  - forward B-type branches predicted not-taken
  - `JALR` still resolved in EX
  - branch and branch-mispredict debug counters.
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
- AHB-Lite bus path:
  - simple-to-AHB master bridge
  - AHB-Lite decoder
  - AHB-to-simple slave bridge
  - opt-in cached system AHB top wrapper.
- AHB-Lite CPU subsystem interface:
  - opt-in `rv32i_cached_ahb_master_top`
  - one external AHB-Lite master port
  - external SoC/bus fabric owns ROM/SRAM/MMIO decode.
- Clean-room AHB-Lite 1-master / 4-slave matrix SoC wrapper:
  - `rv32i_ahb_lite_matrix_1m4s`
  - `rv32i_ahb_matrix_soc_top`
  - flash slot at `0x0800_0000`
  - SRAM slot at `0x2000_0000`
  - AHB peripheral slot at `0x4000_0000`
  - APB peripheral slot at `0x4200_0000`
- AHB-to-APB SoC integration:
  - `rv32i_ahb_to_apb`
  - `rv32i_apb_periph_mux`
  - `rv32i_ahb_matrix_apb_soc_top`
  - APB timer at `0x4200_0000`
  - APB UART at `0x4200_1000`
  - software image `software/bin/ahb_matrix_apb_soc.memh`
- `rv32i_pipe_core` and cached wrappers have a `RESET_PC` parameter so an SoC wrapper can boot from flash.
- Cached system top wrapper.
- MMIO timer peripheral with `mtime`, `mtimecmp`, `ctrl`, and `timer_irq`.
- Machine timer interrupt flow through CSR/trap and `mret`.
- Minimal TX-only UART MMIO peripheral.
- External MMIO peripheral mux for timer at `0x4000_0000` and UART at `0x4000_1000`.
- D-side load/store access fault through `d_error`.
- I-side instruction access fault through `i_error`.
- Misaligned address traps:
  - instruction address misaligned: `mcause=0`
  - load address misaligned: `mcause=4`
  - store/AMO address misaligned: `mcause=6`
- Presentation-quality architecture SVG: `docs/figures/rv32i_cached_system_architecture.svg`.
- Software-driven test image flow:
  - `software/asm/ahb_matrix_soc.S`
  - `software/linker/rv32i_flash.ld`
  - `software/scripts/bin_to_memh.py`
  - `software/bin/ahb_matrix_soc.memh`
  - `rv32i_ahb_matrix_soc_top_tb` now loads flash contents through `$readmemh`.
- Local Windows RISC-V GNU toolchain flow is documented and verified:
  - `riscv-none-elf-gcc`
  - `riscv-none-elf-objcopy`
  - GNU Make
  - `make -C software` regenerates the MEMH image.

## Verification Status Summary

Detailed status is tracked in `docs/VERIFICATION_MATRIX.md`.

User-confirmed VCS PASS has been reported for all directed tests currently listed in `docs/VERIFICATION_MATRIX.md`, including the static branch prediction tests.

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

1. Add a small dynamic BHT/BTB predictor.
2. If licensed vendor IP is required, keep AE350/Andes/ARM files outside the public repo or add them through a private `vendor_ip` path and filelist.
3. Add simple-bus-to-AXI-lite adapter.
4. Add UART RX/FIFO/interrupt if needed.
5. Consider a true multi-master AHB matrix if the project needs parallel slave access.

## Context Rules

For future Codex sessions:

1. Read this file first.
2. Then read `docs/INTERFACE_INDEX.md`.
3. Then read only the relevant RTL/testbench files for the task.
4. Update this file and `docs/VERIFICATION_MATRIX.md` after every completed feature.
