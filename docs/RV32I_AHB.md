# RV32I AHB-Lite Bus Path 说明

这一阶段新增一条 AHB-Lite 形式的系统总线路径。目标是让当前 simple `valid/ready` 内部总线可以通过标准 AHB address/data phase 访问 ROM、SRAM 和 MMIO，同时不破坏已经通过回归的 `rv32i_mem_bus`。

## 1. 新增模块

```text
rtl/bus/rv32i_simple_to_ahb.v
rtl/bus/rv32i_ahb_to_simple.v
rtl/bus/rv32i_ahb_lite_decoder.v
rtl/bus/rv32i_mem_bus_ahb.v
rtl/top/rv32i_cached_system_ahb_top.v
```

整体连接是：

```text
I-cache / D-cache simple memory ports
  |
  v
rv32i_mem_bus_ahb
  D-priority simple arbiter
  rv32i_simple_to_ahb
  rv32i_ahb_lite_decoder
  rv32i_ahb_to_simple x3
  |
  +-- ROM
  +-- SRAM
  `-- MMIO
```

`rv32i_cached_system_ahb_top` 和原来的 `rv32i_cached_system_top` 对外接口保持一致，只是内部 bus 从 `rv32i_mem_bus` 换成 `rv32i_mem_bus_ahb`。

## 2. 支持的 AHB-Lite 行为

当前实现支持：

- AHB address phase / data phase 分离。
- `HTRANS=NONSEQ/IDLE`。
- `HBURST=SINGLE`。
- `HSIZE=BYTE/WORD`，partial write 会拆成多个 byte transfer。
- `HPROT` 固定为 data/instruction-independent 的普通访问属性。
- `HREADY` wait-state。
- `HRESP=OKAY/ERROR`。
- unmapped 地址通过 AHB decoder 产生 ERROR response，再映射回 `i_error/d_error`。

当前实现不生成：

- INCR/WRAP burst。
- BUSY/SEQ burst continuation。
- SPLIT/RETRY。
- 多个 AHB master 同时访问不同 slave 的 bus matrix 并行路径。

原因是当前 core/cache 边界本身仍然是 blocking、single outstanding。先在这个边界后面接 AHB-Lite，可以保持 core/cache 简洁，也便于逐步验证协议行为。

## 3. byte strobe 处理

原 simple bus 有 `wstrb[3:0]`，AHB 没有 byte strobe，只有 `HSIZE` 和 `HADDR[1:0]`。

因此 `rv32i_simple_to_ahb` 做了转换：

```text
wstrb = 1111  -> 1 个 word transfer
wstrb = 其他  -> 每个置位 byte 拆成 1 个 byte transfer
wstrb = 0000  -> no-op write，直接完成
```

这样可以保留原 simple bus 的任意 byte mask 语义。比如 `wstrb=0101` 会被拆成 byte0 和 byte2 两个 AHB byte write。

## 4. 验证入口

独立 AHB memory bus：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_mem_bus_ahb_tb.sv TOP_NAME=rv32i_mem_bus_ahb_tb
```

Cached system + AHB bus path：

```bash
cd sim
make sim TB_FILE=./testcases/rv32i_cached_system_ahb_top_tb.sv TOP_NAME=rv32i_cached_system_ahb_top_tb
```

这两个 testbench 已由用户在 VCS 上确认 PASS。

## 5. 和参考工程的关系

参考工程 `D:\AIoT\rtl_riscv_AE350_clone` 里有 AE350/topo 的 AHB busmatrix、decoder 和 default slave。当前项目没有直接拷贝那些 IP，而是借鉴它们的接口结构：

- master 侧使用 `HADDR/HBURST/HPROT/HSIZE/HTRANS/HWRITE/HWDATA/HRDATA/HREADY/HRESP`。
- slave 侧使用 `HSEL/HREADYOUT/HRESP`。
- decoder 记录 data phase 的 slave 选择，再 mux 回 `HRDATA/HREADY/HRESP`。

后续如果要做真正多 master AHB matrix，可以在当前 `rv32i_simple_to_ahb` 后面继续扩展。
