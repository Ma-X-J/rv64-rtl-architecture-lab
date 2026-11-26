`timescale 1ns/1ps

module DCacheBackendResponse_tb;
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

  localparam [63:0] OLD_WORD0 = 64'h1111_1111_1111_1111;
  localparam [63:0] RETURNED_WORD0 = 64'hdead_beef_cafe_f00d;

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
      $fatal(1, "reset did not place DCache in IDLE");

    // Prepare two lines so the test can distinguish the saved miss index from
    // an unrelated live CPU index.
    dut.tag_array[1] = 56'h55;
    dut.data_array[1][0] = OLD_WORD0;
    dut.data_array[1][1] = 64'h2222_2222_2222_2222;
    dut.data_array[1][2] = 64'h3333_3333_3333_3333;
    dut.data_array[1][3] = 64'h4444_4444_4444_4444;
    dut.data_array[2][0] = 64'haaaa_aaaa_aaaa_aaaa;

    // A response outside REFILL_WAIT must be ignored.
    @(negedge clk);
    reset = 1'b0;
    mem_resp_valid = 1'b1;
    mem_resp_rdata = 64'hbad0_bad0_bad0_bad0;
    #1;
    if (dut.mem_resp_fire !== 1'b0)
      $fatal(1, "response fired in IDLE");
    @(posedge clk);
    #1;
    if (dut.data_array[1][0] !== OLD_WORD0)
      $fatal(1, "IDLE response modified data array");
    checks = checks + 1;

    // Accept a miss at 0x138: line base 0x120, cache index 1.
    @(negedge clk);
    mem_resp_valid = 1'b0;
    cpu_req_valid = 1'b1;
    cpu_req_addr = 64'h138;
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_REFILL_REQ || dut.req_index !== 3'd1)
      $fatal(1, "Load miss did not save index 1 and enter REFILL_REQ");
    checks = checks + 1;

    // Even an unexpected response in REFILL_REQ must not be consumed.
    @(negedge clk);
    mem_resp_valid = 1'b1;
    mem_resp_rdata = 64'hbad1_bad1_bad1_bad1;
    #1;
    if (dut.mem_resp_fire !== 1'b0)
      $fatal(1, "response fired before backend request handshake");
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_REFILL_REQ ||
        dut.data_array[1][0] !== OLD_WORD0)
      $fatal(1, "REFILL_REQ response was not ignored");
    checks = checks + 1;

    // Let the backend accept the read request and enter REFILL_WAIT.
    @(negedge clk);
    mem_resp_valid = 1'b0;
    mem_req_ready = 1'b1;
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_REFILL_WAIT)
      $fatal(1, "backend request handshake did not enter REFILL_WAIT");
    checks = checks + 1;

    // Without resp_valid, changing resp_rdata must not modify the array.
    @(negedge clk);
    mem_req_ready = 1'b0;
    mem_resp_rdata = 64'hbad2_bad2_bad2_bad2;
    @(posedge clk);
    #1;
    if (dut.data_array[1][0] !== OLD_WORD0)
      $fatal(1, "data array changed while mem_resp_valid was low");
    checks = checks + 1;

    // Change the live CPU address to index 2. The backend response still
    // belongs to saved index 1 and must be written only to word 0 there.
    @(negedge clk);
    cpu_req_addr = 64'h40;
    mem_resp_valid = 1'b1;
    mem_resp_rdata = RETURNED_WORD0;
    #1;
    if (dut.mem_resp_fire !== 1'b1)
      $fatal(1, "valid response did not fire in REFILL_WAIT");
    @(posedge clk);
    #1;
    if (dut.data_array[1][0] !== RETURNED_WORD0)
      $fatal(1, "returned word was not written to saved index 1");
    if (dut.data_array[2][0] !== 64'haaaa_aaaa_aaaa_aaaa)
      $fatal(1, "returned word followed live CPU index instead of saved index");
    if (dut.data_array[1][1] !== 64'h2222_2222_2222_2222 ||
        dut.data_array[1][2] !== 64'h3333_3333_3333_3333 ||
        dut.data_array[1][3] !== 64'h4444_4444_4444_4444)
      $fatal(1, "first response modified a word other than word 0");
    if (dut.tag_array[1] !== 56'h55 || dut.valid_array[1] !== 1'b0)
      $fatal(1, "first response committed tag or valid too early");
    if (dut.state !== dut.STATE_REFILL_REQ ||
        dut.refill_word_index !== 2'd1)
      $fatal(1, "first response did not advance to request word 1");
    checks = checks + 1;

    // Reset cancels the pending request for word 1 and returns to IDLE.
    @(negedge clk);
    reset = 1'b1;
    mem_resp_rdata = 64'hbad3_bad3_bad3_bad3;
    #1;
    if (dut.mem_resp_fire !== 1'b0)
      $fatal(1, "response fired while reset was asserted");
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_IDLE)
      $fatal(1, "reset did not cancel the refill sequence");
    if (dut.data_array[1][0] !== RETURNED_WORD0)
      $fatal(1, "reset-time response overwrote the captured word");
    checks = checks + 1;

    $display("PASS: DCache first backend response capture passed %0d checks.",
             checks);
    $finish;
  end
endmodule
