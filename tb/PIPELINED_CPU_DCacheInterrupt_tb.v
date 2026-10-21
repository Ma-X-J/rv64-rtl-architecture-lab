`timescale 1ns/1ps

module PIPELINED_CPU_DCacheInterrupt_tb;
    reg clk;
    reg reset;
    reg external_interrupt_pending;
    integer i;
    integer timeout;
    integer backend_read_fires;
    integer load_write_count;

    localparam [31:0] NOP = 32'h0000_0033;
    localparam [63:0] LOAD_VALUE = 64'h1234_5678_9abc_def0;
    localparam [63:0] CAUSE_EXTERNAL_INTERRUPT =
        64'h8000_0000_0000_000b;

    PIPELINED_CPU dut (
        .reset(reset),
        .clk(clk),
        .external_interrupt_pending(external_interrupt_pending)
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

    // Store one 32-bit instruction in the 64-bit I-Cache backing memory.
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
        if (reset) begin
            backend_read_fires <= 0;
            load_write_count <= 0;
        end
        else begin
            if (dut.dcache_mem_req_valid && dut.dcache_mem_req_ready &&
                !dut.dcache_mem_req_write)
                backend_read_fires <= backend_read_fires + 1;

            if (dut.Regwrite_wb && dut.instruction_wb[11:7] == 5'd5)
                load_write_count <= load_write_count + 1;

            if (dut.dcache_request_inflight &&
                dut.external_interrupt_pending_effective)
                $fatal(1, "external interrupt was not masked during an in-flight cache request");

            if (dut.dcache_request_inflight && dut.trap_enter)
                $fatal(1, "trap entered before the in-flight cache request completed");
        end
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        external_interrupt_pending = 1'b0;

        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'b0;
        for (i = 0; i < 256; i = i + 1) begin
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            dut.u_dcache_backing_memory.memory[i] = 64'b0;
        end

        dut.u_dcache_backing_memory.memory[8'h20] = 64'h1111;
        dut.u_dcache_backing_memory.memory[8'h21] = LOAD_VALUE;
        dut.u_dcache_backing_memory.memory[8'h22] = 64'h2222;
        dut.u_dcache_backing_memory.memory[8'h23] = 64'h3333;

        write_instr(0, enc_i(12'h108, 5'd0, 3'b011, 5'd5,
                                7'b0000011)); // Load miss at PC 0
        write_instr(1, enc_i(12'd6, 5'd0, 3'b000, 5'd6,
                                7'b0010011)); // interrupted at PC 4
        write_instr(2, enc_i(12'd7, 5'd0, 3'b000, 5'd7,
                                7'b0010011)); // younger, must be flushed
        write_instr(64, enc_i(12'd10, 5'd0, 3'b000, 5'd10,
                                 7'b0010011)); // mtvec handler at 0x100

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        // Enable machine external interrupts directly for this focused test.
        dut.u_csrfile.mstatus = 64'h8;

        timeout = 0;
        while (!dut.dcache_request_inflight && timeout < 40) begin
            @(posedge clk);
            #1;
            timeout = timeout + 1;
        end
        if (timeout >= 40)
            $fatal(1, "DCache request never became in-flight");

        // Raise and hold the pending interrupt in the middle of the miss.
        external_interrupt_pending = 1'b1;
        repeat (3) begin
            @(posedge clk);
            #1;
            if (!dut.dcache_request_inflight)
                $fatal(1, "cache request completed too early for interrupt test");
            if (dut.trap_enter)
                $fatal(1, "interrupt was taken while cache miss was outstanding");
        end

        timeout = 0;
        while (!dut.trap_enter && timeout < 80) begin
            @(posedge clk);
            #1;
            timeout = timeout + 1;
        end
        if (timeout >= 80)
            $fatal(1, "deferred external interrupt was never taken");

        if (dut.dcache_request_inflight !== 1'b0)
            $fatal(1, "interrupt taken while request still marked in-flight");
        if (dut.current_pc_mem !== 64'h4)
            $fatal(1, "interrupt PC in MEM=%h expected=4",
                   dut.current_pc_mem);

        // trap_enter is combinational here; the next edge records mepc/mcause
        // and retires the older completed Load from MEM/WB.
        @(posedge clk);
        #1;
        external_interrupt_pending = 1'b0;

        if (dut.u_csrfile.mepc_out !== 64'h4)
            $fatal(1, "mepc=%h expected=4", dut.u_csrfile.mepc_out);
        if (dut.u_csrfile.mcause_out !== CAUSE_EXTERNAL_INTERRUPT)
            $fatal(1, "mcause=%h expected=%h",
                   dut.u_csrfile.mcause_out, CAUSE_EXTERNAL_INTERRUPT);
        if (dut.u_register.registers[5] !== LOAD_VALUE)
            $fatal(1, "older Load did not retire before interrupt: x5=%h",
                   dut.u_register.registers[5]);
        if (dut.u_register.registers[6] !== 64'b0 ||
            dut.u_register.registers[7] !== 64'b0)
            $fatal(1, "interrupted or younger instruction committed");

        timeout = 0;
        while ((dut.u_register.registers[10] !== 64'd10) &&
               (timeout < 180)) begin
            @(posedge clk);
            #1;
            timeout = timeout + 1;
        end
        if (timeout >= 180)
            $fatal(1, "timeout waiting for mtvec handler completion");

        if (dut.u_register.registers[10] !== 64'd10)
            $fatal(1, "mtvec handler did not execute");
        if (backend_read_fires !== 4)
            $fatal(1, "backend refill reads=%0d expected=4",
                   backend_read_fires);
        if (load_write_count !== 1)
            $fatal(1, "older Load write count=%0d expected=1",
                   load_write_count);

        $display("[PASS] External interrupt was deferred until the DCache miss completed");
        $display("       mepc=%h backend_reads=%0d load_writes=%0d",
                 dut.u_csrfile.mepc_out,
                 backend_read_fires,
                 load_write_count);
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "timeout");
    end

endmodule
