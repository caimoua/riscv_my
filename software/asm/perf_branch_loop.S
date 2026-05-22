// Branch-heavy performance workload.
//
// Signature convention:
//   x29 = 0x0b120001
//   x30 = 0 on pass, non-zero fail code on failure
//   x31 = 1 on pass

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  addi  x30, x0, 0
  addi  x31, x0, 0

  addi  x1, x0, 0
  addi  x2, x0, 64
  addi  x3, x0, 0
  addi  x4, x0, 32

loop:
  add   x3, x3, x1
  andi  x5, x1, 1
  beq   x5, x0, even_path
  addi  x3, x3, 3
  jal   x0, parity_done

even_path:
  addi  x3, x3, 1

parity_done:
  bne   x1, x4, no_midpoint_bonus
  addi  x3, x3, 7

no_midpoint_bonus:
  addi  x1, x1, 1
  bne   x1, x2, loop

  li    x6, 2151
  beq   x3, x6, pass
  addi  x30, x0, 1
  jal   x0, fail

pass:
  li    x29, 0x0b120001
  addi  x30, x0, 0
  addi  x31, x0, 1
  ebreak

fail:
  addi  x31, x0, 0
  ebreak
