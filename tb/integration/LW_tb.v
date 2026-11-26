`timescale 1ns/1ps

module LW_tb;
    reg clk;
    reg reset;
    integer i;
    integer cycles;
    reg halt_seen;

    localparam [31:0] NOP = 32'h00000013;
    localparam [63:0] HALT_PC = 64'h0000_0000_0000_000c;

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
                dut.u_icache_backing_memory.memory[word_index][31:0] = instruction;
            else
                dut.u_icache_backing_memory.memory[word_index][63:32] = instruction;
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        cycles = 0;
        halt_seen = 1'b0;

        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'd0;
        for (i = 0; i < 256; i = i + 1) begin
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            dut.u_dcache_backing_memory.memory[i] = 64'd0;
        end

        // The backing memory is little-endian at 32-bit granularity:
        // address 0 selects the low half and address 4 the high half.
        dut.u_dcache_backing_memory.memory[0] =
            {32'h7fff_ffff, 32'h8000_0001};
        dut.u_dcache_backing_memory.memory[1] =
            {32'h1234_5678, 32'hffff_ffff};

        write_instr(0, enc_i(12'd0, 5'd0, 3'b010, 5'd5, 7'b0000011));
        write_instr(1, enc_i(12'd4, 5'd0, 3'b010, 5'd6, 7'b0000011));
        write_instr(2, enc_i(12'd8, 5'd0, 3'b010, 5'd7, 7'b0000011));
        write_instr(3, enc_j(21'd0, 5'd0));

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        while (!halt_seen && cycles < 1000) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
            if (dut.valid_mem === 1'b1 &&
                dut.current_pc_mem === HALT_PC &&
                dut.Jump_mem === 1'b1)
                halt_seen = 1'b1;
        end

        if (!halt_seen)
            $fatal(1, "LW program did not reach halt");

        repeat (2) begin
            @(posedge clk);
            #1;
        end

        if (dut.u_register.registers[5] !== 64'hffff_ffff_8000_0001)
            $fatal(1, "low-half negative LW=%h expected ffffffff80000001",
                   dut.u_register.registers[5]);
        if (dut.u_register.registers[6] !== 64'h0000_0000_7fff_ffff)
            $fatal(1, "high-half positive LW=%h expected 000000007fffffff",
                   dut.u_register.registers[6]);
        if (dut.u_register.registers[7] !== 64'hffff_ffff_ffff_ffff)
            $fatal(1, "second-word negative LW=%h expected ffffffffffffffff",
                   dut.u_register.registers[7]);

        $display("PASS: LW selected both 32-bit halves and sign-extended them to RV64.");
        $finish;
    end
endmodule
