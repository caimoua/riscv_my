`timescale 1ns/1ps

module rv32i_perf_baseline_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  wire [31:0] ahb_haddr;
  wire [2:0]  ahb_hburst;
  wire [3:0]  ahb_hprot;
  wire [2:0]  ahb_hsize;
  wire [1:0]  ahb_htrans;
  wire [31:0] ahb_hwdata;
  wire        ahb_hwrite;
  wire [31:0] ahb_hrdata;
  wire        ahb_hready;
  wire [1:0]  ahb_hresp;

  wire        rom_hsel;
  wire [31:0] rom_haddr;
  wire [2:0]  rom_hburst;
  wire [3:0]  rom_hprot;
  wire [2:0]  rom_hsize;
  wire [1:0]  rom_htrans;
  wire [31:0] rom_hwdata;
  wire        rom_hwrite;
  wire        rom_hready;
  wire [31:0] rom_hrdata;
  wire        rom_hreadyout;
  wire [1:0]  rom_hresp;

  wire        sram_hsel;
  wire [31:0] sram_haddr;
  wire [2:0]  sram_hburst;
  wire [3:0]  sram_hprot;
  wire [2:0]  sram_hsize;
  wire [1:0]  sram_htrans;
  wire [31:0] sram_hwdata;
  wire        sram_hwrite;
  wire        sram_hready;
  wire [31:0] sram_hrdata;
  wire        sram_hreadyout;
  wire [1:0]  sram_hresp;

  wire        mmio_hsel;
  wire [31:0] mmio_haddr;
  wire [2:0]  mmio_hburst;
  wire [3:0]  mmio_hprot;
  wire [2:0]  mmio_hsize;
  wire [1:0]  mmio_htrans;
  wire [31:0] mmio_hwdata;
  wire        mmio_hwrite;
  wire        mmio_hready;
  wire [31:0] mmio_hrdata;
  wire        mmio_hreadyout;
  wire [1:0]  mmio_hresp;

  wire        rom_valid;
  wire        rom_write;
  wire [31:0] rom_addr;
  wire [31:0] rom_wdata;
  wire [3:0]  rom_wstrb;
  wire        rom_ready;
  wire [31:0] rom_rdata;

  wire        sram_valid;
  wire        sram_write;
  wire [31:0] sram_addr;
  wire [31:0] sram_wdata;
  wire [3:0]  sram_wstrb;
  wire        sram_ready;
  wire [31:0] sram_rdata;

  wire        mmio_valid;
  wire        mmio_write;
  wire [31:0] mmio_addr;
  wire [31:0] mmio_wdata;
  wire [3:0]  mmio_wstrb;
  wire        mmio_ready;
  wire [31:0] mmio_rdata;

  wire [31:0] dbg_pc;
  wire [31:0] dbg_cycle;
  wire [31:0] dbg_instret;
  wire [31:0] dbg_stall_cycle;
  wire [31:0] dbg_flush_cycle;
  wire [31:0] dbg_load_use_stall_cycle;
  wire [31:0] dbg_ifetch_wait_cycle;
  wire [31:0] dbg_if_discard_cycle;
  wire [31:0] dbg_mem_wait_cycle;
  wire [31:0] dbg_muldiv_wait_cycle;
  wire [31:0] dbg_branch_redirect_cycle;
  wire [31:0] dbg_commit_redirect_cycle;
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
  wire [31:0] dbg_icache_hit_count;
  wire [31:0] dbg_icache_miss_count;
  wire [31:0] dbg_dcache_hit_count;
  wire [31:0] dbg_dcache_miss_count;
  wire [31:0] dbg_bus_i_grant_count;
  wire [31:0] dbg_bus_d_grant_count;
  wire        dbg_bus_error;

  logic [31:0] rom [0:4095];
  logic [31:0] sram [0:1023];
  logic [31:0] mmio_reg;
  wire         ahb_decode_error;

  string       rom_memh;
  string       workload_name;
  string       config_name;
  logic [31:0] expected_signature;
  logic [31:0] actual_signature;
  logic [31:0] fail_code;
  logic [31:0] pass_marker;
  integer      i;
  integer      memh_fd;
  integer      timeout;
  integer      timeout_limit;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2) clk = ~clk;
  end

  task automatic read_reg(
    input  [4:0]  reg_addr,
    output [31:0] reg_value
  );
    begin
      dbg_reg_addr = reg_addr;
      #1ps;
      reg_value = dbg_reg_rdata;
    end
  endtask

  task automatic print_perf_summary;
    real cpi;
    real stall_pct;
    real flush_pct;
    begin
      cpi = 0.0;
      stall_pct = 0.0;
      flush_pct = 0.0;
      if (dbg_instret != 32'd0) begin
        cpi = $itor(dbg_cycle) / $itor(dbg_instret);
      end
      if (dbg_cycle != 32'd0) begin
        stall_pct = ($itor(dbg_stall_cycle) * 100.0) / $itor(dbg_cycle);
        flush_pct = ($itor(dbg_flush_cycle) * 100.0) / $itor(dbg_cycle);
      end

      $display("[PASS] rv32i_perf_baseline_tb");
      $display("[PERF] name=%s config=%s status=PASS", workload_name, config_name);
      $display("[PERF] cycle=%0d instret=%0d cpi=%0.3f stall_pct=%0.2f flush_pct=%0.2f",
               dbg_cycle, dbg_instret, cpi, stall_pct, flush_pct);
      $display("[PERF] stall=%0d flush=%0d load_use=%0d ifetch_wait=%0d if_discard=%0d mem_wait=%0d muldiv_wait=%0d",
               dbg_stall_cycle, dbg_flush_cycle, dbg_load_use_stall_cycle,
               dbg_ifetch_wait_cycle, dbg_if_discard_cycle, dbg_mem_wait_cycle,
               dbg_muldiv_wait_cycle);
      $display("[PERF] redirect branch=%0d commit=%0d branch_count=%0d mispredict=%0d btb_hit=%0d btb_miss=%0d bht_update=%0d",
               dbg_branch_redirect_cycle, dbg_commit_redirect_cycle,
               dbg_branch_count, dbg_branch_mispredict_count,
               dbg_btb_hit_count, dbg_btb_miss_count, dbg_bht_update_count);
      $display("[PERF] cache_bus ic_hit=%0d ic_miss=%0d dc_hit=%0d dc_miss=%0d bus_i=%0d bus_d=%0d",
               dbg_icache_hit_count, dbg_icache_miss_count,
               dbg_dcache_hit_count, dbg_dcache_miss_count,
               dbg_bus_i_grant_count, dbg_bus_d_grant_count);
      $display("PERF_CSV_HEADER,name,config,cycle,instret,cpi,stall_cycle,flush_cycle,load_use_stall,ifetch_wait,if_discard,mem_wait,muldiv_wait,branch_redirect,commit_redirect,branch_count,branch_mispredict,btb_hit,btb_miss,bht_update,ic_hit,ic_miss,dc_hit,dc_miss,bus_i_grant,bus_d_grant");
      $display("PERF_CSV,%s,%s,%0d,%0d,%0.3f,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
               workload_name, config_name, dbg_cycle, dbg_instret, cpi,
               dbg_stall_cycle, dbg_flush_cycle, dbg_load_use_stall_cycle,
               dbg_ifetch_wait_cycle, dbg_if_discard_cycle, dbg_mem_wait_cycle,
               dbg_muldiv_wait_cycle, dbg_branch_redirect_cycle,
               dbg_commit_redirect_cycle, dbg_branch_count,
               dbg_branch_mispredict_count, dbg_btb_hit_count,
               dbg_btb_miss_count, dbg_bht_update_count,
               dbg_icache_hit_count, dbg_icache_miss_count,
               dbg_dcache_hit_count, dbg_dcache_miss_count,
               dbg_bus_i_grant_count, dbg_bus_d_grant_count);
    end
  endtask

  initial begin
    for (i = 0; i < 4096; i = i + 1) begin
      rom[i] = 32'h0000_0013;
    end
    for (i = 0; i < 1024; i = i + 1) begin
      sram[i] = 32'd0;
    end

    mmio_reg = 32'd0;
    workload_name = "perf_branch_loop";
    config_name = "baseline-ahb-master";
    rom_memh = "../software/bin/perf_branch_loop.memh";
    expected_signature = 32'h0b12_0001;
    timeout_limit = 5000;

    if (!$value$plusargs("WORKLOAD=%s", workload_name)) begin
      workload_name = "perf_branch_loop";
    end
    if (!$value$plusargs("CONFIG=%s", config_name)) begin
      config_name = "baseline-ahb-master";
    end
    if (!$value$plusargs("ROM_MEMH=%s", rom_memh)) begin
      rom_memh = "../software/bin/perf_branch_loop.memh";
    end
    if (!$value$plusargs("SIGNATURE=%h", expected_signature)) begin
      expected_signature = 32'h0b12_0001;
    end
    if (!$value$plusargs("TIMEOUT=%d", timeout_limit)) begin
      timeout_limit = 5000;
    end

    memh_fd = $fopen(rom_memh, "r");
    if (memh_fd == 0) begin
      $fatal(1, "failed to open ROM_MEMH='%s'", rom_memh);
    end
    $fclose(memh_fd);
    $readmemh(rom_memh, rom);
  end

  assign rom_ready = rom_valid;
  assign rom_rdata = rom[rom_addr[13:2]];

  assign sram_ready = sram_valid;
  assign sram_rdata = sram[sram_addr[11:2]];

  assign mmio_ready = mmio_valid;
  assign mmio_rdata = mmio_reg;

  always @(posedge clk) begin
    if (rom_valid && rom_ready && rom_write) begin
      $fatal(1, "unexpected ROM write in perf baseline test");
    end

    if (sram_valid && sram_ready && sram_write) begin
      if (sram_wstrb[0]) sram[sram_addr[11:2]][7:0]   <= sram_wdata[7:0];
      if (sram_wstrb[1]) sram[sram_addr[11:2]][15:8]  <= sram_wdata[15:8];
      if (sram_wstrb[2]) sram[sram_addr[11:2]][23:16] <= sram_wdata[23:16];
      if (sram_wstrb[3]) sram[sram_addr[11:2]][31:24] <= sram_wdata[31:24];
    end

    if (mmio_valid && mmio_ready && mmio_write) begin
      if (mmio_wstrb[0]) mmio_reg[7:0]   <= mmio_wdata[7:0];
      if (mmio_wstrb[1]) mmio_reg[15:8]  <= mmio_wdata[15:8];
      if (mmio_wstrb[2]) mmio_reg[23:16] <= mmio_wdata[23:16];
      if (mmio_wstrb[3]) mmio_reg[31:24] <= mmio_wdata[31:24];
    end
  end

  rv32i_cached_ahb_master_top #(
    .ICACHE_INDEX_BITS(2),
    .DCACHE_INDEX_BITS(2)
  ) u_cpu (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .timer_irq              (1'b0),
    .ahb_haddr              (ahb_haddr),
    .ahb_hburst             (ahb_hburst),
    .ahb_hprot              (ahb_hprot),
    .ahb_hsize              (ahb_hsize),
    .ahb_htrans             (ahb_htrans),
    .ahb_hwdata             (ahb_hwdata),
    .ahb_hwrite             (ahb_hwrite),
    .ahb_hrdata             (ahb_hrdata),
    .ahb_hready             (ahb_hready),
    .ahb_hresp              (ahb_hresp),
    .dbg_pc                 (dbg_pc),
    .dbg_cycle              (dbg_cycle),
    .dbg_instret            (dbg_instret),
    .dbg_stall_cycle        (dbg_stall_cycle),
    .dbg_flush_cycle        (dbg_flush_cycle),
    .dbg_load_use_stall_cycle  (dbg_load_use_stall_cycle),
    .dbg_ifetch_wait_cycle  (dbg_ifetch_wait_cycle),
    .dbg_if_discard_cycle   (dbg_if_discard_cycle),
    .dbg_mem_wait_cycle     (dbg_mem_wait_cycle),
    .dbg_muldiv_wait_cycle  (dbg_muldiv_wait_cycle),
    .dbg_branch_redirect_cycle (dbg_branch_redirect_cycle),
    .dbg_commit_redirect_cycle (dbg_commit_redirect_cycle),
    .dbg_branch_count       (dbg_branch_count),
    .dbg_branch_mispredict_count(dbg_branch_mispredict_count),
    .dbg_btb_hit_count      (dbg_btb_hit_count),
    .dbg_btb_miss_count     (dbg_btb_miss_count),
    .dbg_bht_update_count   (dbg_bht_update_count),
    .dbg_reg_addr           (dbg_reg_addr),
    .dbg_reg_rdata          (dbg_reg_rdata),
    .dbg_illegal_instr      (dbg_illegal_instr),
    .dbg_ecall              (dbg_ecall),
    .dbg_ebreak             (dbg_ebreak),
    .dbg_icache_hit_count   (dbg_icache_hit_count),
    .dbg_icache_miss_count  (dbg_icache_miss_count),
    .dbg_dcache_hit_count   (dbg_dcache_hit_count),
    .dbg_dcache_miss_count  (dbg_dcache_miss_count),
    .dbg_bus_i_grant_count  (dbg_bus_i_grant_count),
    .dbg_bus_d_grant_count  (dbg_bus_d_grant_count),
    .dbg_bus_error          (dbg_bus_error)
  );

  rv32i_ahb_lite_decoder u_ahb_decoder (
    .clk              (clk),
    .rst_n            (rst_n),
    .m_haddr          (ahb_haddr),
    .m_hburst         (ahb_hburst),
    .m_hprot          (ahb_hprot),
    .m_hsize          (ahb_hsize),
    .m_htrans         (ahb_htrans),
    .m_hwdata         (ahb_hwdata),
    .m_hwrite         (ahb_hwrite),
    .m_hrdata         (ahb_hrdata),
    .m_hready         (ahb_hready),
    .m_hresp          (ahb_hresp),
    .s0_hsel          (rom_hsel),
    .s0_haddr         (rom_haddr),
    .s0_hburst        (rom_hburst),
    .s0_hprot         (rom_hprot),
    .s0_hsize         (rom_hsize),
    .s0_htrans        (rom_htrans),
    .s0_hwdata        (rom_hwdata),
    .s0_hwrite        (rom_hwrite),
    .s0_hready        (rom_hready),
    .s0_hrdata        (rom_hrdata),
    .s0_hreadyout     (rom_hreadyout),
    .s0_hresp         (rom_hresp),
    .s1_hsel          (sram_hsel),
    .s1_haddr         (sram_haddr),
    .s1_hburst        (sram_hburst),
    .s1_hprot         (sram_hprot),
    .s1_hsize         (sram_hsize),
    .s1_htrans        (sram_htrans),
    .s1_hwdata        (sram_hwdata),
    .s1_hwrite        (sram_hwrite),
    .s1_hready        (sram_hready),
    .s1_hrdata        (sram_hrdata),
    .s1_hreadyout     (sram_hreadyout),
    .s1_hresp         (sram_hresp),
    .s2_hsel          (mmio_hsel),
    .s2_haddr         (mmio_haddr),
    .s2_hburst        (mmio_hburst),
    .s2_hprot         (mmio_hprot),
    .s2_hsize         (mmio_hsize),
    .s2_htrans        (mmio_htrans),
    .s2_hwdata        (mmio_hwdata),
    .s2_hwrite        (mmio_hwrite),
    .s2_hready        (mmio_hready),
    .s2_hrdata        (mmio_hrdata),
    .s2_hreadyout     (mmio_hreadyout),
    .s2_hresp         (mmio_hresp),
    .dbg_decode_error (ahb_decode_error)
  );

  rv32i_ahb_to_simple u_rom_ahb_to_simple (
    .clk       (clk),
    .rst_n     (rst_n),
    .hsel      (rom_hsel),
    .haddr     (rom_haddr),
    .hburst    (rom_hburst),
    .hprot     (rom_hprot),
    .hsize     (rom_hsize),
    .htrans    (rom_htrans),
    .hwdata    (rom_hwdata),
    .hwrite    (rom_hwrite),
    .hready    (rom_hready),
    .hrdata    (rom_hrdata),
    .hreadyout (rom_hreadyout),
    .hresp     (rom_hresp),
    .valid     (rom_valid),
    .write     (rom_write),
    .addr      (rom_addr),
    .wdata     (rom_wdata),
    .wstrb     (rom_wstrb),
    .ready     (rom_ready),
    .rdata     (rom_rdata),
    .error     (1'b0)
  );

  rv32i_ahb_to_simple u_sram_ahb_to_simple (
    .clk       (clk),
    .rst_n     (rst_n),
    .hsel      (sram_hsel),
    .haddr     (sram_haddr),
    .hburst    (sram_hburst),
    .hprot     (sram_hprot),
    .hsize     (sram_hsize),
    .htrans    (sram_htrans),
    .hwdata    (sram_hwdata),
    .hwrite    (sram_hwrite),
    .hready    (sram_hready),
    .hrdata    (sram_hrdata),
    .hreadyout (sram_hreadyout),
    .hresp     (sram_hresp),
    .valid     (sram_valid),
    .write     (sram_write),
    .addr      (sram_addr),
    .wdata     (sram_wdata),
    .wstrb     (sram_wstrb),
    .ready     (sram_ready),
    .rdata     (sram_rdata),
    .error     (1'b0)
  );

  rv32i_ahb_to_simple u_mmio_ahb_to_simple (
    .clk       (clk),
    .rst_n     (rst_n),
    .hsel      (mmio_hsel),
    .haddr     (mmio_haddr),
    .hburst    (mmio_hburst),
    .hprot     (mmio_hprot),
    .hsize     (mmio_hsize),
    .htrans    (mmio_htrans),
    .hwdata    (mmio_hwdata),
    .hwrite    (mmio_hwrite),
    .hready    (mmio_hready),
    .hrdata    (mmio_hrdata),
    .hreadyout (mmio_hreadyout),
    .hresp     (mmio_hresp),
    .valid     (mmio_valid),
    .write     (mmio_write),
    .addr      (mmio_addr),
    .wdata     (mmio_wdata),
    .wstrb     (mmio_wstrb),
    .ready     (mmio_ready),
    .rdata     (mmio_rdata),
    .error     (1'b0)
  );

  initial begin
    dbg_reg_addr = 5'd0;
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    timeout = 0;
    while (!dbg_ebreak && (timeout < timeout_limit)) begin
      @(posedge clk);
      #1ps;
      timeout = timeout + 1;
    end

    if (!dbg_ebreak) begin
      $fatal(1, "timeout waiting for perf workload '%s' ebreak", workload_name);
    end
    if (dbg_illegal_instr || dbg_ecall || dbg_bus_error || ahb_decode_error) begin
      $fatal(1, "unexpected trap or bus event in perf workload '%s'", workload_name);
    end

    read_reg(5'd30, fail_code);
    read_reg(5'd31, pass_marker);
    read_reg(5'd29, actual_signature);

    if (fail_code !== 32'd0) begin
      $fatal(1, "workload '%s' reported fail code %0d", workload_name, fail_code);
    end
    if (pass_marker !== 32'd1) begin
      $fatal(1, "workload '%s' pass marker mismatch: got 0x%08x",
             workload_name, pass_marker);
    end
    if (actual_signature !== expected_signature) begin
      $fatal(1, "workload '%s' signature mismatch: expected 0x%08x, got 0x%08x",
             workload_name, expected_signature, actual_signature);
    end

    print_perf_summary();
    $finish;
  end

endmodule
