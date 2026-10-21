`timescale 1ns/1ps

module DCacheBackendRequest_tb;
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
    if (dut.state !== dut.STATE_IDLE)
      $fatal(1, "reset did not place DCache in IDLE");
    checks = checks + 1;

    // Accept an aligned Load miss at 0x138. Its 32-byte line starts at 0x120.
    @(negedge clk);
    reset = 1'b0;
    cpu_req_valid = 1'b1;
    cpu_req_addr = 64'h138;
    cpu_req_write = 1'b0;
    cpu_req_wdata = 64'h1111_2222_3333_4444;
    #1;
    if (cpu_req_ready !== 1'b1 || cpu_resp_valid !== 1'b0)
      $fatal(1, "IDLE Load miss was not accepted without completing");
    checks = checks + 1;

    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_REFILL_REQ)
      $fatal(1, "accepted miss did not enter REFILL_REQ");
    if (dut.req_addr_reg !== 64'h138)
      $fatal(1, "miss address was not saved");
    checks = checks + 1;
    check_backend_outputs(1'b1, 1'b0, 64'h120, 64'b0);

    // With ready low, valid and every request payload field must remain stable.
    // Changing the live CPU request must not change the backend line address.
    @(negedge clk);
    cpu_req_addr = 64'h7f8;
    cpu_req_wdata = 64'haaaa_bbbb_cccc_dddd;
    check_backend_outputs(1'b1, 1'b0, 64'h120, 64'b0);
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_REFILL_REQ)
      $fatal(1, "DCache left REFILL_REQ before backend accepted request");
    if (dut.req_addr_reg !== 64'h138)
      $fatal(1, "live CPU input overwrote the saved request");
    if (backend_accepts !== 0)
      $fatal(1, "backend request was counted without ready");
    checks = checks + 1;

    // Once ready rises, fire is asserted and the next edge transfers ownership
    // of the request to the backend.
    @(negedge clk);
    mem_req_ready = 1'b1;
    #1;
    if (dut.mem_req_fire !== 1'b1)
      $fatal(1, "mem_req_fire did not assert when valid and ready were high");
    checks = checks + 1;
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_REFILL_WAIT)
      $fatal(1, "backend handshake did not enter REFILL_WAIT");
    if (backend_accepts !== 1)
      $fatal(1, "backend request acceptance count mismatch: %0d",
             backend_accepts);
    checks = checks + 1;
    check_backend_outputs(1'b0, 1'b0, 64'b0, 64'b0);

    // Holding ready high cannot accept the same request again in WAIT.
    repeat (2) @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_REFILL_WAIT || backend_accepts !== 1)
      $fatal(1, "backend request repeated while waiting for response");
    checks = checks + 1;

    // Reset cancels the wait and leaves no backend request visible.
    @(negedge clk);
    reset = 1'b1;
    check_backend_outputs(1'b0, 1'b0, 64'b0, 64'b0);
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_IDLE || dut.req_addr_reg !== 64'b0)
      $fatal(1, "reset did not cancel the outstanding refill request");
    if (backend_accepts !== 1)
      $fatal(1, "reset caused an extra backend acceptance");
    checks = checks + 1;

    $display("PASS: DCache first backend refill request passed %0d checks.",
             checks);
    $finish;
  end
endmodule
