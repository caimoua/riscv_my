# RV32I Performance Baseline

最后更新：2026-05-22

本文定义 Stage P0 的性能画像口径。当前目标不是立刻优化，而是先保证后续 benchmark、testbench 日志和 RTL 性能计数器使用同一套定义。

本文件记录：

- 现有可观测指标。
- 计划新增的 stall reason 计数器。
- benchmark / workload 表格格式。
- testbench 日志格式。
- baseline 记录规则。

## 1. 基本原则

1. **先记录原始计数，再计算派生指标。** 日志里必须保留 `cycle` 和 `instret`，CPI 只作为派生值。
2. **功能 PASS 和性能趋势分开。** benchmark 要先保证跑到 `ebreak` 且签名正确，再记录性能；早期不把 cycle 精确值做硬性 PASS 条件。
3. **计数口径稳定优先。** 如果后续发现一个计数器定义不清，先修文档和 testbench，再比较优化前后数据。
4. **before/after 必须同配置。** 比较性能时要固定软件镜像、cache 参数、branch predictor 参数、memory wait-state、总线模型和仿真入口。
5. **不重复解释同一停顿。** 细分 stall reason 时允许多个底层原因存在，但用于汇总的 top-level stall bucket 必须有优先级，避免总和大于 `stall_cycle` 后无法解释。

## 2. 当前可观测指标

当前 `rv32i_pipe_core` / cached top 已经透出以下计数器或事件。

| 指标 | 当前来源 | 含义 | 当前状态 |
| --- | --- | --- | --- |
| `cycle` | `dbg_cycle` | core 复位释放后的周期计数 | 已有 |
| `instret` | `dbg_instret` | 有效指令退休数 | 已有 |
| `stall_cycle` | `dbg_stall_cycle` | 粗粒度停顿周期 | 已有 |
| `flush_cycle` | `dbg_flush_cycle` | 粗粒度控制流重定向/flush 周期 | 已有 |
| `branch_count` | `dbg_branch_count` | EX 阶段解析并训练 predictor 的 B-type branch 数 | 已有 |
| `branch_mispredict_count` | `dbg_branch_mispredict_count` | B-type branch 预测错误数 | 已有 |
| `btb_hit_count` | `dbg_btb_hit_count` | B-type branch BTB 命中数 | 已有 |
| `btb_miss_count` | `dbg_btb_miss_count` | B-type branch BTB 未命中数 | 已有 |
| `bht_update_count` | `dbg_bht_update_count` | BHT 更新数 | 已有 |
| `icache_hit_count` | cached top debug | I-cache 命中数 | 已有 |
| `icache_miss_count` | cached top debug | I-cache miss 数 | 已有 |
| `dcache_hit_count` | cached top debug | D-cache 命中数 | 已有 |
| `dcache_miss_count` | cached top debug | D-cache miss 数 | 已有 |
| `bus_i_grant_count` | cached top debug | AHB master bus 授权 I 侧请求次数 | 已有 |
| `bus_d_grant_count` | cached top debug | AHB master bus 授权 D 侧请求次数 | 已有 |
| `bus_error` | cached top debug | 当前或最近总线错误观测 | 已有 |

## 3. 派生指标

testbench / 脚本可以从原始计数计算：

| 指标 | 公式 | 用途 |
| --- | --- | --- |
| `cpi` | `cycle / instret` | 总体每条指令平均周期 |
| `ipc` | `instret / cycle` | 单发射顺序核的利用率视角 |
| `stall_pct` | `stall_cycle / cycle * 100%` | 总停顿占比 |
| `flush_pct` | `flush_cycle / cycle * 100%` | 控制流清空占比 |
| `branch_mispredict_rate` | `branch_mispredict_count / branch_count` | 条件分支预测错误率 |
| `btb_hit_rate` | `btb_hit_count / (btb_hit_count + btb_miss_count)` | BTB 有效性 |
| `icache_miss_rate` | `icache_miss_count / (icache_hit_count + icache_miss_count)` | I-cache 行为 |
| `dcache_miss_rate` | `dcache_miss_count / (dcache_hit_count + dcache_miss_count)` | D-cache 行为 |

当分母为 0 时，日志中填 `NA`，不要填 0，避免误读。

## 4. 计划新增 stall reason 计数器

P0.1 先定义口径，P0.2 再实现 RTL / testbench 连接。当前 P0.2 第一批已覆盖 core 内部可直接观测的 `load_use/ifetch/if_discard/mem_wait/muldiv/redirect` 事件，cache refill 和 AHB wait-state 级别计数器后续在 cache/bus 层继续扩展。

### 4.1 顶层 bucket

后续推荐把 `stall_cycle` 拆成互斥 bucket。若同一周期多个原因同时成立，按如下优先级归类：

```text
commit_redirect_flush
branch_redirect_flush
mem_wait
muldiv_wait
load_use
ifetch_wait
if_discard
other_stall
```

说明：

- `commit_redirect_flush` 优先级最高，因为 trap / interrupt / mret 是架构级重定向。
- `branch_redirect_flush` 统计 EX 阶段预测错误或跳转纠正。
- `mem_wait` 代表后端因 D-side load/store 或 cache/bus 未 ready 而保持。
- `muldiv_wait` 代表多周期乘除法导致前端保持、EX/MEM 插 bubble。
- `load_use` 代表 load-use hazard 插入 bubble。
- `ifetch_wait` 代表取指侧未 ready。
- `if_discard` 代表 redirect 后丢弃旧取指返回。
- `other_stall` 作为兜底，理想情况下应接近 0。

当前 P0.2 第一批保持旧 `dbg_stall_cycle` / `dbg_flush_cycle` 口径不变；新增 stall reason 计数器只细分会进入旧 `stall_event` 的 core 内部原因，redirect 相关计数器作为单独 flush/redirect 观测项透出。

### 4.2 建议信号/计数器名称

| 新计数器 | 建议事件源 | 口径 |
| --- | --- | --- |
| `load_use_stall_cycle` | `load_use_stall` | 因 load-use hazard 导致 ID/EX bubble 的周期 |
| `ifetch_wait_cycle` | `if_stall` | 前端等待 imem/I-cache ready 的周期 |
| `if_discard_cycle` | `if_discard` | redirect 后丢弃旧取指返回的周期 |
| `mem_wait_cycle` | `mem_stall` | MEM 后端等待 dmem/D-cache/bus ready 的周期 |
| `muldiv_wait_cycle` | `ex_muldiv_stall` | EX 阶段等待 `rv32i_muldiv.ready` 的周期 |
| `branch_redirect_cycle` | `ex_redirect && !mem_stall && !commit_redirect` | EX 阶段控制流纠正导致的实际 flush 周期 |
| `commit_redirect_cycle` | `commit_redirect` | trap / interrupt / mret 导致的 flush 周期 |
| `bus_wait_cycle` | AHB transaction active and `!hready` | AHB wait-state 周期 |
| `icache_refill_cycle` | I-cache refill state | I-cache refill 占用周期 |
| `dcache_refill_cycle` | D-cache refill state | D-cache refill 占用周期 |

P0.2 第一批 RTL 输出端口为：

```text
dbg_load_use_stall_cycle
dbg_ifetch_wait_cycle
dbg_if_discard_cycle
dbg_mem_wait_cycle
dbg_muldiv_wait_cycle
dbg_branch_redirect_cycle
dbg_commit_redirect_cycle
```

其中 `rv32i_pipe_core` 内部的 stall reason 计数按 `mem_wait > muldiv_wait > load_use > ifetch_wait > if_discard` 的优先级做互斥归类，避免这些细分计数相加后超过粗粒度 `dbg_stall_cycle`。`dbg_branch_redirect_cycle` 复用原有 `dbg_flush_cycle` 的 EX redirect 口径；`dbg_commit_redirect_cycle` 单独统计 trap / interrupt / mret 这类 commit 阶段重定向，不改变旧 `dbg_flush_cycle` 的含义。

## 5. benchmark 分类

第一批 workload 不追求复杂，而是要能把不同瓶颈分开。

| 分类 | 建议镜像 | 主要观察点 | 状态 |
| --- | --- | --- | --- |
| branch loop | `software/asm/perf_branch_loop.S` | branch、mispredict、flush、BTB/BHT | VCS PASS |
| memcpy/memset | `software/asm/perf_memcpy.S` | D-cache、bus、store/load stall | VCS PASS |
| pointer chase | `software/asm/perf_pointer_chase.S` | 不规则 load、D-cache miss penalty | VCS PASS |
| agent event loop | `software/asm/agent_event_loop.S` | 分支、队列、调度循环 | VCS PASS |
| tool dispatch | `software/asm/agent_tool_dispatch.S` | JAL/JALR、dispatch table、branch predictor | TODO |
| token scan | `software/asm/agent_token_scan.S` | byte load、branch-heavy parser | TODO |
| int8 dot | `software/asm/agent_int8_dot.S` | load、sign extension、mul/macc pattern | TODO |
| int8 matvec | `software/asm/agent_int8_matvec.S` | nested loop、memory bandwidth、muldiv | TODO |

P0.3 第一批先落地 branch/agent 两个镜像，第二批继续补 memory/cache 两个镜像：

- `perf_branch_loop`：纯分支压力测试，用固定 64 次循环制造 backward branch、条件分支和跳转路径，主要看 branch/mispredict/flush/BTB/BHT。
- `agent_event_loop`：CPU-only agent 调度循环雏形，在 SRAM 初始化事件队列，循环 load 事件、按类型分派、更新 checksum 和 store signature，主要看分支密集调度循环、load/store 与 cache/bus 行为。
- `perf_memcpy`：顺序初始化、顺序拷贝、顺序校验 64 个 word，主要看连续 load/store、D-cache hit/miss 和 bus grant。
- `perf_pointer_chase`：构造 16 个 64B 间隔的 SRAM 节点并循环追踪指针，当前 cache 配置下这些节点映射到同一个 D-cache index，用来暴露 dependent load、conflict miss 和 refill 行为。

## 6. benchmark 结束和签名约定

建议所有 perf/agent 汇编程序统一使用：

```text
x29 = workload signature
x30 = fail code, 0 means pass
x31 = pass marker, 1 means pass
ebreak
```

testbench 结束条件：

1. 等待 `dbg_ebreak`。
2. 检查 `x30 == 0`。
3. 检查 `x31 == 1`。
4. 检查 `x29` 等于该 workload 的固定 signature。
5. 打印性能摘要。

性能 benchmark 可以允许数据结果写入 memory signature 区，但 testbench 必须至少检查一个不可被空跑伪造的结果，例如 checksum。

## 7. 统一日志格式

testbench 推荐打印两类行。

人读摘要：

```text
[PERF] name=agent_event_loop status=PASS
[PERF] cycle=... instret=... cpi=...
[PERF] stall=... flush=... branch=... mispredict=...
[PERF] ic_hit=... ic_miss=... dc_hit=... dc_miss=... bus_i=... bus_d=...
```

脚本友好的单行：

```text
PERF_CSV_HEADER,name,config,cycle,instret,cpi,stall_cycle,flush_cycle,load_use_stall,ifetch_wait,if_discard,mem_wait,muldiv_wait,branch_redirect,commit_redirect,branch_count,branch_mispredict,btb_hit,btb_miss,bht_update,ic_hit,ic_miss,dc_hit,dc_miss,bus_i_grant,bus_d_grant
PERF_CSV,agent_event_loop,baseline-ahb-master,0,0,0.000,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
```

P0 早期可以直接由 SystemVerilog `$display` 打印。后续再加脚本汇总到 CSV/Markdown。

## 8. baseline 表格模板

第一张 baseline 表先保存在本文或后续自动生成报告中。

| workload | config | cycle | instret | CPI | stall | flush | br | mispred | ic miss | dc miss | notes |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `rv32i_pipe_isa_basic_tb` | current directed test | 476 | 184 | 2.59 | 190 | 49 | 48 | 48 | NA | NA | 用户已确认 VCS PASS，非专用 perf workload |
| `perf_branch_loop` | baseline-ahb-master | 1393 | 495 | 2.814 | 828 | 68 | 193 | 68 | 7 | 0 | VCS PASS，log `20260522_171940-perf` |
| `perf_memcpy` | baseline-ahb-master | 4037 | 1111 | 3.634 | 2921 | 3 | 194 | 3 | 11 | 160 | VCS PASS，log `20260522_175530-perf` |
| `perf_pointer_chase` | baseline-ahb-master | 2667 | 446 | 5.980 | 2217 | 2 | 80 | 2 | 9 | 96 | VCS PASS，log `20260522_175530-perf` |
| `agent_event_loop` | baseline-ahb-master | 1045 | 217 | 4.816 | 809 | 18 | 54 | 18 | 18 | 25 | VCS PASS，log `20260522_171940-perf` |
| `agent_token_scan` | baseline | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TODO |
| `agent_int8_dot` | baseline | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TODO |

`rv32i_pipe_isa_basic_tb` 只作为已有数据锚点，不作为后续性能优化的主 benchmark。

### 8.1 第一批 PERF_CSV 原始记录

来源：用户在 VCS 环境运行 `perf` regression suite，日志目录 `sim/log/regress/20260522_171940-perf`。

```text
PERF_CSV,perf_branch_loop,baseline-ahb-master,1393,495,2.814,828,68,0,760,68,0,0,68,1,193,68,189,4,193,633,7,0,0,28,0
PERF_CSV,agent_event_loop,baseline-ahb-master,1045,217,4.816,809,18,16,544,18,231,0,18,1,54,18,45,9,54,352,18,17,25,69,40
```

第一批观察：

- `perf_branch_loop` 的 CPI 为 2.814，主要停顿来自 `ifetch_wait=760`，控制流相关 `branch_redirect=68`，分支预测错误率约 `68/193 = 35.2%`。
- `agent_event_loop` 的 CPI 为 4.816，主要停顿来自 `ifetch_wait=544` 和 `mem_wait=231`，D-cache 行为已经开始显现：`dc_hit=17`、`dc_miss=25`。
- 两个 workload 都出现 `commit_redirect=1`，这是结尾 `ebreak` 触发的提交阶段重定向观测项，后续分析时应和普通 branch redirect 分开看。

### 8.2 第二批 PERF_CSV 原始记录

来源：用户在 VCS 环境运行 `perf` regression suite，日志目录 `sim/log/regress/20260522_175530-perf`。

```text
PERF_CSV,perf_memcpy,baseline-ahb-master,4037,1111,3.634,2921,3,128,1446,3,1344,0,3,1,194,3,189,5,194,1919,11,128,160,44,256
PERF_CSV,perf_pointer_chase,baseline-ahb-master,2667,446,5.980,2217,2,64,711,2,1440,0,2,1,80,2,77,3,80,1252,9,128,96,36,288
```

第二批观察：

- `perf_memcpy` 的 CPI 为 3.634，`stall=2921`，主要来自 `ifetch_wait=1446` 和 `mem_wait=1344`；D-cache `dc_hit=128`、`dc_miss=160`，说明顺序访问仍被 blocking refill/write-through 路径明显拖慢。
- `perf_pointer_chase` 的 CPI 为 5.980，`mem_wait=1440` 高于 `ifetch_wait=711`，符合 dependent load + conflict miss workload 的预期；D-cache `dc_hit=128`、`dc_miss=96`，且 `bus_d_grant=288`，说明 D-side traffic 已经成为主瓶颈。
- 两个 memory/cache workload 都有明显 `load_use_stall`，`perf_memcpy=128`、`perf_pointer_chase=64`，后续分析时需要把真实 memory wait 和 load-use 依赖分开看。

## 9. 推荐 testbench 配置记录

每次记录 baseline 时必须写清楚：

- RTL git commit 或工作树说明。
- testbench 名称。
- software image 路径。
- `RESET_PC`。
- `ICACHE_INDEX_BITS`。
- `DCACHE_INDEX_BITS`。
- `BRANCH_PRED_INDEX_BITS`。
- memory wait-state 设置。
- 是否走 direct core memory、cached simple bus、cached AHB master 或 SoC wrapper。
- 仿真器和主要 plusargs。

示例：

```text
config=baseline-ahb-master
top=rv32i_perf_baseline_tb
rom=software/bin/agent_event_loop.memh
RESET_PC=0x00000000
ICACHE_INDEX_BITS=2
DCACHE_INDEX_BITS=2
BRANCH_PRED_INDEX_BITS=6
memory_model=tb_ahb_rom_sram_mmio_default
```

## 10. P0 状态

P0.1 已完成文档口径定义。

P0.2 第一批已经完成 RTL / wrapper / standalone testbench 改动：

1. `rv32i_perf_counter` 已新增 7 个细分事件输入和 7 个 32-bit 计数器输出。
2. `rv32i_pipe_core` 已把现有流水线信号归类成细分事件，并透出 debug 口。
3. cached top、AHB master top、AHB matrix SoC top 和 APB SoC top 已透传新 debug 口。
4. `rv32i_perf_counter_tb` 已覆盖新计数器的累加和 reset。
5. 用户已确认新版 `rv32i_perf_counter_tb` VCS PASS，`docs/VERIFICATION_MATRIX.md` 中 standalone performance counter 状态已恢复为 `PASS`。

P0.3 第一批已经新增两个 workload 和统一 perf testbench：

1. `software/asm/perf_branch_loop.S` 已新增，签名为 `0x0b120001`。
2. `software/asm/agent_event_loop.S` 已新增，签名为 `0x0a6e0001`。
3. `software/bin/perf_branch_loop.memh` 和 `software/bin/agent_event_loop.memh` 已由 `make -C software` 生成。
4. `sim/testcases/rv32i_perf_baseline_tb.sv` 已新增，通过 `+WORKLOAD/+ROM_MEMH/+SIGNATURE/+TIMEOUT` 选择 workload，并打印 `[PERF]` 与 `PERF_CSV`。
5. `sim/regress/regression_list.txt` 已接入 `perf` suite；用户已确认 `perf` regression VCS PASS，日志目录为 `sim/log/regress/20260522_171940-perf`。
6. 用户已提供两条 `PERF_CSV`，第一张 `baseline-ahb-master` 性能表已填写。

P0.3 第二批 memory/cache workload 已新增，并由用户确认 VCS PASS：

1. `software/asm/perf_memcpy.S` 已新增，签名为 `0x0c0f0001`。
2. `software/asm/perf_pointer_chase.S` 已新增，签名为 `0x0c450001`。
3. `software/bin/perf_memcpy.memh` 和 `software/bin/perf_pointer_chase.memh` 已由 `make -C software` 生成。
4. 两个 workload 已接入 `perf` regression suite，验证矩阵状态为 `PASS`。
5. 用户已提供两条 `PERF_CSV`，memory/cache 侧 baseline 表已填写。

单独运行示例：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_perf_baseline_tb.sv TOP_NAME=rv32i_perf_baseline_tb SIM_PLUSARGS="+WORKLOAD=perf_branch_loop +ROM_MEMH=../software/bin/perf_branch_loop.memh +SIGNATURE=0b120001"
make sim TB_FILE=./testcases/rv32i_perf_baseline_tb.sv TOP_NAME=rv32i_perf_baseline_tb SIM_PLUSARGS="+WORKLOAD=perf_memcpy +ROM_MEMH=../software/bin/perf_memcpy.memh +SIGNATURE=0c0f0001"
make sim TB_FILE=./testcases/rv32i_perf_baseline_tb.sv TOP_NAME=rv32i_perf_baseline_tb SIM_PLUSARGS="+WORKLOAD=perf_pointer_chase +ROM_MEMH=../software/bin/perf_pointer_chase.memh +SIGNATURE=0c450001"
make sim TB_FILE=./testcases/rv32i_perf_baseline_tb.sv TOP_NAME=rv32i_perf_baseline_tb SIM_PLUSARGS="+WORKLOAD=agent_event_loop +ROM_MEMH=../software/bin/agent_event_loop.memh +SIGNATURE=0a6e0001"
```

下一步继续补 `agent_token_scan` 和 `agent_int8_dot`，让 baseline 覆盖 parser/dispatch 和 int8 计算类 workload；同时准备在 cache/bus 层补 icache refill、dcache refill、AHB wait-state 计数器。
