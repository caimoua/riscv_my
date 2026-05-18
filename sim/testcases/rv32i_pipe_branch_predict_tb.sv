`timescale 1ns/1ps

module rv32i_pipe_branch_predict_tb;

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

    // Static branch-predictor program.
    // Backward BNEs are predicted taken, forward branches are predicted not taken,
    // JAL is predicted taken, and JALR is resolved in EX.
    imem[0]  = 32'h0000_0093; // 0x00: addi x1, x0, 0
    imem[1]  = 32'h0040_0113; // 0x04: addi x2, x0, 4
    imem[2]  = 32'h0010_8093; // 0x08: addi x1, x1, 1
    imem[3]  = 32'hfe20_9ee3; // 0x0c: bne  x1, x2, -4
    imem[4]  = 32'h0330_0193; // 0x10: addi x3, x0, 0x33
    imem[5]  = 32'h0000_0463; // 0x14: beq  x0, x0, +8
    imem[6]  = 32'h0440_0213; // 0x18: addi x4, x0, 0x44 (wrong path)
    imem[7]  = 32'h0080_02ef; // 0x1c: jal  x5, +8
    imem[8]  = 32'h0550_0213; // 0x20: addi x4, x0, 0x55 (wrong path)
    imem[9]  = 32'h0660_0313; // 0x24: addi x6, x0, 0x66
    imem[10] = 32'h0380_0393; // 0x28: addi x7, x0, 0x38
    imem[11] = 32'h0003_8467; // 0x2c: jalr x8, x7, 0
    imem[12] = 32'h07a0_0513; // 0x30: addi x10, x0, 0x7a (wrong path)
    imem[13] = 32'h07b0_0513; // 0x34: addi x10, x0, 0x7b (wrong path)
    imem[14] = 32'h0770_0493; // 0x38: addi x9, x0, 0x77
    imem[15] = 32'h0010_0073; // 0x3c: ebreak
  end

  assign imem_ready = imem_valid;
  assign imem_rdata = imem[imem_addr[9:2]];
  assign dmem_ready = 1'b1;
  assign dmem_rdata = 32'd0;

  always @(posedge clk) begin
    if (dmem_valid) begin
      $fatal(1, "unexpected data-memory access in branch predictor test");
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
    while (!dbg_ebreak && (timeout < 120)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for branch predictor ebreak");
    end
    if (dbg_illegal_instr) begin
      $fatal(1, "unexpected illegal instruction in branch predictor test");
    end
    if (dbg_ecall) begin
      $fatal(1, "unexpected ECALL event in branch predictor test");
    end

    check_reg(5'd1,  32'd4,        "x1 loop counter");
    check_reg(5'd2,  32'd4,        "x2 loop limit");
    check_reg(5'd3,  32'h33,       "x3 forward branch target path");
    check_reg(5'd4,  32'd0,        "x4 wrong-path guard");
    check_reg(5'd5,  32'h20,       "x5 JAL return");
    check_reg(5'd6,  32'h66,       "x6 JAL target path");
    check_reg(5'd7,  32'h38,       "x7 JALR target");
    check_reg(5'd8,  32'h30,       "x8 JALR return");
    check_reg(5'd9,  32'h77,       "x9 JALR target path");
    check_reg(5'd10, 32'd0,        "x10 JALR wrong-path guard");

    if (dbg_instret !== 32'd18) begin
      $fatal(1, "instret mismatch: expected 18, got %0d", dbg_instret);
    end
    if (dbg_branch_count !== 32'd5) begin
      $fatal(1, "branch_count mismatch: expected 5, got %0d", dbg_branch_count);
    end
    if (dbg_branch_mispredict_count !== 32'd2) begin
      $fatal(1, "branch_mispredict_count mismatch: expected 2, got %0d",
             dbg_branch_mispredict_count);
    end
    if (dbg_flush_cycle !== 32'd3) begin
      $fatal(1, "flush_cycle mismatch: expected 3, got %0d", dbg_flush_cycle);
    end

    $display("[PASS] rv32i_pipe_branch_predict_tb");
    $display("  pc=0x%08x cycle=%0d instret=%0d stall_cycle=%0d flush_cycle=%0d",
             dbg_pc, dbg_cycle, dbg_instret, dbg_stall_cycle, dbg_flush_cycle);
    $display("  branch_count=%0d branch_mispredict_count=%0d",
             dbg_branch_count, dbg_branch_mispredict_count);
    $display("  static backward-branch/JAL prediction and mispredict redirect passed");
    $finish;
  end

endmodule
