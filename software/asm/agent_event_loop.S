// Agent-style event loop performance workload.
//
// This is a CPU-only baseline for a tiny agent scheduler loop. It initializes
// a small event queue in SRAM, repeatedly loads events, dispatches by event
// type, and checks a final checksum.
//
// Signature convention:
//   x29 = 0x0a6e0001
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
  addi  x11, x0, 1
  sw    x11, 0(x10)
  addi  x11, x0, 2
  sw    x11, 4(x10)
  addi  x11, x0, 3
  sw    x11, 8(x10)
  addi  x11, x0, 0
  sw    x11, 12(x10)
  addi  x11, x0, 1
  sw    x11, 16(x10)
  addi  x11, x0, 2
  sw    x11, 20(x10)
  addi  x11, x0, 3
  sw    x11, 24(x10)
  addi  x11, x0, 0
  sw    x11, 28(x10)
  addi  x11, x0, 1
  sw    x11, 32(x10)
  addi  x11, x0, 2
  sw    x11, 36(x10)
  addi  x11, x0, 3
  sw    x11, 40(x10)
  addi  x11, x0, 0
  sw    x11, 44(x10)
  addi  x11, x0, 1
  sw    x11, 48(x10)
  addi  x11, x0, 2
  sw    x11, 52(x10)
  addi  x11, x0, 3
  sw    x11, 56(x10)
  addi  x11, x0, 0
  sw    x11, 60(x10)

  addi  x1, x0, 0
  addi  x2, x0, 16
  addi  x3, x0, 0
  addi  x4, x10, 0

event_loop:
  lw    x5, 0(x4)
  andi  x6, x5, 3
  beq   x6, x0, handle_idle
  addi  x7, x0, 1
  beq   x6, x7, handle_add
  addi  x7, x0, 2
  beq   x6, x7, handle_xor

handle_store:
  sw    x3, 64(x10)
  addi  x3, x3, 3
  jal   x0, event_done

handle_idle:
  addi  x3, x3, 1
  jal   x0, event_done

handle_add:
  add   x3, x3, x5
  jal   x0, event_done

handle_xor:
  xor   x3, x3, x5

event_done:
  addi  x4, x4, 4
  addi  x1, x1, 1
  bne   x1, x2, event_loop

  addi  x8, x0, 20
  bne   x3, x8, fail_checksum
  lw    x9, 64(x10)
  addi  x8, x0, 16
  bne   x9, x8, fail_store_signature

pass:
  li    x29, 0x0a6e0001
  addi  x30, x0, 0
  addi  x31, x0, 1
  ebreak

fail_checksum:
  addi  x30, x0, 1
  jal   x0, fail

fail_store_signature:
  addi  x30, x0, 2

fail:
  addi  x31, x0, 0
  ebreak
