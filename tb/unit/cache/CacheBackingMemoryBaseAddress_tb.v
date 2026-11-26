`timescale 1ns/1ps

module CacheBackingMemoryBaseAddress_tb;
    reg clk;
    reg reset;
    reg req_valid;
    reg req_write;
    reg [63:0] req_addr;
    reg [63:0] req_wdata;
    reg [7:0] req_wstrb;
    wire req_ready;
    wire resp_valid;
    wire [63:0] resp_rdata;
    integer timeout;

    localparam integer MEM_WORDS = 8;
    localparam [63:0] BASE_ADDR = 64'h0000_0000_0000_4000;
    localparam [63:0] LAST_ADDR = BASE_ADDR + MEM_WORDS * 8 - 8;

    CacheBackingMemory #(
        .MEM_WORDS(MEM_WORDS),
        .BASE_ADDR(BASE_ADDR)
    ) dut (
        .clk(clk),
        .reset(reset),
        .req_valid(req_valid),
        .req_write(req_write),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_wstrb(req_wstrb),
        .req_ready(req_ready),
        .resp_valid(resp_valid),
        .resp_rdata(resp_rdata)
    );

    always #5 clk = ~clk;

    task issue_request;
        input write_enable;
        input [63:0] address;
        input [63:0] write_data;
        input [7:0] write_strobe;
        begin
            @(negedge clk);
            req_valid = 1'b1;
            req_write = write_enable;
            req_addr = address;
            req_wdata = write_data;
            req_wstrb = write_strobe;

            timeout = 0;
            while (req_ready !== 1'b1) begin
                @(negedge clk);
                timeout = timeout + 1;
                if (timeout > 20)
                    $fatal(1, "request-ready timeout");
            end

            @(posedge clk);
            @(negedge clk);
            req_valid = 1'b0;

            timeout = 0;
            while (resp_valid !== 1'b1) begin
                @(negedge clk);
                timeout = timeout + 1;
                if (timeout > 20)
                    $fatal(1, "response timeout for address %h", address);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        req_valid = 1'b0;
        req_write = 1'b0;
        req_addr = 64'b0;
        req_wdata = 64'b0;
        req_wstrb = 8'b0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        issue_request(1'b1, BASE_ADDR,
                      64'h0123_4567_89ab_cdef, 8'hff);
        issue_request(1'b1, LAST_ADDR,
                      64'hfedc_ba98_7654_3210, 8'hff);
        issue_request(1'b0, BASE_ADDR, 64'b0, 8'b0);
        if (resp_rdata !== 64'h0123_4567_89ab_cdef)
            $fatal(1, "base-address readback failed: %h", resp_rdata);
        issue_request(1'b0, LAST_ADDR, 64'b0, 8'b0);
        if (resp_rdata !== 64'hfedc_ba98_7654_3210)
            $fatal(1, "last-address readback failed: %h", resp_rdata);

        issue_request(1'b1, BASE_ADDR - 8,
                      64'hffff_ffff_ffff_ffff, 8'hff);
        issue_request(1'b1, BASE_ADDR + MEM_WORDS * 8,
                      64'hffff_ffff_ffff_ffff, 8'hff);
        issue_request(1'b1, BASE_ADDR + 1,
                      64'hffff_ffff_ffff_ffff, 8'hff);
        if (dut.memory[0] !== 64'h0123_4567_89ab_cdef ||
            dut.memory[MEM_WORDS-1] !== 64'hfedc_ba98_7654_3210)
            $fatal(1, "illegal request corrupted a legal word");

        issue_request(1'b0, BASE_ADDR - 8, 64'b0, 8'b0);
        if (resp_rdata !== 64'b0)
            $fatal(1, "below-base read did not return zero");
        issue_request(1'b0, BASE_ADDR + MEM_WORDS * 8, 64'b0, 8'b0);
        if (resp_rdata !== 64'b0)
            $fatal(1, "above-range read did not return zero");

        $display("PASS: non-zero backing-memory base and both boundaries.");
        $finish;
    end
endmodule
