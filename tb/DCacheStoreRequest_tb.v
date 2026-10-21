`timescale 1ns/1ps

module DCacheStoreRequest_tb;
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
  integer backend_accepts;

  DCache dut (
    .clk(clk),
    .reset(reset),
    .cpu_req_valid(cpu_req_valid),
    .cpu_req_addr(cpu_req_addr),
    .cpu_req_write(cpu_req_write),
    .cpu_req_wdata(cpu_req_wdata),
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

  always @(posedge clk) begin
    if (dut.mem_req_fire)
      backend_accepts = backend_accepts + 1;
  end

  task check_backend_outputs;
    input        expected_valid;
    input        expected_write;
    input [63:0] expected_addr;
    input [63:0] expected_wdata;
    begin
      #1;
      if (mem_req_valid !== expected_valid)
        $fatal(1, "mem_req_valid mismatch: got=%b expected=%b state=%0d",
               mem_req_valid, expected_valid, dut.state);
      if (mem_req_write !== expected_write)
        $fatal(1, "mem_req_write mismatch: got=%b expected=%b",
               mem_req_write, expected_write);
      if (mem_req_addr !== expected_addr)
        $fatal(1, "mem_req_addr mismatch: got=%h expected=%h",
               mem_req_addr, expected_addr);
      if (mem_req_wdata !== expected_wdata)
        $fatal(1, "mem_req_wdata mismatch: got=%h expected=%h",
               mem_req_wdata, expected_wdata);
      checks = checks + 1;
    end
  endtask

  task reset_dut;
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
        $fatal(1, "reset did not place DCache in IDLE");
      if (dut.store_hit_reg !== 1'b0)
        $fatal(1, "reset did not clear store_hit_reg");
      checks = checks + 1;
      check_backend_outputs(1'b0, 1'b0, 64'b0, 64'b0);
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
    backend_accepts = 0;

    check_backend_outputs(1'b0, 1'b0, 64'b0, 64'b0);
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_IDLE || dut.store_hit_reg !== 1'b0)
      $fatal(1, "initial reset state is incorrect");
    checks = checks + 1;

    // Address 0x128 selects index 1, tag 1, word offset 1.
    // Install that line so the first Store is a hit.
    @(negedge clk);
    reset = 1'b0;
    dut.valid_array = 8'b0000_0010;
    dut.tag_array[1] = 56'h1;
    dut.data_array[1][1] = 64'h1111_2222_3333_4444;
    cpu_req_valid = 1'b1;
    cpu_req_addr = 64'h128;
    cpu_req_write = 1'b1;
    cpu_req_wdata = 64'hdead_beef_cafe_f00d;
    #1;
    if (cpu_req_ready !== 1'b1 || cpu_resp_valid !== 1'b0)
      $fatal(1, "aligned Store hit was not accepted correctly in IDLE");
    checks = checks + 1;

    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_STORE_REQ)
      $fatal(1, "accepted Store did not enter STORE_REQ");
    if (dut.req_addr_reg !== 64'h128 ||
        dut.req_write_reg !== 1'b1 ||
        dut.req_wdata_reg !== 64'hdead_beef_cafe_f00d)
      $fatal(1, "Store request fields were not captured correctly");
    if (dut.store_hit_reg !== 1'b1)
      $fatal(1, "Store hit was not captured");
    if (cpu_req_ready !== 1'b0 || cpu_resp_valid !== 1'b0)
      $fatal(1, "CPU interface was not blocked during STORE_REQ");
    checks = checks + 1;
    check_backend_outputs(1'b1, 1'b1, 64'h128,
                          64'hdead_beef_cafe_f00d);

    // Backpressure must preserve the accepted request even if CPU inputs move.
    @(negedge clk);
    cpu_req_addr = 64'h7f8;
    cpu_req_wdata = 64'haaaa_bbbb_cccc_dddd;
    check_backend_outputs(1'b1, 1'b1, 64'h128,
                          64'hdead_beef_cafe_f00d);
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_STORE_REQ || backend_accepts !== 0)
      $fatal(1, "Store request advanced before the backend was ready");
    if (dut.data_array[1][1] !== 64'h1111_2222_3333_4444)
      $fatal(1, "Store hit changed cache data before backend completion");
    checks = checks + 1;

    // A ready/valid handshake accepts the request exactly once.
    @(negedge clk);
    mem_req_ready = 1'b1;
    #1;
    if (dut.mem_req_fire !== 1'b1)
      $fatal(1, "Store backend request did not fire");
    checks = checks + 1;
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_STORE_WAIT || backend_accepts !== 1)
      $fatal(1, "Store handshake did not enter STORE_WAIT exactly once");
    check_backend_outputs(1'b0, 1'b0, 64'b0, 64'b0);
    repeat (2) @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_STORE_WAIT || backend_accepts !== 1)
      $fatal(1, "Store request repeated while waiting for completion");
    checks = checks + 1;

    // Reset and install a conflicting line at the same index. The next Store
    // must record a miss but still issue the same kind of backend write.
    reset_dut();
    @(negedge clk);
    reset = 1'b0;
    dut.valid_array = 8'b0000_0010;
    dut.tag_array[1] = 56'h2;
    dut.data_array[1][1] = 64'h5555_6666_7777_8888;
    cpu_req_valid = 1'b1;
    cpu_req_addr = 64'h128;
    cpu_req_write = 1'b1;
    cpu_req_wdata = 64'h0123_4567_89ab_cdef;
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_STORE_REQ || dut.store_hit_reg !== 1'b0)
      $fatal(1, "Store miss was not captured correctly");
    if (dut.tag_array[1] !== 56'h2 ||
        dut.data_array[1][1] !== 64'h5555_6666_7777_8888)
      $fatal(1, "Store miss allocated or modified the cache");
    checks = checks + 1;
    check_backend_outputs(1'b1, 1'b1, 64'h128,
                          64'h0123_4567_89ab_cdef);

    @(negedge clk);
    mem_req_ready = 1'b1;
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_STORE_WAIT || backend_accepts !== 2)
      $fatal(1, "Store-miss backend request was not accepted once");
    if (dut.valid_array[1] !== 1'b1 || dut.tag_array[1] !== 56'h2 ||
        dut.data_array[1][1] !== 64'h5555_6666_7777_8888)
      $fatal(1, "Store miss changed the existing cache line");
    checks = checks + 1;
    check_backend_outputs(1'b0, 1'b0, 64'b0, 64'b0);

    $display("PASS: DCache Store request and backend handshake passed %0d checks.",
             checks);
    $finish;
  end
endmodule
