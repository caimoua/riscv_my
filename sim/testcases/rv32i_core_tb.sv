`timescale 1ns/1ps

module rv32i_core_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  wire        imem_valid;
  wire [31:0] imem_addr;
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
  logic [4:0]  dbg_reg_addr;
  wire [31:0] dbg_reg_rdata;
  wire        dbg_illegal_instr;
  wire        dbg_ecall;
  wire        dbg_ebreak;

  logic [31:0] imem [0:255];
  logic [31:0] dmem [0:255];
  logic        illegal_seen;
  logic [31:0] illegal_pc;
  logic        jal_ret_seen;
  logic [31:0] jal_x24_ret;
  logic        branch_score_seen;
  logic [31:0] branch_x24_score;
  logic        lw_word_seen;
  logic [31:0] lw_x24_value;
  logic        ecall_seen;
  logic        ebreak_seen;
  logic [31:0] ecall_pc;
  logic [31:0] ebreak_pc;
  logic [31:0] csr_cycle_value;
  integer i;

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
      imem[i] = 32'h0000_0013; //  addi x0, x0, 0  (NOP)
      dmem[i] = 32'd0;
    end

    //  --- original tests ---
    imem[0] = 32'h0050_0093;   //  addi x1, x0, 5
    imem[1] = 32'h0070_0113;   //  addi x2, x0, 7
    imem[2] = 32'h0020_81b3;   //  add  x3, x1, x2
    imem[3] = 32'h4011_8233;   //  sub  x4, x3, x1

    //  --- setup: x5 = -8  for signed/unsigned tests ---
    imem[4] = 32'hff80_0293;   //  addi x5, x0, -8

    //  --- I-type arithmetic ---
    imem[5] = 32'h0002_a313;   //  slti  x6, x5, 0      (x6=1)
    imem[6] = 32'h0002_b393;   //  sltiu x7, x5, 0      (x7=0)
    imem[7] = 32'h0040_f413;   //  andi  x8, x1, 4      (x8=4)
    imem[8] = 32'h0080_e493;   //  ori   x9, x1, 8      (x9=13)
    imem[9] = 32'h0070_c513;   //  xori  x10, x1, 7     (x10=2)
    imem[10]= 32'h0021_1593;   //  slli  x11, x2, 2     (x11=28)
    imem[11]= 32'h0011_5613;   //  srli  x12, x2, 1     (x12=3)
    imem[12]= 32'h4022_d693;   //  srai  x13, x5, 2     (x13=-2)

    //  --- R-type arithmetic ---
    imem[13]= 32'h0020_9733;   //  sll   x14, x1, x2    (x14=640)
    imem[14]= 32'h0012_a7b3;   //  slt   x15, x5, x1    (x15=1)
    imem[15]= 32'h0012_b833;   //  sltu  x16, x5, x1    (x16=0)
    imem[16]= 32'h0020_c8b3;   //  xor   x17, x1, x2    (x17=2)
    imem[17]= 32'h0012_d933;   //  srl   x18, x5, x1    (x18=0x07FFFFFF)
    imem[18]= 32'h4012_d9b3;   //  sra   x19, x5, x1    (x19=-1)
    imem[19]= 32'h0020_ea33;   //  or    x20, x1, x2    (x20=7)
    imem[20]= 32'h0020_fab3;   //  and   x21, x1, x2    (x21=5)

    //  --- U-type ---
    imem[21]= 32'h1234_5b37;   //  lui   x22, 0x12345  (x22=0x12345000)
    imem[22]= 32'h1000_0b97;   //  auipc x23, 0x10000  (x23=0x10000058)

    //  --- JAL / JALR ---
    imem[23]= 32'h0080_0c6f;   //  jal  x24, 8          (skip imem[24])
    imem[24]= 32'h0010_0c93;   //  addi x25, x0, 1      (should be skipped)
    imem[25]= 32'h0de0_0c93;   //  addi x25, x0, 0xDE   (landing, x25=0xDE)
    imem[26]= 32'h0800_0d13;   //  addi x26, x0, 0x80   (target addr: 0x80)
    imem[27]= 32'h000d_0de7;   //  jalr x27, x26, 0     (jump to 0x80)
    imem[28]= 32'h0010_0e13;   //  addi x28, x0, 1      (should be skipped)
    imem[29]= 32'h0000_0013;   //  nop
    imem[30]= 32'h0000_0013;   //  nop
    imem[31]= 32'h0000_0013;   //  nop
    imem[32]= 32'h0ff0_0e13;   //  addi x28, x0, 0xFF   (landing, x28=0xFF)

    //  --- B-type branch ---
    //  x24 is reused as a branch score after its JAL return value is sampled.
    imem[33]= 32'h0000_0c13;   //  addi x24, x0, 0
    imem[34]= 32'h0010_8663;   //  beq  x1, x1, +12      (taken)
    imem[35]= 32'h400c_0c13;   //  addi x24, x24, 1024   (fail path)
    imem[36]= 32'h0080_006f;   //  jal  x0, +8           (skip pass path)
    imem[37]= 32'h001c_0c13;   //  addi x24, x24, 1      (pass path)
    imem[38]= 32'h0020_9663;   //  bne  x1, x2, +12      (taken)
    imem[39]= 32'h400c_0c13;   //  addi x24, x24, 1024   (fail path)
    imem[40]= 32'h0080_006f;   //  jal  x0, +8           (skip pass path)
    imem[41]= 32'h002c_0c13;   //  addi x24, x24, 2      (pass path)
    imem[42]= 32'h0012_c663;   //  blt  x5, x1, +12      (taken, signed)
    imem[43]= 32'h400c_0c13;   //  addi x24, x24, 1024   (fail path)
    imem[44]= 32'h0080_006f;   //  jal  x0, +8           (skip pass path)
    imem[45]= 32'h004c_0c13;   //  addi x24, x24, 4      (pass path)
    imem[46]= 32'h0050_d663;   //  bge  x1, x5, +12      (taken, signed)
    imem[47]= 32'h400c_0c13;   //  addi x24, x24, 1024   (fail path)
    imem[48]= 32'h0080_006f;   //  jal  x0, +8           (skip pass path)
    imem[49]= 32'h008c_0c13;   //  addi x24, x24, 8      (pass path)
    imem[50]= 32'h0050_e663;   //  bltu x1, x5, +12      (taken, unsigned)
    imem[51]= 32'h400c_0c13;   //  addi x24, x24, 1024   (fail path)
    imem[52]= 32'h0080_006f;   //  jal  x0, +8           (skip pass path)
    imem[53]= 32'h010c_0c13;   //  addi x24, x24, 16     (pass path)
    imem[54]= 32'h0050_f663;   //  bgeu x1, x5, +12      (not taken, unsigned)
    imem[55]= 32'h020c_0c13;   //  addi x24, x24, 32     (pass fall-through)
    imem[56]= 32'h0080_006f;   //  jal  x0, +8           (skip fail path)
    imem[57]= 32'h400c_0c13;   //  addi x24, x24, 1024   (fail target)

    //  --- Load / store ---
    //  x24 now becomes the memory test value/result.
    imem[58]= 32'h1234_5c37;   //  lui  x24, 0x12345      (x24=0x12345000)
    imem[59]= 32'h678c_0c13;   //  addi x24, x24, 0x678  (x24=0x12345678)
    imem[60]= 32'h0180_2223;   //  sw   x24, 4(x0)       (dmem[1]=0x12345678)
    imem[61]= 32'h0000_0c13;   //  addi x24, x0, 0       (clear x24)
    imem[62]= 32'h0040_2c03;   //  lw   x24, 4(x0)       (x24=0x12345678)

    //  --- Byte / halfword load-store ---
    imem[63]= 32'hfff0_0e93;   //  addi x29, x0, -1      (x29=0xFFFFFFFF)
    imem[64]= 32'h01d0_0423;   //  sb   x29, 8(x0)       (dmem[2][7:0]=0xFF)
    imem[65]= 32'h01d0_05a3;   //  sb   x29, 11(x0)      (dmem[2][31:24]=0xFF)
    imem[66]= 32'h0080_0f03;   //  lb   x30, 8(x0)       (x30=0xFFFFFFFF)
    imem[67]= 32'h00b0_4f83;   //  lbu  x31, 11(x0)      (x31=0x000000FF)
    imem[68]= 32'h01d0_1723;   //  sh   x29, 14(x0)      (dmem[3][31:16]=0xFFFF)
    imem[69]= 32'h00e0_1e83;   //  lh   x29, 14(x0)      (x29=0xFFFFFFFF)
    imem[70]= 32'h00e0_5c03;   //  lhu  x24, 14(x0)      (x24=0x0000FFFF)

    //  --- Minimal SYSTEM / CSR ---
    imem[71]= 32'h0190_2823;   //  sw    x25, 16(x0)     (save JAL landing result before CSR reuses x25)
    imem[72]= 32'hc000_2cf3;   //  csrrs x25, cycle, x0  (x25=cycle CSR)
    imem[73]= 32'h0000_0073;   //  ecall                 (debug event only)
    imem[74]= 32'h0010_0073;   //  ebreak                (debug event only)
  end

  assign imem_rdata = imem[imem_addr[9:2]];
  assign dmem_ready = 1'b1;
  assign dmem_rdata = dmem[dmem_addr[9:2]];

  always @(posedge clk) begin
    if (dmem_valid && dmem_write) begin
      if (dmem_wstrb[0]) dmem[dmem_addr[9:2]][7:0]   <= dmem_wdata[7:0];
      if (dmem_wstrb[1]) dmem[dmem_addr[9:2]][15:8]  <= dmem_wdata[15:8];
      if (dmem_wstrb[2]) dmem[dmem_addr[9:2]][23:16] <= dmem_wdata[23:16];
      if (dmem_wstrb[3]) dmem[dmem_addr[9:2]][31:24] <= dmem_wdata[31:24];
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      illegal_seen <= 1'b0;
      illegal_pc   <= 32'd0;
      jal_ret_seen <= 1'b0;
      jal_x24_ret  <= 32'd0;
      branch_score_seen <= 1'b0;
      branch_x24_score  <= 32'd0;
      lw_word_seen  <= 1'b0;
      lw_x24_value  <= 32'd0;
      ecall_seen   <= 1'b0;
      ebreak_seen  <= 1'b0;
      ecall_pc     <= 32'd0;
      ebreak_pc    <= 32'd0;
    end else begin
      if (dbg_illegal_instr) begin
        illegal_seen <= 1'b1;
        illegal_pc   <= dbg_pc;
      end
      if ((dbg_pc == 32'h0000_0084) && !jal_ret_seen) begin
        jal_ret_seen <= 1'b1;
        jal_x24_ret  <= dbg_reg_rdata;
      end
      if ((dbg_pc == 32'h0000_00e8) && !branch_score_seen) begin
        branch_score_seen <= 1'b1;
        branch_x24_score  <= dbg_reg_rdata;
      end
      if ((dbg_pc == 32'h0000_0100) && !lw_word_seen) begin
        lw_word_seen <= 1'b1;
        lw_x24_value <= dbg_reg_rdata;
      end
      if (dbg_ecall) begin
        ecall_seen <= 1'b1;
        ecall_pc   <= dbg_pc;
      end
      if (dbg_ebreak) begin
        ebreak_seen <= 1'b1;
        ebreak_pc   <= dbg_pc;
      end
    end
  end

  rv32i_core u_core (
    .clk        (clk),
    .rst_n      (rst_n),
    .imem_valid (imem_valid),
    .imem_addr  (imem_addr),
    .imem_rdata (imem_rdata),
    .dmem_valid (dmem_valid),
    .dmem_write (dmem_write),
    .dmem_addr  (dmem_addr),
    .dmem_wdata (dmem_wdata),
    .dmem_wstrb (dmem_wstrb),
    .dmem_ready (dmem_ready),
    .dmem_rdata (dmem_rdata),
    .dbg_pc     (dbg_pc),
    .dbg_cycle  (dbg_cycle),
    .dbg_reg_addr (dbg_reg_addr),
    .dbg_reg_rdata(dbg_reg_rdata),
    .dbg_illegal_instr(dbg_illegal_instr),
    .dbg_ecall   (dbg_ecall),
    .dbg_ebreak  (dbg_ebreak)
  );

  initial begin
    dbg_reg_addr = 5'd24;
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    repeat (105) @(posedge clk);
    #1;

    if (dbg_cycle == 32'd0) begin
      $fatal(1, "cycle counter did not advance");
    end

    if (dbg_pc == 32'd0) begin
      $fatal(1, "PC did not advance");
    end

    if (illegal_seen) begin
      $fatal(1, "unexpected illegal instruction observed at pc=0x%08x", illegal_pc);
    end

    if (!jal_ret_seen) begin
      $fatal(1, "JAL return snapshot was not captured");
    end

    if (!branch_score_seen) begin
      $fatal(1, "branch score snapshot was not captured");
    end

    if (!lw_word_seen) begin
      $fatal(1, "LW result snapshot was not captured");
    end

    if (!ecall_seen || (ecall_pc !== 32'h0000_0124)) begin
      $fatal(1, "ECALL event mismatch: seen=%0d pc=0x%08x", ecall_seen, ecall_pc);
    end

    if (!ebreak_seen || (ebreak_pc !== 32'h0000_0128)) begin
      $fatal(1, "EBREAK event mismatch: seen=%0d pc=0x%08x", ebreak_seen, ebreak_pc);
    end

    // original tests
    check_reg(5'd1,  32'd5,         "x1");
    check_reg(5'd2,  32'd7,         "x2");
    check_reg(5'd3,  32'd12,        "x3");
    check_reg(5'd4,  32'd7,         "x4");

    // setup
    check_reg(5'd5,  32'hFFFF_FFF8, "x5");

    // I-type
    check_reg(5'd6,  32'd1,         "x6 (slti)");
    check_reg(5'd7,  32'd0,         "x7 (sltiu)");
    check_reg(5'd8,  32'd4,         "x8 (andi)");
    check_reg(5'd9,  32'd13,        "x9 (ori)");
    check_reg(5'd10, 32'd2,         "x10 (xori)");
    check_reg(5'd11, 32'd28,        "x11 (slli)");
    check_reg(5'd12, 32'd3,         "x12 (srli)");
    check_reg(5'd13, 32'hFFFF_FFFE, "x13 (srai)");

    // R-type
    check_reg(5'd14, 32'd640,       "x14 (sll)");
    check_reg(5'd15, 32'd1,         "x15 (slt)");
    check_reg(5'd16, 32'd0,         "x16 (sltu)");
    check_reg(5'd17, 32'd2,         "x17 (xor)");
    check_reg(5'd18, 32'h07FF_FFFF, "x18 (srl)");
    check_reg(5'd19, 32'hFFFF_FFFF, "x19 (sra)");
    check_reg(5'd20, 32'd7,         "x20 (or)");
    check_reg(5'd21, 32'd5,         "x21 (and)");

    // U-type
    check_reg(5'd22, 32'h1234_5000, "x22 (lui)");
    check_reg(5'd23, 32'h1000_0058, "x23 (auipc)");

    // JAL / JALR
    if (jal_x24_ret !== 32'h0000_0060) begin
      $fatal(1, "x24 (jal ret) mismatch: expected 0x60, got 0x%08x", jal_x24_ret);
    end
    if (dmem[4] !== 32'h0000_00DE) begin
      $fatal(1, "x25 (jal land saved) mismatch: expected 0xDE, got 0x%08x", dmem[4]);
    end
    check_reg(5'd26, 32'h0000_0080, "x26 (jalr base)");
    check_reg(5'd27, 32'h0000_0070, "x27 (jalr ret)");
    check_reg(5'd28, 32'h0000_00FF, "x28 (jalr land)");

    // B-type
    if (branch_x24_score !== 32'd63) begin
      $fatal(1, "x24 (branch score) mismatch: expected 63, got %0d", branch_x24_score);
    end

    // Load / store
    if (dmem[1] !== 32'h1234_5678) begin
      $fatal(1, "dmem[1] mismatch: expected 0x12345678, got 0x%08x", dmem[1]);
    end
    if (lw_x24_value !== 32'h1234_5678) begin
      $fatal(1, "x24 (lw result) mismatch: expected 0x12345678, got 0x%08x", lw_x24_value);
    end

    // Byte / halfword load-store
    if (dmem[2] !== 32'hFF00_00FF) begin
      $fatal(1, "dmem[2] mismatch: expected 0xFF0000FF, got 0x%08x", dmem[2]);
    end
    if (dmem[3] !== 32'hFFFF_0000) begin
      $fatal(1, "dmem[3] mismatch: expected 0xFFFF0000, got 0x%08x", dmem[3]);
    end
    check_reg(5'd30, 32'hFFFF_FFFF, "x30 (lb result)");
    check_reg(5'd31, 32'h0000_00FF, "x31 (lbu result)");
    check_reg(5'd29, 32'hFFFF_FFFF, "x29 (lh result)");
    check_reg(5'd24, 32'h0000_FFFF, "x24 (lhu result)");

    // Minimal SYSTEM / CSR
    dbg_reg_addr = 5'd25;
    #1ps;
    csr_cycle_value = dbg_reg_rdata;
    if (csr_cycle_value == 32'd0) begin
      $fatal(1, "x25 (cycle CSR) should be non-zero");
    end
    if (csr_cycle_value >= dbg_cycle) begin
      $fatal(1, "x25 (cycle CSR) should be smaller than final cycle: csr=%0d final=%0d",
             csr_cycle_value, dbg_cycle);
    end

    $display("[PASS] rv32i_core_tb");
    $display("  pc=0x%08x cycle=%0d", dbg_pc, dbg_cycle);
    $display("  directed register checks passed");
    $display("  jal_x24_ret=0x%08x", jal_x24_ret);
    $display("  branch_score(x24)=%0d", branch_x24_score);
    $display("  dmem[1]=0x%08x lw_x24=0x%08x", dmem[1], lw_x24_value);
    $display("  dmem[2]=0x%08x dmem[3]=0x%08x byte_half_loads passed", dmem[2], dmem[3]);
    $display("  jal_x25_store(dmem[4])=0x%08x", dmem[4]);
    $display("  cycle_csr(x25)=%0d ecall_pc=0x%08x ebreak_pc=0x%08x",
             csr_cycle_value, ecall_pc, ebreak_pc);
    $finish;
  end

endmodule
