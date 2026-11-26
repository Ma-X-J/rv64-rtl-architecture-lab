`timescale 1ns/1ps

module DCacheStoreLoop_tb;
  reg         clk;
  reg         reset;
  reg         cpu_req_valid;
  reg  [63:0] cpu_req_addr;
  reg         cpu_req_write;
  reg  [63:0] cpu_req_wdata;
  wire        cpu_req_ready;
  wire        cpu_resp_valid;
  wire [63:0] cpu_resp_rdata;

  wire        mem_req_ready;
  wire        mem_resp_valid;
  wire [63:0] mem_resp_rdata;
  wire        mem_req_valid;
  wire        mem_req_write;
  wire [63:0] mem_req_addr;
  wire [63:0] mem_req_wdata;
  wire [7:0]  mem_req_wstrb;

  integer checks;
  integer backend_reads;
  integer backend_writes;

  DCache dut (
    .clk(clk),
    .reset(reset),
    .cpu_req_valid(cpu_req_valid),
    .cpu_req_addr(cpu_req_addr),
    .cpu_req_write(cpu_req_write),
    .cpu_req_wdata(cpu_req_wdata),
    .cpu_req_wstrb(8'hff),
    .cpu_req_ready(cpu_req_ready),
    .cpu_resp_valid(cpu_resp_valid),
    .cpu_resp_rdata(cpu_resp_rdata),
    .mem_req_ready(mem_req_ready),
    .mem_resp_valid(mem_resp_valid),
    .mem_resp_rdata(mem_resp_rdata),
    .mem_req_valid(mem_req_valid),
    .mem_req_write(mem_req_write),
    .mem_req_addr(mem_req_addr),
    .mem_req_wdata(mem_req_wdata),
    .mem_req_wstrb(mem_req_wstrb)
  );

  CacheBackingMemory memory_model (
    .clk(clk),
    .reset(reset),
    .req_valid(mem_req_valid),
    .req_write(mem_req_write),
    .req_addr(mem_req_addr),
    .req_wdata(mem_req_wdata),
    .req_wstrb(mem_req_wstrb),
    .req_ready(mem_req_ready),
    .resp_valid(mem_resp_valid),
    .resp_rdata(mem_resp_rdata)
  );

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (mem_req_valid && mem_req_ready) begin
      if (mem_req_write)
        backend_writes = backend_writes + 1;
      else
        backend_reads = backend_reads + 1;
    end
  end

  task issue_store;
    input [63:0] address;
    input [63:0] write_data;
    integer timeout;
    begin
      @(negedge clk);
      cpu_req_valid = 1'b1;
      cpu_req_addr = address;
      cpu_req_write = 1'b1;
      cpu_req_wdata = write_data;
      #1;
      if (cpu_req_ready !== 1'b1 || cpu_resp_valid !== 1'b0)
        $fatal(1, "Store was not accepted without premature completion");

      @(posedge clk);
      #1;
      if (dut.state !== dut.STATE_STORE_REQ)
        $fatal(1, "accepted Store did not enter STORE_REQ");
      @(negedge clk);
      cpu_req_valid = 1'b0;

      timeout = 0;
      while (cpu_resp_valid !== 1'b1) begin
        @(negedge clk);
        timeout = timeout + 1;
        if (timeout > 40)
          $fatal(1, "timed out waiting for Store completion");
      end
      #1;
      if (dut.state !== dut.STATE_STORE_RESP || cpu_resp_rdata !== 64'b0)
        $fatal(1, "Store CPU response is incorrect");

      @(posedge clk);
      #1;
      if (dut.state !== dut.STATE_IDLE || cpu_resp_valid !== 1'b0)
        $fatal(1, "Store response did not return DCache to IDLE");
      checks = checks + 1;
    end
  endtask

  task issue_load_miss;
    input [63:0] address;
    input [63:0] expected_data;
    integer timeout;
    begin
      @(negedge clk);
      cpu_req_valid = 1'b1;
      cpu_req_addr = address;
      cpu_req_write = 1'b0;
      cpu_req_wdata = 64'b0;
      #1;
      if (cpu_req_ready !== 1'b1 || cpu_resp_valid !== 1'b0)
        $fatal(1, "Load miss was not accepted correctly");

      @(posedge clk);
      @(negedge clk);
      cpu_req_valid = 1'b0;

      timeout = 0;
      while (cpu_resp_valid !== 1'b1) begin
        @(negedge clk);
        timeout = timeout + 1;
        if (timeout > 100)
          $fatal(1, "timed out waiting for Load refill completion");
      end
      #1;
      if (dut.state !== dut.STATE_RESP || cpu_resp_rdata !== expected_data)
        $fatal(1, "Load miss returned %h expected %h",
               cpu_resp_rdata, expected_data);

      @(posedge clk);
      #1;
      if (dut.state !== dut.STATE_IDLE)
        $fatal(1, "Load response did not return DCache to IDLE");
      checks = checks + 1;
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    cpu_req_valid = 1'b0;
    cpu_req_addr = 64'b0;
    cpu_req_write = 1'b0;
    cpu_req_wdata = 64'b0;
    checks = 0;
    backend_reads = 0;
    backend_writes = 0;

    // Initialize the backend line at 0x120 before releasing reset.
    memory_model.memory[8'h24] = 64'h1111_1111_1111_1111;
    memory_model.memory[8'h25] = 64'h2222_2222_2222_2222;
    memory_model.memory[8'h26] = 64'h3333_3333_3333_3333;
    memory_model.memory[8'h27] = 64'h4444_4444_4444_4444;

    repeat (2) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;

    // First Store misses because reset invalidated all cache lines. It must
    // write through once without allocating a line.
    issue_store(64'h128, 64'haaaa_bbbb_cccc_dddd);
    if (backend_writes !== 1 || backend_reads !== 0)
      $fatal(1, "Store miss backend traffic mismatch: writes=%0d reads=%0d",
             backend_writes, backend_reads);
    if (memory_model.memory[8'h25] !== 64'haaaa_bbbb_cccc_dddd)
      $fatal(1, "Store miss did not update backend memory");
    if (dut.valid_array[1] !== 1'b0)
      $fatal(1, "Store miss incorrectly allocated a cache line");
    checks = checks + 1;

    // A following Load must still miss, refill four words, and observe the
    // value written through by the previous Store.
    issue_load_miss(64'h128, 64'haaaa_bbbb_cccc_dddd);
    if (backend_writes !== 1 || backend_reads !== 4)
      $fatal(1, "Load after Store miss did not perform one full refill");
    if (dut.valid_array[1] !== 1'b1 || dut.tag_array[1] !== 56'h1)
      $fatal(1, "Load refill did not install the expected cache line");
    if (dut.data_array[1][0] !== 64'h1111_1111_1111_1111 ||
        dut.data_array[1][1] !== 64'haaaa_bbbb_cccc_dddd ||
        dut.data_array[1][2] !== 64'h3333_3333_3333_3333 ||
        dut.data_array[1][3] !== 64'h4444_4444_4444_4444)
      $fatal(1, "refilled line contents are incorrect after Store miss");
    checks = checks + 1;

    // The same address now hits. It must update both backend memory and the
    // cached word after the backend reports completion.
    issue_store(64'h128, 64'hdead_beef_cafe_f00d);
    if (dut.store_hit_reg !== 1'b1)
      $fatal(1, "second Store was not recorded as a hit");
    if (backend_writes !== 2 || backend_reads !== 4)
      $fatal(1, "Store hit backend traffic mismatch");
    if (memory_model.memory[8'h25] !== 64'hdead_beef_cafe_f00d ||
        dut.data_array[1][1] !== 64'hdead_beef_cafe_f00d)
      $fatal(1, "Store hit did not update backend and cache consistently");
    checks = checks + 1;

    // A final Load is a same-cycle hit and must issue no backend request.
    @(negedge clk);
    cpu_req_valid = 1'b1;
    cpu_req_addr = 64'h128;
    cpu_req_write = 1'b0;
    cpu_req_wdata = 64'b0;
    #1;
    if (cpu_req_ready !== 1'b1 || cpu_resp_valid !== 1'b1 ||
        cpu_resp_rdata !== 64'hdead_beef_cafe_f00d)
      $fatal(1, "Load after Store hit did not return updated cache data");
    if (backend_writes !== 2 || backend_reads !== 4)
      $fatal(1, "Load hit generated unexpected backend traffic");
    checks = checks + 1;
    @(posedge clk);
    @(negedge clk);
    cpu_req_valid = 1'b0;

    // Reproduce the exact value pattern used by the recursive Fibonacci
    // failure: first place 0 at 0x700, refill it, then overwrite the same
    // cached address with 2 and read it back as a hit.
    issue_store(64'h700, 64'd0);
    if (memory_model.memory[8'he0] !== 64'd0)
      $fatal(1, "initial zero Store at 0x700 failed");
    issue_load_miss(64'h700, 64'd0);
    issue_store(64'h700, 64'd2);
    if (memory_model.memory[8'he0] !== 64'd2 ||
        dut.data_array[0][0] !== 64'd2)
      $fatal(1, "same-address overwrite lost value 2");

    @(negedge clk);
    cpu_req_valid = 1'b1;
    cpu_req_addr = 64'h700;
    cpu_req_write = 1'b0;
    cpu_req_wdata = 64'b0;
    #1;
    if (cpu_req_ready !== 1'b1 || cpu_resp_valid !== 1'b1 ||
        cpu_resp_rdata !== 64'd2)
      $fatal(1, "same-address final Load returned %h, expected 2",
             cpu_resp_rdata);
    checks = checks + 1;
    @(posedge clk);
    @(negedge clk);
    cpu_req_valid = 1'b0;

    $display("PASS: DCache complete Store write-through flow passed %0d checks.",
             checks);
    $finish;
  end
endmodule
