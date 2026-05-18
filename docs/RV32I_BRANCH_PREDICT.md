# RV32I Static Branch Prediction

This note records the first branch prediction step in `rv32i_pipe_core`.

## Status

Implemented and user-confirmed VCS PASS on 2026-05-18.

Directed test:

```bash
make sim TB_FILE=./testcases/rv32i_pipe_branch_predict_tb.sv TOP_NAME=rv32i_pipe_branch_predict_tb
```

The existing pipeline control test also needs a fresh run because the expected `stall_cycle` and `flush_cycle` counters changed:

```bash
make sim TB_FILE=./testcases/rv32i_pipe_core_tb.sv TOP_NAME=rv32i_pipe_core_tb
```

Observed PASS summaries:

```text
rv32i_pipe_branch_predict_tb:
  cycle=31 instret=18 stall_cycle=3 flush_cycle=3
  branch_count=5 branch_mispredict_count=2

rv32i_pipe_core_tb:
  cycle=56 instret=33 stall_cycle=16 flush_cycle=2
```

## Policy

The predictor is intentionally static and small:

- `JAL`: predicted taken in IF when the target is word-aligned.
- B-type branch with negative immediate: predicted taken in IF when the target is word-aligned.
- B-type branch with non-negative immediate: predicted not taken.
- `JALR`: not predicted, still resolved in EX.

The IF stage computes the predicted next PC from the fetched instruction. The predicted PC is carried through `IF/ID` and `ID/EX`.

At EX, the core computes the real next PC:

```text
actual next PC = taken target for taken control flow
actual next PC = pc + 4 for not-taken branch
```

Only a prediction mismatch causes `ex_redirect` and a frontend flush. Correctly predicted `JAL` and correctly predicted taken backward branches do not flush.

## Counters

New debug counters are exposed from `rv32i_pipe_core` and propagated through cached/top wrappers:

```text
dbg_branch_count             conditional B-type branches resolved in EX
dbg_branch_mispredict_count  conditional B-type branches whose predicted PC was wrong
```

`dbg_flush_cycle` now counts prediction-mismatch redirects instead of every taken branch/jump. `JALR` still usually contributes a flush because this first static predictor does not predict register-indirect targets.

## Test Intent

`rv32i_pipe_branch_predict_tb` checks:

- a backward `bne` loop is predicted taken while looping;
- the loop exit is a branch mispredict;
- a forward taken `beq` is a branch mispredict;
- a `jal` is predicted correctly and does not add a flush;
- a `jalr` redirects from EX;
- wrong-path instructions do not write registers.
