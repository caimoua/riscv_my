# Interface Index

Last updated: 2026-05-18

This file records stable module boundaries so future work does not need to rediscover common ports by scanning many RTL files.

## Top-Level System

### `rv32i_cached_system_top`

File: `rtl/top/rv32i_cached_system_top.v`

Role: reusable cached system wrapper.

External interfaces:

- `timer_irq`: external timer interrupt input to pipeline CSR/trap.
- ROM slave-side passthrough:
  - `rom_valid`, `rom_write`, `rom_addr`, `rom_wdata`, `rom_wstrb`, `rom_ready`, `rom_rdata`
- SRAM slave-side passthrough:
  - `sram_valid`, `sram_write`, `sram_addr`, `sram_wdata`, `sram_wstrb`, `sram_ready`, `sram_rdata`
- MMIO slave-side passthrough:
  - `mmio_valid`, `mmio_write`, `mmio_addr`, `mmio_wdata`, `mmio_wstrb`, `mmio_ready`, `mmio_rdata`
- Debug outputs:
  - core performance counters, including branch and branch-mispredict counters
  - cache hit/miss counters
  - bus grant counters
  - bus decode error.

Internal connections:

```text
core imem -> I-cache -> bus I master
core dmem -> D-cache -> bus D master
bus ROM/SRAM/MMIO -> external ports
bus i_error -> I-cache mem_error -> core imem_error
bus d_error -> D-cache mem_error -> core dmem_error
timer_irq -> core CSR/trap
MMIO external port -> optional timer/UART peripheral mux
```

## Core

### `rv32i_pipe_core`

File: `rtl/core/rv32i_pipe_core.v`

Role: five-stage RV32I pipeline.

Instruction-side interface:

- Outputs: `imem_valid`, `imem_addr`
- Inputs: `imem_ready`, `imem_rdata`, `imem_error`
- `imem_error` is captured as an instruction fault token and committed precisely.

Data-side interface:

- Outputs: `dmem_valid`, `dmem_write`, `dmem_addr`, `dmem_wdata`, `dmem_wstrb`
- Inputs: `dmem_ready`, `dmem_rdata`, `dmem_error`
- `dmem_error` is converted by LSU into load/store fault flags.
- Load/store address misalignment is caught in the LSU before issuing a D-bus request.
- Taken branch/jump target misalignment is caught in EX and committed as a precise instruction-address-misaligned trap.

Interrupt input:

- `timer_irq`

Debug:

- `dbg_pc`
- `dbg_cycle`
- `dbg_instret`
- `dbg_stall_cycle`
- `dbg_flush_cycle`
- `dbg_branch_count`
- `dbg_branch_mispredict_count`
- `dbg_reg_addr`, `dbg_reg_rdata`
- `dbg_illegal_instr`, `dbg_ecall`, `dbg_ebreak`

Branch prediction:

- IF predicts aligned `JAL` taken.
- IF predicts aligned backward B-type branches taken.
- Forward B-type branches remain predicted not-taken.
- `JALR` remains EX-resolved.
- EX redirects only on predicted-PC mismatch or commit-time trap/interrupt redirect.

Key internal modules:

- `rv32i_pipe_hazard`
- `rv32i_pipe_lsu`
- `rv32i_pipe_csr`
- `rv32i_regfile`
- `rv32i_decoder`
- `rv32i_imm_gen`
- `rv32i_alu`

## CSR / Trap

### `rv32i_pipe_csr`

File: `rtl/core/rv32i_pipe_csr.v`

Role: architectural CSR state and commit-time trap/interrupt redirect.

Implemented CSRs:

- `mstatus`: only MIE/MPIE
- `mie`: only MTIE
- `mtvec`
- `mepc`
- `mcause`
- `mip`: MTIP is derived from `timer_irq`
- `cycle`

Commit exception inputs:

- `commit_illegal`
- `commit_ecall`
- `commit_ebreak`
- `commit_instr_addr_misaligned`
- `commit_instr_fault`
- `commit_load_addr_misaligned`
- `commit_load_fault`
- `commit_store_addr_misaligned`
- `commit_store_fault`

Supported causes:

```text
0             instruction address misaligned
1             instruction access fault
2             illegal instruction
3             breakpoint
4             load address misaligned
5             load access fault
6             store/AMO address misaligned
7             store/AMO access fault
11            environment call from machine mode
0x80000007    machine timer interrupt
```

## Caches

### `rv32i_icache`

File: `rtl/mem/rv32i_icache.v`

Role: blocking instruction cache.

CPU side:

- `cpu_valid`
- `cpu_addr`
- `cpu_ready`
- `cpu_rdata`
- `cpu_error`

Memory side:

- `mem_valid`
- `mem_addr`
- `mem_ready`
- `mem_rdata`
- `mem_error`

On `mem_error`, refill is aborted and `cpu_error` is returned to core.

### `rv32i_dcache`

File: `rtl/mem/rv32i_dcache.v`

Role: blocking data cache.

CPU side:

- `cpu_valid`
- `cpu_write`
- `cpu_addr`
- `cpu_wdata`
- `cpu_wstrb`
- `cpu_ready`
- `cpu_rdata`
- `cpu_error`

Memory side:

- `mem_valid`
- `mem_write`
- `mem_addr`
- `mem_wdata`
- `mem_wstrb`
- `mem_ready`
- `mem_rdata`
- `mem_error`

Default MMIO bypass sends accesses in the MMIO region directly to the bus without caching.

## Bus

### `rv32i_mem_bus`

File: `rtl/bus/rv32i_mem_bus.v`

Role: simple internal blocking memory bus.

I master:

- `i_valid`
- `i_addr`
- `i_ready`
- `i_rdata`
- `i_error`

D master:

- `d_valid`
- `d_write`
- `d_addr`
- `d_wdata`
- `d_wstrb`
- `d_ready`
- `d_rdata`
- `d_error`

Slaves:

- ROM
- SRAM
- MMIO

Default memory map:

```text
0x0000_0000 - 0x0FFF_FFFF  ROM
0x2000_0000 - 0x2FFF_FFFF  SRAM
0x4000_0000 - 0x4FFF_FFFF  MMIO
other addresses             decode error
```

Decode error behavior:

```text
ready = 1
rdata = 0
i_error or d_error = 1
dbg_decode_error = 1
```

### `rv32i_mem_bus_ahb`

File: `rtl/bus/rv32i_mem_bus_ahb.v`

Role: AHB-Lite version of the internal memory bus.

The external simple interfaces match `rv32i_mem_bus`:

- I master
- D master
- ROM
- SRAM
- MMIO

Internal AHB-Lite path:

```text
simple I/D request arbiter
  -> rv32i_simple_to_ahb
  -> rv32i_ahb_lite_decoder
  -> rv32i_ahb_to_simple for ROM/SRAM/MMIO
```

Implemented AHB-Lite signals:

- `HADDR`
- `HBURST`
- `HPROT`
- `HSIZE`
- `HTRANS`
- `HWRITE`
- `HWDATA`
- `HRDATA`
- `HREADY`
- `HRESP`

The current path generates single-beat AHB-Lite transfers. Partial simple-bus writes are split into byte transfers.

### `rv32i_ahb_to_apb`

File: `rtl/bus/rv32i_ahb_to_apb.v`

Role: AHB-Lite slave to APB4-style master bridge.

AHB-Lite slave side:

- Inputs: `hsel`, `haddr`, `hburst`, `hprot`, `hsize`, `htrans`, `hwdata`, `hwrite`, `hready`
- Outputs: `hrdata`, `hreadyout`, `hresp`

APB master side:

- Outputs: `psel`, `penable`, `paddr`, `pwrite`, `pwdata`, `pstrb`, `pprot`
- Inputs: `prdata`, `pready`, `pslverr`

Behavior:

```text
AHB single-beat transfer
  -> APB setup phase
  -> APB access phase
  -> AHB HREADYOUT/HRESP completion
```

### `rv32i_cached_system_ahb_top`

File: `rtl/top/rv32i_cached_system_ahb_top.v`

Role: cached system wrapper using `rv32i_mem_bus_ahb`.

The external port list intentionally matches `rv32i_cached_system_top`, so testbenches can switch between the simple-bus and AHB-Lite bus path without changing memory/peripheral models.

### `rv32i_cached_ahb_master_top`

File: `rtl/top/rv32i_cached_ahb_master_top.v`

Role: integration-style cached CPU subsystem with an external AHB-Lite master interface.

External AHB-Lite master port:

- Outputs: `ahb_haddr`, `ahb_hburst`, `ahb_hprot`, `ahb_hsize`, `ahb_htrans`, `ahb_hwdata`, `ahb_hwrite`
- Inputs: `ahb_hrdata`, `ahb_hready`, `ahb_hresp`

External non-bus ports:

- Inputs: `clk`, `rst_n`, `timer_irq`, `dbg_reg_addr`
- Outputs: core performance/debug counters, branch prediction counters, cache hit/miss counters, bus grant counters, `dbg_bus_error`

Internal connections:

```text
core imem -> I-cache -> rv32i_ahb_master_bus
core dmem -> D-cache -> rv32i_ahb_master_bus
rv32i_ahb_master_bus -> external AHB-Lite master port
external AHB fabric -> ROM/SRAM/MMIO/peripherals
```

This top is the cleaner CPU-IP boundary. It does not expose ROM/SRAM/MMIO simple ports; memory and peripheral decode is owned by the external SoC fabric.

### `rv32i_ahb_lite_matrix_1m4s`

File: `rtl/bus/rv32i_ahb_lite_matrix_1m4s.v`

Role: clean-room AHB-Lite single-master / four-slave decoder matrix for the current SoC integration step.

Master side:

- Inputs: `m_haddr`, `m_hburst`, `m_hprot`, `m_hsize`, `m_htrans`, `m_hwdata`, `m_hwrite`
- Outputs: `m_hrdata`, `m_hready`, `m_hresp`

Slave side:

- `s0_*`: flash slot
- `s1_*`: SRAM slot
- `s2_*`: AHB peripheral slot
- `s3_*`: APB peripheral slot, still exposed as an AHB-Lite slave-side port so an AHB-to-APB bridge can be attached later.

Default map:

```text
0x0800_0000 - 0x0FFF_FFFF  flash
0x2000_0000 - 0x2FFF_FFFF  SRAM
0x4000_0000 - 0x41FF_FFFF  AHB peripherals
0x4200_0000 - 0x43FF_FFFF  APB peripherals
other addresses             AHB ERROR response
```

### `rv32i_ahb_matrix_soc_top`

File: `rtl/top/rv32i_ahb_matrix_soc_top.v`

Role: SoC-style wrapper around `rv32i_cached_ahb_master_top` plus the local AHB-Lite matrix.

External ports:

- Four AHB-Lite slave-side slots: `flash_*`, `sram_*`, `ahb_periph_*`, `apb_periph_*`
- Core debug, branch prediction, and cache/bus counters
- `dbg_cpu_bus_error`
- `dbg_matrix_decode_error`

Default boot address:

```text
RESET_PC = 0x0800_0000
```

### `rv32i_ahb_matrix_apb_soc_top`

File: `rtl/top/rv32i_ahb_matrix_apb_soc_top.v`

Role: SoC-style wrapper that keeps flash/SRAM/AHB-peripheral AHB slots external and turns the matrix APB slot into an internal APB peripheral subsystem.

Internal path:

```text
rv32i_cached_ahb_master_top
  -> rv32i_ahb_lite_matrix_1m4s
    -> flash AHB slot
    -> SRAM AHB slot
    -> AHB peripheral slot
    -> rv32i_ahb_to_apb
      -> rv32i_apb_periph_mux
        -> rv32i_timer
        -> rv32i_uart
```

APB peripheral map:

```text
0x4200_0000 - 0x4200_0FFF  timer
0x4200_1000 - 0x4200_1FFF  UART
```

Status: implemented and user-confirmed VCS PASS with `rv32i_ahb_matrix_apb_soc_top_tb`.

## Timer

### `rv32i_timer`

File: `rtl/periph/rv32i_timer.v`

Role: minimal MMIO timer.

Registers:

- `mtime_lo`
- `mtime_hi`
- `mtimecmp_lo`
- `mtimecmp_hi`
- `ctrl`

Output:

- `timer_irq`

Typical integration:

```text
rv32i_cached_system_top MMIO port -> rv32i_mmio_periph_mux -> rv32i_timer
timer_irq -> rv32i_cached_system_top.timer_irq
```

## UART

### `rv32i_uart`

File: `rtl/periph/rv32i_uart.v`

Role: minimal TX-only MMIO UART model.

Registers, relative to UART base:

```text
0x00 TXDATA  write byte0 emits one tx_valid pulse; read returns last TX byte
0x04 STATUS  bit0 tx_ready, currently constant 1
```

Bus interface:

- `valid`, `write`, `addr`, `wdata`, `wstrb`
- `ready`, `rdata`

TX/debug outputs:

- `tx_valid`
- `tx_data`
- `dbg_tx_count`
- `dbg_last_tx`

Typical integration:

```text
rv32i_cached_system_top MMIO port -> rv32i_mmio_periph_mux -> rv32i_uart
UART base address: 0x4000_1000
```

### `rv32i_mmio_periph_mux`

File: `rtl/periph/rv32i_mmio_periph_mux.v`

Role: simple external MMIO peripheral decoder for timer and UART.

Default map:

```text
0x4000_0000 - 0x4000_0FFF  timer
0x4000_1000 - 0x4000_1FFF  UART
```

Unmatched sub-MMIO accesses return `ready=valid`, `rdata=0`, and assert `dbg_decode_error`.

### `rv32i_apb_periph_mux`

File: `rtl/periph/rv32i_apb_periph_mux.v`

Role: APB peripheral decoder for timer and UART.

APB side:

- Inputs: `psel`, `penable`, `paddr`, `pwrite`, `pwdata`, `pstrb`, `pprot`
- Outputs: `prdata`, `pready`, `pslverr`

Peripheral map:

```text
0x4200_0000 - 0x4200_0FFF  timer
0x4200_1000 - 0x4200_1FFF  UART
```

Unmatched APB accesses complete with `pslverr=1` and assert `dbg_decode_error`.
