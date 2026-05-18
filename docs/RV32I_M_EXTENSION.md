# RV32M 乘除法扩展

本文记录 `rv32i_pipe_core` 的 RV32M 乘除法扩展实现。

## 当前状态

已实现，并已在 2026-05-18 由用户确认 VCS PASS：

```bash
make sim TB_FILE=./testcases/rv32i_pipe_muldiv_tb.sv TOP_NAME=rv32i_pipe_muldiv_tb
```

已确认的 PASS 摘要：

```text
cycle=212 instret=31 stall_cycle=177 flush_cycle=0
RV32M mul/div/rem operations and dependent forwarding passed
```

## 支持的指令

当前支持 RV32M 的 8 条 R-type 指令：

```text
mul
mulh
mulhsu
mulhu
div
divu
rem
remu
```

编码条件：

```text
opcode = 7'b0110011
funct7 = 7'b0000001
funct3 = M 扩展操作选择
```

## 微架构

新增模块：

```text
rtl/core/rv32i_muldiv.v
```

该模块接在 `rv32i_pipe_core` 的 EX 阶段：

```text
ID decode M instruction
  -> ID/EX carries muldiv_valid / muldiv_op
  -> EX starts rv32i_muldiv
  -> pipeline stalls while result is not ready
  -> result enters EX/MEM through ALU-result writeback path
```

为了保持已有 writeback 和 forwarding 逻辑简单，M 扩展结果复用 `RV32I_WB_ALU` 路径进入 `ex_mem_alu_result_q`。

## Stall 行为

M 指令在 EX 阶段等待 `rv32i_muldiv.ready`。

- `mul/mulh/mulhsu/mulhu`：启动后下一拍 ready，因此会产生短 stall。
- 普通 `div/divu/rem/remu`：使用 iterative divider，最多 32 次迭代。
- 除零和 signed overflow 是特殊情况，直接生成架构规定结果，不跑完整 32 次迭代。

EX stall 期间：

- IF 和 ID/EX 保持不动。
- EX/MEM 会插入 bubble。
- MEM/WB 继续 drain 旧指令。

这样可以避免 EX stall 时旧的 store、CSR 或 trap 在后端重复提交。

## RISC-V 边界行为

实现遵循 RV32M 对除法特殊情况的规定：

```text
div/divu by zero   -> quotient = 0xffffffff
rem/remu by zero   -> remainder = dividend
INT_MIN / -1       -> quotient = INT_MIN
INT_MIN % -1       -> remainder = 0
```

## Directed Test

`rv32i_pipe_muldiv_tb` 覆盖：

- `mul` low 32-bit 结果。
- `mulh` signed high 32-bit。
- `mulhsu` signed-by-unsigned high 32-bit。
- `mulhu` unsigned high 32-bit。
- signed / unsigned divide 和 remainder。
- divide by zero。
- `INT_MIN / -1` overflow。
- M 指令结果被后一条指令立即使用时的 forwarding。
- M 指令产生的 multicycle stall。
