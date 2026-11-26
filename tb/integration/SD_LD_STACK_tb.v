`timescale 1ns/1ps

module SD_LD_STACK_tb;
    reg clk;
    reg reset;
    integer i;
    integer cycles;
    reg halt_seen;

    localparam [31:0] NOP = 32'h00000013; // addi x0, x0, 0
    localparam [63:0] STACK_ADDRESS = 64'h0000_0000_0000_0700;
    localparam [63:0] SAVED_S0_ADDRESS = 64'h0000_0000_0000_0710;
    localparam [63:0] HALT_PC = 64'h0000_0000_0000_001c;

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

        // Reproduce a function prologue: update sp, let the first SD stall the
        // pipeline, then make a second SD consume that updated sp.
        write_instr(0, enc_i(12'h720, 5'd0, 3'b000, 5'd2, 7'b0010011));
        write_instr(1, enc_i(12'd2,   5'd0, 3'b000, 5'd8, 7'b0010011));
        write_instr(2, enc_i(12'hfe0, 5'd2, 3'b000, 5'd2, 7'b0010011)); // sp -= 32
        write_instr(3, enc_s(12'd24,  5'd0, 5'd2, 3'b011));             // first SD stalls
        write_instr(4, enc_s(12'd16,  5'd8, 5'd2, 3'b011));             // save s0
        write_instr(5, enc_i(12'd0,   5'd0, 3'b000, 5'd8, 7'b0010011));
        write_instr(6, enc_i(12'd16,  5'd2, 3'b011, 5'd8, 7'b0000011)); // restore s0
        write_instr(7, enc_j(21'd0,   5'd0));

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
            $fatal(1, "SD/LD stack program did not reach halt");

        // The halt JAL reaches MEM in the same cycle that the preceding LD
        // reaches WB. Register-file writes occur on the following edge.
        @(posedge clk);
        #1;

        if (dut.u_dcache_backing_memory.memory[8'he2] !== 64'd2)
            $fatal(1, "SD wrote %h at the correct stack slot, expected 2",
                   dut.u_dcache_backing_memory.memory[8'he2]);
        if (dut.u_register.registers[8] !== 64'd2)
            $fatal(1, "LD restored s0=%h, expected 2",
                   dut.u_register.registers[8]);
        if (dut.u_register.registers[2] !== STACK_ADDRESS)
            $fatal(1, "sp=%h, expected %h",
                   dut.u_register.registers[2], STACK_ADDRESS);

        if (dut.u_dcache_backing_memory.memory[8'he6] === 64'd2)
            $fatal(1, "SD used stale sp and wrote 2 to old slot %h",
                   SAVED_S0_ADDRESS + 64'h20);

        $display("PASS: CPU SD/LD stack save and restore preserved value 2.");
        $finish;
    end
endmodule
