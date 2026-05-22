module rv32i_perf_counter (
  input  wire        clk,
  input  wire        rst_n,

  input  wire        instret_event,
  input  wire        stall_event,
  input  wire        flush_event,
  input  wire        branch_event,
  input  wire        branch_mispredict_event,
  input  wire        load_use_stall_event,
  input  wire        ifetch_wait_event,
  input  wire        if_discard_event,
  input  wire        mem_wait_event,
  input  wire        muldiv_wait_event,
  input  wire        branch_redirect_event,
  input  wire        commit_redirect_event,

  output reg  [31:0] cycle_count,
  output reg  [31:0] instret_count,
  output reg  [31:0] stall_cycle_count,
  output reg  [31:0] flush_cycle_count,
  output reg  [31:0] branch_count,
  output reg  [31:0] branch_mispredict_count,
  output reg  [31:0] load_use_stall_cycle_count,
  output reg  [31:0] ifetch_wait_cycle_count,
  output reg  [31:0] if_discard_cycle_count,
  output reg  [31:0] mem_wait_cycle_count,
  output reg  [31:0] muldiv_wait_cycle_count,
  output reg  [31:0] branch_redirect_cycle_count,
  output reg  [31:0] commit_redirect_cycle_count
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count                  <= 32'd0;
      instret_count                <= 32'd0;
      stall_cycle_count            <= 32'd0;
      flush_cycle_count            <= 32'd0;
      branch_count                 <= 32'd0;
      branch_mispredict_count      <= 32'd0;
      load_use_stall_cycle_count   <= 32'd0;
      ifetch_wait_cycle_count      <= 32'd0;
      if_discard_cycle_count       <= 32'd0;
      mem_wait_cycle_count         <= 32'd0;
      muldiv_wait_cycle_count      <= 32'd0;
      branch_redirect_cycle_count  <= 32'd0;
      commit_redirect_cycle_count  <= 32'd0;
    end else begin
      cycle_count <= cycle_count + 32'd1;

      if (instret_event) begin
        instret_count <= instret_count + 32'd1;
      end
      if (stall_event) begin
        stall_cycle_count <= stall_cycle_count + 32'd1;
      end
      if (flush_event) begin
        flush_cycle_count <= flush_cycle_count + 32'd1;
      end
      if (branch_event) begin
        branch_count <= branch_count + 32'd1;
      end
      if (branch_mispredict_event) begin
        branch_mispredict_count <= branch_mispredict_count + 32'd1;
      end
      if (load_use_stall_event) begin
        load_use_stall_cycle_count <= load_use_stall_cycle_count + 32'd1;
      end
      if (ifetch_wait_event) begin
        ifetch_wait_cycle_count <= ifetch_wait_cycle_count + 32'd1;
      end
      if (if_discard_event) begin
        if_discard_cycle_count <= if_discard_cycle_count + 32'd1;
      end
      if (mem_wait_event) begin
        mem_wait_cycle_count <= mem_wait_cycle_count + 32'd1;
      end
      if (muldiv_wait_event) begin
        muldiv_wait_cycle_count <= muldiv_wait_cycle_count + 32'd1;
      end
      if (branch_redirect_event) begin
        branch_redirect_cycle_count <= branch_redirect_cycle_count + 32'd1;
      end
      if (commit_redirect_event) begin
        commit_redirect_cycle_count <= commit_redirect_cycle_count + 32'd1;
      end
    end
  end

endmodule
