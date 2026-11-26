`timescale 1ns/1ps

module DCacheStoreCompletion_tb;
  reg         clk;
  reg         reset;
  reg         cpu_req_valid;
  reg  [63:0] cpu_req_addr;
  reg         cpu_req_write;
  reg  [63:0] cpu_req_wdata;
  wire        cpu_req_ready;
  wire        cpu_resp_valid;
  wire [63:0] cpu_resp_rdata;

  reg         mem_req_ready;
  reg         mem_resp_valid;
  reg  [63:0] mem_resp_rdata;
  wire        mem_req_valid;
  wire        mem_req_write;
  wire [63:0] mem_req_addr;
  wire [63:0] mem_req_wdata;

  integer checks;

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
    .mem_req_wdata(mem_req_wdata)
  );

  always #5 clk = ~clk;

  task apply_reset;
    begin
      @(negedge clk);
      reset = 1'b1;
      cpu_req_valid = 1'b0;
      cpu_req_addr = 64'b0;
      cpu_req_write = 1'b0;
      cpu_req_wdata = 64'b0;
      mem_req_ready = 1'b0;
      mem_resp_valid = 1'b0;
      mem_resp_rdata = 64'b0;
      @(posedge clk);
      #1;
      if (dut.state !== dut.STATE_IDLE)
        $fatal(1, "reset did not return DCache to IDLE");
      if (dut.store_hit_reg !== 1'b0)
        $fatal(1, "reset did not clear store_hit_reg");
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
    mem_req_ready = 1'b0;
    mem_resp_valid = 1'b0;
    mem_resp_rdata = 64'b0;
    checks = 0;

    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_IDLE)
      $fatal(1, "initial reset did not establish IDLE");
    checks = checks + 1;

    // Store hit at address 0x138: tag 1, index 1, word offset 3.
    @(negedge clk);
    reset = 1'b0;
    dut.valid_array = 8'b0000_0010;
    dut.tag_array[1] = 56'h1;
    dut.data_array[1][0] = 64'h1000_0000_0000_0000;
    dut.data_array[1][1] = 64'h1000_0000_0000_0001;
    dut.data_array[1][2] = 64'h1000_0000_0000_0002;
    dut.data_array[1][3] = 64'h1000_0000_0000_0003;
    cpu_req_valid = 1'b1;
    cpu_req_addr = 64'h138;
    cpu_req_write = 1'b1;
    cpu_req_wdata = 64'hdead_beef_cafe_f00d;

    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_STORE_REQ || dut.store_hit_reg !== 1'b1)
      $fatal(1, "Store hit was not captured before backend request");
    checks = checks + 1;

    // Let the backend accept the write request.
    @(negedge clk);
    mem_req_ready = 1'b1;
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_STORE_WAIT)
      $fatal(1, "Store request handshake did not enter STORE_WAIT");
    if (dut.data_array[1][3] !== 64'h1000_0000_0000_0003)
      $fatal(1, "Store hit updated cache before backend completion");
    checks = checks + 1;

    // Waiting without a response must preserve the complete cache line.
    @(negedge clk);
    mem_req_ready = 1'b0;
    cpu_req_addr = 64'h7f8;
    cpu_req_wdata = 64'haaaa_bbbb_cccc_dddd;
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_STORE_WAIT ||
        dut.data_array[1][0] !== 64'h1000_0000_0000_0000 ||
        dut.data_array[1][1] !== 64'h1000_0000_0000_0001 ||
        dut.data_array[1][2] !== 64'h1000_0000_0000_0002 ||
        dut.data_array[1][3] !== 64'h1000_0000_0000_0003)
      $fatal(1, "Store wait changed cache without a completion response");
    checks = checks + 1;

    // The write response commits only the requested word and enters RESP.
    @(negedge clk);
    mem_resp_valid = 1'b1;
    mem_resp_rdata = 64'hffff_ffff_ffff_ffff;
    #1;
    if (dut.store_mem_resp_fire !== 1'b1)
      $fatal(1, "Store completion event did not assert");
    checks = checks + 1;
    @(posedge clk);
    #1;
    mem_resp_valid = 1'b0;
    if (dut.state !== dut.STATE_STORE_RESP)
      $fatal(1, "Store completion did not enter STORE_RESP");
    if (dut.data_array[1][3] !== 64'hdead_beef_cafe_f00d)
      $fatal(1, "Store hit did not update the requested cache word");
    if (dut.data_array[1][0] !== 64'h1000_0000_0000_0000 ||
        dut.data_array[1][1] !== 64'h1000_0000_0000_0001 ||
        dut.data_array[1][2] !== 64'h1000_0000_0000_0002)
      $fatal(1, "Store hit changed another word in the cache line");
    if (dut.valid_array[1] !== 1'b1 || dut.tag_array[1] !== 56'h1)
      $fatal(1, "Store hit changed line valid or tag metadata");
    if (cpu_resp_valid !== 1'b1 || cpu_resp_rdata !== 64'b0)
      $fatal(1, "STORE_RESP did not return a zero-data completion to CPU");
    checks = checks + 1;

    // Store miss: keep an unrelated valid line at the same index.
    apply_reset();
    @(negedge clk);
    reset = 1'b0;
    dut.valid_array = 8'b0000_0010;
    dut.tag_array[1] = 56'h2;
    dut.data_array[1][0] = 64'h2000_0000_0000_0000;
    dut.data_array[1][1] = 64'h2000_0000_0000_0001;
    dut.data_array[1][2] = 64'h2000_0000_0000_0002;
    dut.data_array[1][3] = 64'h2000_0000_0000_0003;
    cpu_req_valid = 1'b1;
    cpu_req_addr = 64'h138;
    cpu_req_write = 1'b1;
    cpu_req_wdata = 64'h0123_4567_89ab_cdef;

    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_STORE_REQ || dut.store_hit_reg !== 1'b0)
      $fatal(1, "Store miss was not captured");
    checks = checks + 1;

    @(negedge clk);
    mem_req_ready = 1'b1;
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_STORE_WAIT)
      $fatal(1, "Store-miss request did not enter STORE_WAIT");
    checks = checks + 1;

    @(negedge clk);
    mem_req_ready = 1'b0;
    mem_resp_valid = 1'b1;
    @(posedge clk);
    #1;
    mem_resp_valid = 1'b0;
    if (dut.state !== dut.STATE_STORE_RESP)
      $fatal(1, "Store-miss completion did not enter STORE_RESP");
    if (cpu_resp_valid !== 1'b1 || cpu_resp_rdata !== 64'b0)
      $fatal(1, "Store-miss response did not complete at the CPU interface");
    if (dut.valid_array[1] !== 1'b1 || dut.tag_array[1] !== 56'h2 ||
        dut.data_array[1][0] !== 64'h2000_0000_0000_0000 ||
        dut.data_array[1][1] !== 64'h2000_0000_0000_0001 ||
        dut.data_array[1][2] !== 64'h2000_0000_0000_0002 ||
        dut.data_array[1][3] !== 64'h2000_0000_0000_0003)
      $fatal(1, "Store miss allocated, invalidated, or changed the cache line");
    checks = checks + 1;

    $display("PASS: DCache Store completion and conditional cache update passed %0d checks.",
             checks);
    $finish;
  end
endmodule
