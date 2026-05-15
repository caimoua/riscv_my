# 仿真说明

这个目录是 VCS/Verdi 仿真的统一入口。

## 常用命令

```bash
make help
make com
make sim
make verdi
make clean
```

默认 testbench：

```text
sim/testcases/rv32i_core_tb.sv
```

默认运行方式：

```bash
make sim
```

## 单周期 Core Testbench

```text
sim/testcases/rv32i_core_tb.sv
```

覆盖内容：

- R-type 和 I-type ALU 指令
- `lui`、`auipc`
- `jal`、`jalr`
- `beq`、`bne`、`blt`、`bge`、`bltu`、`bgeu`
- `lb`、`lh`、`lw`、`lbu`、`lhu`、`sb`、`sh`、`sw`
- `csrrs rd, cycle, x0`、`ecall`、`ebreak` 的最小 SYSTEM/CSR 路径

## 流水线 Core Testbench

```text
sim/testcases/rv32i_pipe_core_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb
```

覆盖内容：

- EX/MEM、MEM/WB 到 EX 阶段的 forwarding
- `lw` 后紧跟使用者时的 load-use stall
- 指令存储器和数据存储器 wait-state
- branch/jump redirect 后的 flush
- `instret/stall_cycle/flush_cycle` debug 性能计数器

## Trap/CSR Testbench

```text
sim/testcases/rv32i_trap_csr_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_trap_csr_tb.sv TOP_NAME=rv32i_trap_csr_tb
```

覆盖内容：

- `csrrw x0, mtvec, x5`
- `ecall` 进入 `mtvec`
- handler 读取 `mcause/mepc`
- `csrrw x0, mepc, x7` 修改返回地址
- `mret` 返回主程序
- trap commit 时较年轻 store 不会提前写 data memory

## I-Cache Testbench

```text
sim/testcases/rv32i_icache_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_icache_tb.sv TOP_NAME=rv32i_icache_tb
```

覆盖内容：

- 2-way set associative
- 4-word cache line
- SRAM-style tag/data 存储
- hit、miss、refill 和 replacement

Pipeline + I-cache：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_icache_tb.sv TOP_NAME=rv32i_pipe_icache_tb
```

## D-Cache Testbench

```text
sim/testcases/rv32i_dcache_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_dcache_tb.sv TOP_NAME=rv32i_dcache_tb
```

覆盖内容：

- 2-way set associative
- 4-word cache line
- data SRAM byte write mask
- load miss refill
- store hit write-through
- store miss no-write-allocate

Pipeline + D-cache：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_dcache_tb.sv TOP_NAME=rv32i_pipe_dcache_tb
```

## Memory Bus Testbench

```text
sim/testcases/rv32i_mem_bus_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_mem_bus_tb.sv TOP_NAME=rv32i_mem_bus_tb
```

覆盖内容：

- I-cache/D-cache 两个 master
- D 优先仲裁
- ROM/SRAM/MMIO 地址 decode
- SRAM byte write strobe
- unmapped 地址的 `dbg_decode_error`

Pipeline + cache + bus 手工集成：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_cached_bus_tb.sv TOP_NAME=rv32i_pipe_cached_bus_tb
```

这个 testbench 直接实例化 core、I-cache、D-cache 和 bus，适合调试中间连接。

## Cached System Top Testbench

```text
sim/testcases/rv32i_cached_system_top_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_cached_system_top_tb.sv TOP_NAME=rv32i_cached_system_top_tb
```

这个 testbench 只实例化 `rv32i_cached_system_top`，在顶层外接 ROM、SRAM、MMIO 模型，验证正式系统 wrapper 的连接关系。

## MMIO Timer Testbench

独立 timer：

```text
sim/testcases/rv32i_timer_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_timer_tb.sv TOP_NAME=rv32i_timer_tb
```

Cached system + timer：

```text
sim/testcases/rv32i_cached_timer_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_cached_timer_tb.sv TOP_NAME=rv32i_cached_timer_tb
```

这个 testbench 验证 CPU 能通过 `0x4000_0000` MMIO 地址访问 `rv32i_timer`，并验证 D-cache 对 MMIO 走 uncached bypass。

Cached system + timer interrupt：

```text
sim/testcases/rv32i_cached_timer_irq_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_cached_timer_irq_tb.sv TOP_NAME=rv32i_cached_timer_irq_tb
```

这个 testbench 验证 `timer_irq` 通过 `mstatus.MIE && mie.MTIE && mip.MTIP` 进入 machine timer interrupt，handler 读取 `mcause/mepc/mstatus/mie/mip`，关闭 `mie.MTIE` 后通过 `mret` 返回主程序。

## MMIO UART Testbench

独立 UART：

```text
sim/testcases/rv32i_uart_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_uart_tb.sv TOP_NAME=rv32i_uart_tb
```

Cached system + UART：

```text
sim/testcases/rv32i_cached_uart_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_cached_uart_tb.sv TOP_NAME=rv32i_cached_uart_tb
```

这个 testbench 在 `rv32i_cached_system_top` 外接 `rv32i_mmio_periph_mux`、`rv32i_timer` 和 `rv32i_uart`。ROM 程序通过 `0x4000_1000` 写出 `UART\n`，并检查 UART MMIO 访问仍然绕过 D-cache。

## Access Fault Testbench

```text
sim/testcases/rv32i_cached_access_fault_tb.sv
```

运行方式：

```bash
make sim TB_FILE=./testcases/rv32i_cached_access_fault_tb.sv TOP_NAME=rv32i_cached_access_fault_tb
```

这个 testbench 验证 D 侧 unmapped 地址访问会由 bus 返回 `d_error`，经过 D-cache/LSU 形成 precise load/store access fault。handler 读取 `mcause/mepc` 写入 SRAM，修改 `mepc += 4` 后通过 `mret` 跳过 faulting 指令并返回主程序。

Instruction access fault：
```text
sim/testcases/rv32i_cached_instr_access_fault_tb.sv
```

运行方式：
```bash
make sim TB_FILE=./testcases/rv32i_cached_instr_access_fault_tb.sv TOP_NAME=rv32i_cached_instr_access_fault_tb
```

这个 testbench 验证 I 侧 unmapped 取指会由 bus 返回 `i_error`，经过 I-cache/core fetch fault 标记形成 precise instruction access fault。handler 读取 `mcause/mepc` 写入 SRAM，修改 `mepc` 到安全返回地址后通过 `mret` 返回主程序。

## 注意事项

当前 core 和 cache 仍是教学/学习版本。cache 和 bus 都是 blocking 风格，没有 outstanding 或 burst。I/D 侧 decode error 已经可以返回 core 并形成 instruction/load/store access fault；UART MMIO 已有最小 TX-only 版本，后续还可继续补 RX/FIFO/interrupt 或 AHB-lite/AXI-lite adapter。
