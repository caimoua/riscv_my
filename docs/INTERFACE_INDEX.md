# Interface Index

Last updated: 2026-05-15

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
  - core performance counters
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

Interrupt input:

- `timer_irq`

Debug:

- `dbg_pc`
- `dbg_cycle`
- `dbg_instret`
- `dbg_stall_cycle`
- `dbg_flush_cycle`
- `dbg_reg_addr`, `dbg_reg_rdata`
- `dbg_illegal_instr`, `dbg_ecall`, `dbg_ebreak`

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
- `commit_instr_fault`
- `commit_load_fault`
- `commit_store_fault`

Supported causes:

```text
1             instruction access fault
2             illegal instruction
3             breakpoint
5             load access fault
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
- Outputs: core performance/debug counters, cache hit/miss counters, bus grant counters, `dbg_bus_error`

Internal connections:

```text
core imem -> I-cache -> rv32i_ahb_master_bus
core dmem -> D-cache -> rv32i_ahb_master_bus
rv32i_ahb_master_bus -> external AHB-Lite master port
external AHB fabric -> ROM/SRAM/MMIO/peripherals
```

This top is the cleaner CPU-IP boundary. It does not expose ROM/SRAM/MMIO simple ports; memory and peripheral decode is owned by the external SoC fabric.

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
