# RV32I 分支预测

本文记录 `rv32i_pipe_core` 当前的分支预测实现。

## 当前状态

静态预测版本已经在 2026-05-18 由用户确认 VCS PASS：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_tb.sv TOP_NAME=rv32i_pipe_branch_predict_tb
make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb
```

动态 BHT/BTB 版本已经在 2026-05-18 由用户确认 VCS PASS：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_dynamic_branch_predict_tb.sv TOP_NAME=rv32i_pipe_dynamic_branch_predict_tb
```

已确认的动态预测 PASS 摘要：

```text
cycle=32 instret=22 stall_cycle=2 flush_cycle=2
branch_count=8 branch_mispredict_count=2
btb_hit=6 btb_miss=2 bht_update=8
```

## 预测结构

当前 core 在原来的静态预测基础上增加了一个很小的动态预测器：

- BHT：64 项 direct-mapped 表，每项是 2-bit 饱和计数器。
- BTB：64 项 direct-mapped 表，记录分支 PC tag 和预测目标 PC。
- `JAL`：仍然在 IF 阶段直接用立即数目标预测 taken，不依赖 BTB。
- B-type branch：如果 BTB 命中且 BHT 最高位为 1，则使用 BTB 目标预测 taken。
- B-type branch：如果 BTB 未命中，则保留原来的静态后备规则，backward branch 预测 taken，forward branch 预测 not-taken。
- `JALR`：目标来自寄存器，仍然在 EX 阶段解析。

这样做的好处是：第一次遇到分支时仍然有简单静态规则可用；当同一条分支反复执行后，BHT/BTB 可以学习 forward taken branch 或循环退出行为。

## 流水线行为

IF 阶段会生成预测下一条 PC，并把它随指令进入 `IF/ID` 和 `ID/EX`。

EX 阶段会重新计算真实下一条 PC：

```text
taken 控制流：真实下一条 PC = 跳转目标
not-taken 分支：真实下一条 PC = pc + 4
```

只有预测 PC 和真实下一条 PC 不一致时，core 才产生 `ex_redirect` 并 flush 前端。预测正确的 `JAL`、预测正确的 taken branch、预测正确的 not-taken branch 都不会产生 flush。

## 训练策略

BHT/BTB 在 EX 阶段训练，条件是这条 B-type 分支有效、不是 illegal/fault、目标地址没有 misaligned，并且当前没有 memory stall 或 commit redirect。

- 实际 taken：BHT 计数器加 1，最大到 `2'b11`；BTB 写入该分支 PC 的 tag 和目标 PC。
- 实际 not-taken：BHT 计数器减 1，最小到 `2'b00`；BTB 目标保留。
- reset 后 BHT 初始化为 `2'b01`，也就是 weak not-taken。

## Debug 计数器

`rv32i_pipe_core` 以及 cached/top wrapper 透出了这些分支预测计数器：

```text
dbg_branch_count             EX 阶段实际解析的 B-type 分支数量
dbg_branch_mispredict_count  预测 PC 错误的 B-type 分支数量
dbg_btb_hit_count            B-type 分支到 EX 时，对应取指预测曾经 BTB 命中的数量
dbg_btb_miss_count           B-type 分支到 EX 时，对应取指预测没有 BTB 命中的数量
dbg_bht_update_count         BHT 被训练更新的次数
```

`dbg_flush_cycle` 统计预测错误导致的 EX redirect，不统计预测正确的 taken branch/jump。

## 测试意图

`rv32i_pipe_branch_predict_tb` 覆盖基础预测路径：

- backward `bne` 循环在循环期间预测 taken。
- 循环退出时产生一次 branch mispredict。
- forward taken `beq` 产生一次 branch mispredict。
- `jal` 被正确预测，不增加 flush。
- `jalr` 在 EX 阶段 redirect。
- 错误路径指令不会写寄存器。

`rv32i_pipe_dynamic_branch_predict_tb` 覆盖动态学习路径：

- 固定 PC 的 forward `beq` 连续 taken。
- 第一次 forward `beq` 因为 BTB 未命中而预测 not-taken。
- 后续同一条 forward `beq` 通过 BHT+BTB 预测 taken。
- backward `bne` 使用静态后备开始循环，随后进入 BTB/BHT 路径。
- 预期 B-type 分支总数为 8，BTB miss 为 2，BTB hit 为 6。
