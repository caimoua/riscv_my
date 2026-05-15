# CPU_PRJ

## Current AHB Matrix SoC Work

The current SoC-style integration step adds a clean-room local AHB-Lite matrix wrapper instead of copying third-party AE350/Andes/ARM IP into this repo:

```text
rv32i_ahb_matrix_soc_top
  rv32i_cached_ahb_master_top
  rv32i_ahb_lite_matrix_1m4s
```

VCS command:

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_ahb_matrix_soc_top_tb.sv TOP_NAME=rv32i_ahb_matrix_soc_top_tb
```

这是一个面向学习和面试准备的 RISC-V CPU 项目，目标是系统性练习 CPU 微架构、简单 SoC 集成和验证流程。

## 项目导航入口

后续维护和协作时，优先阅读这三份文件，避免每次重新扫描大量 RTL：

- `docs/PROJECT_STATUS.md`：当前完成状态、未完成方向和上下文规则
- `docs/INTERFACE_INDEX.md`：主要 RTL 模块接口索引
- `docs/VERIFICATION_MATRIX.md`：testbench、运行命令和 PASS/PENDING 状态

关键设计决策记录放在 `docs/adr/`。

## 当前状态

- 已完成一版清晰、可解释的 RV32I 单周期 core。
- 已完成基础五级流水线，包含 forwarding、load-use stall、memory wait-state、branch/jump flush 和性能计数器。
- pipeline core 已完成第一版最小 trap/CSR 机制，支持 `mtvec/mepc/mcause`、`ecall/ebreak/illegal` trap、`mret` 返回和 commit 阶段 precise exception。说明见 `docs/RV32I_TRAP_CSR.md`。
- 已完成 blocking 2-way I-cache 和 D-cache，cache line 为 4 个 32-bit word，tag/data 存储通过 SRAM-style 模型访问。说明见 `docs/RV32I_ICACHE.md` 和 `docs/RV32I_DCACHE.md`。
- 已完成内部 memory bus，支持 I-cache/D-cache 两个 master 到 ROM/SRAM/MMIO 三类 slave 的 blocking 访问、D 优先仲裁和地址 decode。说明见 `docs/RV32I_MEM_BUS.md`。
- 已新增 `rv32i_cached_system_top`，把 pipeline core、I-cache、D-cache 和 memory bus 固化成一个可复用系统顶层。说明见 `docs/RV32I_CACHED_SYSTEM_TOP.md`。
- 已新增 AHB-Lite 总线路径和 `rv32i_cached_system_ahb_top`，directed tests 已通过 VCS。说明见 `docs/RV32I_AHB.md`。
- 已新增 `rv32i_cached_ahb_master_top`，作为更标准的 CPU subsystem 边界，对外只暴露 AHB-Lite master 接口；directed test 已通过 VCS。
- 已新增最小 MMIO timer 外设，并给 D-cache 增加默认 MMIO uncached bypass。说明见 `docs/RV32I_TIMER.md`。
- 已把 `timer_irq` 接入 pipeline trap/CSR 框架，新增最小 `mstatus/mie/mip`，支持 machine timer interrupt 和 `mret` 返回。
- 已把 I/D 侧 bus decode error 接入 pipeline trap/CSR，支持 instruction/load/store access fault，并新增 `rv32i_cached_access_fault_tb` 和 `rv32i_cached_instr_access_fault_tb`。
- 已新增最小 TX-only UART MMIO 外设和 timer/UART MMIO 子外设 mux，UART directed tests 已通过。说明见 `docs/RV32I_UART.md`。

## 主要目录

| 路径 | 用途 |
| --- | --- |
| `rtl/` | CPU、cache、bus 和顶层 wrapper RTL |
| `filelist/` | 仿真使用的 RTL filelist |
| `sim/` | VCS/Verdi 仿真工作区 |
| `software/` | 汇编/C 测试程序和构建脚本 |
| `docs/` | 架构笔记、迭代计划和调试记录 |
| `project/` | 后续可能使用的 FPGA/EDA 工程文件 |
| `ref/` | 参考资料笔记和小示例 |
| `tools/` | 本地辅助脚本 |

## 常用命令

默认单周期 core testbench：

```bash
cd sim
make sim
```

流水线 core：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb
```

trap/CSR：

```bash
make sim TB_FILE=./testcases/rv32i_trap_csr_tb.sv TOP_NAME=rv32i_trap_csr_tb
```

I-cache / D-cache / memory bus：

```bash
make sim TB_FILE=./testcases/rv32i_icache_tb.sv TOP_NAME=rv32i_icache_tb
make sim TB_FILE=./testcases/rv32i_dcache_tb.sv TOP_NAME=rv32i_dcache_tb
make sim TB_FILE=./testcases/rv32i_mem_bus_tb.sv TOP_NAME=rv32i_mem_bus_tb
```

pipeline + cache + bus 手工集成：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_cached_bus_tb.sv TOP_NAME=rv32i_pipe_cached_bus_tb
```

cached system top 顶层集成：

```bash
make sim TB_FILE=./testcases/rv32i_cached_system_top_tb.sv TOP_NAME=rv32i_cached_system_top_tb
```

AHB-Lite bus path：

```bash
make sim TB_FILE=./testcases/rv32i_mem_bus_ahb_tb.sv TOP_NAME=rv32i_mem_bus_ahb_tb
make sim TB_FILE=./testcases/rv32i_cached_system_ahb_top_tb.sv TOP_NAME=rv32i_cached_system_ahb_top_tb
make sim TB_FILE=./testcases/rv32i_cached_ahb_master_top_tb.sv TOP_NAME=rv32i_cached_ahb_master_top_tb
```

MMIO timer：

```bash
make sim TB_FILE=./testcases/rv32i_timer_tb.sv TOP_NAME=rv32i_timer_tb
make sim TB_FILE=./testcases/rv32i_cached_timer_tb.sv TOP_NAME=rv32i_cached_timer_tb
make sim TB_FILE=./testcases/rv32i_cached_timer_irq_tb.sv TOP_NAME=rv32i_cached_timer_irq_tb
make sim TB_FILE=./testcases/rv32i_cached_access_fault_tb.sv TOP_NAME=rv32i_cached_access_fault_tb
```

MMIO UART：

```bash
make sim TB_FILE=./testcases/rv32i_uart_tb.sv TOP_NAME=rv32i_uart_tb
make sim TB_FILE=./testcases/rv32i_cached_uart_tb.sv TOP_NAME=rv32i_cached_uart_tb
```

## 后续方向

后续适合继续做 AXI-lite adapter，或者补 UART RX/FIFO/interrupt；如果需要更接近 SoC 总线，也可以继续扩展真正的多 master AHB matrix。
