`timescale 1ns/1ps

module DCacheHitInterface_tb;
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

  task check_cpu_interface;
    input [63:0] address;
    input        request_valid;
    input        request_write;
    input        reset_value;
    input        expected_ready;
    input        expected_resp_valid;
    input [63:0] expected_resp_data;
    begin
      cpu_req_addr  = address;
      cpu_req_valid = request_valid;
      cpu_req_write = request_write;
      reset         = reset_value;
      #1;

      if (cpu_req_ready !== expected_ready)
        $fatal(1, "ready mismatch: reset=%b valid=%b write=%b addr=%h got=%b expected=%b",
               reset_value, request_valid, request_write, address,
               cpu_req_ready, expected_ready);
      if (cpu_resp_valid !== expected_resp_valid)
        $fatal(1, "resp_valid mismatch: reset=%b valid=%b write=%b addr=%h got=%b expected=%b",
               reset_value, request_valid, request_write, address,
               cpu_resp_valid, expected_resp_valid);
      if (cpu_resp_rdata !== expected_resp_data)
        $fatal(1, "resp_rdata mismatch: addr=%h got=%h expected=%h",
               address, cpu_resp_rdata, expected_resp_data);

      checks = checks + 1;
    end
  endtask

  task check_saved_request;
    input [63:0] expected_addr;
    input        expected_write;
    input [63:0] expected_wdata;
    begin
      if (dut.req_addr_reg !== expected_addr)
        $fatal(1, "saved address mismatch: got=%h expected=%h",
               dut.req_addr_reg, expected_addr);
      if (dut.req_write_reg !== expected_write)
        $fatal(1, "saved write flag mismatch: got=%b expected=%b",
               dut.req_write_reg, expected_write);
      if (dut.req_wdata_reg !== expected_wdata)
        $fatal(1, "saved write data mismatch: got=%h expected=%h",
               dut.req_wdata_reg, expected_wdata);

      checks = checks + 1;
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b0;
    cpu_req_valid = 1'b0;
    cpu_req_addr = 64'b0;
    cpu_req_write = 1'b0;
    cpu_req_wdata = 64'b0;
    mem_req_ready = 1'b0;
    mem_resp_valid = 1'b0;
    mem_resp_rdata = 64'b0;
    checks = 0;

    // Reset establishes IDLE and clears every saved request field.
    reset = 1'b1;
    check_cpu_interface(64'h28, 1'b1, 1'b0, 1'b1,
                        1'b0, 1'b0, 64'b0);
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_IDLE)
      $fatal(1, "reset did not place DCache in IDLE: state=%0d", dut.state);
    check_saved_request(64'b0, 1'b0, 64'b0);

    @(negedge clk);
    reset = 1'b0;

    // Install line base 0x20: tag=0, index=1.
    dut.valid_array = 8'b0000_0010;
    dut.tag_array[1] = 56'h0;
    dut.data_array[1][0] = 64'h1111_1111_1111_1111;
    dut.data_array[1][1] = 64'h2222_2222_2222_2222;
    dut.data_array[1][2] = 64'h3333_3333_3333_3333;
    dut.data_array[1][3] = 64'h4444_4444_4444_4444;

    // An aligned Load hit is accepted and completed combinationally.
    check_cpu_interface(64'h28, 1'b1, 1'b0, 1'b0,
                        1'b1, 1'b1, 64'h2222_2222_2222_2222);

    // ready describes whether the current payload could be accepted; it does
    // not depend on valid. Without a request, no response may be generated.
    check_cpu_interface(64'h28, 1'b0, 1'b0, 1'b0,
                        1'b1, 1'b0, 64'b0);

    // ready is only capability. A miss-shaped payload without valid must not
    // be accepted, saved, or move the state out of IDLE.
    check_cpu_interface(64'h128, 1'b0, 1'b0, 1'b0,
                        1'b1, 1'b0, 64'b0);
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_IDLE)
      $fatal(1, "invalid request incorrectly moved state out of IDLE");
    check_saved_request(64'b0, 1'b0, 64'b0);

    // An aligned Store can now be accepted, but it does not complete in IDLE.
    check_cpu_interface(64'h28, 1'b1, 1'b1, 1'b0,
                        1'b1, 1'b0, 64'b0);

    // The first version supports only naturally aligned 64-bit accesses.
    check_cpu_interface(64'h29, 1'b1, 1'b0, 1'b0,
                        1'b0, 1'b0, 64'b0);

    // A valid aligned Load miss is accepted but does not complete. Its fields
    // are captured at the following rising edge.
    @(negedge clk);
    cpu_req_wdata = 64'hfeed_face_cafe_beef;
    check_cpu_interface(64'h128, 1'b1, 1'b0, 1'b0,
                        1'b1, 1'b0, 64'b0);
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_REFILL_REQ)
      $fatal(1, "accepted Load miss did not enter REFILL_REQ: state=%0d",
             dut.state);
    check_saved_request(64'h128, 1'b0, 64'hfeed_face_cafe_beef);

    // While busy, even a valid address that would hit may neither be accepted
    // nor generate a response from the live CPU lookup path.
    check_cpu_interface(64'h28, 1'b1, 1'b0, 1'b0,
                        1'b0, 1'b0, 64'b0);

    // A second request cannot overwrite the one outstanding request.
    @(negedge clk);
    cpu_req_wdata = 64'h9999_aaaa_bbbb_cccc;
    check_cpu_interface(64'h240, 1'b1, 1'b0, 1'b0,
                        1'b0, 1'b0, 64'b0);
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_REFILL_REQ)
      $fatal(1, "REFILL_REQ did not remain blocked before backend logic");
    check_saved_request(64'h128, 1'b0, 64'hfeed_face_cafe_beef);

    // Reset gates the interface immediately, then cancels the saved miss at
    // the clock edge and returns the controller to IDLE.
    reset = 1'b1;
    check_cpu_interface(64'h28, 1'b1, 1'b0, 1'b1,
                        1'b0, 1'b0, 64'b0);
    @(posedge clk);
    #1;
    if (dut.state !== dut.STATE_IDLE)
      $fatal(1, "reset did not cancel the outstanding miss");
    check_saved_request(64'b0, 1'b0, 64'b0);

    $display("PASS: DCache CPU interface and Load-miss capture passed %0d checks.",
             checks);
    $finish;
  end
endmodule
