`timescale 1ns/1ps

module PIPELINED_CPU_CacheInteraction_tb;

    localparam [31:0] NOP = 32'h0000_0033;
    localparam [63:0] BACKING_VALUE = 64'h1122_3344_5566_7788;
    localparam [63:0] STORE_VALUE   = 64'haaaa_bbbb_cccc_dddd;

    reg clk;
    reg reset;
    integer i;
    integer timeout;
    integer icache_backend_reads;
    integer dcache_backend_reads;
    integer dcache_backend_writes;
    integer x5_write_count;
    integer x6_write_count;
    integer x7_write_count;
    integer x9_write_count;
    integer x11_write_count;
    reg saw_simultaneous_misses;
    reg saw_icache_response_during_dcache_stall;
    reg saw_icache_replay_after_dcache_stall;
    reg [63:0] blocked_fetch_pc;
    reg check_pc_hold;
    reg [63:0] pc_before_edge;
    reg [63:0] icache_addr_log [0:7];

    PIPELINED_CPU #(.DCACHE_BACKING_BASE_ADDR(64'h0)) dut (
        .reset(reset),
        .clk(clk),
        .external_interrupt_pending(1'b0)
    );

    always #5 clk = ~clk;

    function [31:0] enc_i;
        input [11:0] imm;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            enc_i = {imm, rs1, funct3, rd, opcode};
        end
    endfunction

    function [31:0] enc_s;
        input [11:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        begin
            enc_s = {imm[11:5], rs2, rs1, funct3,
                     imm[4:0], 7'b0100011};
        end
    endfunction

    task write_instr;
        input integer instruction_index;
        input [31:0] instruction;
        integer backend_word_index;
        begin
            backend_word_index = instruction_index >> 1;
            if ((instruction_index & 1) == 0)
                dut.u_icache_backing_memory.memory[backend_word_index][31:0] = instruction;
            else
                dut.u_icache_backing_memory.memory[backend_word_index][63:32] = instruction;
        end
    endtask

    always @(posedge clk) begin
        check_pc_hold = !reset && dut.dcache_stall &&
                        !dut.control_flush_mem;
        pc_before_edge = dut.current_pc_if;

        if (reset) begin
            icache_backend_reads <= 0;
            dcache_backend_reads <= 0;
            dcache_backend_writes <= 0;
            x5_write_count <= 0;
            x6_write_count <= 0;
            x7_write_count <= 0;
            x9_write_count <= 0;
            x11_write_count <= 0;
            saw_simultaneous_misses <= 1'b0;
            saw_icache_response_during_dcache_stall <= 1'b0;
            saw_icache_replay_after_dcache_stall <= 1'b0;
            blocked_fetch_pc <= 64'b0;
        end
        else begin
            if (dut.icache_mem_req_valid && dut.icache_mem_req_ready) begin
                if (icache_backend_reads < 8)
                    icache_addr_log[icache_backend_reads] <= dut.icache_mem_req_addr;
                icache_backend_reads <= icache_backend_reads + 1;
            end

            if (dut.dcache_mem_req_valid && dut.dcache_mem_req_ready) begin
                if (dut.dcache_mem_req_write)
                    dcache_backend_writes <= dcache_backend_writes + 1;
                else
                    dcache_backend_reads <= dcache_backend_reads + 1;
            end

            if (dut.dcache_stall && dut.icache_request_inflight)
                saw_simultaneous_misses <= 1'b1;

            if (dut.dcache_stall && dut.icache_resp_usable) begin
                saw_icache_response_during_dcache_stall <= 1'b1;
                blocked_fetch_pc <= dut.current_pc_if;
            end

            if (saw_icache_response_during_dcache_stall &&
                !dut.dcache_stall && dut.icache_resp_usable &&
                (dut.current_pc_if == blocked_fetch_pc))
                saw_icache_replay_after_dcache_stall <= 1'b1;

            if (dut.Regwrite_wb) begin
                case (dut.instruction_wb[11:7])
                    5'd5:  x5_write_count <= x5_write_count + 1;
                    5'd6:  x6_write_count <= x6_write_count + 1;
                    5'd7:  x7_write_count <= x7_write_count + 1;
                    5'd9:  x9_write_count <= x9_write_count + 1;
                    5'd11: x11_write_count <= x11_write_count + 1;
                    default: ;
                endcase
            end
        end

        #1;
        if (check_pc_hold && (dut.current_pc_if !== pc_before_edge))
            $fatal(1, "PC changed while D-Cache stalled the pipeline");
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        check_pc_hold = 1'b0;
        pc_before_edge = 64'b0;

        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'b0;
        for (i = 0; i < 256; i = i + 1) begin
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            dut.u_dcache_backing_memory.memory[i] = 64'b0;
        end
        for (i = 0; i < 8; i = i + 1)
            icache_addr_log[i] = 64'hffff_ffff_ffff_ffff;

        // The Load is placed at the end of the first instruction line.  Its
        // D-Cache miss overlaps the fetch miss for the next instruction line.
        write_instr(0, enc_i(12'd1, 5'd0, 3'b000, 5'd1, 7'b0010011));
        write_instr(1, enc_i(12'd2, 5'd0, 3'b000, 5'd2, 7'b0010011));
        write_instr(2, enc_i(12'd3, 5'd0, 3'b000, 5'd3, 7'b0010011));
        write_instr(3, enc_i(12'd4, 5'd0, 3'b000, 5'd4, 7'b0010011));
        write_instr(4, enc_i(12'd12, 5'd0, 3'b000, 5'd12, 7'b0010011));
        write_instr(5, enc_i(12'd13, 5'd0, 3'b000, 5'd13, 7'b0010011));
        write_instr(6, enc_i(12'h108, 5'd0, 3'b011, 5'd5,
                             7'b0000011));
        write_instr(7, enc_i(12'd6, 5'd0, 3'b000, 5'd6,
                             7'b0010011));

        write_instr(8, enc_i(12'd7, 5'd0, 3'b000, 5'd7,
                             7'b0010011));
        write_instr(9, enc_s(12'h108, 5'd10, 5'd0, 3'b011));
        write_instr(10, enc_i(12'h108, 5'd0, 3'b011, 5'd9,
                              7'b0000011));
        write_instr(11, enc_i(12'd11, 5'd0, 3'b000, 5'd11,
                              7'b0010011));

        dut.u_register.registers[10] = STORE_VALUE;
        dut.u_dcache_backing_memory.memory[8'h20] = 64'h0101_0101_0101_0101;
        dut.u_dcache_backing_memory.memory[8'h21] = BACKING_VALUE;
        dut.u_dcache_backing_memory.memory[8'h22] = 64'h0202_0202_0202_0202;
        dut.u_dcache_backing_memory.memory[8'h23] = 64'h0303_0303_0303_0303;

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        timeout = 0;
        while ((dut.u_register.registers[11] !== 64'd11) &&
               (timeout < 500)) begin
            @(posedge clk);
            #1;
            timeout = timeout + 1;
        end
        if (timeout >= 500)
            $fatal(1, "timeout waiting for combined I/D Cache program");

        if (dut.u_register.registers[5] !== BACKING_VALUE)
            $fatal(1, "D-Cache miss Load returned %h, expected %h",
                   dut.u_register.registers[5], BACKING_VALUE);
        if (dut.u_register.registers[6] !== 64'd6 ||
            dut.u_register.registers[7] !== 64'd7 ||
            dut.u_register.registers[11] !== 64'd11)
            $fatal(1, "instructions surrounding the overlapping misses were lost");
        if (dut.u_register.registers[9] !== STORE_VALUE)
            $fatal(1, "Load after Store returned %h, expected %h",
                   dut.u_register.registers[9], STORE_VALUE);
        if (dut.u_dcache_backing_memory.memory[8'h21] !== STORE_VALUE)
            $fatal(1, "write-through Store did not update backing memory");

        if (!saw_simultaneous_misses)
            $fatal(1, "I-Cache and D-Cache misses never overlapped");
        if (!saw_icache_response_during_dcache_stall)
            $fatal(1, "I-Cache response did not occur while D-Cache stalled the CPU");
        if (!saw_icache_replay_after_dcache_stall)
            $fatal(1, "held fetch was not presented again after D-Cache stall ended");

        if (dcache_backend_reads !== 4 || dcache_backend_writes !== 1)
            $fatal(1, "D-Cache backend requests read=%0d write=%0d, expected 4/1",
                   dcache_backend_reads, dcache_backend_writes);
        if (icache_backend_reads < 8)
            $fatal(1, "I-Cache backend reads=%0d, expected at least 8",
                   icache_backend_reads);

        if (icache_addr_log[0] !== 64'h000 ||
            icache_addr_log[1] !== 64'h008 ||
            icache_addr_log[2] !== 64'h010 ||
            icache_addr_log[3] !== 64'h018 ||
            icache_addr_log[4] !== 64'h020 ||
            icache_addr_log[5] !== 64'h028 ||
            icache_addr_log[6] !== 64'h030 ||
            icache_addr_log[7] !== 64'h038)
            $fatal(1, "the first two I-Cache line-fill address sequences were incorrect");

        if (x5_write_count !== 1 || x6_write_count !== 1 ||
            x7_write_count !== 1 || x9_write_count !== 1 ||
            x11_write_count !== 1)
            $fatal(1, "architectural writes were repeated: x5=%0d x6=%0d x7=%0d x9=%0d x11=%0d",
                   x5_write_count, x6_write_count, x7_write_count,
                   x9_write_count, x11_write_count);

        $display("PASS: simultaneous I-Cache/D-Cache miss and response interaction passed");
        $display("      cycles=%0d icache_reads=%0d dcache_reads=%0d dcache_writes=%0d",
                 timeout, icache_backend_reads,
                 dcache_backend_reads, dcache_backend_writes);
        $finish;
    end

    initial begin
        #8000;
        $fatal(1, "timeout");
    end

endmodule
