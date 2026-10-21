`timescale 1ns/1ps

module PIPELINED_CPU_ICache_tb;

    localparam [31:0] NOP = 32'h00000033;

    reg clk;
    reg reset;
    reg external_interrupt_pending;

    integer i;
    integer cycles;
    integer failures;
    integer icache_backend_reads;
    integer icache_miss_accepts;
    integer stale_responses;
    integer control_flushes;
    integer x6_write_count;
    integer x10_write_count;
    integer x11_write_count;
    integer wrong_path_write_count;

    reg [63:0] backend_addr_log [0:15];
    reg        check_pc_hold;
    reg [63:0] pc_before_edge;
    reg        check_if_id_bubble;

    PIPELINED_CPU dut (
        .reset(reset),
        .clk(clk),
        .external_interrupt_pending(external_interrupt_pending)
    );

    always #5 clk = ~clk;

    function [31:0] enc_i;
        input [11:0] imm;
        input [4:0]  rs1;
        input [2:0]  funct3;
        input [4:0]  rd;
        input [6:0]  opcode;
        begin
            enc_i = {imm, rs1, funct3, rd, opcode};
        end
    endfunction

    function [31:0] enc_j;
        input [20:0] imm;
        input [4:0]  rd;
        begin
            enc_j = {imm[20], imm[10:1], imm[11], imm[19:12],
                     rd, 7'b1101111};
        end
    endfunction

    task expect_reg;
        input [4:0] reg_index;
        input [63:0] expected;
        input [8*48-1:0] description;
        begin
            if (dut.u_register.registers[reg_index] !== expected) begin
                $display("FAIL: %0s: x%0d=%h, expected=%h",
                         description, reg_index,
                         dut.u_register.registers[reg_index], expected);
                failures = failures + 1;
            end
        end
    endtask

    task expect_integer;
        input integer actual;
        input integer expected;
        input [8*48-1:0] description;
        begin
            if (actual != expected) begin
                $display("FAIL: %0s: actual=%0d, expected=%0d",
                         description, actual, expected);
                failures = failures + 1;
            end
        end
    endtask

    task expect_backend_addr;
        input integer log_index;
        input [63:0] expected;
        begin
            if (backend_addr_log[log_index] !== expected) begin
                $display("FAIL: backend request %0d address=%h, expected=%h",
                         log_index, backend_addr_log[log_index], expected);
                failures = failures + 1;
            end
        end
    endtask

    // Observe the top-level I-Cache protocol and pipeline behavior at every edge.
    always @(posedge clk) begin
        check_pc_hold = !reset &&
                        !dut.control_flush_mem &&
                        !dut.icache_resp_usable &&
                        !dut.dcache_stall &&
                        dut.PCwrite_hazard;
        pc_before_edge = dut.current_pc_if;

        check_if_id_bubble = !reset &&
                             dut.IF_ID_write_final &&
                             !dut.control_flush_mem &&
                             !dut.icache_resp_usable;

        if (!reset) begin
            if (dut.icache_mem_req_valid && dut.icache_mem_req_ready) begin
                if (icache_backend_reads < 16)
                    backend_addr_log[icache_backend_reads] = dut.icache_mem_req_addr;
                icache_backend_reads = icache_backend_reads + 1;
            end

            if (dut.icache_cpu_req_fire && !dut.icache_cpu_resp_valid)
                icache_miss_accepts = icache_miss_accepts + 1;

            if (dut.icache_cpu_resp_valid &&
                dut.icache_request_inflight &&
                (dut.icache_pending_pc != dut.current_pc_if))
                stale_responses = stale_responses + 1;

            if (dut.control_flush_mem)
                control_flushes = control_flushes + 1;

            if (dut.Regwrite_wb) begin
                case (dut.instruction_wb[11:7])
                    5'd6:  x6_write_count = x6_write_count + 1;
                    5'd10: x10_write_count = x10_write_count + 1;
                    5'd11: x11_write_count = x11_write_count + 1;
                    5'd20,
                    5'd21: wrong_path_write_count = wrong_path_write_count + 1;
                    default: ;
                endcase
            end
        end

        #1;
        if (check_pc_hold && (dut.current_pc_if !== pc_before_edge)) begin
            $display("FAIL: PC changed while waiting for an I-Cache response: before=%h after=%h",
                     pc_before_edge, dut.current_pc_if);
            failures = failures + 1;
        end

        if (check_if_id_bubble && (dut.valid_id !== 1'b0)) begin
            $display("FAIL: IF/ID accepted a valid instruction without a usable I-Cache response");
            failures = failures + 1;
        end
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        external_interrupt_pending = 1'b0;
        cycles = 0;
        failures = 0;
        icache_backend_reads = 0;
        icache_miss_accepts = 0;
        stale_responses = 0;
        control_flushes = 0;
        x6_write_count = 0;
        x10_write_count = 0;
        x11_write_count = 0;
        wrong_path_write_count = 0;
        check_pc_hold = 1'b0;
        check_if_id_bubble = 1'b0;
        pc_before_edge = 64'b0;

        // Fill both independent backing memories with deterministic data.
        for (i = 0; i < 256; i = i + 1) begin
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            dut.u_dcache_backing_memory.memory[i] = 64'b0;
        end

        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'b0;

        for (i = 0; i < 16; i = i + 1)
            backend_addr_log[i] = 64'hffff_ffff_ffff_ffff;

        // PC 0x000--0x01c share the first 32-byte line.  The JAL at
        // 0x018 redirects to 0x100 after the sequential PC 0x020 miss has
        // already started, so the old response must be discarded.
        dut.u_icache_backing_memory.memory[0] = {
            enc_i(12'd2, 5'd0, 3'b000, 5'd2, 7'b0010011),
            enc_i(12'd1, 5'd0, 3'b000, 5'd1, 7'b0010011)
        };
        dut.u_icache_backing_memory.memory[1] = {
            enc_i(12'd4, 5'd0, 3'b000, 5'd4, 7'b0010011),
            enc_i(12'd3, 5'd0, 3'b000, 5'd3, 7'b0010011)
        };
        dut.u_icache_backing_memory.memory[2] = {
            enc_i(12'd7, 5'd0, 3'b000, 5'd7, 7'b0010011),
            enc_i(12'd5, 5'd0, 3'b000, 5'd5, 7'b0010011)
        };
        dut.u_icache_backing_memory.memory[3] = {
            enc_i(12'd20, 5'd0, 3'b000, 5'd20, 7'b0010011),
            enc_j(21'd232, 5'd6)
        };
        dut.u_icache_backing_memory.memory[4] = {
            NOP,
            enc_i(12'd21, 5'd0, 3'b000, 5'd21, 7'b0010011)
        };
        dut.u_icache_backing_memory.memory[32] = {
            enc_i(12'd11, 5'd0, 3'b000, 5'd11, 7'b0010011),
            enc_i(12'd10, 5'd0, 3'b000, 5'd10, 7'b0010011)
        };

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        while ((dut.u_register.registers[11] !== 64'd11) && (cycles < 400)) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
        end

        if (cycles >= 400) begin
            $display("FAIL: timeout waiting for the redirected target program");
            failures = failures + 1;
        end

        expect_reg(5'd1,  64'd1,  "first instruction after cold miss");
        expect_reg(5'd2,  64'd2,  "same-line hit at PC 0x004");
        expect_reg(5'd3,  64'd3,  "same-line hit at PC 0x008");
        expect_reg(5'd4,  64'd4,  "same-line hit at PC 0x00c");
        expect_reg(5'd5,  64'd5,  "same-line hit at PC 0x010");
        expect_reg(5'd7,  64'd7,  "same-line hit at PC 0x014");
        expect_reg(5'd6,  64'd28, "JAL link value");
        expect_reg(5'd20, 64'd0,  "wrong-path PC 0x01c instruction flushed");
        expect_reg(5'd21, 64'd0,  "stale PC 0x020 instruction discarded");
        expect_reg(5'd10, 64'd10, "redirect target instruction");
        expect_reg(5'd11, 64'd11, "redirect target same-line hit");

        expect_integer(icache_backend_reads, 12,
                       "three line fills issue four backend reads each");
        expect_integer(icache_miss_accepts, 3,
                       "cold, sequential stale, and redirect misses");
        expect_integer(stale_responses, 1,
                       "one old-path I-Cache response is rejected");
        expect_integer(control_flushes, 1,
                       "JAL generates one redirect/flush cycle");
        expect_integer(x6_write_count, 1, "JAL commits exactly once");
        expect_integer(x10_write_count, 1, "target x10 commits exactly once");
        expect_integer(x11_write_count, 1, "target x11 commits exactly once");
        expect_integer(wrong_path_write_count, 0,
                       "wrong-path instructions never commit");

        expect_backend_addr(0,  64'h000);
        expect_backend_addr(1,  64'h008);
        expect_backend_addr(2,  64'h010);
        expect_backend_addr(3,  64'h018);
        expect_backend_addr(4,  64'h020);
        expect_backend_addr(5,  64'h028);
        expect_backend_addr(6,  64'h030);
        expect_backend_addr(7,  64'h038);
        expect_backend_addr(8,  64'h100);
        expect_backend_addr(9,  64'h108);
        expect_backend_addr(10, 64'h110);
        expect_backend_addr(11, 64'h118);

        if (failures == 0)
            $display("PASS: PIPELINED_CPU I-Cache integration test passed (%0d cycles)",
                     cycles);
        else
            $display("FAIL: PIPELINED_CPU I-Cache integration test found %0d error(s)",
                     failures);

        $finish;
    end

endmodule
