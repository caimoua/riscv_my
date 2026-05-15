# Verification Matrix

Last updated: 2026-05-15

Status meanings:

- `PASS`: user has reported a successful VCS run, or the test existed before the current management-doc pass and was already part of the passing regression.
- `PENDING`: testbench exists but still needs a fresh VCS run from the user.
- `TODO`: planned but not implemented.

## Directed Tests

| Area | Testbench | Command from `sim/` | Status |
| --- | --- | --- | --- |
| Single-cycle RV32I core | `testcases/rv32i_core_tb.sv` | `make sim` | PASS |
| Pipeline hazards/control | `testcases/rv32i_pipe_core_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb` | PASS |
| Trap/CSR | `testcases/rv32i_trap_csr_tb.sv` | `make sim TB_FILE=./testcases/rv32i_trap_csr_tb.sv TOP_NAME=rv32i_trap_csr_tb` | PASS |
| I-cache | `testcases/rv32i_icache_tb.sv` | `make sim TB_FILE=./testcases/rv32i_icache_tb.sv TOP_NAME=rv32i_icache_tb` | PASS |
| D-cache | `testcases/rv32i_dcache_tb.sv` | `make sim TB_FILE=./testcases/rv32i_dcache_tb.sv TOP_NAME=rv32i_dcache_tb` | PASS |
| Memory bus | `testcases/rv32i_mem_bus_tb.sv` | `make sim TB_FILE=./testcases/rv32i_mem_bus_tb.sv TOP_NAME=rv32i_mem_bus_tb` | PENDING |
| Pipeline + I-cache | `testcases/rv32i_pipe_icache_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_icache_tb.sv TOP_NAME=rv32i_pipe_icache_tb` | PASS |
| Pipeline + D-cache | `testcases/rv32i_pipe_dcache_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_dcache_tb.sv TOP_NAME=rv32i_pipe_dcache_tb` | PASS |
| Pipeline + cache + bus | `testcases/rv32i_pipe_cached_bus_tb.sv` | `make sim TB_FILE=./testcases/rv32i_pipe_cached_bus_tb.sv TOP_NAME=rv32i_pipe_cached_bus_tb` | PASS |
| Cached system top | `testcases/rv32i_cached_system_top_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_system_top_tb.sv TOP_NAME=rv32i_cached_system_top_tb` | PASS |
| Timer peripheral | `testcases/rv32i_timer_tb.sv` | `make sim TB_FILE=./testcases/rv32i_timer_tb.sv TOP_NAME=rv32i_timer_tb` | PASS |
| Cached timer MMIO | `testcases/rv32i_cached_timer_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_timer_tb.sv TOP_NAME=rv32i_cached_timer_tb` | PASS |
| Cached timer interrupt | `testcases/rv32i_cached_timer_irq_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_timer_irq_tb.sv TOP_NAME=rv32i_cached_timer_irq_tb` | PASS |
| D-side load/store access fault | `testcases/rv32i_cached_access_fault_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_access_fault_tb.sv TOP_NAME=rv32i_cached_access_fault_tb` | PASS |
| I-side instruction access fault | `testcases/rv32i_cached_instr_access_fault_tb.sv` | `make sim TB_FILE=./testcases/rv32i_cached_instr_access_fault_tb.sv TOP_NAME=rv32i_cached_instr_access_fault_tb` | PENDING |

## Regression Notes

- After any RTL interface change, run at least:
  - `rv32i_mem_bus_tb`
  - `rv32i_icache_tb`
  - `rv32i_dcache_tb`
  - `rv32i_cached_system_top_tb`
  - access fault tests.
- After any CSR/trap change, run:
  - `rv32i_trap_csr_tb`
  - `rv32i_cached_timer_irq_tb`
  - `rv32i_cached_access_fault_tb`
  - `rv32i_cached_instr_access_fault_tb`.
- After any MMIO change, run:
  - timer tests
  - cached system top test
  - future UART tests.

## Latest Manual Update

- 2026-05-15: Added I-side instruction access fault RTL/testbench. Needs user-side VCS confirmation.
