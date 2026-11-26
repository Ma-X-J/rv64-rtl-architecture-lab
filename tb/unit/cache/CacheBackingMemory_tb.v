`timescale 1ns/1ps

module CacheBackingMemory_tb;
  reg         clk;
  reg         reset;
  reg         req_valid;
  reg         req_write;
  reg  [63:0] req_addr;
  reg  [63:0] req_wdata;
  wire        req_ready;
  wire        resp_valid;
  wire [63:0] resp_rdata;

  integer i;
  integer checks;

  CacheBackingMemory dut (
    .clk(clk),
    .reset(reset),
    .req_valid(req_valid),
    .req_write(req_write),
    .req_addr(req_addr),
    .req_wdata(req_wdata),
    .req_wstrb(8'hff),
    .req_ready(req_ready),
    .resp_valid(resp_valid),
    .resp_rdata(resp_rdata)
  );

  always #5 clk = ~clk;

  task expect_idle;
    begin
      if (req_ready !== 1'b1)
        $fatal(1, "Backend is not ready in IDLE");
      if (resp_valid !== 1'b0)
        $fatal(1, "Response is unexpectedly valid in IDLE");
      checks = checks + 1;
    end
  endtask

  task start_request;
    input        write_enable;
    input [63:0] address;
    input [63:0] write_data;
    begin
      @(negedge clk);
      expect_idle();
      req_write = write_enable;
      req_addr = address;
      req_wdata = write_data;
      req_valid = 1'b1;

      @(posedge clk);
      #1;
      if (req_ready !== 1'b0 || resp_valid !== 1'b0)
        $fatal(1, "Accepted request did not enter WAIT: ready=%b resp_valid=%b",
               req_ready, resp_valid);
      if (dut.pending_addr !== address ||
          dut.pending_write !== write_enable ||
          dut.pending_wdata !== write_data)
        $fatal(1, "Request fields were not latched correctly");

      req_valid = 1'b0;
      checks = checks + 1;
    end
  endtask

  task expect_wait_cycle;
    begin
      @(posedge clk);
      #1;
      if (req_ready !== 1'b0 || resp_valid !== 1'b0)
        $fatal(1, "Backend left WAIT too early: ready=%b resp_valid=%b",
               req_ready, resp_valid);
      checks = checks + 1;
    end
  endtask

  task expect_response;
    input [63:0] expected_data;
    begin
      @(posedge clk);
      #1;
      if (req_ready !== 1'b0)
        $fatal(1, "Backend asserted ready during RESP");
      if (resp_valid !== 1'b1)
        $fatal(1, "Backend response was not valid after exactly three cycles");
      if (resp_rdata !== expected_data)
        $fatal(1, "Response data mismatch: got=%h expected=%h",
               resp_rdata, expected_data);
      checks = checks + 1;
    end
  endtask

  task finish_response;
    begin
      @(posedge clk);
      #1;
      expect_idle();
    end
  endtask

  task complete_read;
    input [63:0] expected_data;
    begin
      expect_wait_cycle();
      expect_wait_cycle();
      expect_response(expected_data);
      finish_response();
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    req_valid = 1'b0;
    req_write = 1'b0;
    req_addr = 64'b0;
    req_wdata = 64'b0;
    checks = 0;

    for (i = 0; i < 256; i = i + 1)
      dut.memory[i] = 64'b0;

    dut.memory[5] = 64'h0123_4567_89ab_cdef;
    dut.memory[6] = 64'h1111_2222_3333_4444;
    dut.memory[8] = 64'haaaa_bbbb_cccc_dddd;
    dut.memory[9] = 64'h9999_8888_7777_6666;

    repeat (2) @(posedge clk);
    #1;
    if (dut.memory[5] !== 64'h0123_4567_89ab_cdef)
      $fatal(1, "Reset unexpectedly cleared backing memory");
    reset = 1'b0;
    expect_idle();

    // Read address 0x28 (word 5). Change every live request input while
    // busy and present a second request; the accepted read must be unaffected.
    start_request(1'b0, 64'h28, 64'b0);
    req_valid = 1'b1;
    req_write = 1'b1;
    req_addr = 64'h30;
    req_wdata = 64'hdead_beef_cafe_f00d;
    expect_wait_cycle();
    if (req_ready !== 1'b0)
      $fatal(1, "Backend accepted a second request while busy");
    expect_wait_cycle();
    expect_response(64'h0123_4567_89ab_cdef);
    req_valid = 1'b0;
    if (dut.memory[6] !== 64'h1111_2222_3333_4444)
      $fatal(1, "Busy backend executed an unaccepted write request");
    finish_response();

    // A legal write must remain invisible during WAIT, commit exactly on the
    // third cycle, and use the latched write flag/data despite live changes.
    start_request(1'b1, 64'h40, 64'hfeed_face_1234_5678);
    req_write = 1'b0;
    req_addr = 64'h28;
    req_wdata = 64'h0;
    expect_wait_cycle();
    if (dut.memory[8] !== 64'haaaa_bbbb_cccc_dddd)
      $fatal(1, "Write committed before its response cycle");
    expect_wait_cycle();
    if (dut.memory[8] !== 64'haaaa_bbbb_cccc_dddd)
      $fatal(1, "Write committed before its response cycle");
    expect_response(64'b0);
    if (dut.memory[8] !== 64'hfeed_face_1234_5678)
      $fatal(1, "Latched write did not commit on the response cycle");
    finish_response();

    // Read-after-write observes the newly committed value.
    start_request(1'b0, 64'h40, 64'b0);
    complete_read(64'hfeed_face_1234_5678);

    // Misaligned and out-of-range writes complete but do not alter memory.
    start_request(1'b1, 64'h41, 64'hffff_ffff_ffff_ffff);
    complete_read(64'b0);
    if (dut.memory[8] !== 64'hfeed_face_1234_5678)
      $fatal(1, "Misaligned write modified memory");

    start_request(1'b1, 64'h800, 64'hffff_ffff_ffff_ffff);
    complete_read(64'b0);
    if (dut.memory[0] !== 64'b0)
      $fatal(1, "Out-of-range write aliased to memory word zero");

    // Reset while a write is waiting must cancel the transaction and must not
    // produce a delayed response after reset is released.
    start_request(1'b1, 64'h48, 64'h5555_aaaa_5555_aaaa);
    expect_wait_cycle();
    @(negedge clk);
    reset = 1'b1;
    @(posedge clk);
    #1;
    if (resp_valid !== 1'b0 || req_ready !== 1'b1)
      $fatal(1, "Reset did not return the backend directly to IDLE");
    if (dut.memory[9] !== 64'h9999_8888_7777_6666)
      $fatal(1, "Reset failed to cancel a pending write");
    reset = 1'b0;
    repeat (4) begin
      @(posedge clk);
      #1;
      if (resp_valid !== 1'b0)
        $fatal(1, "Canceled request produced a response after reset");
    end
    expect_idle();

    $display("PASS: CacheBackingMemory protocol passed %0d checks.", checks);
    $finish;
  end
endmodule
