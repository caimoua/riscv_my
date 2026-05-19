# 接口索引

最后更新：2026-05-19

本文记录稳定模块边界，后续工作不需要每次重新扫描大量 RTL。

## 顶层系统

### `rv32i_cached_system_top`

文件：`rtl/top/rv32i_cached_system_top.v`

用途：可复用 cached system wrapper。

外部接口：

- `timer_irq`：外部 timer interrupt 输入 core CSR/trap。
- ROM passthrough：`rom_valid`, `rom_write`, `rom_addr`, `rom_wdata`, `rom_wstrb`, `rom_ready`, `rom_rdata`
- SRAM passthrough：`sram_valid`, `sram_write`, `sram_addr`, `sram_wdata`, `sram_wstrb`, `sram_ready`, `sram_rdata`
- MMIO passthrough：`mmio_valid`, `mmio_write`, `mmio_addr`, `mmio_wdata`, `mmio_wstrb`, `mmio_ready`, `mmio_rdata`
- Debug 输出：
  - core 性能计数器
  - branch / mispredict / BTB / BHT 计数器
  - cache hit/miss 计数器
  - bus grant 计数器
  - bus decode error

内部连接：

```text
core imem -> I-cache -> bus I master
core dmem -> D-cache -> bus D master
bus ROM/SRAM/MMIO -> external ports
bus i_error -> I-cache mem_error -> core imem_error
bus d_error -> D-cache mem_error -> core dmem_error
timer_irq -> core CSR/trap
MMIO external port -> optional timer/UART peripheral mux
```

### `rv32i_cached_ahb_master_top`

文件：`rtl/top/rv32i_cached_ahb_master_top.v`

用途：推荐的 CPU 子系统边界。内部包含 core、I-cache、D-cache 和 simple-to-AHB master bus，对外只暴露一个 AHB-Lite master interface。

外部 AHB-Lite master port：

- Outputs：`ahb_haddr`, `ahb_hburst`, `ahb_hprot`, `ahb_hsize`, `ahb_htrans`, `ahb_hwdata`, `ahb_hwrite`
- Inputs：`ahb_hrdata`, `ahb_hready`, `ahb_hresp`

### `rv32i_ahb_matrix_soc_top`

文件：`rtl/top/rv32i_ahb_matrix_soc_top.v`

用途：clean-room AHB-Lite 1-master / 4-slave matrix SoC wrapper。

slot：

- flash：`0x0800_0000`
- SRAM：`0x2000_0000`
- AHB peripheral：`0x4000_0000`
- APB peripheral：`0x4200_0000`

### `rv32i_ahb_matrix_apb_soc_top`

文件：`rtl/top/rv32i_ahb_matrix_apb_soc_top.v`

用途：在 AHB matrix SoC 的 APB slot 后面接 AHB-to-APB bridge、APB mux、timer 和 UART。

APB 外设：

- timer：`0x4200_0000`
- UART：`0x4200_1000`

## Core

### `rv32i_pipe_core`

文件：`rtl/core/rv32i_pipe_core.v`

用途：五级流水 RV32I core。

主要参数：

- `RESET_PC`：复位取指地址。
- `BRANCH_PRED_INDEX_BITS`：BHT/BTB index 位宽，默认 6，对应 64 项 direct-mapped BHT/BTB。

Instruction-side interface：

- Outputs：`imem_valid`, `imem_addr`
- Inputs：`imem_ready`, `imem_rdata`, `imem_error`
- `imem_error` 会作为 instruction access fault token 流入流水线，并在 commit 阶段精确提交。

Data-side interface：

- Outputs：`dmem_valid`, `dmem_write`, `dmem_addr`, `dmem_wdata`, `dmem_wstrb`
- Inputs：`dmem_ready`, `dmem_rdata`, `dmem_error`
- `dmem_error` 由 LSU 转换为 load/store access fault。
- load/store address misaligned 在 LSU 发出 D-bus 请求前检测。

Interrupt input：

- `timer_irq`

Debug interface：

- `dbg_pc`
- `dbg_cycle`
- `dbg_instret`
- `dbg_stall_cycle`
- `dbg_flush_cycle`
- `dbg_branch_count`
- `dbg_branch_mispredict_count`
- `dbg_btb_hit_count`
- `dbg_btb_miss_count`
- `dbg_bht_update_count`
- `dbg_reg_addr`, `dbg_reg_rdata`
- `dbg_illegal_instr`, `dbg_ecall`, `dbg_ebreak`

分支预测：

- `JAL`：若目标地址对齐，在 IF 阶段直接预测 taken。
- B-type branch：优先查 BTB，BTB 命中且 BHT 计数器最高位为 1 时预测 taken。
- B-type branch：BTB 未命中时回退到静态规则，backward branch 预测 taken，forward branch 预测 not-taken。
- `JALR`：仍在 EX 阶段解析。
- EX 阶段发现预测 PC 与真实下一条 PC 不一致时产生 `ex_redirect` 并 flush 前端。
- `BRANCH_PRED_INDEX_BITS` 已从 cached/AHB/SoC wrapper 透传，便于在不同集成层级调整 BHT/BTB 表项数量。

RV32M：

- `opcode=0110011` 且 `funct7=0000001` 的 M 扩展指令在 `rv32i_pipe_core` 内部识别。
- `rv32i_muldiv` 位于 EX 阶段。
- M 指令等待 `rv32i_muldiv.ready`，等待期间 IF 和 ID/EX 保持，EX/MEM 插入 bubble，MEM/WB drain。
- M 指令结果复用 `RV32I_WB_ALU` writeback/forwarding 路径。

关键内部模块：

- `rv32i_pipe_hazard`
- `rv32i_pipe_lsu`
- `rv32i_pipe_csr`
- `rv32i_muldiv`
- `rv32i_regfile`
- `rv32i_decoder`
- `rv32i_imm_gen`
- `rv32i_alu`

## CSR / Trap

### `rv32i_pipe_csr`

文件：`rtl/core/rv32i_pipe_csr.v`

用途：保存架构 CSR 状态，并在 commit 阶段生成 trap/interrupt redirect。

已实现 CSR：

- `mstatus`：只实现 MIE/MPIE
- `mie`：只实现 MTIE
- `mtvec`
- `mepc`
- `mcause`
- `mip`：MTIP 由 `timer_irq` 派生
- `cycle`

commit exception inputs：

- `commit_illegal`
- `commit_ecall`
- `commit_ebreak`
- `commit_instr_addr_misaligned`
- `commit_instr_fault`
- `commit_load_addr_misaligned`
- `commit_load_fault`
- `commit_store_addr_misaligned`
- `commit_store_fault`

支持的 `mcause`：

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

## Cache

### `rv32i_icache`

文件：`rtl/mem/rv32i_icache.v`

用途：blocking instruction cache。

- 2-way set associative。
- 4-word cache line。
- CPU side：`cpu_valid`, `cpu_addr`, `cpu_ready`, `cpu_rdata`, `cpu_error`
- Memory side：`mem_valid`, `mem_addr`, `mem_ready`, `mem_rdata`, `mem_error`
- `mem_error` 会终止 refill 并返回给 core。

### `rv32i_dcache`

文件：`rtl/mem/rv32i_dcache.v`

用途：blocking data cache。

- 2-way set associative。
- 4-word cache line。
- write-through。
- no-write-allocate。
- 默认 MMIO uncached bypass。
- CPU side：`cpu_valid`, `cpu_write`, `cpu_addr`, `cpu_wdata`, `cpu_wstrb`, `cpu_ready`, `cpu_rdata`, `cpu_error`
- Memory side：`mem_valid`, `mem_write`, `mem_addr`, `mem_wdata`, `mem_wstrb`, `mem_ready`, `mem_rdata`, `mem_error`

## Bus / SoC

### `rv32i_mem_bus`

文件：`rtl/bus/rv32i_mem_bus.v`

用途：内部 simple blocking memory bus。

- I master：来自 I-cache。
- D master：来自 D-cache。
- slaves：ROM、SRAM、MMIO。
- arbitration：D 侧优先。
- unmapped 地址返回 decode error。

### `rv32i_ahb_master_bus`

文件：`rtl/bus/rv32i_ahb_master_bus.v`

用途：把 core/cache 的 simple blocking memory request 转成单 outstanding AHB-Lite master transaction。

### `rv32i_ahb_lite_matrix_1m4s`

文件：`rtl/bus/rv32i_ahb_lite_matrix_1m4s.v`

用途：clean-room 1-master / 4-slave AHB-Lite matrix/decode。

## MMIO 外设

### `rv32i_timer`

文件：`rtl/periph/rv32i_timer.v`

base：`0x4000_0000` 或 APB SoC 中的 `0x4200_0000`。

寄存器：

- `mtime_lo`
- `mtime_hi`
- `mtimecmp_lo`
- `mtimecmp_hi`
- `ctrl`

### `rv32i_uart`

文件：`rtl/periph/rv32i_uart.v`

base：`0x4000_1000` 或 APB SoC 中的 `0x4200_1000`。

当前是最小 TX-only UART，用于 MMIO 输出验证。
