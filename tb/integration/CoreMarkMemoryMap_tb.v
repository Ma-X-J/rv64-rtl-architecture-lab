`timescale 1ns/1ps

module CoreMarkMemoryMap_tb;
    reg clk;
    reg reset;
    integer i;
    integer cycles;
    reg done;

    localparam [31:0] NOP = 32'h0000_0013;
    localparam [63:0] DATA_BASE = 64'h0000_0000_0000_4000;
    localparam [63:0] HALT_PC = 64'd16;

    // Use the production defaults: 16 KiB instruction storage at zero and
    // 8 KiB data storage at 0x4000.
    PIPELINED_CPU dut (
        .reset(reset),
        .clk(clk),
        .external_interrupt_pending(1'b0)
    );

    always #5 clk = ~clk;

    function [31:0] enc_u;
        input [19:0] imm;
        input [4:0] rd;
        begin
            enc_u = {imm, rd, 7'b0110111};
        end
    endfunction

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

    function [31:0] enc_j;
        input [20:0] imm;
        input [4:0] rd;
        begin
            enc_j = {imm[20], imm[10:1], imm[11], imm[19:12],
                     rd, 7'b1101111};
        end
    endfunction

    task write_instr;
        input integer instruction_index;
        input [31:0] instruction;
        integer word_index;
        begin
            word_index = instruction_index >> 1;
            if ((instruction_index & 1) == 0)
                dut.u_icache_backing_memory.memory[word_index][31:0] =
                    instruction;
            else
                dut.u_icache_backing_memory.memory[word_index][63:32] =
                    instruction;
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        cycles = 0;
        done = 1'b0;

        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'd0;
        for (i = 0; i < 64; i = i + 1) begin
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            dut.u_dcache_backing_memory.memory[i] = 64'd0;
        end

        dut.u_dcache_backing_memory.memory[0] = 64'd41;

        write_instr(0, enc_u(20'h00004, 5'd1)); // lui  x1, 0x4
        write_instr(1, enc_i(12'd0, 5'd1, 3'b011, 5'd2,
                            7'b0000011));       // ld   x2, 0(x1)
        write_instr(2, enc_i(12'd1, 5'd2, 3'b000, 5'd3,
                            7'b0010011));       // addi x3, x2, 1
        write_instr(3, enc_s(12'd8, 5'd3, 5'd1, 3'b011)); // sd x3, 8(x1)
        write_instr(4, enc_i(12'd8, 5'd1, 3'b011, 5'd4,
                            7'b0000011));       // ld   x4, 8(x1)
        write_instr(5, enc_j(21'd0, 5'd0));     // halt loop

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        while (cycles < 2500 && !done) begin
            @(negedge clk);
            cycles = cycles + 1;
            if (dut.current_pc_if == HALT_PC + 64'd4 &&
                dut.u_register.registers[4] == 64'd42)
                done = 1'b1;
        end

        if (!done)
            $fatal(1, "default 0x4000 data mapping timed out: x1=%h x4=%h pc=%h",
                   dut.u_register.registers[1],
                   dut.u_register.registers[4], dut.current_pc_if);
        if (dut.u_register.registers[1] !== DATA_BASE)
            $fatal(1, "LUI did not form data base: x1=%h",
                   dut.u_register.registers[1]);
        if (dut.u_register.registers[2] !== 64'd41 ||
            dut.u_register.registers[3] !== 64'd42)
            $fatal(1, "mapped load/add failed: x2=%h x3=%h",
                   dut.u_register.registers[2], dut.u_register.registers[3]);

        $display("PASS: default CPU map executes LD/SD at 0x4000.");
        $finish;
    end
endmodule
