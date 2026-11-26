`timescale 1ns/1ps

module PIPELINED_CPU_TRAP_tb;
    reg clk;
    reg reset;
    reg external_interrupt_pending;
    integer i;

    localparam [31:0] NOP   = 32'h00000033;
    localparam [31:0] ECALL = 32'h00000073;
    localparam [31:0] MRET  = 32'h30200073;

    localparam [63:0] CAUSE_INSTRUCTION_MISALIGNED = 64'h0;
    localparam [63:0] CAUSE_ILLEGAL_INSTRUCTION    = 64'h2;
    localparam [63:0] CAUSE_LOAD_MISALIGNED        = 64'h4;
    localparam [63:0] CAUSE_STORE_MISALIGNED       = 64'h6;
    localparam [63:0] CAUSE_ECALL_MMODE             = 64'hb;
    localparam [63:0] CAUSE_EXTERNAL_INTERRUPT      = 64'h8000_0000_0000_000b;

    PIPELINED_CPU #(.DCACHE_BACKING_BASE_ADDR(64'h0)) dut (
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

    function [31:0] enc_s;
        input [11:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        begin
            enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
        end
    endfunction

    function [31:0] enc_b;
        input [12:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        begin
            enc_b = {imm[12], imm[10:5], rs2, rs1, funct3,
                     imm[4:1], imm[11], 7'b1100011};
        end
    endfunction

    function [31:0] enc_j;
        input [20:0] imm;
        input [4:0] rd;
        begin
            enc_j = {imm[20], imm[10:1], imm[11], imm[19:12],
                     rd, 7'b1101111};
        end
    endfunction

    function [31:0] enc_csr;
        input [11:0] csr;
        input [4:0] rs1_or_zimm;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            enc_csr = {csr, rs1_or_zimm, funct3, rd, 7'b1110011};
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
    task start_phase;
        input [511:0] phase_name;
        begin
            external_interrupt_pending = 1'b0;
            reset = 1'b1;
            @(posedge clk);
            #1;
            if (dut.current_pc_if !== 64'd0)
                $fatal(1, "%0s: reset did not clear PC", phase_name);

            @(negedge clk);
            reset = 1'b0;

            for (i = 0; i < 32; i = i + 1)
                dut.u_register.registers[i] = 64'd0;
            for (i = 0; i < 256; i = i + 1) begin
                dut.u_dcache_backing_memory.memory[i] = 64'd0;
                dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            end

            // mtvec resets to 0x100, so ROM word 64 is the first handler instruction.
            write_instr(64, enc_i(12'd7, 5'd0, 3'b000, 5'd10, 7'b0010011));
            $display("\n[PHASE] %0s", phase_name);
        end
    endtask

    task run_cycles;
        input integer count;
        integer cycle;
        begin
            for (cycle = 0; cycle < count; cycle = cycle + 1) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    task wait_for_reg;
        input [4:0] index;
        input [63:0] expected;
        input integer max_cycles;
        input [511:0] description;
        integer waited;
        begin
            waited = 0;
            while ((dut.u_register.registers[index] !== expected) &&
                   (waited < max_cycles)) begin
                @(posedge clk);
                #1;
                waited = waited + 1;
            end
            if (waited >= max_cycles)
                $fatal(1, "%0s: timeout waiting for x%0d=%h (got %h)",
                       description, index, expected,
                       dut.u_register.registers[index]);
        end
    endtask

    task check_reg;
        input [4:0] index;
        input [63:0] expected;
        input [511:0] description;
        begin
            if (dut.u_register.registers[index] !== expected)
                $fatal(1, "%0s: x%0d = %h, expected %h",
                       description, index,
                       dut.u_register.registers[index], expected);
        end
    endtask

    task check64;
        input [63:0] actual;
        input [63:0] expected;
        input [511:0] description;
        begin
            if (actual !== expected)
                $fatal(1, "%0s: got %h, expected %h",
                       description, actual, expected);
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        external_interrupt_pending = 1'b0;

        // An older WB instruction must retire, while ECALL and its younger
        // instructions redirect to mtvec and are flushed.
        start_phase("ECALL records PC/cause, preserves older WB, flushes younger instructions");
        write_instr(0, enc_i(12'd5, 5'd0, 3'b000, 5'd1, 7'b0010011));
        write_instr(1, ECALL);
        write_instr(2, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        write_instr(3, enc_i(12'd1, 5'd0, 3'b000, 5'd3, 7'b0010011));
        wait_for_reg(5'd10, 64'd7, 240, "ECALL handler completion");
        check64(dut.u_csrfile.mepc_out, 64'h4, "ECALL stores its own PC in mepc");
        check64(dut.u_csrfile.mcause_out, CAUSE_ECALL_MMODE, "ECALL cause");
        check_reg(5'd1, 64'd5, "instruction older than ECALL still retires");
        check_reg(5'd2, 64'd0, "first younger instruction is flushed");
        check_reg(5'd3, 64'd0, "second younger instruction is flushed");
        check_reg(5'd10, 64'd7, "mtvec handler executes after ECALL");

        start_phase("illegal instruction enters trap and flushes younger instruction");
        write_instr(0, 32'hffff_ffff);
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        wait_for_reg(5'd10, 64'd7, 220,
                     "illegal-instruction handler completion");
        check64(dut.u_csrfile.mepc_out, 64'h0, "illegal instruction stores PC");
        check64(dut.u_csrfile.mcause_out, CAUSE_ILLEGAL_INSTRUCTION, "illegal instruction cause");
        check_reg(5'd2, 64'd0, "illegal instruction flushes younger instruction");
        check_reg(5'd10, 64'd7, "mtvec handler executes after illegal instruction");

        start_phase("misaligned LD traps without writing rd");
        dut.u_register.registers[5] = 64'h55aa;
        dut.u_dcache_backing_memory.memory[0] = 64'h1122_3344_5566_7788;
        write_instr(0, enc_i(12'd4, 5'd0, 3'b011, 5'd5, 7'b0000011));
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        wait_for_reg(5'd10, 64'd7, 220,
                     "misaligned-load handler completion");
        check64(dut.u_csrfile.mcause_out, CAUSE_LOAD_MISALIGNED, "misaligned LD cause");
        check_reg(5'd5, 64'h55aa, "misaligned LD does not write rd");
        check_reg(5'd2, 64'd0, "misaligned LD flushes younger instruction");

        start_phase("misaligned LW traps without writing rd");
        dut.u_register.registers[5] = 64'h66bb;
        dut.u_dcache_backing_memory.memory[0] = 64'h1122_3344_5566_7788;
        write_instr(0, enc_i(12'd2, 5'd0, 3'b010, 5'd5, 7'b0000011));
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        wait_for_reg(5'd10, 64'd7, 220,
                     "misaligned-LW handler completion");
        check64(dut.u_csrfile.mcause_out, CAUSE_LOAD_MISALIGNED,
                "misaligned LW cause");
        check_reg(5'd5, 64'h66bb, "misaligned LW does not write rd");
        check_reg(5'd2, 64'd0, "misaligned LW flushes younger instruction");

        start_phase("misaligned LH traps while byte loads remain legal");
        dut.u_register.registers[5] = 64'h77cc;
        dut.u_dcache_backing_memory.memory[0] = 64'h1122_3344_5566_7788;
        write_instr(0, enc_i(12'd1, 5'd0, 3'b001, 5'd5, 7'b0000011));
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        wait_for_reg(5'd10, 64'd7, 220,
                     "misaligned-LH handler completion");
        check64(dut.u_csrfile.mcause_out, CAUSE_LOAD_MISALIGNED,
                "misaligned LH cause");
        check_reg(5'd5, 64'h77cc, "misaligned LH does not write rd");
        check_reg(5'd2, 64'd0, "misaligned LH flushes younger instruction");

        start_phase("misaligned SD traps without changing memory");
        dut.u_register.registers[6] = 64'hdead_beef_cafe_babe;
        dut.u_dcache_backing_memory.memory[0] = 64'h0123_4567_89ab_cdef;
        write_instr(0, enc_s(12'd2, 5'd6, 5'd0, 3'b011));
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        wait_for_reg(5'd10, 64'd7, 220,
                     "misaligned-store handler completion");
        check64(dut.u_csrfile.mcause_out, CAUSE_STORE_MISALIGNED, "misaligned SD cause");
        check64(dut.u_dcache_backing_memory.memory[0], 64'h0123_4567_89ab_cdef,
                "misaligned SD does not change memory");
        check_reg(5'd2, 64'd0, "misaligned SD flushes younger instruction");

        start_phase("misaligned SH traps without changing memory");
        dut.u_register.registers[6] = 64'hbeef;
        dut.u_dcache_backing_memory.memory[0] = 64'h0123_4567_89ab_cdef;
        write_instr(0, enc_s(12'd1, 5'd6, 5'd0, 3'b001));
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        wait_for_reg(5'd10, 64'd7, 220,
                     "misaligned-SH handler completion");
        check64(dut.u_csrfile.mcause_out, CAUSE_STORE_MISALIGNED,
                "misaligned SH cause");
        check64(dut.u_dcache_backing_memory.memory[0], 64'h0123_4567_89ab_cdef,
                "misaligned SH does not change memory");
        check_reg(5'd2, 64'd0, "misaligned SH flushes younger instruction");

        start_phase("misaligned JALR target traps without writing rd");
        dut.u_register.registers[5] = 64'h7788;
        dut.u_register.registers[6] = 64'h2;
        write_instr(0, enc_i(12'd0, 5'd6, 3'b000, 5'd5, 7'b1100111));
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        wait_for_reg(5'd10, 64'd7, 220,
                     "misaligned-JALR handler completion");
        check64(dut.u_csrfile.mcause_out, CAUSE_INSTRUCTION_MISALIGNED,
                "misaligned JALR target cause");
        check_reg(5'd5, 64'h7788, "misaligned JALR does not write link register");
        check_reg(5'd2, 64'd0, "misaligned JALR flushes younger instruction");
        check_reg(5'd10, 64'd7, "mtvec handler executes after misaligned JALR");

        start_phase("misaligned JAL target traps without writing link register");
        dut.u_register.registers[5] = 64'h8899;
        // JAL x5, +2 targets address 0x2, which is invalid when IALIGN is 32.
        write_instr(0, enc_j(21'd2, 5'd5));
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        wait_for_reg(5'd10, 64'd7, 220,
                     "misaligned-JAL handler completion");
        check64(dut.u_csrfile.mepc_out, 64'h0,
                "misaligned JAL stores its own PC");
        check64(dut.u_csrfile.mcause_out, CAUSE_INSTRUCTION_MISALIGNED,
                "misaligned JAL target cause");
        check_reg(5'd5, 64'h8899, "misaligned JAL does not write link register");
        check_reg(5'd2, 64'd0, "misaligned JAL flushes younger instruction");
        check_reg(5'd10, 64'd7, "mtvec handler executes after misaligned JAL");

        start_phase("taken branch with misaligned target enters trap");
        dut.u_register.registers[6] = 64'd9;
        // BEQ x6, x6, +2 is taken and targets the misaligned address 0x2.
        write_instr(0, enc_b(13'd2, 5'd6, 5'd6, 3'b000));
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        wait_for_reg(5'd10, 64'd7, 220,
                     "misaligned-branch handler completion");
        check64(dut.u_csrfile.mepc_out, 64'h0,
                "misaligned taken branch stores its own PC");
        check64(dut.u_csrfile.mcause_out, CAUSE_INSTRUCTION_MISALIGNED,
                "misaligned taken branch target cause");
        check_reg(5'd2, 64'd0, "misaligned taken branch flushes younger instruction");
        check_reg(5'd10, 64'd7,
                  "mtvec handler executes after misaligned taken branch");

        start_phase("untaken branch ignores its unused misaligned target");
        dut.u_register.registers[6] = 64'd9;
        // BNE x6, x6, +2 is not taken, so address 0x2 is never used as a PC.
        write_instr(0, enc_b(13'd2, 5'd6, 5'd6, 3'b001));
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        wait_for_reg(5'd2, 64'd1, 180,
                     "untaken-branch fall-through completion");
        check64(dut.u_csrfile.mcause_out, 64'd0,
                "untaken branch does not raise instruction-address exception");
        check_reg(5'd2, 64'd1, "untaken branch continues at the sequential PC");
        check_reg(5'd10, 64'd0, "untaken branch does not enter mtvec handler");

        start_phase("MRET restores interrupt state, redirects to mepc, and flushes younger instructions");
        dut.u_csrfile.mepc_out = 64'h40;
        dut.u_csrfile.mstatus = 64'h80;
        write_instr(0, MRET);
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        write_instr(2, enc_i(12'd1, 5'd0, 3'b000, 5'd3, 7'b0010011));
        write_instr(16, enc_i(12'd9, 5'd0, 3'b000, 5'd8, 7'b0010011));
        wait_for_reg(5'd8, 64'd9, 220, "MRET target completion");
        check_reg(5'd2, 64'd0, "MRET flushes first younger instruction");
        check_reg(5'd3, 64'd0, "MRET flushes second younger instruction");
        check_reg(5'd8, 64'd9, "MRET resumes execution at mepc");
        check64(dut.u_csrfile.mstatus, 64'h88, "MRET restores MIE and sets MPIE");

        start_phase("pending external interrupt is ignored while MIE is zero");
        external_interrupt_pending = 1'b1;
        write_instr(0, enc_i(12'd5, 5'd0, 3'b000, 5'd1, 7'b0010011));
        wait_for_reg(5'd1, 64'd5, 180,
                     "disabled-interrupt instruction completion");
        check_reg(5'd1, 64'd5, "disabled external interrupt does not block normal instruction");
        check_reg(5'd10, 64'd0, "disabled external interrupt does not enter mtvec handler");
        check64(dut.u_csrfile.mcause_out, 64'd0, "disabled external interrupt does not change mcause");

        start_phase("enabled external interrupt traps before current MEM instruction commits");
        external_interrupt_pending = 1'b1;
        // CSRRWI x0, mstatus, 8 enables MIE.  The following instruction is
        // interrupted before it commits, so mepc points to PC 4.
        write_instr(0, enc_csr(12'h300, 5'd8, 3'b101, 5'd0));
        write_instr(1, enc_i(12'd5, 5'd0, 3'b000, 5'd1, 7'b0010011));
        write_instr(2, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        wait_for_reg(5'd10, 64'd7, 240,
                     "external-interrupt handler completion");
        check64(dut.u_csrfile.mepc_out, 64'h4, "external interrupt stores interrupted PC");
        check64(dut.u_csrfile.mcause_out, CAUSE_EXTERNAL_INTERRUPT, "external interrupt cause");
        check_reg(5'd1, 64'd0, "interrupted MEM instruction does not commit");
        check_reg(5'd2, 64'd0, "younger instruction is flushed by external interrupt");
        check_reg(5'd10, 64'd7, "mtvec handler executes after external interrupt");
        check64(dut.u_csrfile.mstatus, 64'h80, "external interrupt saves MIE in MPIE and clears MIE");

        $display("\nPASS: trap entry, misaligned control-transfer paths, untaken-branch gating, external interrupt gating, precise side-effect suppression, flushing, and MRET return passed.");
        $finish;
    end

    initial begin
        #8000;
        $fatal(1, "Timeout: trap pipeline testbench did not finish");
    end

endmodule
