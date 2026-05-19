# 项目状态

最后更新：2026-05-19

这是后续 Codex 会话的第一入口。继续工作前先读这个文件，再按需读取 `docs/INTERFACE_INDEX.md` 和 `docs/VERIFICATION_MATRIX.md`，避免每次重新扫描大量 RTL。

## 当前基线

这是一个用于学习和迭代的 RV32I CPU / 小型 SoC 项目。当前主要系统边界有两类。

传统 cached system top：

```text
rv32i_cached_system_top
  rv32i_pipe_core
  rv32i_icache
  rv32i_dcache
  rv32i_mem_bus
  external ROM / SRAM / MMIO peripherals
```

更推荐作为 CPU 子系统交付边界的是：

```text
rv32i_cached_ahb_master_top
  rv32i_pipe_core
  rv32i_icache
  rv32i_dcache
  rv32i_ahb_master_bus
  external AHB-Lite master interface
```

## 已完成

- RV32I 单周期 baseline core。
- 五级流水线 core，包含 forwarding、load-use stall、memory wait-state、branch/jump flush 和性能计数器。
- 第一版静态分支预测：
  - 对齐的 `JAL` 在 IF 阶段预测 taken。
  - 对齐的 backward B-type branch 在 IF 阶段预测 taken。
  - forward B-type branch 预测 not-taken。
  - `JALR` 仍在 EX 阶段解析。
  - `dbg_branch_count` 和 `dbg_branch_mispredict_count` 已透出。
- 小型动态 BHT/BTB 分支预测：
  - 默认 64 项 direct-mapped BHT，2-bit 饱和计数器。
  - 默认 64 项 direct-mapped BTB，记录分支 PC tag 和目标 PC。
  - BHT/BTB 已从 `rv32i_pipe_core` 抽成独立 `rv32i_branch_predictor` 模块。
  - `BRANCH_PRED_INDEX_BITS` 参数已从 core 透传到 cached/AHB/SoC wrapper，用于调整 BHT/BTB 表项数量。
  - B-type branch 优先使用 BTB+BHT，BTB miss 时回退到静态 backward-taken 规则。
  - `dbg_btb_hit_count`, `dbg_btb_miss_count`, `dbg_bht_update_count` 已透出。
  - `rv32i_pipe_dynamic_branch_predict_tb` 已由用户确认 VCS PASS。
  - `rv32i_pipe_branch_predict_param_tb` 已由用户确认 VCS PASS。
  - `rv32i_branch_predictor_tb` 已由用户确认 VCS PASS。
  - 抽出 `rv32i_branch_predictor` 后的分支预测和 pipeline core 集成回归已由用户确认 VCS PASS。
- RV32M 乘除法扩展：
  - 支持 `mul/mulh/mulhsu/mulhu/div/divu/rem/remu`。
  - M 扩展识别已并入 `rv32i_decoder`，由 `ENABLE_M` 参数控制。
  - `rv32i_pipe_core` 打开 `ENABLE_M` 并只消费 decoder 输出的 `muldiv_valid/muldiv_op`。
  - 单周期 `rv32i_core` 保持 decoder 默认 `ENABLE_M=0`，仍作为 RV32I-only baseline。
  - 新增 EX 阶段 `rv32i_muldiv` 多周期执行单元。
  - M 指令结果复用 ALU writeback/forwarding 路径。
  - `rv32i_pipe_muldiv_tb` 已由用户确认 VCS PASS。
  - `rv32i_decoder_muldiv_tb` 已由用户确认 VCS PASS。
- 最小 machine-mode trap/CSR 路径：
  - `mtvec`, `mepc`, `mcause`
  - `mstatus.MIE/MPIE`, `mie.MTIE`, `mip.MTIP`
  - `ecall`, `ebreak`, illegal instruction trap
  - `mret`
  - MEM/WB commit 阶段 precise trap。
- instruction/load/store access fault。
- instruction/load/store misaligned address trap。
- Blocking 2-way I-cache，4-word cache line。
- Blocking 2-way D-cache，4-word cache line，write-through，no-write-allocate，默认 MMIO uncached bypass。
- 内部 blocking memory bus：
  - I-cache 和 D-cache 两个 master。
  - ROM、SRAM、MMIO 三类 slave。
  - D 侧优先仲裁。
  - decode error response。
- AHB-Lite bus path：
  - simple-to-AHB master bridge。
  - AHB-Lite decoder。
  - AHB-to-simple slave bridge。
  - `rv32i_cached_system_ahb_top`。
- 标准 CPU 子系统接口：
  - `rv32i_cached_ahb_master_top`
  - 对外只暴露一个 AHB-Lite master port。
  - 外部 SoC/bus fabric 负责 ROM/SRAM/MMIO decode。
- Clean-room AHB-Lite 1-master / 4-slave matrix SoC wrapper：
  - `rv32i_ahb_lite_matrix_1m4s`
  - `rv32i_ahb_matrix_soc_top`
  - flash slot at `0x0800_0000`
  - SRAM slot at `0x2000_0000`
  - AHB peripheral slot at `0x4000_0000`
  - APB peripheral slot at `0x4200_0000`
- AHB-to-APB SoC integration：
  - `rv32i_ahb_to_apb`
  - `rv32i_apb_periph_mux`
  - `rv32i_ahb_matrix_apb_soc_top`
  - APB timer at `0x4200_0000`
  - APB UART at `0x4200_1000`
  - software image `software/bin/ahb_matrix_apb_soc.memh`
- `RESET_PC` 参数，支持 SoC wrapper 从 flash 启动。
- MMIO timer peripheral，包含 `mtime`, `mtimecmp`, `ctrl`, `timer_irq`。
- machine timer interrupt 路径，支持 handler 进入和 `mret` 返回。
- 最小 TX-only UART MMIO peripheral。
- external MMIO peripheral mux，timer at `0x4000_0000`，UART at `0x4000_1000`。
- 论文/PPT 可用的系统结构 SVG：`docs/figures/rv32i_cached_system_architecture.svg`。
- 软件镜像构建流：
  - `software/asm/ahb_matrix_soc.S`
  - `software/linker/rv32i_flash.ld`
  - `software/scripts/bin_to_memh.py`
  - `software/bin/ahb_matrix_soc.memh`
  - `rv32i_ahb_matrix_soc_top_tb` 通过 `$readmemh` 加载 flash 内容。
- 本地 Windows RISC-V GNU 工具链流程已经记录并验证：
  - `riscv-none-elf-gcc`
  - `riscv-none-elf-objcopy`
  - GNU Make
  - `make -C software` 可重新生成 MEMH 镜像。

## 验证状态摘要

详细状态见 `docs/VERIFICATION_MATRIX.md`。

当前 `docs/VERIFICATION_MATRIX.md` 中列出的 directed tests 均已有用户报告的 VCS PASS。

## 设计假设

- 流水线 core 已支持 RV32IM 指令子集。
- 32-bit 固定长度指令。
- 不支持 compressed instruction。
- machine mode only。
- 无虚拟内存，无 page fault。
- cache 和 bus 都是 blocking。
- 无 outstanding transaction。
- 暂不支持 burst。
- CPU 子系统推荐通过 AHB-Lite master port 接入外部 SoC。

## 下一步候选

1. 抽出性能计数器模块，继续减轻 `rv32i_pipe_core` 顶层负担。
2. 增加 AXI-Lite adapter。
3. 扩展 UART RX/FIFO/interrupt。
4. 如果项目需要并行 slave 访问，再考虑真正 multi-master AHB matrix。

## 上下文规则

后续 Codex 会话：

1. 先读本文件。
2. 再读 `docs/INTERFACE_INDEX.md`。
3. 再按任务读取相关 RTL/testbench。
4. 新增测试在用户给出 VCS PASS 前只能标记为 `PENDING`。
5. 用户确认 PASS 后，再更新 `docs/VERIFICATION_MATRIX.md`、本文件，并提交。
