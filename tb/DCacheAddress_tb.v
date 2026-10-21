`timescale 1ns/1ps

module DCacheAddress_tb;
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

  task check_cpu_decode;
    input [63:0] address;
    input [63:0] expected_line_base;
    input [1:0]  expected_word_offset;
    input [2:0]  expected_index;
    input [55:0] expected_tag;
    input [2:0]  expected_byte_offset;
    begin
      cpu_req_addr = address;
      #1;

      if (dut.cpu_line_base !== expected_line_base)
        $fatal(1, "CPU line base mismatch: addr=%h got=%h expected=%h",
               address, dut.cpu_line_base, expected_line_base);
      if (dut.cpu_addr_word_offset !== expected_word_offset)
        $fatal(1, "CPU word offset mismatch: addr=%h got=%h expected=%h",
               address, dut.cpu_addr_word_offset, expected_word_offset);
      if (dut.cpu_addr_index !== expected_index)
        $fatal(1, "CPU index mismatch: addr=%h got=%h expected=%h",
               address, dut.cpu_addr_index, expected_index);
      if (dut.cpu_addr_tag !== expected_tag)
        $fatal(1, "CPU tag mismatch: addr=%h got=%h expected=%h",
               address, dut.cpu_addr_tag, expected_tag);
      if (dut.cpu_addr_byte_offset !== expected_byte_offset)
        $fatal(1, "CPU byte offset mismatch: addr=%h got=%h expected=%h",
               address, dut.cpu_addr_byte_offset, expected_byte_offset);
      if (dut.cpu_addr_aligned !== (expected_byte_offset == 3'b000))
        $fatal(1, "CPU alignment mismatch: addr=%h aligned=%b",
               address, dut.cpu_addr_aligned);

      checks = checks + 1;
    end
  endtask

  task check_latched_decode;
    input [63:0] address;
    begin
      dut.req_addr_reg = address;
      #1;

      if (dut.req_tag !== address[63:8])
        $fatal(1, "Latched tag mismatch: addr=%h got=%h expected=%h",
               address, dut.req_tag, address[63:8]);
      if (dut.req_index !== address[7:5])
        $fatal(1, "Latched index mismatch: addr=%h got=%h expected=%h",
               address, dut.req_index, address[7:5]);
      if (dut.req_word_offset !== address[4:3])
        $fatal(1, "Latched word offset mismatch: addr=%h got=%h expected=%h",
               address, dut.req_word_offset, address[4:3]);
      if (dut.req_byte_offset !== address[2:0])
        $fatal(1, "Latched byte offset mismatch: addr=%h got=%h expected=%h",
               address, dut.req_byte_offset, address[2:0]);
      if (dut.req_line_base !== {address[63:5], 5'b0})
        $fatal(1, "Latched line base mismatch: addr=%h got=%h expected=%h",
               address, dut.req_line_base, {address[63:5], 5'b0});
      if (dut.req_addr_aligned !== (address[2:0] == 3'b000))
        $fatal(1, "Latched alignment mismatch: addr=%h aligned=%b",
               address, dut.req_addr_aligned);

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

    // Touch both ends of every declared array dimension. Besides checking the
    // geometry, this keeps older Icarus versions from optimizing unused
    // multi-dimensional memories out of the design.
    dut.valid_array = 8'h81;
    dut.tag_array[0] = 56'h01;
    dut.tag_array[7] = 56'h80;
    dut.data_array[0][0] = 64'h0123_4567_89ab_cdef;
    dut.data_array[7][3] = 64'hfedc_ba98_7654_3210;
    #1;
    if (dut.valid_array !== 8'h81 ||
        dut.tag_array[0] !== 56'h01 || dut.tag_array[7] !== 56'h80 ||
        dut.data_array[0][0] !== 64'h0123_4567_89ab_cdef ||
        dut.data_array[7][3] !== 64'hfedc_ba98_7654_3210)
      $fatal(1, "DCache array geometry or storage width is incorrect");

    check_cpu_decode(64'h0000_0000_0000_0000, 64'h0000_0000_0000_0000, 2'd0, 3'd0, 56'h0, 3'd0);
    check_cpu_decode(64'h0000_0000_0000_0008, 64'h0000_0000_0000_0000, 2'd1, 3'd0, 56'h0, 3'd0);
    check_cpu_decode(64'h0000_0000_0000_0018, 64'h0000_0000_0000_0000, 2'd3, 3'd0, 56'h0, 3'd0);
    check_cpu_decode(64'h0000_0000_0000_0020, 64'h0000_0000_0000_0020, 2'd0, 3'd1, 56'h0, 3'd0);
    check_cpu_decode(64'h0000_0000_0000_0038, 64'h0000_0000_0000_0020, 2'd3, 3'd1, 56'h0, 3'd0);
    check_cpu_decode(64'h0000_0000_0000_00f8, 64'h0000_0000_0000_00e0, 2'd3, 3'd7, 56'h0, 3'd0);
    check_cpu_decode(64'h0000_0000_0000_0100, 64'h0000_0000_0000_0100, 2'd0, 3'd0, 56'h1, 3'd0);
    check_cpu_decode(64'h0000_0000_0000_0138, 64'h0000_0000_0000_0120, 2'd3, 3'd1, 56'h1, 3'd0);
    check_cpu_decode(64'h1234_5678_9abc_de38, 64'h1234_5678_9abc_de20, 2'd3, 3'd1,
                     56'h1234_5678_9abc_de, 3'd0);
    check_cpu_decode(64'h0000_0000_0000_0039, 64'h0000_0000_0000_0020, 2'd3, 3'd1, 56'h0, 3'd1);

    check_latched_decode(64'h0000_0000_0000_0038);
    check_latched_decode(64'h0000_0000_0000_0138);
    check_latched_decode(64'h1234_5678_9abc_de39);

    $display("PASS: DCache address decomposition and array geometry passed %0d cases.", checks);
    $finish;
  end
endmodule
