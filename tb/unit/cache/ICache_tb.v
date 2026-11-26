`timescale 1ns/1ps

module ICache_tb;
  reg         clk;
  reg         reset;
  reg         cpu_req_valid;
  reg  [63:0] cpu_req_addr;
  wire        cpu_req_ready;
  wire        cpu_resp_valid;
  wire [31:0] cpu_resp_instr;

  wire        mem_req_valid;
  wire [63:0] mem_req_addr;
  wire        mem_req_ready;
  wire        mem_resp_valid;
  wire [63:0] mem_resp_rdata;

  integer i;
  integer checks;
  integer backend_read_fires;
  reg [63:0] backend_addr_log [0:31];

  ICache dut (
    .clk(clk),
    .reset(reset),
    .cpu_req_valid(cpu_req_valid),
    .cpu_req_addr(cpu_req_addr),
    .cpu_req_ready(cpu_req_ready),
    .cpu_resp_valid(cpu_resp_valid),
    .cpu_resp_instr(cpu_resp_instr),
    .mem_req_valid(mem_req_valid),
    .mem_req_addr(mem_req_addr),
    .mem_req_ready(mem_req_ready),
    .mem_resp_valid(mem_resp_valid),
    .mem_resp_rdata(mem_resp_rdata)
  );

  CacheBackingMemory backing_memory (
    .clk(clk),
    .reset(reset),
    .req_valid(mem_req_valid),
    .req_write(1'b0),
    .req_addr(mem_req_addr),
    .req_wdata(64'b0),
    .req_wstrb(8'b0),
    .req_ready(mem_req_ready),
    .resp_valid(mem_resp_valid),
    .resp_rdata(mem_resp_rdata)
  );

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (!reset && mem_req_valid && mem_req_ready) begin
      backend_addr_log[backend_read_fires] = mem_req_addr;
      backend_read_fires = backend_read_fires + 1;
    end
  end

  task check_refill_addresses;
    input integer first_log_entry;
    input [63:0] line_base;
    begin
      if (backend_addr_log[first_log_entry + 0] !== line_base + 64'd0 ||
          backend_addr_log[first_log_entry + 1] !== line_base + 64'd8 ||
          backend_addr_log[first_log_entry + 2] !== line_base + 64'd16 ||
          backend_addr_log[first_log_entry + 3] !== line_base + 64'd24)
        $fatal(1,
               "Refill addresses incorrect: got %h %h %h %h, base=%h",
               backend_addr_log[first_log_entry + 0],
               backend_addr_log[first_log_entry + 1],
               backend_addr_log[first_log_entry + 2],
               backend_addr_log[first_log_entry + 3],
               line_base);
      checks = checks + 1;
    end
  endtask

  task fetch_instruction;
    input [63:0] address;
    input [31:0] expected_instruction;
    input integer expected_backend_reads;
    integer reads_before;
    integer timeout;
    reg immediate_response;
    begin
      reads_before = backend_read_fires;

      @(negedge clk);
      cpu_req_addr = address;
      cpu_req_valid = 1'b1;
      #1;

      if (cpu_req_ready !== 1'b1)
        $fatal(1, "ICache did not accept address %h while IDLE", address);

      immediate_response = cpu_resp_valid;
      if (immediate_response && cpu_resp_instr !== expected_instruction)
        $fatal(1, "Immediate response mismatch at %h: got=%h expected=%h",
               address, cpu_resp_instr, expected_instruction);

      // The request is accepted on this edge. Afterwards the requester may
      // withdraw valid and change its address; a miss must use req_addr_reg.
      @(posedge clk);
      #1;
      cpu_req_valid = 1'b0;
      cpu_req_addr = 64'h0000_0000_0000_07fc;

      if (!immediate_response) begin
        timeout = 0;
        while (cpu_resp_valid !== 1'b1 && timeout < 100) begin
          @(posedge clk);
          #1;
          timeout = timeout + 1;
        end

        if (timeout >= 100)
          $fatal(1, "Timed out waiting for ICache response at %h", address);
        if (cpu_resp_instr !== expected_instruction)
          $fatal(1, "Miss response mismatch at %h: got=%h expected=%h",
                 address, cpu_resp_instr, expected_instruction);

        // STATE_RESP commits tag/valid and returns to IDLE on this edge.
        @(posedge clk);
        #1;
      end

      if (backend_read_fires - reads_before !== expected_backend_reads)
        $fatal(1,
               "Address %h issued %0d backend reads, expected %0d",
               address, backend_read_fires - reads_before,
               expected_backend_reads);

      checks = checks + 1;
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    cpu_req_valid = 1'b0;
    cpu_req_addr = 64'b0;
    checks = 0;
    backend_read_fires = 0;

    for (i = 0; i < 32; i = i + 1)
      backend_addr_log[i] = 64'b0;

    for (i = 0; i < 256; i = i + 1)
      backing_memory.memory[i] = 64'b0;

    // Cache line 0x000: each 64-bit backend word contains two instructions.
    backing_memory.memory[0] = 64'h2222_2222_1111_1111;
    backing_memory.memory[1] = 64'h4444_4444_3333_3333;
    backing_memory.memory[2] = 64'h6666_6666_5555_5555;
    backing_memory.memory[3] = 64'h8888_8888_7777_7777;

    // Cache line 0x100 has the same direct-mapped index and a different tag.
    backing_memory.memory[32] = 64'haaaa_0002_aaaa_0001;
    backing_memory.memory[33] = 64'haaaa_0004_aaaa_0003;
    backing_memory.memory[34] = 64'haaaa_0006_aaaa_0005;
    backing_memory.memory[35] = 64'haaaa_0008_aaaa_0007;

    repeat (3) @(posedge clk);
    #1;
    if (dut.valid_array !== 8'b0)
      $fatal(1, "Reset did not invalidate every ICache line");
    if (cpu_req_ready !== 1'b0 || cpu_resp_valid !== 1'b0 ||
        mem_req_valid !== 1'b0)
      $fatal(1, "ICache asserted a handshake signal during reset");
    checks = checks + 1;

    @(negedge clk);
    reset = 1'b0;

    // An instruction address with nonzero bits [1:0] must not be accepted.
    cpu_req_addr = 64'h2;
    cpu_req_valid = 1'b1;
    #1;
    if (cpu_req_ready !== 1'b0 || cpu_resp_valid !== 1'b0)
      $fatal(1, "Misaligned instruction request was accepted");
    @(posedge clk);
    #1;
    cpu_req_valid = 1'b0;
    if (backend_read_fires !== 0 || dut.state !== dut.STATE_IDLE)
      $fatal(1, "Misaligned instruction request changed cache state");
    checks = checks + 1;

    // First access misses. It selects the upper 32 bits of backend word zero.
    fetch_instruction(64'h0000_0000_0000_0004, 32'h2222_2222, 4);
    check_refill_addresses(0, 64'h0000_0000_0000_0000);
    if (dut.valid_array[0] !== 1'b1 || dut.tag_array[0] !== 56'h0)
      $fatal(1, "First refill did not install tag 0 at index 0");
    if (dut.data_array[0][0] !== 64'h2222_2222_1111_1111 ||
        dut.data_array[0][1] !== 64'h4444_4444_3333_3333 ||
        dut.data_array[0][2] !== 64'h6666_6666_5555_5555 ||
        dut.data_array[0][3] !== 64'h8888_8888_7777_7777)
      $fatal(1, "First refill did not store the complete cache line");
    checks = checks + 1;

    // Both halves and another backend word in the resident line must hit.
    fetch_instruction(64'h0000_0000_0000_0000, 32'h1111_1111, 0);
    fetch_instruction(64'h0000_0000_0000_000c, 32'h4444_4444, 0);

    // Address 0x104 has index 0 and tag 1, so it replaces the first line.
    fetch_instruction(64'h0000_0000_0000_0104, 32'haaaa_0002, 4);
    check_refill_addresses(4, 64'h0000_0000_0000_0100);
    if (dut.valid_array[0] !== 1'b1 || dut.tag_array[0] !== 56'h1)
      $fatal(1, "Conflicting refill did not replace index 0 with tag 1");
    checks = checks + 1;

    // The old tag no longer hits and therefore requires another full refill.
    fetch_instruction(64'h0000_0000_0000_0000, 32'h1111_1111, 4);
    check_refill_addresses(8, 64'h0000_0000_0000_0000);

    if (backend_read_fires !== 12)
      $fatal(1, "Total backend reads=%0d expected=12", backend_read_fires);

    $display("PASS: ICache reset, miss/refill, hit, instruction selection, and replacement passed %0d checks.",
             checks);
    $finish;
  end

  initial begin
    #5000;
    $fatal(1, "ICache test timed out");
  end
endmodule
