# RV32I Verilog/SystemVerilog Style Guide

最后更新：2026-05-22

本文定义本项目 RTL 和 testbench 的统一写法。后续新增或修改 Verilog/SystemVerilog 代码时，优先遵守本文；如果某个旧文件已经有局部一致风格，在不扩大改动面的前提下先保持局部一致，并逐步向本文收敛。

这份规范不是只从当前代码里提炼，而是本项目对公开企业级/大项目 RTL 规范的裁剪版。目标不是追求漂亮格式，而是让后续性能计数、cache/bus 优化和自定义指令扩展时，代码容易读、容易 review、容易跑 lint/综合。

## 0. 参考基准和采用策略

主要参考：

- lowRISC Verilog Coding Style Guide：https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md
- OpenTitan Style Guides：https://opentitan.org/earlgrey_1.0.0/book/doc/contributing/style_guides/index.html
- OpenTitan Hardware Design Methodology：https://opentitan.org/earlgrey_1.0.0/book/doc/contributing/hw/methodology.html
- Verible SystemVerilog style lint rules：https://chipsalliance.github.io/verible/verilog_lint.html
- Clifford E. Cummings, SNUG-2000, Nonblocking Assignments in Verilog Synthesis, Coding Styles That Kill：https://csg.csail.mit.edu/6.375/6_375_2009_www/papers/cummings-nonblocking-snug99.pdf

采用策略：

1. **以 lowRISC/OpenTitan 风格作为目标风格。** 命名、缩进、组合/时序块、reset、实例化和 lint 思路都向这套规范靠拢。
2. **以 Verible 作为未来自动化检查方向。** 当前本机未必安装 Verible，但文档规则要尽量能映射到 Verible lint。
3. **以 Cummings 规则作为组合/时序赋值底线。** 组合逻辑用 blocking，时序逻辑用 nonblocking，不混用，不多 always 块驱动同一变量。
4. **保留本项目现实边界。** 现有 RTL 大量使用 `.v`、`wire/reg` 和 `always @(*)` / `always @(posedge clk or negedge rst_n)`；短期不强制全量迁移到 `.sv`、`logic`、`always_ff/always_comb`，但新模块应按企业规范写清楚边界，后续可逐步升级。
5. **新代码比旧代码更严格。** 旧代码只在 touched scope 内收敛；新增模块、重大重构和 P0/P1/P2 性能相关 RTL 必须主动遵守本文。

规则等级：

| 等级 | 含义 |
| --- | --- |
| MUST | 新代码必须遵守，除非文档说明例外 |
| SHOULD | 强烈建议，若不遵守需要有局部一致性或工具限制理由 |
| MAY | 可选，用于未来迁移或特定场景 |

## 1. 文件和语言边界

- MUST：RTL 文件当前默认使用 `.v`，保持与现有 filelist 和工具流一致。
- MUST：Testbench 使用 `.sv`。
- SHOULD：新 RTL 采用可综合 SystemVerilog 子集的写法理念，但不要无计划引入工具链尚未验证的语法。
- MAY：在单独验证工具链后，把新 RTL 文件迁移为 `.sv` 并使用 `logic`、`always_comb`、`always_ff`。
- MUST：新增仿真期 assertion 必须用 ``ifndef SYNTHESIS`` 或项目已有宏保护。
- MUST：不在 RTL 主体中引入 class、interface、package、randomize 等验证侧特性，除非建立专门的 SV 迁移计划。
- SHOULD：新文件考虑加入 ``default_nettype none`` / ``default_nettype wire`` 包裹；若现有 include/filelist 受影响，先在局部模块试点，不全仓一刀切。

目录约定：

```text
rtl/core/      core pipeline, decoder, CSR, hazard, LSU
rtl/common/    ALU, regfile, shared simple blocks
rtl/mem/       cache, SRAM-style memory
rtl/bus/       memory bus, AHB/APB bridge/matrix
rtl/periph/    timer, UART, MMIO peripherals
rtl/top/       integration wrappers
sim/testcases/ testbench
```

## 2. 命名规则

模块名、文件名一致：

```text
rtl/core/rv32i_perf_counter.v -> module rv32i_perf_counter
```

实例名使用 `u_` 前缀：

```verilog
rv32i_perf_counter u_perf_counter (
  ...
);
```

信号命名：

| 类别 | 规则 | 示例 |
| --- | --- | --- |
| 时钟 | `clk` | `clk` |
| 低有效复位 | `_n` 后缀 | `rst_n` |
| 寄存器状态 | `_q` 后缀 | `state_q`, `pc_q` |
| 下一状态 | `_d` 后缀，只有需要显式 next-state 时使用 | `state_d` |
| 有效/就绪握手 | `valid` / `ready` | `imem_valid`, `dmem_ready` |
| 写使能 | `we` 或 `write`，按局部接口保持一致 | `w_en`, `dmem_write` |
| 字节写使能 | `wstrb` | `dmem_wstrb` |
| debug | `dbg_` 前缀 | `dbg_cycle` |
| 未使用信号 | `unused_` 前缀 | `unused_bus_dbg_active` |
| 参数 | 优先 `UpperCamelCase` 或既有参数风格，当前项目可保留大写 | `RESET_PC`, `INDEX_BITS` |
| FSM 状态 | `STATE_` 前缀 | `STATE_IDLE` |

不要混用同一含义的多个名字。例如同一个接口里不要同时出现 `req_vld`、`req_valid` 和 `request_valid`。本项目优先使用 `valid`。

企业规范对齐：

- SHOULD：普通信号使用 lower_snake_case。
- SHOULD：模块名和文件名使用 lower_snake_case。
- MUST：低有效信号用 `_n` 后缀，不使用 `_b`、`_l` 混用。
- MUST：流水线/寄存器状态用 `_q`，显式 next-state 用 `_d`。
- SHOULD：Verible 可检查的命名规则后续尽量接入 lint。

## 3. 模块头和端口

参数写在 module header 中，端口方向、类型、位宽显式写出：

```verilog
module rv32i_example #(
  parameter INDEX_BITS = 2,
  parameter [31:0] RESET_PC = 32'h0000_0000
) (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        req_valid,
  input  wire [31:0] req_addr,
  output wire        req_ready,
  output wire [31:0] req_rdata
);
```

格式规则：

- 缩进使用 2 个空格。
- 端口按功能分组：clock/reset、core side、memory/bus side、debug。
- 同组端口方向和位宽尽量纵向对齐。
- `input` 默认写 `wire`。
- RTL 输出如果由 `assign` 驱动，写 `output wire`；如果在时序块中赋值，写 `output reg`。
- MUST：所有端口必须显式方向和位宽。
- MUST：禁止隐式 net。
- SHOULD：端口列表不要使用位置连接依赖，实例化时必须命名连接。
- SHOULD：大型端口列表按接口块留空行，提高 review 可读性。

## 4. 常量和位宽

所有数字常量 MUST 尽量显式位宽：

```verilog
32'd0
32'h0000_0000
4'b1111
```

MUST：避免无位宽常量参与拼接、比较或赋值。地址、数据、计数器默认 32-bit 时也要写清位宽。

位切片和拼接保持清楚：

```verilog
assign word_addr = addr[31:2];
assign byte_sel  = addr[1:0];
```

## 5. 组合逻辑

简单组合逻辑优先使用连续赋值：

```verilog
assign cache_hit = way0_hit || way1_hit;
```

复杂组合逻辑使用 `always @(*)`，并在块开头给所有输出默认值，避免 latch：

```verilog
always @(*) begin
  next_state = state_q;
  grant_d    = 1'b0;

  case (state_q)
    STATE_IDLE: begin
      if (req_valid) begin
        next_state = STATE_BUSY;
        grant_d    = 1'b1;
      end
    end
    default: begin
      next_state = STATE_IDLE;
    end
  endcase
end
```

MUST：组合块使用 blocking assignment `=`。不要在组合块里使用 nonblocking assignment `<=`。

SHOULD：复杂组合逻辑优先写成“默认赋值 + case/if 覆盖”的结构。这样更接近 lowRISC/OpenTitan 可读性目标，也更利于 lint 检查 latch。

MUST：除非明确设计 latch，否则组合逻辑不得产生 latch。当前项目不鼓励 latch。

## 6. 时序逻辑

时序块统一使用低有效异步复位：

```verilog
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    count_q <= 32'd0;
  end else begin
    count_q <= count_q + 32'd1;
  end
end
```

时序块规则：

- MUST：使用 nonblocking assignment `<=`。
- MUST：一个寄存器只在一个时序块中赋值。
- MUST：reset 分支显式初始化所有该块维护的寄存器。
- MUST：同一个 always 块里不混用 blocking 和 nonblocking assignment。
- 同一个 always 块中尽量只维护同一类状态。
- 对 pipeline stage 寄存器，优先沿用 `clear_*` task 或局部统一清零函数，避免重复散落清零逻辑。

MAY：未来迁移到 `.sv` 后，新模块优先使用 `always_ff @(posedge clk or negedge rst_n)`。

## 7. FSM 写法

状态用 `localparam`，不要使用裸数字：

```verilog
localparam STATE_IDLE = 2'd0;
localparam STATE_BUSY = 2'd1;
localparam STATE_DONE = 2'd2;

reg [1:0] state_q;
```

FSM 可以使用当前项目已有的单时序块风格，也可以在复杂模块中使用 next-state 双块风格。新增复杂 FSM SHOULD 使用 next-state 双块风格。无论哪种，都要满足：

- 状态命名清楚。
- 默认分支回到安全状态或保持当前状态。
- 所有输出在每个状态都有定义或有明确默认值。
- 不把协议 side effect 藏在难读的嵌套条件里。
- SHOULD：default 分支处理非法状态，通常回到 `STATE_IDLE` 或安全状态。
- SHOULD：状态编码位宽显式，不依赖工具自动推断。
- MAY：未来 `.sv` 迁移时使用 `typedef enum logic [...]`，enum 类型名用 lower_snake_case + `_e` 或 `_t` 后缀，与 Verible/lowRISC 风格一致。

## 8. valid/ready 握手

本项目简单接口优先使用 blocking valid/ready 语义：

```text
valid: requester 本周期有请求
ready: responder 本周期完成或可接受
```

规则：

- request payload 在 `valid && !ready` 期间必须保持稳定，除非接口文档明确允许变化。
- 完成事件通常用 `valid && ready`。
- 如果模块 busy，`ready` 应明确拉低或只在完成周期拉高。
- cache/bus 当前仍以 blocking、single outstanding 为默认，除非路线图任务明确要求扩展。
- SHOULD：接口信号按 `valid/ready/addr/write/wdata/wstrb/rdata/error` 顺序组织。
- SHOULD：跨模块新增接口时同步更新 `docs/INTERFACE_INDEX.md`。

## 9. reset 和异常路径

- 所有架构可见状态必须有确定 reset 值。
- `rst_n` 统一为低有效异步复位。
- SHOULD：数据通路大数组是否 reset 按综合代价决定，但 valid/state/tag/control 必须 reset 到安全值。
- trap/interrupt/mret 这类 commit redirect 优先级高于普通 EX redirect。
- 任何可能产生架构副作用的控制信号，在 flush/bubble 后必须变成无副作用状态。
- fault/illegal 指令不得写回寄存器或写内存。

## 10. 参数化

参数只用于确实需要配置的容量或地址：

```verilog
parameter ICACHE_INDEX_BITS = 2
parameter [31:0] RESET_PC = 32'h0000_0000
```

规则：

- 参数从 top 向下透传时，保持同名或非常接近的名字。
- 不为尚未使用的未来功能提前加参数。
- 参数影响接口位宽或存储容量时，文档要同步更新。

## 11. 实例化风格

使用命名端口连接，不使用位置连接：

```verilog
rv32i_pipe_ctrl u_pipe_ctrl (
  .commit_redirect  (commit_redirect),
  .ex_redirect      (ex_redirect),
  .mem_stall        (mem_stall),
  .front_advance    (pipe_front_advance)
);
```

规则：

- MUST：参数 override 使用命名参数。
- MUST：端口连接使用命名端口。
- SHOULD：端口连接按被实例模块端口顺序或按功能分组。
- SHOULD：未使用输出接到 `unused_*` wire，不直接留空。
- SHOULD：不把复杂表达式塞进端口连接；先用 `wire` 命名，再连接。
- SHOULD：关联端口和信号名尽量一致，减少 review 时的脑内映射。

## 12. 注释

注释只解释设计意图、协议假设或不明显的优先级。不要写重复代码含义的注释。

推荐：

```verilog
// Commit redirect wins over EX redirect to keep traps precise.
```

不推荐：

```verilog
// Assign count to count plus one.
```

复杂模块顶部可以有一小段结构说明，但不要把文档整段复制进 RTL。

MUST：TODO 注释要写清责任或后续条件，不留模糊的 `TODO fix later`。

## 13. Testbench 风格

testbench 使用 `.sv` 和 `logic`。文件头：

```systemverilog
`timescale 1ns/1ps

module rv32i_example_tb;
```

推荐规则：

- 时钟周期用 `localparam CLK_PERIOD_NS = 10;`。
- reset 至少保持数个时钟。
- 使用 `$fatal(1, "...")` 报错。
- 使用 `$value$plusargs` 覆盖 MEMH 路径。
- 程序型测试用 `ebreak` 作为结束事件。
- perf/agent workload 遵守 `x29/x30/x31` 签名约定，见 `docs/RV32I_PERF_BASELINE.md`。
- PASS 日志格式稳定，便于回归脚本抓取。
- SHOULD：新 perf testbench 输出 `PERF_CSV` 单行，格式见 `docs/RV32I_PERF_BASELINE.md`。
- SHOULD：testbench 中可使用 SystemVerilog task/function 提升可读性，但不要过度抽象到难以定位波形。

## 14. Assertion 风格

仿真期 assertion 只保护关键不变量：

- redirect 优先级。
- flush 后无副作用。
- stall 期间 stage 保持。
- fault/illegal 屏蔽写回。
- handshake payload 稳定。

RTL 中 assertion 必须放在综合保护宏下：

```verilog
`ifndef SYNTHESIS
`ifndef RV32I_DISABLE_ASSERT
  // assertions
`endif
`endif
```

新增 assertion 后，必须更新或运行相关 directed regression；用户确认 VCS PASS 前，不把验证矩阵标为 PASS。

## 15. Lint / Formatter 方向

当前项目已有基础质量检查入口 `tools/quality`。后续建议逐步加入 Verible：

```text
verible-verilog-format
verible-verilog-lint
```

建议第一批 lint 关注：

- module filename match。
- signal/module/parameter naming。
- tabs / trailing spaces / line length。
- implicit nets。
- always block assignment style。
- forbidden system tasks in synthesizable RTL。
- one declaration per line 或项目可读性等价规则。

Verible 接入前，本文即为人工 review 标准。接入后，不要一次打开所有规则；先用 warning baseline，逐步收紧。

## 16. 代码改动清单

每次改 RTL 前后检查：

1. 新文件是否加入 `filelist/cpu_filelist/`。
2. 模块名是否和文件名一致。
3. 是否遵守 `clk/rst_n`、`valid/ready`、`_q`、`dbg_` 等命名约定。
4. 时序块是否使用 `<=`，组合块是否使用 `=`。
5. reset 是否覆盖所有寄存器。
6. 是否引入 latch、多驱动、无位宽常量、隐式 wire。
7. flush/bubble 后是否无副作用。
8. 新功能是否有 testbench 或明确验证计划。
9. 相关文档和验证矩阵是否需要更新。
10. 是否违反本文 MUST 规则。
11. 提交前运行 `git diff --check`。

## 17. 新代码模板

```verilog
module rv32i_example #(
  parameter [31:0] BASE_ADDR = 32'h0000_0000
) (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        req_valid,
  input  wire [31:0] req_addr,
  output wire        req_ready,
  output wire [31:0] req_rdata,

  output wire [31:0] dbg_count
);

  reg [31:0] count_q;

  assign req_ready = req_valid;
  assign req_rdata = BASE_ADDR ^ req_addr;
  assign dbg_count = count_q;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count_q <= 32'd0;
    end else if (req_valid && req_ready) begin
      count_q <= count_q + 32'd1;
    end
  end

endmodule
```
