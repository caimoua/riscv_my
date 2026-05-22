# RV32I Workload-Driven Roadmap

最后更新：2026-05-22

本文是后续项目推进的主路线图。它替代“先收口交付、再考虑性能”的旧叙事，把当前 CPU 明确定位为一个仍然很简单的教学/实验核，并把后续目标改为：

```text
从 toy RV32IM core 继续演进为 workload-driven RISC-V Agent Core。
```

`rv32i_cached_ahb_master_top` 仍然是当前最干净的集成边界，但它不是终点，也不代表项目已经接近产品级 CPU IP。它只是后续做性能画像、cache/bus 优化、SoC demo 和专用扩展时比较稳定的实验壳。

## 0. 当前真实定位

当前 CPU 已经具备完整学习价值和继续演进的工程基础：

- 单发射、顺序执行、五级流水。
- RV32IM 指令子集。
- forwarding、load-use stall、memory wait-state、branch/jump flush。
- 静态 fallback + 小型 BHT/BTB 分支预测。
- blocking I-cache / D-cache。
- blocking、single outstanding AHB-Lite master path。
- machine mode only 的最小 CSR/trap/timer interrupt。
- 软件镜像流、directed testbench、自动化回归和基础质量检查入口。

但它仍然是一个 toy CPU，不应被误判为已经可以“交付收口”的高性能核。主要限制包括：

- 不支持 compressed instruction。
- 不支持 supervisor/user mode、MMU、Linux。
- 不支持 atomic、bitmanip、vector、DSP/int8 dot-product。
- cache blocking，miss 期间前后端都容易停住。
- AHB 路径无 burst、无多个 outstanding transaction。
- 分支预测没有 RAS、indirect branch/JALR target cache。
- 性能计数刚开始细分，core 内部原因已有第一批计数器，但 cache/bus 层 penalty 和稳定 benchmark 仍不完整。
- 还没有稳定 benchmark 和 before/after 性能报告。

## 1. 路线原则

后续所有功能和优化按下面规则推进：

1. **先测量，再优化。** 不凭感觉说哪里慢，先用 benchmark 和性能计数定位瓶颈。
2. **每个微架构改动都要有 before/after。** 至少记录 cycle、instret、CPI、stall、flush、branch/mispredict、cache miss。
3. **保持可验证小步快跑。** 新 RTL 要配 directed testbench；用户给出 VCS PASS 前，验证矩阵只标 `PENDING`。
4. **当前 AHB master top 是实验边界，不是终点。** 后续可以围绕它扩展，也可以在性能数据证明需要时重构。
5. **面向 agent/runtime workload，而不是泛泛堆功能。** 优先服务 event loop、tool dispatch、token scan、int8 dot/matvec、队列、状态机和小型调度。

## 2. Stage P0：性能画像基线

目标：先回答“当前 CPU 到底慢在哪里”。

### P0.1 指标与日志口径

目标：

- 新增 `docs/RV32I_PERF_BASELINE.md`。
- 固定现有可观测指标、派生指标、benchmark 分类、日志格式和 baseline 表格模板。
- 明确 P0.2 要实现的 stall reason 计数器口径。

当前状态：

- `docs/RV32I_PERF_BASELINE.md` 已新增第一版。
- 本步骤只改文档，不新增 RTL/testbench，不改变验证矩阵状态。

### P0.2 细分性能计数器

在现有 `cycle/instret/stall/flush/branch/cache/bus` 基础上，逐步增加：

- `load_use_stall_cycle`
- `ifetch_wait_cycle`
- `dcache_wait_cycle`
- `icache_miss_penalty_cycle`
- `dcache_miss_penalty_cycle`
- `muldiv_wait_cycle`
- `bus_wait_cycle`
- `branch_redirect_flush_cycle`
- `trap_redirect_flush_cycle`

验收标准：

- 计数器有 standalone test 或 core 集成 test。
- 指标能从顶层 debug 口或 testbench 日志输出。
- 文档记录每个计数器的精确定义，避免重复计数。

当前状态：

- 第一批 core 内部细分计数器已实现：`load_use_stall_cycle`、`ifetch_wait_cycle`、`if_discard_cycle`、`mem_wait_cycle`、`muldiv_wait_cycle`、`branch_redirect_cycle`、`commit_redirect_cycle`。
- 新计数器已从 `rv32i_pipe_core` 透传到 cached top、AHB master top、AHB matrix SoC top 和 APB SoC top。
- `rv32i_perf_counter_tb` 已更新为覆盖新计数器，并由用户确认新版 VCS PASS。
- cache refill、D-cache miss penalty、AHB wait-state 级别计数器尚未实现，后续在 cache/bus 层继续扩展。

### P0.3 benchmark / workload 镜像

第一批 benchmark 先用汇编，减少 C runtime 变量：

```text
software/asm/perf_branch_loop.S
software/asm/perf_memcpy.S
software/asm/perf_pointer_chase.S
software/asm/agent_event_loop.S
software/asm/agent_tool_dispatch.S
software/asm/agent_token_scan.S
software/asm/agent_int8_dot.S
software/asm/agent_int8_matvec.S
```

对应可新增：

```text
sim/testcases/rv32i_perf_baseline_tb.sv
docs/RV32I_PERF_BASELINE.md
```

验收标准：

- 每个 workload 能稳定跑到 `ebreak`。
- testbench 输出统一格式的性能摘要。
- `docs/RV32I_PERF_BASELINE.md` 记录当前 baseline 表格。

当前状态：

- `perf_branch_loop.S` 已新增，覆盖固定循环中的条件分支、跳转和 backward branch，签名 `0x0b120001`。
- `agent_event_loop.S` 已新增，覆盖 CPU-only event queue 初始化、load-dispatch-store 循环和 checksum，签名 `0x0a6e0001`。
- `perf_memcpy.S` 已新增，覆盖顺序初始化、顺序拷贝和顺序校验，签名 `0x0c0f0001`，并由用户确认 VCS PASS。
- `perf_pointer_chase.S` 已新增，覆盖同 index 节点 ring 上的 dependent load 和 conflict miss 行为，签名 `0x0c450001`，并由用户确认 VCS PASS。
- 四个 workload 已接入 `software/Makefile`，并已生成对应 `software/bin/*.memh`。
- `rv32i_perf_baseline_tb.sv` 已新增，可通过 plusarg 选择 workload 并输出统一 `[PERF]` / `PERF_CSV` 日志。
- 用户已确认第一版 `perf` regression VCS PASS，日志目录为 `sim/log/regress/20260522_171940-perf`。
- 用户已确认第二版 `perf` regression VCS PASS，日志目录为 `sim/log/regress/20260522_175530-perf`。
- 用户已提供 `PERF_CSV` 数据，`docs/RV32I_PERF_BASELINE.md` 已填入 branch、memory/cache 和 agent event loop 的 `baseline-ahb-master` 表。

### P0.4 perf regression suite

在 `sim/regress/regression_list.txt` 中新增 `perf` suite。

验收标准：

- `smoke` 仍保持轻量。
- `perf` 专门用于性能画像，不与功能 directed tests 混在一起。
- 性能测试默认先看趋势，不把 cycle 精确值过早做成硬性 PASS 条件。

当前状态：

- `perf` suite 已接入 PowerShell/Bash 回归入口。
- 当前 suite 包含 `perf_branch_loop`、`perf_memcpy`、`perf_pointer_chase` 和 `agent_event_loop` 四项。
- 本地完成 dry-run 和脚本检查；用户已在 VCS 环境确认包含四个 workload 的 `perf` regression PASS。

## 3. Stage P1：前端与控制流优化

目标：减少取指停顿和错误路径执行，服务分支密集、函数调用密集、dispatch table 类 workload。

候选方向：

- Return Address Stack，优化函数返回。
- JALR / indirect branch target cache，优化 dispatch table 和解释器式控制流。
- 更大或更合理索引的 BHT/BTB。
- I-cache next-line prefetch。
- fetch buffer / instruction queue。
- branch predictor 训练和 flush 统计细化。

验收标准：

- `agent_event_loop`、`agent_tool_dispatch`、`perf_branch_loop` 有 before/after 数据。
- 证明 mispredict、flush 或 ifetch wait 至少有一项下降。

## 4. Stage P2：memory/cache/bus 优化

目标：减少 load/store、cache miss 和总线等待对流水线的阻塞。

优先级建议：

1. 细分 D-cache / bus stall reason。
2. D-cache write buffer，让 store 不总是阻塞后续流水线。
3. cache refill critical-word-first，让 miss 后先返回当前需要的 word。
4. AHB burst refill，用 burst 填 4-word cache line。
5. I-cache prefetch 和简单 stream buffer。
6. 更长期再考虑 non-blocking cache / MSHR。

验收标准：

- `perf_memcpy`、`perf_pointer_chase`、`agent_int8_matvec` 有 before/after 数据。
- 能说明 CPI 改善来自哪类 stall 减少，而不是只看总 cycle。

## 5. Stage P3：ISA / runtime 扩展

目标：给 agent runtime 和 tiny inference 增加小而明确的指令能力，不直接跳到完整 RVV 或大矩阵 ISA。

候选方向：

- RV32B bitmanip 子集：`clz/ctz/cpop/andn/orn/xnor/rol/ror`。
- 轻量 atomic 或同步原语，服务 ring buffer / task queue。
- RV32C compressed instruction，提高 I-cache 有效容量。
- custom int8 dot-product：`dot4.s8`、`dot4.u8`、`mac4.s8`。
- saturating / clamp / pack / unpack 指令，服务 token 和量化小算子。

验收标准：

- decoder、EX 单元、hazard/forwarding、汇编宏、testbench、软件 workload 全链路齐全。
- custom 指令必须和 CPU-only baseline 比较。

## 6. Stage P4：Agent SoC 与小型加速器

目标：从“CPU-only workload”推进到“CPU 调度 + 外设/加速器协同”。

优先方向：

- 更稳定的 timer/interrupt controller。
- UART 输出 agent demo 过程和性能计数。
- scratchpad memory。
- 简单 DMA。
- MMIO 形式的 int8 dot/matvec accelerator。

第一版 accelerator 可以是 MMIO 设备，而不是直接改 ISA：

```text
rv32i_agent_matrix_accel
  control/status register
  source/destination base
  shape/stride
  int8 MAC datapath
  done/irq
```

验收标准：

- CPU 配置 accelerator。
- accelerator 访问 SRAM 或本地 scratchpad。
- polling 或 interrupt 都能完成。
- 与 CPU-only / custom instruction 版本比较性能。

## 7. Stage P5：FPGA / PPA 闭环

目标：让性能优化和真实实现代价挂钩。

需要逐步建立：

- Verilator lint baseline。
- Yosys synthesis baseline。
- OpenSTA 或 FPGA timing baseline。
- FPGA resource / Fmax 报告。
- UART/timer/agent demo 的板级或近板级验证。

验收标准：

- 每个大优化不仅有 cycle/CPI 数据，也有面积/频率/复杂度记录。
- 避免为了仿真 cycle 降低而引入不可收敛的时序路径。

## 8. 近期执行顺序

当前最推荐的下一步仍然沿 Stage P0 推进，但前两个 workload 与 perf 入口已经落地：

1. 新增 agent 侧 workload：`agent_token_scan` 和 `agent_int8_dot`。
2. 在 cache/bus 层补 icache refill、dcache refill、AHB wait-state 计数器。
3. 有了 branch/memory/agent/int8 四类数据后，再决定 P1/P2/P3 的第一刀。

## 9. 暂不优先做

短期不优先：

- 乱序执行。
- 双发射/多发射。
- 完整 RVV。
- 完整 Linux-capable MMU/privilege stack。
- 多核 cache coherence。
- 大而全的矩阵 ISA。

这些方向不是不能做，而是现在会把项目拉离“可验证、可测量、可持续演进”的主线。
