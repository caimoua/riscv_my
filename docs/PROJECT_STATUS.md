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

## 项目大路线

后续大方向固定为三阶段，详细路线见 `docs/RV32I_PROJECT_ROADMAP.md`。

```text
Stage A：可交付 CPU IP
  先把 rv32i_cached_ahb_master_top 打磨成可集成、可验证、可文档化的 CPU 子系统。

Stage B：可运行 SoC / FPGA demo
  再把 CPU 子系统放入小型 SoC，形成 boot、UART、timer、SRAM/flash 和 FPGA 展示路径。

Stage C：性能优化型 CPU core
  最后基于可测量 workload 做分支、取指、cache、总线和 CPI 优化。
```

当前正式进入 Stage A。近期优先级是：自动化回归、汇编/C 测试流、IP 交付文档、ISA 基础测试、lint/综合基础检查。

## 已完成

- RV32I 单周期 baseline core。
- 五级流水线 core，包含 forwarding、load-use stall、memory wait-state、branch/jump flush 和性能计数器。
  - 性能计数器已从 `rv32i_pipe_core` 抽成独立 `rv32i_perf_counter` 模块。
  - `rv32i_perf_counter_tb` 已由用户确认 VCS PASS。
  - 性能计数器抽出后的 `rv32i_pipe_core_tb`、静态/动态/参数化分支预测回归已由用户确认 VCS PASS。
  - `rv32i_pipe_ctrl` 已新增，用于集中管理当前 stall/flush 优先级。
  - `rv32i_pipe_ctrl_tb` 已由用户确认 VCS PASS。
  - pipeline control 抽出后的 core/perf/branch/muldiv 回归已由用户确认 VCS PASS。
  - Phase 5 第一轮已完成：`rv32i_pipe_core` 的 PC/IFID、ID/EX、EX/MEM、MEM/WB 时序更新块已拆分，并由用户确认 VCS 回归 PASS。
  - Phase 5 第二轮已完成：重复的 stage bubble/flush 清零逻辑已抽成本地 task，并由用户确认 VCS 回归 PASS。
  - Phase 6 第一轮已完成：`rv32i_pipe_core` 已加入仿真期 SystemVerilog assertion，覆盖 commit redirect 优先级、流水线清空、memory stall 保持、mul/div stall 前端保持、分支预测更新合法性和 fault/illegal 写回屏蔽，并由用户确认 VCS 回归 PASS。
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
- Stage A1 自动化回归入口第一版：
  - `sim/regress/regression_list.txt`
  - `sim/regress/run_regression.ps1`
  - `sim/regress/run_regression.sh`
  - 支持 `smoke/core/cache/ahb/mmio/soc/full` suite。
  - 本地已完成 PowerShell dry-run 和 Bash 语法/dry-run 检查；真实 VCS 回归仍需在仿真环境运行。

## 验证状态摘要

详细状态见 `docs/VERIFICATION_MATRIX.md`。

当前 Phase 6 第一轮 `rv32i_pipe_core` 仿真期 assertion 已加入，并由用户确认 VCS 回归 PASS。Stage A1 自动化回归入口第一版已完成 dry-run 检查；既有 directed tests 的历史 PASS 记录见 `docs/VERIFICATION_MATRIX.md`。

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

1. 在 VCS 环境运行 Stage A1 自动化回归脚本，优先确认 `smoke`，再确认 `core/cache/soc/full`。
2. Stage A2：把更多 directed test 迁移到汇编/C 软件镜像流，减少手写机器码。
3. Stage A5：补齐 CPU IP 交付文档，重点写清楚 `rv32i_cached_ahb_master_top` 的接口、假设和限制。
4. Stage A3：引入 RV32I/RV32M ISA 基础测试子集。
5. Stage A4：建立 lint / 综合 / 时序基础检查流程。
6. Stage B/C 的 SoC/FPGA demo 和性能优化等 Stage A 收敛后再展开。

## 上下文规则

后续 Codex 会话：

1. 先读本文件。
2. 再读 `docs/INTERFACE_INDEX.md`。
3. 再按任务读取相关 RTL/testbench。
4. 新增测试在用户给出 VCS PASS 前只能标记为 `PENDING`。
5. 用户确认 PASS 后，再更新 `docs/VERIFICATION_MATRIX.md`、本文件，并提交。
