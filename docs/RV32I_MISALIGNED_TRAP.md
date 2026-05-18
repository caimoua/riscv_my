# RV32I Misaligned Address Traps

This note records the current misaligned-address trap implementation.

## Supported Causes

```text
0  instruction address misaligned
4  load address misaligned
6  store/AMO address misaligned
```

The core is RV32I-only and does not implement compressed instructions, so valid instruction fetch targets are 4-byte aligned.

## RTL Behavior

- Taken branch/JAL/JALR target alignment is checked in EX.
- If the target is not 4-byte aligned, the redirect is suppressed and the faulting control-flow instruction is allowed to reach commit.
- Load/store alignment is checked in `rv32i_pipe_lsu` before a D-side bus request is issued.
- Misaligned load/store operations do not assert `dmem_valid`, so they do not produce bus decode errors or partial memory writes.
- The existing `rv32i_pipe_csr` commit-time trap path records `mepc`, writes `mcause`, redirects to `mtvec`, and flushes younger instructions.

## Alignment Rules

```text
instruction target: addr[1:0] == 2'b00
byte load/store:    always aligned
half load/store:    addr[0] == 1'b0
word load/store:    addr[1:0] == 2'b00
```

## Directed Test

```bash
make sim TB_FILE=./testcases/rv32i_cached_misaligned_trap_tb.sv TOP_NAME=rv32i_cached_misaligned_trap_tb
```

The test covers:

- `lw` from `0x2000_0002`, expecting `mcause=4`.
- `sw` to `0x2000_001a`, expecting `mcause=6` and no SRAM write.
- `jalr` to target `0x0000_0032`, expecting `mcause=0`.
- Each handler stores `mcause/mepc`, advances `mepc` by 4, then returns with `mret`.

Status: user-confirmed VCS PASS on 2026-05-18.
