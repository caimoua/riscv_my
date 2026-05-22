# RV32I 项目路线图

最后更新：2026-05-22

本文是路线图入口。当前项目不再按“先把 toy CPU 收口成可交付 IP，再以后有空做性能”的方式推进。新的主线是：

```text
从 toy RV32IM core 继续演进为 workload-driven RISC-V Agent Core。
```

详细执行路线以 `docs/RV32I_WORKLOAD_DRIVEN_ROADMAP.md` 为准。`docs/RV32I_XUANTIE_AGENT_ROADMAP.md` 继续作为面向 agent/AIoT 方向的背景分析。

## 定位纠偏

当前 CPU 仍然是一个简单的学习/实验核：

- 单发射、顺序执行、五级流水。
- RV32IM。
- blocking I-cache / D-cache。
- blocking、single outstanding AHB-Lite path。
- 简单 BHT/BTB 分支预测。
- machine mode only。
- 无 MMU、无 Linux、无 atomic、无 vector、无 burst、无多个 outstanding。

`rv32i_cached_ahb_master_top` 仍然是当前最干净的集成边界，但它不是项目终点。后续把它当作性能画像和微架构演进的稳定实验壳，而不是“已经交付收口”的产品边界。

## 新阶段总览

```text
Stage P0：性能画像基线
  建立 benchmark、细分性能计数器、统一性能日志，回答当前 CPU 慢在哪里。

Stage P1：前端与控制流优化
  围绕分支密集和函数调用密集 workload，优化 BHT/BTB、RAS、JALR target、I-cache prefetch/fetch buffer。

Stage P2：memory/cache/bus 优化
  围绕 load/store、cache miss 和 bus wait，推进 write buffer、critical-word-first、AHB burst、prefetch。

Stage P3：ISA / runtime 扩展
  以 agent runtime 和 tiny inference 为目标，增加 bitmanip、轻量同步、compressed、int8 dot/custom ISA。

Stage P4：Agent SoC 与小型加速器
  建立 CPU 调度 + scratchpad/DMA/MMIO accelerator/timer interrupt 的协同路径。

Stage P5：FPGA / PPA 闭环
  把性能收益和 lint、综合、时序、面积、Fmax、FPGA demo 绑定起来。
```

## 推进规则

后续所有优化遵守：

1. 先测量，再优化。
2. 每个微架构改动都要有 before/after 数据。
3. 新 RTL 必须有 directed testbench 或明确的验证入口。
4. 用户给出 VCS PASS 前，新增测试只标 `PENDING`。
5. 优先服务 agent/runtime workload：event loop、tool dispatch、token scan、int8 dot/matvec、队列、状态机。
6. 不因为“看起来更高级”就跳到乱序、多发射、完整 RVV、Linux/MMU 或多核 coherence。

## 近期重点

现在优先进入 Stage P0：

1. `docs/RV32I_PERF_BASELINE.md` 已建立，用于定义性能指标和表格格式。
2. P0.2 第一批 core 内部细分计数器已接入 RTL/top/testbench，并已由用户确认新版 `rv32i_perf_counter_tb` VCS PASS。
3. P0.3 第一批 `perf_branch_loop` 和 `agent_event_loop` workload 已新增，对应 MEMH 已生成。
4. `rv32i_perf_baseline_tb` 已新增，可通过 plusarg 选择 workload 并输出统一 `[PERF]` / `PERF_CSV`。
5. `perf` suite 已接入回归列表，并已由用户确认 VCS PASS。
6. 第二批 `perf_memcpy` 和 `perf_pointer_chase` workload 已新增，对应 MEMH 已生成，并已由用户确认 VCS PASS。
7. 继续补 cache/bus 层的 refill、wait-state 计数器。
8. 有了 branch/memory/agent/int8 baseline 后，再决定第一轮优化做前端、cache/bus 还是 ISA/runtime。

旧的 Stage A/A1-A5 成果仍然保留为工程基础：自动化回归、软件镜像流、ISA 基础测试、质量检查入口和 AHB master 集成边界都继续使用。但它们不再定义项目终点。
