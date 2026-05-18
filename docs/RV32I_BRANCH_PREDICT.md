# RV32I 静态分支预测

本文记录 `rv32i_pipe_core` 的第一版分支预测实现。

## 状态

已实现，并已在 2026-05-18 由用户确认 VCS PASS。

定向测试：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_tb.sv TOP_NAME=rv32i_pipe_branch_predict_tb
```

由于 `stall_cycle` 和 `flush_cycle` 的期望值发生变化，原有流水线控制测试也需要重新运行：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb
```

已确认的 PASS 摘要：

```text
rv32i_pipe_branch_predict_tb:
  cycle=31 instret=18 stall_cycle=3 flush_cycle=3
  branch_count=5 branch_mispredict_count=2

rv32i_pipe_core_tb:
  cycle=56 instret=33 stall_cycle=16 flush_cycle=2
```

## 预测策略

当前预测器刻意保持为一个很小的静态预测器：

- `JAL`：如果目标地址按字对齐，则在 IF 阶段预测 taken。
- 立即数为负数的 B-type 分支：如果目标地址按字对齐，则在 IF 阶段预测 taken。
- 立即数为非负数的 B-type 分支：预测 not-taken。
- `JALR`：暂不预测，仍然在 EX 阶段解析。

IF 阶段会根据当前取到的指令计算预测下一条 PC。预测 PC 会跟随指令经过 `IF/ID` 和 `ID/EX` 流水寄存器。

到了 EX 阶段，core 会计算真实下一条 PC：

```text
实际下一条 PC = taken 控制流的跳转目标
实际下一条 PC = not-taken 分支的 pc + 4
```

只有预测 PC 和实际下一条 PC 不一致时，才会产生 `ex_redirect` 并 flush 前端。预测正确的 `JAL` 和预测正确的 taken backward branch 不再产生 flush。

## 计数器

`rv32i_pipe_core` 新增了两个 debug 计数器，并通过 cached/top wrapper 向外透出：

```text
dbg_branch_count             在 EX 阶段解析的条件 B-type 分支数量
dbg_branch_mispredict_count  预测 PC 错误的条件 B-type 分支数量
```

`dbg_flush_cycle` 现在统计预测错误导致的 redirect，而不是统计每一次 taken branch/jump。由于第一版静态预测器不预测寄存器间接目标，`JALR` 通常仍然会贡献一次 flush。

## 测试意图

`rv32i_pipe_branch_predict_tb` 覆盖以下场景：

- backward `bne` 循环在循环期间被预测 taken。
- 循环退出时产生一次 branch mispredict。
- forward taken `beq` 产生一次 branch mispredict。
- `jal` 被正确预测，不增加 flush。
- `jalr` 在 EX 阶段 redirect。
- 错误路径指令不会写寄存器。
