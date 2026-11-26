`timescale 1ns/1ps

module DCacheRefillLoop_tb;
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
  integer backend_requests;
  integer backend_responses;
  integer timeout_cycles;

  localparam [63:0] WORD0 = 64'h1111_aaaa_0000_0000;
  localparam [63:0] WORD1 = 64'h2222_bbbb_1111_1111;
  localparam [63:0] WORD2 = 64'h3333_cccc_2222_2222;
  localparam [63:0] WORD3 = 64'h4444_dddd_3333_3333;
  localparam [63:0] REPL_WORD0 = 64'haaaa_0000_0000_0000;
  localparam [63:0] REPL_WORD1 = 64'hbbbb_1111_1111_1111;
  localparam [63:0] REPL_WORD2 = 64'hcccc_2222_2222_2222;
  localparam [63:0] REPL_WORD3 = 64'hdddd_3333_3333_3333;

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

  CacheBackingMemory backing (
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

  // Observe every request that the real backing-memory model accepts.
  always @(posedge clk) begin
    if (mem_req_valid && mem_req_ready) begin
      case (backend_requests)
        0: if (mem_req_addr !== 64'h120)
             $fatal(1, "word 0 request address mismatch: %h", mem_req_addr);
        1: if (mem_req_addr !== 64'h128)
             $fatal(1, "word 1 request address mismatch: %h", mem_req_addr);
        2: if (mem_req_addr !== 64'h130)
             $fatal(1, "word 2 request address mismatch: %h", mem_req_addr);
        3: if (mem_req_addr !== 64'h138)
             $fatal(1, "word 3 request address mismatch: %h", mem_req_addr);
        4: if (mem_req_addr !== 64'h20)
             $fatal(1, "replacement word 0 address mismatch: %h", mem_req_addr);
        5: if (mem_req_addr !== 64'h28)
             $fatal(1, "replacement word 1 address mismatch: %h", mem_req_addr);
        6: if (mem_req_addr !== 64'h30)
             $fatal(1, "replacement word 2 address mismatch: %h", mem_req_addr);
        7: if (mem_req_addr !== 64'h38)
             $fatal(1, "replacement word 3 address mismatch: %h", mem_req_addr);
        default:
             $fatal(1, "DCache issued an unexpected backend request: %h",
                    mem_req_addr);
      endcase
      if (mem_req_write !== 1'b0 || mem_req_wdata !== 64'b0)
        $fatal(1, "refill request was not a clean backend read");
      backend_requests = backend_requests + 1;
    end

    if (dut.mem_resp_fire)
      backend_responses = backend_responses + 1;
  end

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    cpu_req_valid = 1'b0;
    cpu_req_addr = 64'b0;
    cpu_req_write = 1'b0;
    cpu_req_wdata = 64'b0;
    checks = 0;
    backend_requests = 0;
    backend_responses = 0;
    timeout_cycles = 0;

    // 0x120 >> 3 = 36. Populate all four words of the backing line.
    backing.memory[36] = WORD0;
    backing.memory[37] = WORD1;
    backing.memory[38] = WORD2;
    backing.memory[39] = WORD3;
    backing.memory[4] = REPL_WORD0;
    backing.memory[5] = REPL_WORD1;
    backing.memory[6] = REPL_WORD2;
    backing.memory[7] = REPL_WORD3;

    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_IDLE || dut.refill_word_index !== 2'd0)
      $fatal(1, "reset did not initialize state and refill index");
    checks = checks + 1;

    // Request word 3 of the line. A miss must still refill words 0 through 3.
    @(negedge clk);
    reset = 1'b0;
    cpu_req_valid = 1'b1;
    cpu_req_addr = 64'h138;
    cpu_req_write = 1'b0;
    cpu_req_wdata = 64'b0;
    #1;
    if (cpu_req_ready !== 1'b1 || cpu_resp_valid !== 1'b0)
      $fatal(1, "initial Load miss handshake was incorrect");
    checks = checks + 1;

    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_REFILL_REQ ||
        dut.refill_word_index !== 2'd0 || dut.req_word_offset !== 2'd3)
      $fatal(1, "miss did not start refill at word 0 while preserving CPU word 3");
    cpu_req_valid = 1'b0;
    checks = checks + 1;

    // The real three-cycle backend drives all request stalls and responses.
    while (dut.state !== dut.STATE_RESP && timeout_cycles < 80) begin
      @(posedge clk);
      #1;
      timeout_cycles = timeout_cycles + 1;
    end
    if (dut.state !== dut.STATE_RESP)
      $fatal(1, "refill did not reach STATE_RESP before timeout");
    checks = checks + 1;

    if (backend_requests !== 4)
      $fatal(1, "backend request count mismatch: got=%0d expected=4",
             backend_requests);
    if (backend_responses !== 4)
      $fatal(1, "consumed response count mismatch: got=%0d expected=4",
             backend_responses);
    checks = checks + 1;

    if (dut.data_array[1][0] !== WORD0 ||
        dut.data_array[1][1] !== WORD1 ||
        dut.data_array[1][2] !== WORD2 ||
        dut.data_array[1][3] !== WORD3)
      $fatal(1, "four returned words were not stored in order");
    checks = checks + 1;

    if (dut.refill_word_index !== 2'd3)
      $fatal(1, "refill index did not stop at the final word");
    if (mem_req_valid !== 1'b0 || cpu_req_ready !== 1'b0 ||
        cpu_resp_valid !== 1'b1 || cpu_resp_rdata !== WORD3)
      $fatal(1, "STATE_RESP did not return the original requested word");
    checks = checks + 1;

    // Metadata remains uncommitted until the response cycle's ending edge.
    if (dut.valid_array[1] !== 1'b0)
      $fatal(1, "valid was committed before the response edge");
    checks = checks + 1;

    // The response is one cycle. Its ending edge commits metadata and returns
    // the controller to IDLE.
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_IDLE || dut.valid_array[1] !== 1'b1 ||
        dut.tag_array[1] !== 56'h1 || cpu_resp_valid !== 1'b0 ||
        backend_requests !== 4)
      $fatal(1, "response edge did not commit tag/valid and return to IDLE");
    checks = checks + 1;

    // A second access to the newly filled line must hit without a backend read.
    @(negedge clk);
    cpu_req_valid = 1'b1;
    cpu_req_addr = 64'h120;
    #1;
    if (cpu_req_ready !== 1'b1 || cpu_resp_valid !== 1'b1 ||
        cpu_resp_rdata !== WORD0)
      $fatal(1, "second access to the filled line did not hit");
    cpu_req_valid = 1'b0;
    @(posedge clk);
    #1;
    if (backend_requests !== 4 || dut.state !== dut.STATE_IDLE)
      $fatal(1, "Load hit incorrectly issued another backend request");
    checks = checks + 1;

    // 0x38 has the same direct-mapped index as 0x138 but a different tag.
    // It must refill and replace line 1.
    @(negedge clk);
    cpu_req_valid = 1'b1;
    cpu_req_addr = 64'h38;
    #1;
    if (cpu_req_ready !== 1'b1 || cpu_resp_valid !== 1'b0)
      $fatal(1, "same-index different-tag access was not a miss");
    @(posedge clk);
    #1;
    cpu_req_valid = 1'b0;
    timeout_cycles = 0;
    while (dut.state !== dut.STATE_RESP && timeout_cycles < 80) begin
      @(posedge clk);
      #1;
      timeout_cycles = timeout_cycles + 1;
    end
    if (dut.state !== dut.STATE_RESP || cpu_resp_valid !== 1'b1 ||
        cpu_resp_rdata !== REPL_WORD3 || backend_requests !== 8 ||
        backend_responses !== 8)
      $fatal(1, "replacement refill did not complete correctly");
    checks = checks + 1;

    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_IDLE || dut.valid_array[1] !== 1'b1 ||
        dut.tag_array[1] !== 56'h0 ||
        dut.data_array[1][0] !== REPL_WORD0 ||
        dut.data_array[1][1] !== REPL_WORD1 ||
        dut.data_array[1][2] !== REPL_WORD2 ||
        dut.data_array[1][3] !== REPL_WORD3)
      $fatal(1, "replacement line was not committed correctly");
    checks = checks + 1;

    // The replaced old tag must miss, while the new tag must hit.
    @(negedge clk);
    cpu_req_valid = 1'b1;
    cpu_req_addr = 64'h138;
    #1;
    if (dut.cpu_line_hit !== 1'b0 || cpu_resp_valid !== 1'b0)
      $fatal(1, "old tag still hit after direct-mapped replacement");
    cpu_req_addr = 64'h38;
    #1;
    if (dut.cpu_line_hit !== 1'b1 || cpu_resp_valid !== 1'b1 ||
        cpu_resp_rdata !== REPL_WORD3)
      $fatal(1, "replacement line did not hit after commit");
    cpu_req_valid = 1'b0;
    checks = checks + 1;

    // Reset starts a future refill from word 0 again.
    @(negedge clk);
    reset = 1'b1;
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_IDLE || dut.refill_word_index !== 2'd0)
      $fatal(1, "reset did not restore IDLE and word index 0");
    checks = checks + 1;

    $display("PASS: DCache Load miss refill, response, hit, and replacement passed %0d checks.",
             checks);
    $finish;
  end
endmodule
