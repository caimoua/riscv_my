// Pointer-chase performance workload.
//
// This workload builds a 16-node ring in SRAM. Nodes are spaced 64 bytes
// apart, which maps all node lines to the same D-cache index for the current
// 4-set, 2-way baseline configuration. Traversing the ring stresses dependent
// loads, refill behavior, and conflict misses.
//
// Signature convention:
//   x29 = 0x0c450001
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
  addi  x12, x10, 64
  addi  x1, x0, 0
  addi  x2, x0, 15
  addi  x13, x0, 1

init_loop:
  sw    x12, 0(x11)
  sw    x13, 4(x11)
  addi  x11, x11, 64
  addi  x12, x12, 64
  addi  x13, x13, 1
  addi  x1, x1, 1
  bne   x1, x2, init_loop

  sw    x10, 0(x11)
  sw    x13, 4(x11)

  addi  x4, x10, 0
  addi  x5, x0, 0
  addi  x6, x0, 64
  addi  x7, x0, 0

chase_loop:
  lw    x8, 4(x4)
  add   x7, x7, x8
  lw    x4, 0(x4)
  addi  x5, x5, 1
  bne   x5, x6, chase_loop

  li    x9, 544
  bne   x7, x9, fail_checksum

pass:
  li    x29, 0x0c450001
  addi  x30, x0, 0
  addi  x31, x0, 1
  ebreak

fail_checksum:
  addi  x30, x0, 1

fail:
  addi  x31, x0, 0
  ebreak
