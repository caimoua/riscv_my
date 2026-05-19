# RV32I 工程化重构计划

最后更新：2026-05-19

本文记录当前 RV32I/RV32IM core 从“功能型原型代码”继续走向“更可维护工程代码”的重构路线。目标不是推翻已有实现，而是在保持 directed tests 持续通过的前提下，小步拆分 `rv32i_pipe_core`，降低后续扩展和调试成本。

## 总体判断

当前代码适合作为学习型、原型级 CPU core：

- 功能覆盖较完整，已经包含五级流水、hazard、cache、trap/CSR、中断、AHB-Lite、MMIO timer/UART、RV32M、静态和动态分支预测。
- 接口命名和流水线寄存器命名比较清楚。
- 已有较多 directed test 和项目状态文档，适合继续迭代。

但从严谨工程代码、可维护 IP、团队协作项目的标准看，还需要继续重构：

- `rv32i_pipe_core` 顶层承担过多功能。
- 主要时序 always 块过大。
- 分支预测器、M 扩展识别、性能计数器、stall/flush 优先级仍和 core 顶层耦合较深。
- 缺少 assertion 和更细粒度模块级验证。

## 当前主要问题

### 1. `rv32i_pipe_core` 顶层过重

当前 core 顶层同时负责：

- PC 更新和 IF 取指
- BHT/BTB 分支预测
- 所有流水线寄存器
- M 扩展识别和乘除法单元调度
- ALU 输入选择和分支比较
- CSR/trap 调用
- LSU 调用
- 性能计数器
- stall/flush 控制

短期内这很直观，但随着功能继续增加，review、调试和局部修改都会变难。

### 2. 大 always 块可维护性不足

现在主要时序逻辑集中在一个较大的 `always @(posedge clk or negedge rst_n)` 中。它同时处理 reset、BHT/BTB 更新、性能计数器、PC/IFID、IDEX、EXMEM、MEMWB。

后续更工程化的方向是拆成：

```text
PC / IFID always
IDEX always
EXMEM always
MEMWB always
performance counter always
branch predictor update always
```

### 3. 分支预测器仍是原型式集成

当前动态预测器思路合理：

- direct-mapped BHT
- direct-mapped BTB
- 2-bit 饱和计数器
- IF 阶段预测
- EX 阶段更新
- `BRANCH_PRED_INDEX_BITS` 可配置

但 BHT/BTB 仍直接写在 `rv32i_pipe_core` 内部，后续替换预测策略会牵动 core 顶层。下一步应先抽成独立 `rv32i_branch_predictor`。

### 4. RV32M 识别绕过 decoder

当前 M 扩展识别由 core 顶层额外判断：

```text
opcode == OP && funct7 == 0000001
```

然后在 core 中修正 `reg_we`、`wb_sel`、`illegal`。这对快速扩展很实用，但长期应并入 `rv32i_decoder`，由 decoder 统一输出：

```text
id_muldiv_valid
id_muldiv_op
id_reg_we
id_wb_sel
id_illegal
```

### 5. IF/memory 协议假设需要继续明确

当前 core/cache/bus 是 blocking、单 outstanding 风格。`if_discard_q` 可以处理 redirect 后旧取指返回，但它仍依赖顺序返回的简单存储模型。

短期目标不是改成复杂 outstanding fetch，而是在文档中明确：

- 无 outstanding transaction
- 无 burst
- redirect 后通过 discard 处理旧响应
- CPU 子系统通过 blocking cache/AHB-Lite master 接入系统

### 6. assertion 不足

现有验证主要依赖 directed test 和波形。后续应逐步补充断言，例如：

```systemverilog
ex_muldiv_stall 时 ID/EX 保持稳定
mem_stall 时 EX/MEM 保持稳定
commit_redirect 优先于 ex_redirect
flush 后 wrong-path 不写回
branch update 只发生在有效 B-type branch 上
```

## 推荐实施顺序

每一步都应保持“小步改动、小步验证”的节奏。新增 testbench 在用户给出 VCS PASS 前只标记为 `PENDING`。

### Phase 1：抽出分支预测器

新增：

```text
rtl/core/rv32i_branch_predictor.v
```

目标：

- 从 `rv32i_pipe_core` 移出 BHT、BTB、预测 PC 选择、BHT/BTB 更新、BTB/BHT debug 计数器。
- 保持 `BRANCH_PRED_INDEX_BITS` 参数。
- 保持默认 64 项行为不变。
- 保持现有 `JAL`、B-type branch、`JALR` 行为不变。

建议接口：

```text
IF 查询：
if_pc
if_instr
if_error
if_predicted_pc
if_predict_taken
if_btb_hit

EX 更新：
ex_update_valid
ex_pc
ex_taken
ex_target_pc
ex_fetch_btb_hit

Debug：
dbg_btb_hit_count
dbg_btb_miss_count
dbg_bht_update_count
```

验证重点：

```bash
make sim TB_FILE=./testcases/rv32i_branch_predictor_tb.sv TOP_NAME=rv32i_branch_predictor_tb
make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_tb.sv TOP_NAME=rv32i_pipe_branch_predict_tb
make sim TB_FILE=./testcases/rv32i_pipe_dynamic_branch_predict_tb.sv TOP_NAME=rv32i_pipe_dynamic_branch_predict_tb
make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_param_tb.sv TOP_NAME=rv32i_pipe_branch_predict_param_tb
make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb
```

当前状态：

- `rv32i_branch_predictor.v` 已新增。
- `rv32i_pipe_core` 已改为实例化该模块。
- `rv32i_branch_predictor_tb` 已由用户确认 VCS PASS。
- 分支预测相关集成回归已由用户确认 VCS PASS。

### Phase 2：RV32M 识别并入 decoder

目标：

- `rv32i_decoder` 直接识别 M 扩展。
- core 顶层不再修正 decoder 的 illegal/reg_we/wb_sel。
- `rv32i_pipe_core` 只消费 decoder 输出的 `id_muldiv_valid` 和 `id_muldiv_op`。

验证重点：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_muldiv_tb.sv TOP_NAME=rv32i_pipe_muldiv_tb
make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb
```

### Phase 3：抽出性能计数器

新增：

```text
rtl/core/rv32i_perf_counter.v
```

目标：

- 从 core 顶层移出 cycle、instret、stall、flush、branch、mispredict 计数器。
- core 顶层只提供事件脉冲。

建议输入：

```text
instret_event
stall_event
flush_event
branch_event
mispredict_event
```

### Phase 4：建立统一 pipeline control

新增：

```text
rtl/core/rv32i_pipe_ctrl.v
```

目标：

- 显式管理 `commit_redirect`、`ex_redirect`、`mem_stall`、`ex_muldiv_stall`、`load_use_stall`、`if_stall`、`if_discard` 的优先级。
- 输出统一的 enable/flush 控制信号。

建议输出：

```text
pc_en
if_id_flush
id_ex_flush
ex_mem_flush
mem_wb_flush
front_stall
```

### Phase 5：拆流水线寄存器 always 块

目标：

- 将 `rv32i_pipe_core` 的大 always 块拆成多个 stage 级 always。
- 每一级只管理自己的 pipeline register。
- 依赖 Phase 4 的统一控制信号降低改动风险。

这一步风险较高，必须在前面几步验证稳定后进行。

### Phase 6：补 assertion 和组合场景测试

目标：

- 为 stall/flush/redirect/writeback 加防呆断言。
- 增加更复杂组合场景 directed test。

优先覆盖：

- `mem_stall + ex_muldiv_stall`
- `ex_redirect + commit_redirect`
- `load-use stall + branch`
- `mret/trap redirect + wrong-path writeback`
- `muldiv_stall` 后紧跟 forwarding

## 执行规则

每个 phase 都按同一流程推进：

1. 小范围 RTL 修改。
2. 更新 filelist。
3. 新增或更新 directed test。
4. 更新 `docs/VERIFICATION_MATRIX.md`，新测试先标 `PENDING`。
5. 更新相关专题文档和 `docs/PROJECT_STATUS.md`。
6. 用户运行 VCS 并给出 PASS log。
7. 再把矩阵改为 `PASS`，commit 并 push。

## 当前建议

当前正在执行 Phase 1：抽出 `rv32i_branch_predictor.v`。

原因：

- 当前 BHT/BTB 已完成参数化，边界已经比较清楚。
- 这是从 `rv32i_pipe_core` 中移出独立功能块的最低风险一步。
- 新增 standalone test 加上现有三个分支预测 directed tests 能直接验证行为是否保持一致。
