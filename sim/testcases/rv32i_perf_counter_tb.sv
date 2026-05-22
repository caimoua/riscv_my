`timescale 1ns/1ps

module rv32i_perf_counter_tb;

  localparam CLK_PERIOD_NS = 10;

  logic clk;
  logic rst_n;

  logic instret_event;
  logic stall_event;
  logic flush_event;
  logic branch_event;
  logic branch_mispredict_event;
  logic load_use_stall_event;
  logic ifetch_wait_event;
  logic if_discard_event;
  logic mem_wait_event;
  logic muldiv_wait_event;
  logic branch_redirect_event;
  logic commit_redirect_event;

  wire [31:0] cycle_count;
  wire [31:0] instret_count;
  wire [31:0] stall_cycle_count;
  wire [31:0] flush_cycle_count;
  wire [31:0] branch_count;
  wire [31:0] branch_mispredict_count;
  wire [31:0] load_use_stall_cycle_count;
  wire [31:0] ifetch_wait_cycle_count;
  wire [31:0] if_discard_cycle_count;
  wire [31:0] mem_wait_cycle_count;
  wire [31:0] muldiv_wait_cycle_count;
  wire [31:0] branch_redirect_cycle_count;
  wire [31:0] commit_redirect_cycle_count;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2) clk = ~clk;
  end

  task automatic check_value(
    input [31:0] actual,
    input [31:0] expected,
    input string name
  );
    begin
      if (actual !== expected) begin
        $fatal(1, "%s mismatch: expected 0x%08x, got 0x%08x",
               name, expected, actual);
      end
    end
  endtask

  task automatic clear_events;
    begin
      instret_event = 1'b0;
      stall_event = 1'b0;
      flush_event = 1'b0;
      branch_event = 1'b0;
      branch_mispredict_event = 1'b0;
      load_use_stall_event = 1'b0;
      ifetch_wait_event = 1'b0;
      if_discard_event = 1'b0;
      mem_wait_event = 1'b0;
      muldiv_wait_event = 1'b0;
      branch_redirect_event = 1'b0;
      commit_redirect_event = 1'b0;
    end
  endtask

  task automatic check_counts(
    input [31:0] expected_cycle,
    input [31:0] expected_instret,
    input [31:0] expected_stall,
    input [31:0] expected_flush,
    input [31:0] expected_branch,
    input [31:0] expected_mispredict,
    input [31:0] expected_load_use,
    input [31:0] expected_ifetch_wait,
    input [31:0] expected_if_discard,
    input [31:0] expected_mem_wait,
    input [31:0] expected_muldiv_wait,
    input [31:0] expected_branch_redirect,
    input [31:0] expected_commit_redirect
  );
    begin
      check_value(cycle_count, expected_cycle, "cycle_count");
      check_value(instret_count, expected_instret, "instret_count");
      check_value(stall_cycle_count, expected_stall, "stall_cycle_count");
      check_value(flush_cycle_count, expected_flush, "flush_cycle_count");
      check_value(branch_count, expected_branch, "branch_count");
      check_value(branch_mispredict_count, expected_mispredict,
                  "branch_mispredict_count");
      check_value(load_use_stall_cycle_count, expected_load_use,
                  "load_use_stall_cycle_count");
      check_value(ifetch_wait_cycle_count, expected_ifetch_wait,
                  "ifetch_wait_cycle_count");
      check_value(if_discard_cycle_count, expected_if_discard,
                  "if_discard_cycle_count");
      check_value(mem_wait_cycle_count, expected_mem_wait,
                  "mem_wait_cycle_count");
      check_value(muldiv_wait_cycle_count, expected_muldiv_wait,
                  "muldiv_wait_cycle_count");
      check_value(branch_redirect_cycle_count, expected_branch_redirect,
                  "branch_redirect_cycle_count");
      check_value(commit_redirect_cycle_count, expected_commit_redirect,
                  "commit_redirect_cycle_count");
    end
  endtask

  rv32i_perf_counter u_perf_counter (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .instret_event           (instret_event),
    .stall_event             (stall_event),
    .flush_event             (flush_event),
    .branch_event            (branch_event),
    .branch_mispredict_event (branch_mispredict_event),
    .load_use_stall_event    (load_use_stall_event),
    .ifetch_wait_event       (ifetch_wait_event),
    .if_discard_event        (if_discard_event),
    .mem_wait_event          (mem_wait_event),
    .muldiv_wait_event       (muldiv_wait_event),
    .branch_redirect_event   (branch_redirect_event),
    .commit_redirect_event   (commit_redirect_event),
    .cycle_count             (cycle_count),
    .instret_count           (instret_count),
    .stall_cycle_count       (stall_cycle_count),
    .flush_cycle_count       (flush_cycle_count),
    .branch_count            (branch_count),
    .branch_mispredict_count (branch_mispredict_count),
    .load_use_stall_cycle_count(load_use_stall_cycle_count),
    .ifetch_wait_cycle_count (ifetch_wait_cycle_count),
    .if_discard_cycle_count  (if_discard_cycle_count),
    .mem_wait_cycle_count    (mem_wait_cycle_count),
    .muldiv_wait_cycle_count (muldiv_wait_cycle_count),
    .branch_redirect_cycle_count(branch_redirect_cycle_count),
    .commit_redirect_cycle_count(commit_redirect_cycle_count)
  );

  initial begin
    clear_events();
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    #1ps;
    check_counts(32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0,
                 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0);

    rst_n = 1'b1;
    @(posedge clk);
    #1ps;
    check_counts(32'd1, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0,
                 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0);

    instret_event = 1'b1;
    stall_event = 1'b1;
    branch_event = 1'b1;
    load_use_stall_event = 1'b1;
    ifetch_wait_event = 1'b1;
    mem_wait_event = 1'b1;
    @(posedge clk);
    #1ps;
    check_counts(32'd2, 32'd1, 32'd1, 32'd0, 32'd1, 32'd0,
                 32'd1, 32'd1, 32'd0, 32'd1, 32'd0, 32'd0, 32'd0);

    clear_events();
    flush_event = 1'b1;
    branch_event = 1'b1;
    branch_mispredict_event = 1'b1;
    if_discard_event = 1'b1;
    muldiv_wait_event = 1'b1;
    branch_redirect_event = 1'b1;
    commit_redirect_event = 1'b1;
    @(posedge clk);
    #1ps;
    check_counts(32'd3, 32'd1, 32'd1, 32'd1, 32'd2, 32'd1,
                 32'd1, 32'd1, 32'd1, 32'd1, 32'd1, 32'd1, 32'd1);

    instret_event = 1'b1;
    stall_event = 1'b1;
    flush_event = 1'b1;
    branch_event = 1'b1;
    branch_mispredict_event = 1'b1;
    load_use_stall_event = 1'b1;
    ifetch_wait_event = 1'b1;
    if_discard_event = 1'b1;
    mem_wait_event = 1'b1;
    muldiv_wait_event = 1'b1;
    branch_redirect_event = 1'b1;
    commit_redirect_event = 1'b1;
    @(posedge clk);
    #1ps;
    check_counts(32'd4, 32'd2, 32'd2, 32'd2, 32'd3, 32'd2,
                 32'd2, 32'd2, 32'd2, 32'd2, 32'd2, 32'd2, 32'd2);

    clear_events();
    @(posedge clk);
    #1ps;
    check_counts(32'd5, 32'd2, 32'd2, 32'd2, 32'd3, 32'd2,
                 32'd2, 32'd2, 32'd2, 32'd2, 32'd2, 32'd2, 32'd2);

    rst_n = 1'b0;
    #1ps;
    check_counts(32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0,
                 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0);

    $display("[PASS] rv32i_perf_counter_tb");
    $display("  cycle=%0d instret=%0d stall=%0d flush=%0d",
             cycle_count, instret_count, stall_cycle_count,
             flush_cycle_count);
    $display("  branch=%0d branch_mispredict=%0d",
             branch_count, branch_mispredict_count);
    $display("  load_use=%0d ifetch_wait=%0d if_discard=%0d",
             load_use_stall_cycle_count, ifetch_wait_cycle_count,
             if_discard_cycle_count);
    $display("  mem_wait=%0d muldiv_wait=%0d branch_redirect=%0d commit_redirect=%0d",
             mem_wait_cycle_count, muldiv_wait_cycle_count,
             branch_redirect_cycle_count, commit_redirect_cycle_count);
    $display("  standalone performance counter events and reset passed");
    $finish;
  end

endmodule
