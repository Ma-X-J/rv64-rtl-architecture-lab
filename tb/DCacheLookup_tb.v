`timescale 1ns/1ps

module DCacheLookup_tb;
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

  integer line;
  integer word_index;
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

  task check_lookup;
    input [63:0] address;
    input        request_valid;
    input        request_write;
    input        expected_line_hit;
    input        expected_load_hit;
    input        expected_aligned;
    input [63:0] expected_selected_data;
    begin
      cpu_req_addr = address;
      cpu_req_valid = request_valid;
      cpu_req_write = request_write;
      #1;

      if (dut.cpu_addr_aligned !== expected_aligned)
        $fatal(1, "Alignment mismatch: addr=%h got=%b expected=%b",
               address, dut.cpu_addr_aligned, expected_aligned);
      if (dut.cpu_line_hit !== expected_line_hit)
        $fatal(1, "Line-hit mismatch: addr=%h got=%b expected=%b",
               address, dut.cpu_line_hit, expected_line_hit);
      if (dut.cpu_load_hit !== expected_load_hit)
        $fatal(1, "Load-hit mismatch: addr=%h valid=%b write=%b got=%b expected=%b",
               address, request_valid, request_write,
               dut.cpu_load_hit, expected_load_hit);
      if (dut.cpu_hit_rdata !== expected_selected_data)
        $fatal(1, "Selected data mismatch: addr=%h got=%h expected=%h",
               address, dut.cpu_hit_rdata, expected_selected_data);

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

    for (line = 0; line < 8; line = line + 1) begin
      dut.tag_array[line] = 56'h0100 + line;
      for (word_index = 0; word_index < 4; word_index = word_index + 1)
        dut.data_array[line][word_index] =
          64'hf000_0000_0000_0000 + (line * 16) + word_index;
    end

    // Prove that reset invalidates every line while leaving tag/data storage
    // untouched. Only valid bits define whether stale storage may be used.
    dut.valid_array = 8'hff;
    reset = 1'b1;
    @(posedge clk);
    #1;
    if (dut.valid_array !== 8'h00)
      $fatal(1, "Reset did not invalidate every cache line: valid=%h",
             dut.valid_array);
    if (dut.tag_array[1] !== 56'h0101 ||
        dut.data_array[1][3] !== 64'hf000_0000_0000_0013)
      $fatal(1, "Reset unexpectedly modified tag or data storage");
    checks = checks + 1;

    @(negedge clk);
    reset = 1'b0;

    // Install line base 0x20: tag=0, index=1, four distinct words.
    dut.valid_array[1] = 1'b1;
    dut.tag_array[1] = 56'h0;
    dut.data_array[1][0] = 64'h1111_1111_1111_1111;
    dut.data_array[1][1] = 64'h2222_2222_2222_2222;
    dut.data_array[1][2] = 64'h3333_3333_3333_3333;
    dut.data_array[1][3] = 64'h4444_4444_4444_4444;

    check_lookup(64'h20, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1,
                 64'h1111_1111_1111_1111);
    check_lookup(64'h28, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1,
                 64'h2222_2222_2222_2222);
    check_lookup(64'h30, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1,
                 64'h3333_3333_3333_3333);
    check_lookup(64'h38, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1,
                 64'h4444_4444_4444_4444);

    // Valid=0 blocks a hit even when the stored tag happens to match.
    dut.valid_array[2] = 1'b0;
    dut.tag_array[2] = 56'h0;
    dut.data_array[2][0] = 64'haaaa_aaaa_aaaa_aaaa;
    check_lookup(64'h40, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1,
                 64'haaaa_aaaa_aaaa_aaaa);

    // 0x138 has the same index/word offset as 0x38 but a different tag.
    check_lookup(64'h138, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1,
                 64'h4444_4444_4444_4444);

    // The raw line lookup may hit without a valid CPU transaction, but the
    // complete Load-hit condition must remain false.
    check_lookup(64'h20, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1,
                 64'h1111_1111_1111_1111);

    // A Store can find the line, but it is deliberately excluded from the
    // read-only Load-hit signal implemented in this step.
    check_lookup(64'h20, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1,
                 64'h1111_1111_1111_1111);

    // Misalignment blocks a complete Load hit even though tag/index match.
    check_lookup(64'h21, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0,
                 64'h1111_1111_1111_1111);

    // Verify that all 56 tag bits participate in the comparison.
    dut.tag_array[1] = 56'h1234_5678_9abc_de;
    dut.data_array[1][3] = 64'hdeaf_beef_cafe_f00d;
    check_lookup(64'h1234_5678_9abc_de38,
                 1'b1, 1'b0, 1'b1, 1'b1, 1'b1,
                 64'hdeaf_beef_cafe_f00d);

    // A later reset must invalidate an already populated line without
    // requiring tag/data arrays to be cleared.
    @(negedge clk);
    reset = 1'b1;
    @(posedge clk);
    #1;
    if (dut.valid_array !== 8'h00)
      $fatal(1, "Second reset did not clear valid bits");
    if (dut.tag_array[1] !== 56'h1234_5678_9abc_de ||
        dut.data_array[1][3] !== 64'hdeaf_beef_cafe_f00d)
      $fatal(1, "Second reset unexpectedly cleared tag/data storage");
    cpu_req_addr = 64'h1234_5678_9abc_de38;
    cpu_req_valid = 1'b1;
    cpu_req_write = 1'b0;
    #1;
    if (dut.cpu_line_hit !== 1'b0 || dut.cpu_load_hit !== 1'b0)
      $fatal(1, "Invalidated line still reported a hit after reset");
    checks = checks + 1;

    $display("PASS: DCache reset and Load-hit lookup passed %0d checks.", checks);
    $finish;
  end
endmodule
