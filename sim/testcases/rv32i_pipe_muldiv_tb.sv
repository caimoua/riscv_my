`timescale 1ns/1ps

module rv32i_pipe_muldiv_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  wire        imem_valid;
  wire [31:0] imem_addr;
  wire        imem_ready;
  wire [31:0] imem_rdata;

  wire        dmem_valid;
  wire        dmem_write;
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wdata;
  wire [3:0]  dmem_wstrb;
  wire        dmem_ready;
  wire [31:0] dmem_rdata;

  wire [31:0] dbg_pc;
  wire [31:0] dbg_cycle;
  wire [31:0] dbg_instret;
  wire [31:0] dbg_stall_cycle;
  wire [31:0] dbg_flush_cycle;
  wire [31:0] dbg_branch_count;
  wire [31:0] dbg_branch_mispredict_count;
  wire [31:0] dbg_btb_hit_count;
  wire [31:0] dbg_btb_miss_count;
  wire [31:0] dbg_bht_update_count;
  logic [4:0] dbg_reg_addr;
  wire [31:0] dbg_reg_rdata;
  wire        dbg_illegal_instr;
  wire        dbg_ecall;
  wire        dbg_ebreak;

  logic [31:0] imem [0:255];
  integer i;
  integer timeout;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2) clk = ~clk;
  end

  task automatic check_reg(
    input [4:0]  reg_addr,
    input [31:0] expected,
    input string reg_name
  );
    begin
      dbg_reg_addr = reg_addr;
      #1ps;
      if (dbg_reg_rdata !== expected) begin
        $fatal(1, "%s mismatch: expected 0x%08x, got 0x%08x",
               reg_name, expected, dbg_reg_rdata);
      end
    end
  endtask

  initial begin
    for (i = 0; i < 256; i = i + 1) begin
      imem[i] = 32'h0000_0013; // addi x0, x0, 0
    end

    // RV32M directed program.
    imem[0]  = 32'h0060_0093; // 0x00: addi  x1,  x0, 6
    imem[1]  = 32'h0070_0113; // 0x04: addi  x2,  x0, 7
    imem[2]  = 32'h0220_81b3; // 0x08: mul   x3,  x1,  x2
    imem[3]  = 32'hffd0_0213; // 0x0c: addi  x4,  x0, -3
    imem[4]  = 32'h0050_0293; // 0x10: addi  x5,  x0, 5
    imem[5]  = 32'h0252_0333; // 0x14: mul   x6,  x4,  x5
    imem[6]  = 32'h0252_13b3; // 0x18: mulh  x7,  x4,  x5
    imem[7]  = 32'h0252_2433; // 0x1c: mulhsu x8, x4,  x5
    imem[8]  = 32'hfff0_0513; // 0x20: addi  x10, x0, -1
    imem[9]  = 32'h0020_0593; // 0x24: addi  x11, x0, 2
    imem[10] = 32'h02b5_34b3; // 0x28: mulhu x9,  x10, x11
    imem[11] = 32'hfeb0_0613; // 0x2c: addi  x12, x0, -21
    imem[12] = 32'h0150_0693; // 0x30: addi  x13, x0, 21
    imem[13] = 32'h0000_0713; // 0x34: addi  x14, x0, 0
    imem[14] = 32'h0256_47b3; // 0x38: div   x15, x12, x5
    imem[15] = 32'h0256_6833; // 0x3c: rem   x16, x12, x5
    imem[16] = 32'h0256_d8b3; // 0x40: divu  x17, x13, x5
    imem[17] = 32'h0256_fc33; // 0x44: remu  x24, x13, x5
    imem[18] = 32'h02e6_ccb3; // 0x48: div   x25, x13, x14
    imem[19] = 32'h02e6_ed33; // 0x4c: rem   x26, x13, x14
    imem[20] = 32'h02e6_ddb3; // 0x50: divu  x27, x13, x14
    imem[21] = 32'h02e6_fe33; // 0x54: remu  x28, x13, x14
    imem[22] = 32'h8000_0937; // 0x58: lui   x18, 0x80000
    imem[23] = 32'hfff0_0993; // 0x5c: addi  x19, x0, -1
    imem[24] = 32'h0339_4eb3; // 0x60: div   x29, x18, x19
    imem[25] = 32'h0339_6f33; // 0x64: rem   x30, x18, x19
    imem[26] = 32'h0220_8a33; // 0x68: mul   x20, x1,  x2
    imem[27] = 32'h001a_0a93; // 0x6c: addi  x21, x20, 1
    imem[28] = 32'h0256_4b33; // 0x70: div   x22, x12, x5
    imem[29] = 32'h002b_0b93; // 0x74: addi  x23, x22, 2
    imem[30] = 32'h0010_0073; // 0x78: ebreak
  end

  assign imem_ready = imem_valid;
  assign imem_rdata = imem[imem_addr[9:2]];
  assign dmem_ready = 1'b1;
  assign dmem_rdata = 32'd0;

  always @(posedge clk) begin
    if (dmem_valid) begin
      $fatal(1, "unexpected data-memory access in RV32M pipeline test");
    end
  end

  rv32i_pipe_core u_core (
    .clk                         (clk),
    .rst_n                       (rst_n),
    .timer_irq                   (1'b0),
    .imem_valid                  (imem_valid),
    .imem_addr                   (imem_addr),
    .imem_ready                  (imem_ready),
    .imem_rdata                  (imem_rdata),
    .imem_error                  (1'b0),
    .dmem_valid                  (dmem_valid),
    .dmem_write                  (dmem_write),
    .dmem_addr                   (dmem_addr),
    .dmem_wdata                  (dmem_wdata),
    .dmem_wstrb                  (dmem_wstrb),
    .dmem_ready                  (dmem_ready),
    .dmem_rdata                  (dmem_rdata),
    .dmem_error                  (1'b0),
    .dbg_pc                      (dbg_pc),
    .dbg_cycle                   (dbg_cycle),
    .dbg_instret                 (dbg_instret),
    .dbg_stall_cycle             (dbg_stall_cycle),
    .dbg_flush_cycle             (dbg_flush_cycle),
    .dbg_branch_count            (dbg_branch_count),
    .dbg_branch_mispredict_count (dbg_branch_mispredict_count),
    .dbg_btb_hit_count           (dbg_btb_hit_count),
    .dbg_btb_miss_count          (dbg_btb_miss_count),
    .dbg_bht_update_count        (dbg_bht_update_count),
    .dbg_reg_addr                (dbg_reg_addr),
    .dbg_reg_rdata               (dbg_reg_rdata),
    .dbg_illegal_instr           (dbg_illegal_instr),
    .dbg_ecall                   (dbg_ecall),
    .dbg_ebreak                  (dbg_ebreak)
  );

  initial begin
    dbg_reg_addr = 5'd0;
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    timeout = 0;
    while (!dbg_ebreak && (timeout < 900)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for RV32M pipeline ebreak");
    end
    if (dbg_illegal_instr) begin
      $fatal(1, "unexpected illegal instruction in RV32M pipeline test");
    end
    if (dbg_ecall) begin
      $fatal(1, "unexpected ECALL event in RV32M pipeline test");
    end

    check_reg(5'd3,  32'd42,        "x3 mul 6*7");
    check_reg(5'd6,  32'hffff_fff1, "x6 mul -3*5");
    check_reg(5'd7,  32'hffff_ffff, "x7 mulh -3*5");
    check_reg(5'd8,  32'hffff_ffff, "x8 mulhsu -3*5u");
    check_reg(5'd9,  32'd1,         "x9 mulhu 0xffffffff*2");
    check_reg(5'd15, 32'hffff_fffc, "x15 div -21/5");
    check_reg(5'd16, 32'hffff_ffff, "x16 rem -21%5");
    check_reg(5'd17, 32'd4,         "x17 divu 21/5");
    check_reg(5'd24, 32'd1,         "x24 remu 21%5");
    check_reg(5'd25, 32'hffff_ffff, "x25 div by zero");
    check_reg(5'd26, 32'd21,        "x26 rem by zero");
    check_reg(5'd27, 32'hffff_ffff, "x27 divu by zero");
    check_reg(5'd28, 32'd21,        "x28 remu by zero");
    check_reg(5'd29, 32'h8000_0000, "x29 div overflow");
    check_reg(5'd30, 32'd0,         "x30 rem overflow");
    check_reg(5'd21, 32'd43,        "x21 mul forwarding");
    check_reg(5'd23, 32'hffff_fffe, "x23 div forwarding");

    if (dbg_instret !== 32'd31) begin
      $fatal(1, "instret mismatch: expected 31, got %0d", dbg_instret);
    end
    if (dbg_stall_cycle < 32'd8) begin
      $fatal(1, "expected RV32M multicycle stalls, got %0d", dbg_stall_cycle);
    end
    if (dbg_flush_cycle !== 32'd0) begin
      $fatal(1, "unexpected flush_cycle in RV32M pipeline test: %0d",
             dbg_flush_cycle);
    end
    if (dbg_branch_count !== 32'd0) begin
      $fatal(1, "unexpected branch_count in RV32M pipeline test: %0d",
             dbg_branch_count);
    end

    $display("[PASS] rv32i_pipe_muldiv_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d flush_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle, dbg_flush_cycle);
    $display("  RV32M mul/div/rem operations and dependent forwarding passed");
    $finish;
  end

endmodule
