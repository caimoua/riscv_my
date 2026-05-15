# Software 目录

## 汇编到 MEMH 流程

新的 directed test 程序应该优先写在 `asm/*.S` 里，再生成给 SystemVerilog `$readmemh` 使用的 memory image。

```bash
cd software
make
```

默认目标会构建：

```text
asm/ahb_matrix_soc.S
  -> build/ahb_matrix_soc.elf
  -> bin/ahb_matrix_soc.bin
  -> bin/ahb_matrix_soc.memh
```

默认工具链前缀是 `riscv-none-elf`，对应 xPack RISC-V embedded GCC。可以按本机安装情况覆盖：

```bash
make TOOLCHAIN_PREFIX=riscv64-unknown-elf
```

`bin/*.memh` 可以提交，用来保证仿真环境没有本地 RISC-V 工具链时仍能跑现有 test。`bin/*.elf`、`bin/*.bin` 和 map 文件不提交。

更多安装说明见 `docs/RISCV_TOOLCHAIN.md`。

这个目录用于放 CPU 测试程序。

计划结构：

- `asm/`：手写汇编 directed test
- `c/`：小型 C 程序
- `linker/`：linker script
- `scripts/`：ELF、HEX、MEM 转换脚本
- `bin/`：生成的二进制文件或 memory image
