`timescale 1ns/1ps

module CoreMarkALUPipeline_tb;
    reg clk;
    reg reset;
    integer i;
    integer cycles;
    reg done;

    localparam [31:0] NOP = 32'h00000013;
    localparam [63:0] HALT_PC = 64'd64;

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

    function [31:0] enc_r;
        input [6:0] funct7;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            enc_r = {funct7, rs2, rs1, funct3, rd, opcode};
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

    task check_reg;
        input [4:0] index;
        input [63:0] expected;
        begin
            if (dut.u_register.registers[index] !== expected)
                $fatal(1, "x%0d=%h expected=%h", index,
                       dut.u_register.registers[index], expected);
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        cycles = 0;
        done = 1'b0;

        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'd0;
        for (i = 0; i < 256; i = i + 1) begin
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            dut.u_dcache_backing_memory.memory[i] = 64'd0;
        end

        write_instr(0, enc_i(12'hfff, 5'd0, 3'b000, 5'd1, 7'b0010011));
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd2, 7'b0010011));
        write_instr(2, enc_b(13'd8, 5'd1, 5'd2, 3'b110)); // BLTU
        write_instr(3, enc_i(12'd99, 5'd0, 3'b000, 5'd3, 7'b0010011));
        write_instr(4, enc_b(13'd8, 5'd2, 5'd1, 3'b111)); // BGEU
        write_instr(5, enc_i(12'd99, 5'd0, 3'b000, 5'd4, 7'b0010011));
        write_instr(6, enc_r(7'b0000001, 5'd2, 5'd1, 3'b000, 5'd5,
                             7'b0110011)); // MUL
        write_instr(7, enc_r(7'b0000001, 5'd2, 5'd1, 3'b011, 5'd6,
                             7'b0110011)); // MULHU
        write_instr(8, enc_r(7'b0000001, 5'd2, 5'd1, 3'b000, 5'd7,
                             7'b0111011)); // MULW
        write_instr(9, enc_r(7'b0000001, 5'd2, 5'd1, 3'b101, 5'd8,
                             7'b0111011)); // DIVUW
        write_instr(10, enc_i({6'b010000, 6'd4}, 5'd1, 3'b101,
                              5'd9, 7'b0010011)); // SRAI
        write_instr(11, enc_i({6'b000000, 6'd4}, 5'd1, 3'b101,
                              5'd10, 7'b0010011)); // SRLI
        write_instr(12, enc_i({7'b0000000, 5'd31}, 5'd2, 3'b001,
                              5'd11, 7'b0011011)); // SLLIW
        write_instr(13, enc_i({7'b0000000, 5'd31}, 5'd11, 3'b101,
                              5'd12, 7'b0011011)); // SRLIW
        write_instr(14, enc_i({7'b0100000, 5'd31}, 5'd11, 3'b101,
                              5'd13, 7'b0011011)); // SRAIW
        write_instr(15, enc_r(7'b0100000, 5'd1, 5'd2, 3'b000, 5'd14,
                              7'b0111011)); // SUBW: 1 - (-1) = 2
        write_instr(16, enc_j(21'd0, 5'd0));

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        while (cycles < 2000 && !done) begin
            @(negedge clk);
            cycles = cycles + 1;
            if (dut.current_pc_if == HALT_PC &&
                dut.u_register.registers[14] == 64'd2)
                done = 1'b1;
        end
        if (!done)
            $fatal(1, "timed out waiting for CoreMark ALU pipeline program");

        check_reg(5'd3, 64'd0);
        check_reg(5'd4, 64'd0);
        check_reg(5'd5, 64'hffff_ffff_ffff_ffff);
        check_reg(5'd6, 64'd0);
        check_reg(5'd7, 64'hffff_ffff_ffff_ffff);
        check_reg(5'd8, 64'hffff_ffff_ffff_ffff);
        check_reg(5'd9, 64'hffff_ffff_ffff_ffff);
        check_reg(5'd10, 64'h0fff_ffff_ffff_ffff);
        check_reg(5'd11, 64'hffff_ffff_8000_0000);
        check_reg(5'd12, 64'd1);
        check_reg(5'd13, 64'hffff_ffff_ffff_ffff);
        check_reg(5'd14, 64'd2);

        $display("PASS: unsigned branches, M operations and shifts ran through pipeline.");
        $finish;
    end
endmodule
