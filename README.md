# CPU_PRJ

## 当前稳定实验/集成边界

当前项目不会把“交付 CPU IP”当作终点。后续主线是把这个 toy RV32IM core 继续演进为 workload-driven RISC-V Agent Core。当前如果需要一个稳定的集成壳、性能画像入口或外部 SoC 连接边界，优先使用：

```text
rv32i_cached_ahb_master_top
  rv32i_pipe_core
  rv32i_icache
  rv32i_dcache
  rv32i_ahb_master_bus
  external AHB-Lite master interface
```

它对外只暴露一个 AHB-Lite master port，外部 SoC 负责 boot ROM/flash、SRAM、MMIO 外设和 default error slave。这个边界是当前最干净的实验边界，不代表项目已经接近产品级交付。接口说明见 `docs/RV32I_CPU_IP_DELIVERY.md`。

## 当前 AHB Matrix SoC 工作

当前 SoC 集成采用项目内自研的 AHB-Lite matrix wrapper，没有把第三方 AE350/Andes/ARM IP 直接拷进仓库：

```text
rv32i_ahb_matrix_soc_top
  rv32i_cached_ahb_master_top
  rv32i_ahb_lite_matrix_1m4s
```

VCS 运行命令：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_ahb_matrix_soc_top_tb.sv TOP_NAME=rv32i_ahb_matrix_soc_top_tb
```

这个测试使用的 flash 程序位于 `software/asm/ahb_matrix_soc.S`，仿真时通过 `software/bin/ahb_matrix_soc.memh` 加载。重新生成命令：

```bash
cd software
make
```

Stage A2 开始，部分 directed test 也改为加载软件镜像：

```text
software/asm/cached_system_smoke.S  -> software/bin/cached_system_smoke.memh
software/asm/cached_ahb_master.S    -> software/bin/cached_ahb_master.memh
software/asm/cached_timer.S         -> software/bin/cached_timer.memh
software/asm/cached_uart.S          -> software/bin/cached_uart.memh
software/asm/cached_timer_irq.S     -> software/bin/cached_timer_irq.memh
software/asm/cached_access_fault.S  -> software/bin/cached_access_fault.memh
software/asm/cached_instr_access_fault.S
  -> software/bin/cached_instr_access_fault.memh
software/asm/cached_misaligned_trap.S
  -> software/bin/cached_misaligned_trap.memh
software/asm/pipe_branch_predict.S
  -> software/bin/pipe_branch_predict.memh
software/asm/pipe_dynamic_branch_predict.S
  -> software/bin/pipe_dynamic_branch_predict.memh
software/asm/pipe_branch_predict_param.S
  -> software/bin/pipe_branch_predict_param.memh
software/asm/pipe_muldiv.S
  -> software/bin/pipe_muldiv.memh
software/asm/pipe_core.S
  -> software/bin/pipe_core.memh
software/asm/trap_csr.S
  -> software/bin/trap_csr.memh
software/asm/core_smoke.S
  -> software/bin/core_smoke.memh
software/asm/pipe_icache.S
  -> software/bin/pipe_icache.memh
software/asm/pipe_dcache.S
  -> software/bin/pipe_dcache.memh
software/asm/pipe_cached_bus.S
  -> software/bin/pipe_cached_bus.memh
software/asm/isa_basic.S
  -> software/bin/isa_basic.memh
software/asm/perf_branch_loop.S
  -> software/bin/perf_branch_loop.memh
software/asm/perf_memcpy.S
  -> software/bin/perf_memcpy.memh
software/asm/perf_pointer_chase.S
  -> software/bin/perf_pointer_chase.memh
software/asm/agent_event_loop.S
  -> software/bin/agent_event_loop.memh
```

对应 testbench 默认使用 `+ROM_MEMH` 或 `+IMEM_MEMH` 可覆盖的软件镜像，不再在 SystemVerilog 里直接手写程序机器码。

RISC-V GNU 工具链安装说明见 `docs/RISCV_TOOLCHAIN.md`。

这是一个面向学习和面试准备的 RISC-V CPU 项目，目标是系统性练习 CPU 微架构、简单 SoC 集成和验证流程。

中长期方向已经从单纯 CPU/SoC demo 或交付收口调整为：

```text
从 toy RV32IM core 演进为 workload-driven RISC-V Agent Core
```

主路线见 `docs/RV32I_WORKLOAD_DRIVEN_ROADMAP.md`，入口摘要见 `docs/RV32I_PROJECT_ROADMAP.md`。玄铁式 agent 背景分析见 `docs/RV32I_XUANTIE_AGENT_ROADMAP.md`。后续会先建立性能画像 baseline，再基于数据推进前端、cache/bus、ISA/runtime 和 int8/matrix 加速方向。

## 项目导航入口

后续维护和协作时，优先阅读这三份文件，避免每次重新扫描大量 RTL：

- `docs/PROJECT_STATUS.md`：当前完成状态、未完成方向和上下文规则
- `docs/RV32I_WORKLOAD_DRIVEN_ROADMAP.md`：后续所有性能驱动演进的主路线图
- `docs/RV32I_PROJECT_ROADMAP.md`：路线图入口摘要
- `docs/RV32I_PERF_BASELINE.md`：Stage P0 性能指标、benchmark 和日志口径
- `docs/RV32I_VERILOG_STYLE.md`：RTL/testbench 统一写法规范
- `docs/INTERFACE_INDEX.md`：主要 RTL 模块接口索引
- `docs/VERIFICATION_MATRIX.md`：testbench、运行命令和 PASS/PENDING 状态
- `docs/RV32I_XUANTIE_AGENT_ROADMAP.md`：面向 agent 的玄铁式 CPU 路线分析

关键设计决策记录放在 `docs/adr/`。

## 当前状态

- 已完成一版清晰、可解释的 RV32I 单周期 core。
- 已完成基础五级流水线，包含 forwarding、load-use stall、memory wait-state、branch/jump flush 和性能计数器。
- 已实现第一版静态分支预测，包含 IF 阶段 JAL/backward-branch 预测和 branch/mispredict 计数器；directed tests 已通过 VCS。
- pipeline core 已完成第一版最小 trap/CSR 机制，支持 `mtvec/mepc/mcause`、`ecall/ebreak/illegal` trap、`mret` 返回和 commit 阶段 precise exception。说明见 `docs/RV32I_TRAP_CSR.md`。
- 已完成 blocking 2-way I-cache 和 D-cache，cache line 为 4 个 32-bit word，tag/data 存储通过 SRAM-style 模型访问。说明见 `docs/RV32I_ICACHE.md` 和 `docs/RV32I_DCACHE.md`。
- 已完成内部 memory bus，支持 I-cache/D-cache 两个 master 到 ROM/SRAM/MMIO 三类 slave 的 blocking 访问、D 优先仲裁和地址 decode。说明见 `docs/RV32I_MEM_BUS.md`。
- 已新增 `rv32i_cached_system_top`，把 pipeline core、I-cache、D-cache 和 memory bus 固化成一个可复用系统顶层。说明见 `docs/RV32I_CACHED_SYSTEM_TOP.md`。
- 已新增 AHB-Lite 总线路径和 `rv32i_cached_system_ahb_top`，directed tests 已通过 VCS。说明见 `docs/RV32I_AHB.md`。
- 已新增 `rv32i_cached_ahb_master_top`，作为更标准的 CPU subsystem 边界，对外只暴露 AHB-Lite master 接口；directed test 已通过 VCS。交付说明见 `docs/RV32I_CPU_IP_DELIVERY.md`。
- 已新增 Stage A3 第一版 RV32I/RV32M ISA 基础测试子集，说明见 `docs/RV32I_ISA_TESTS.md`；已通过 VCS。
- 已新增 Stage A4 第一版质量检查入口，支持 filelist/SDC 检查，并可选接入 Verilator lint、Yosys 综合和 OpenSTA 时序检查。说明见 `docs/RV32I_QUALITY_CHECKS.md`。
- 已新增 workload-driven Agent Core 主路线图，并新增 Stage P0.1 性能画像口径文档 `docs/RV32I_PERF_BASELINE.md`；Stage P0.2 第一批 core 内部细分性能计数器已经接入 RTL/top/testbench；Stage P0.3 第一批 `perf_branch_loop` 和 `agent_event_loop` workload 已由用户确认 VCS PASS，第二批 `perf_memcpy` 和 `perf_pointer_chase` 也已由用户确认 VCS PASS。
- 已新增项目级 Verilog/SystemVerilog 风格规范 `docs/RV32I_VERILOG_STYLE.md`，后续 RTL/testbench 新增和重构按该规范执行。
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

自动化回归入口：

```bash
cd sim
bash ./regress/run_regression.sh --suite smoke --dry-run
bash ./regress/run_regression.sh --suite smoke
bash ./regress/run_regression.sh --suite perf --dry-run
```

Windows PowerShell 也可以从仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sim\regress\run_regression.ps1 -Suite smoke -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File .\sim\regress\run_regression.ps1 -Suite smoke
powershell -NoProfile -ExecutionPolicy Bypass -File .\sim\regress\run_regression.ps1 -Suite perf -DryRun
```

当前支持 `smoke/core/cache/ahb/mmio/soc/isa/perf/full` 几个回归集合，日志保存在 `sim/log/regress/`。

Perf workload 单独运行示例：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_perf_baseline_tb.sv TOP_NAME=rv32i_perf_baseline_tb SIM_PLUSARGS="+WORKLOAD=perf_branch_loop +ROM_MEMH=../software/bin/perf_branch_loop.memh +SIGNATURE=0b120001"
make sim TB_FILE=./testcases/rv32i_perf_baseline_tb.sv TOP_NAME=rv32i_perf_baseline_tb SIM_PLUSARGS="+WORKLOAD=perf_memcpy +ROM_MEMH=../software/bin/perf_memcpy.memh +SIGNATURE=0c0f0001"
make sim TB_FILE=./testcases/rv32i_perf_baseline_tb.sv TOP_NAME=rv32i_perf_baseline_tb SIM_PLUSARGS="+WORKLOAD=perf_pointer_chase +ROM_MEMH=../software/bin/perf_pointer_chase.memh +SIGNATURE=0c450001"
make sim TB_FILE=./testcases/rv32i_perf_baseline_tb.sv TOP_NAME=rv32i_perf_baseline_tb SIM_PLUSARGS="+WORKLOAD=agent_event_loop +ROM_MEMH=../software/bin/agent_event_loop.memh +SIGNATURE=0a6e0001"
```

基础质量检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\quality\run_quality_checks.ps1 -Suite basic
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\quality\run_quality_checks.ps1 -Suite all -DryRun
```

Linux/WSL：

```bash
bash tools/quality/run_quality_checks.sh --suite basic
bash tools/quality/run_quality_checks.sh --suite all --dry-run
```

流水线 core：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb
```

Standalone 性能计数器：

```bash
make sim TB_FILE=./testcases/rv32i_perf_counter_tb.sv TOP_NAME=rv32i_perf_counter_tb
```

Standalone 流水线控制：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_ctrl_tb.sv TOP_NAME=rv32i_pipe_ctrl_tb
```

静态分支预测：
```bash
make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_tb.sv TOP_NAME=rv32i_pipe_branch_predict_tb
```

Standalone 分支预测器：
```bash
make sim TB_FILE=./testcases/rv32i_branch_predictor_tb.sv TOP_NAME=rv32i_branch_predictor_tb
```

动态 BHT/BTB 分支预测：
```bash
make sim TB_FILE=./testcases/rv32i_pipe_dynamic_branch_predict_tb.sv TOP_NAME=rv32i_pipe_dynamic_branch_predict_tb
```

参数化 BHT/BTB 分支预测：
```bash
make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_param_tb.sv TOP_NAME=rv32i_pipe_branch_predict_param_tb
```

RV32M 乘除法扩展：
```bash
make sim TB_FILE=./testcases/rv32i_decoder_muldiv_tb.sv TOP_NAME=rv32i_decoder_muldiv_tb
make sim TB_FILE=./testcases/rv32i_pipe_muldiv_tb.sv TOP_NAME=rv32i_pipe_muldiv_tb
```

RV32I/RV32M ISA 基础子集：
```bash
make sim TB_FILE=./testcases/rv32i_pipe_isa_basic_tb.sv TOP_NAME=rv32i_pipe_isa_basic_tb
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

Stage P0.1 性能画像口径文档已经建立，Stage P0.2 第一批 core 内部细分性能计数器已经完成 RTL 和 standalone testbench 更新且已由用户确认 VCS PASS。Stage P0.3 第一批 `perf_branch_loop` 和 `agent_event_loop` workload 已经新增，`perf` regression suite 已接入，并已由用户确认 VCS PASS；第一张 `baseline-ahb-master` 性能表已经根据 `PERF_CSV` 填入 `docs/RV32I_PERF_BASELINE.md`。第二批 `perf_memcpy` 和 `perf_pointer_chase` memory/cache workload 也已由用户确认 VCS PASS，memory/cache 性能 baseline 已形成。后续继续补 agent/int8 类 workload，并在 cache/bus 层继续补 icache refill、dcache refill、AHB wait-state 计数器。同时继续完善质量检查：固定 lint warning baseline，在 Linux/CI 中接入 Verilator/Yosys，并补充真实综合/时序报告。
