# 项目状态

最后更新：2026-05-24

这是后续 Codex 会话的第一入口。继续工作前先读这个文件，再读 `docs/RV32I_WORKLOAD_DRIVEN_ROADMAP.md`，再按需读取 `docs/INTERFACE_INDEX.md` 和 `docs/VERIFICATION_MATRIX.md`，避免每次重新扫描大量 RTL。

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

后续大方向已经从“把 toy CPU 收口成交付 IP”调整为“继续把当前 toy RV32IM core 演进成 workload-driven RISC-V Agent Core”。详细路线以 `docs/RV32I_WORKLOAD_DRIVEN_ROADMAP.md` 为准，入口摘要见 `docs/RV32I_PROJECT_ROADMAP.md`。

```text
Stage P0：性能画像基线
  先建立 benchmark、细分性能计数器和统一性能日志，回答当前 CPU 慢在哪里。

Stage P1：前端与控制流优化
  优化 BHT/BTB、RAS、JALR target、I-cache prefetch/fetch buffer。

Stage P2：memory/cache/bus 优化
  推进 write buffer、critical-word-first、AHB burst、prefetch 等方向。

Stage P3：ISA / runtime 扩展
  面向 agent runtime 和 tiny inference 增加 bitmanip、轻量同步、compressed、int8 dot/custom ISA。

Stage P4/P5：Agent SoC、小型加速器、FPGA/PPA 闭环
  从 CPU-only baseline 推进到软硬协同 demo，并记录面积/频率/时序代价。
```

当前应优先进入 Stage P0。旧 Stage A 的自动化回归、软件镜像流、ISA 基础测试、质量检查入口和 AHB master 集成边界仍然作为工程基础保留，但不再定义项目终点。近期优先级是：建立性能画像 baseline、细分 stall reason 计数器、增加 perf/agent workload、接入 `perf` regression suite，然后基于数据决定第一轮优化做前端、cache/bus 还是 ISA/runtime。

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
- Stage A3 第一版项目内 ISA 基础测试子集：
  - `software/asm/isa_basic.S`
  - `software/bin/isa_basic.memh`
  - `sim/testcases/rv32i_pipe_isa_basic_tb.sv`
  - 覆盖 RV32I arithmetic/branch/jump/load-store 和 RV32M mul/div/rem 基础行为。
  - 已接入 `isa/core/full` 回归 suite，并由用户确认 VCS PASS。
- Stage A4 第一版质量检查入口：
  - `tools/quality/run_quality_checks.ps1`
  - `tools/quality/run_quality_checks.sh`
  - `project/constraints/rv32i_cached_ahb_master_top.sdc`
  - `docs/RV32I_QUALITY_CHECKS.md`
  - 支持 filelist/SDC 基础检查，并可选接入 Verilator lint、Yosys synthesis/check 和 OpenSTA timing。
- Stage P0.1 性能画像口径文档：
  - `docs/RV32I_PERF_BASELINE.md`
  - 定义现有性能指标、派生指标、stall reason 计数器口径、benchmark 分类、统一日志格式和 baseline 表格模板。
- Stage P0.2 第一批细分性能计数器：
  - `rv32i_perf_counter` 已新增 `load_use/ifetch/if_discard/mem_wait/muldiv/branch_redirect/commit_redirect` 计数器。
  - `rv32i_pipe_core` 已把现有流水线原因信号归类成互斥 stall bucket，并透出对应 debug 口。
  - cached top、AHB master top、AHB matrix SoC top 和 APB SoC top 已透传新 debug 口。
  - `rv32i_perf_counter_tb` 已更新，并由用户确认新版 VCS PASS。
- Stage P0.2 cache/bus 扩展计数器：
  - `rv32i_icache` / `rv32i_dcache` 已新增 refill cycle 计数器。
  - `rv32i_mem_bus`、`rv32i_mem_bus_ahb` 和 `rv32i_ahb_master_bus` 已新增 bus wait cycle 计数器。
  - cached top、AHB master top、AHB matrix SoC top 和 APB SoC top 已透传 `dbg_icache_refill_cycle`、`dbg_dcache_refill_cycle`、`dbg_bus_wait_cycle`。
  - `rv32i_perf_baseline_tb` 已把这三个字段追加到 `[PERF]` 和 `PERF_CSV` 输出；当前等待用户重新运行 `perf` regression，验证状态为 `PENDING`。
- Stage P0.3 第一批 perf/agent workload：
  - `software/asm/perf_branch_loop.S` 已新增，作为 branch-heavy 性能画像 workload，签名 `0x0b120001`。
  - `software/asm/agent_event_loop.S` 已新增，作为 CPU-only agent event queue / dispatch loop workload，签名 `0x0a6e0001`。
  - `software/asm/perf_memcpy.S` 已新增，作为顺序 load/store stream 性能画像 workload，签名 `0x0c0f0001`，并由用户确认 VCS PASS。
  - `software/asm/perf_pointer_chase.S` 已新增，作为 dependent load / conflict miss 性能画像 workload，签名 `0x0c450001`，并由用户确认 VCS PASS。
  - 四个 workload 已接入 `software/Makefile`，并已生成 `software/bin/perf_branch_loop.memh`、`software/bin/perf_memcpy.memh`、`software/bin/perf_pointer_chase.memh` 与 `software/bin/agent_event_loop.memh`。
  - `sim/testcases/rv32i_perf_baseline_tb.sv` 已新增，复用 `rv32i_cached_ahb_master_top` 边界，通过 plusarg 加载 workload 并输出统一 `[PERF]` / `PERF_CSV`。
  - `sim/regress/regression_list.txt`、PowerShell/Bash 回归入口已接入 `perf` suite；用户已确认 `perf` regression VCS PASS，日志目录为 `sim/log/regress/20260522_171940-perf`。
  - 用户已提供 `PERF_CSV` 数据，第一张 `baseline-ahb-master` 性能表已填入 `docs/RV32I_PERF_BASELINE.md`。
  - 当前 baseline：`perf_branch_loop` 为 `cycle=1393`、`instret=495`、`CPI=2.814`；`perf_memcpy` 为 `cycle=4037`、`instret=1111`、`CPI=3.634`；`perf_pointer_chase` 为 `cycle=2667`、`instret=446`、`CPI=5.980`；`agent_event_loop` 为 `cycle=1045`、`instret=217`、`CPI=4.816`。
- 项目级 Verilog/SystemVerilog 风格规范：
  - `docs/RV32I_VERILOG_STYLE.md`
  - 参考 lowRISC/OpenTitan/Verible/Cummings 等公开工程规范，定义本项目 RTL/testbench 的命名、组合/时序逻辑、FSM、握手、reset、实例化、assertion 和 lint 方向。
- 玄铁式 Agent Core 路线分析：
  - `docs/RV32I_XUANTIE_AGENT_ROADMAP.md`
  - 将后续方向从泛化 CPU/SoC demo 收敛为面向 agent runtime 的调度、控制流、内存访问和轻量 AI 加速。
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
  - CPU IP 交付说明第一版：`docs/RV32I_CPU_IP_DELIVERY.md`。
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
  - `software/asm/ahb_matrix_apb_soc.S`
  - `software/asm/cached_system_smoke.S`
  - `software/asm/cached_ahb_master.S`
  - `software/asm/cached_timer.S`
  - `software/asm/cached_uart.S`
  - `software/asm/cached_timer_irq.S`
  - `software/asm/cached_access_fault.S`
  - `software/asm/cached_instr_access_fault.S`
  - `software/asm/cached_misaligned_trap.S`
  - `software/asm/pipe_branch_predict.S`
  - `software/asm/pipe_dynamic_branch_predict.S`
  - `software/asm/pipe_branch_predict_param.S`
  - `software/asm/pipe_muldiv.S`
  - `software/asm/pipe_core.S`
  - `software/asm/trap_csr.S`
  - `software/asm/core_smoke.S`
  - `software/asm/pipe_icache.S`
  - `software/asm/pipe_dcache.S`
  - `software/asm/pipe_cached_bus.S`
  - `software/asm/isa_basic.S`
  - `software/asm/perf_branch_loop.S`
  - `software/asm/perf_memcpy.S`
  - `software/asm/perf_pointer_chase.S`
  - `software/asm/agent_event_loop.S`
  - `software/linker/rv32i_flash.ld`
  - `software/linker/rv32i_rom0.ld`
  - `software/scripts/bin_to_memh.py`
  - `software/bin/ahb_matrix_soc.memh`
  - `software/bin/ahb_matrix_apb_soc.memh`
  - `software/bin/cached_system_smoke.memh`
  - `software/bin/cached_ahb_master.memh`
  - `software/bin/cached_timer.memh`
  - `software/bin/cached_uart.memh`
  - `software/bin/cached_timer_irq.memh`
  - `software/bin/cached_access_fault.memh`
  - `software/bin/cached_instr_access_fault.memh`
  - `software/bin/cached_misaligned_trap.memh`
  - `software/bin/pipe_branch_predict.memh`
  - `software/bin/pipe_dynamic_branch_predict.memh`
  - `software/bin/pipe_branch_predict_param.memh`
  - `software/bin/pipe_muldiv.memh`
  - `software/bin/pipe_core.memh`
  - `software/bin/trap_csr.memh`
  - `software/bin/core_smoke.memh`
  - `software/bin/pipe_icache.memh`
  - `software/bin/pipe_dcache.memh`
  - `software/bin/pipe_cached_bus.memh`
  - `software/bin/isa_basic.memh`
  - `software/bin/perf_branch_loop.memh`
  - `software/bin/perf_memcpy.memh`
  - `software/bin/perf_pointer_chase.memh`
  - `software/bin/agent_event_loop.memh`
  - `rv32i_ahb_matrix_soc_top_tb` 通过 `$readmemh` 加载 flash 内容。
  - `rv32i_cached_system_top_tb`、`rv32i_cached_system_ahb_top_tb` 和 `rv32i_cached_ahb_master_top_tb` 已改为通过 `$readmemh` 加载 ROM 内容，并已由用户确认 VCS PASS。
  - `rv32i_cached_timer_tb` 和 `rv32i_cached_uart_tb` 已改为通过 `$readmemh` 加载 ROM 内容，并已由用户确认 `mmio` suite VCS PASS。
  - `rv32i_cached_timer_irq_tb`、`rv32i_cached_access_fault_tb`、`rv32i_cached_instr_access_fault_tb` 和 `rv32i_cached_misaligned_trap_tb` 已改为通过 `$readmemh` 加载 ROM 内容，并已由用户确认 VCS PASS。
  - `rv32i_pipe_branch_predict_tb`、`rv32i_pipe_dynamic_branch_predict_tb`、`rv32i_pipe_branch_predict_param_tb` 和 `rv32i_pipe_muldiv_tb` 已改为通过 `$readmemh` 加载指令内容，并已由用户确认 VCS PASS。
  - `rv32i_pipe_core_tb` 和 `rv32i_trap_csr_tb` 已改为通过 `$readmemh` 加载指令内容，并已由用户确认 VCS PASS。
  - `rv32i_core_tb`、`rv32i_pipe_icache_tb`、`rv32i_pipe_dcache_tb` 和 `rv32i_pipe_cached_bus_tb` 已改为通过 `$readmemh` 加载指令内容，并已由用户确认 full regression PASS。
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
  - 支持可选软件镜像构建入口：PowerShell `-BuildSoftware`，Bash `--build-software`。
  - 本地已完成 PowerShell dry-run 和 Bash 语法/dry-run 检查。
  - 用户已在 VCS 环境确认 `smoke` suite PASS。
  - 用户已在 VCS 环境确认 `core/cache/soc/full` suite PASS，Stage A1 收口。

## 验证状态摘要

详细状态见 `docs/VERIFICATION_MATRIX.md`。

当前 Phase 6 第一轮 `rv32i_pipe_core` 仿真期 assertion 已加入，并由用户确认 VCS 回归 PASS。Stage A1 自动化回归入口第一版已完成，`smoke/core/cache/soc/full` suite 均已由用户确认 VCS PASS。Stage A2 第一轮已把 cached system / AHB master 相关 directed tests 从手写机器码迁移到软件镜像流，相关 testbench 已由用户确认 VCS PASS。Stage A2 第二轮已迁移 cached timer / UART，并给回归脚本加入软件镜像构建和缺失检查；用户已确认 `mmio` suite VCS PASS。Stage A2 第三轮已迁移 timer IRQ、access fault、instruction access fault 和 misaligned trap 相关 cached directed tests，并已由用户确认 VCS PASS。Stage A2 第四轮已迁移 branch predict 和 RV32M pipeline directed tests，并已由用户确认 VCS PASS。Stage A2 第五轮已迁移 `rv32i_pipe_core_tb` 和 `rv32i_trap_csr_tb` 到软件镜像流，并已由用户确认 VCS PASS。Stage A2 第六轮已把剩余 CPU 程序型 directed tests 一次性迁移到软件镜像流，并已由用户确认 full regression PASS，日志目录为 `sim/log/regress/20260520_173852-full`。Stage A3 第一版项目内 ISA 基础测试子集已新增并接入 `isa/core/full` suite，用户已确认 `rv32i_pipe_isa_basic_tb` VCS PASS：`cycle=476`、`instret=184`、`stall_cycle=190`、`flush_cycle=49`、`branch_count=48`、`branch_mispredict_count=48`。Stage A4 第一版质量检查入口已新增，PowerShell `basic` suite 已通过 filelist/SDC 检查，`all -DryRun` 已验证命令路径，Bash 脚本已通过语法检查；本机未安装 Verilator/Yosys/OpenSTA，真实 lint/synth/timing 运行当前为工具缺失导致的 `SKIP`。Stage A5 CPU IP 交付文档第一版已补齐，新增 `docs/RV32I_CPU_IP_DELIVERY.md` 并把 README、接口索引和 AHB 文档入口统一到 `rv32i_cached_ahb_master_top`。Stage P0.2 第一批 core 内部细分性能计数器已完成 RTL 和 standalone testbench 更新；用户已确认新版 `rv32i_perf_counter_tb` VCS PASS。Stage P0.2 cache/bus 扩展计数器已接入 RTL/top/perf testbench，等待用户重新运行 `perf` regression 确认。Stage P0.3 第一批 `perf_branch_loop` 和 `agent_event_loop` workload、`rv32i_perf_baseline_tb`、`perf` suite 入口已新增；用户已确认第一版 `perf` regression VCS PASS，并已提供 `PERF_CSV`，第一张 `baseline-ahb-master` 性能表已形成。Stage P0.3 第二批 `perf_memcpy` 和 `perf_pointer_chase` memory/cache workload 已新增并接入 `perf` suite；用户已确认新版 `perf` regression VCS PASS，并已提供 `PERF_CSV`，memory/cache 性能 baseline 已形成。Linux 回归机暂未配置 `riscv-none-elf-gcc`，因此 `--build-software` 会停在工具链预检查；使用已生成 MEMH 的普通 `make sim` 路径已确认通过。

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

1. 重新运行 `perf` regression，确认 P0.2 cache/bus 扩展计数器输出并记录新版 `PERF_CSV`。
2. Stage P0.3 后续扩展：新增 `agent_token_scan`、`agent_int8_dot`。
3. 并行项：在 Linux/CI 或本机安装 Verilator/Yosys 后运行 `tools/quality` 的 `lint/synth/all` suite，形成第一版 warning baseline。

## 上下文规则

后续 Codex 会话：

1. 先读本文件。
2. 再读 `docs/RV32I_WORKLOAD_DRIVEN_ROADMAP.md`，确认任务是否符合 Stage P0/P1/P2/P3/P4/P5。
3. 再按任务读取 `docs/INTERFACE_INDEX.md`、`docs/VERIFICATION_MATRIX.md` 和相关 RTL/testbench。
4. 默认把 `rv32i_cached_ahb_master_top` 当作当前稳定实验边界，而不是最终产品交付目标。
5. 任何 RTL/testbench 新增或重构都要遵守 `docs/RV32I_VERILOG_STYLE.md`；旧文件在 touched scope 内逐步收敛。
6. 新增测试在用户给出 VCS PASS 前只能标记为 `PENDING`。
7. 用户确认 PASS 后，再更新 `docs/VERIFICATION_MATRIX.md`、本文件，并提交。
