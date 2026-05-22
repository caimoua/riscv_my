// Sequential copy performance workload.
//
// This is a memory-side baseline for store/load/store streams. It initializes
// 64 source words in SRAM, copies them to a destination region, and verifies
// the destination checksum.
//
// Signature convention:
//   x29 = 0x0c0f0001
//   x30 = 0 on pass, non-zero fail code on failure
//   x31 = 1 on pass

  .option norvc
  .option norelax
  .section .text.init, "ax", @progbits
  .globl _start

_start:
  addi  x30, x0, 0
  addi  x31, x0, 0

  lui   x10, 0x20000
  addi  x11, x10, 0
  addi  x1, x0, 0
  addi  x2, x0, 64
  addi  x3, x0, 1

init_loop:
  sw    x3, 0(x11)
  addi  x11, x11, 4
  addi  x3, x3, 1
  addi  x1, x1, 1
  bne   x1, x2, init_loop

  addi  x11, x10, 0
  addi  x12, x10, 512
  addi  x1, x0, 0
  addi  x4, x0, 0

copy_loop:
  lw    x5, 0(x11)
  sw    x5, 0(x12)
  add   x4, x4, x5
  addi  x11, x11, 4
  addi  x12, x12, 4
  addi  x1, x1, 1
  bne   x1, x2, copy_loop

  li    x8, 2080
  bne   x4, x8, fail_source_sum

  addi  x12, x10, 512
  addi  x1, x0, 0
  addi  x6, x0, 0

verify_loop:
  lw    x7, 0(x12)
  add   x6, x6, x7
  addi  x12, x12, 4
  addi  x1, x1, 1
  bne   x1, x2, verify_loop

  bne   x6, x8, fail_dest_sum

pass:
  li    x29, 0x0c0f0001
  addi  x30, x0, 0
  addi  x31, x0, 1
  ebreak

fail_source_sum:
  addi  x30, x0, 1
  jal   x0, fail

fail_dest_sum:
  addi  x30, x0, 2

fail:
  addi  x31, x0, 0
  ebreak
