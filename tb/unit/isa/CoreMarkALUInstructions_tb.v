`timescale 1ns/1ps

module CoreMarkALUInstructions_tb;
    reg  [31:0] instruction;
    reg  [63:0] operand_a;
    reg  [63:0] operand_b;
    wire [1:0]  alu_op;
    wire        branch;
    wire        regwrite;
    wire        illegal_instruction;
    wire [4:0]  alu_control;
    wire [63:0] alu_result;
    wire        zero;

    Control u_control (
        .instruction(instruction),
        .Branch(branch),
        .ALUOp(alu_op),
        .Regwrite(regwrite),
        .IllegalInstruction(illegal_instruction)
    );

    ALUControl u_alu_control (
        .ALUOp(alu_op),
        .instruction(instruction),
        .ALUControl(alu_control)
    );

    ALU u_alu (
        .A(operand_a),
        .B(operand_b),
        .ALUControl(alu_control),
        .ALUResult(alu_result),
        .Zero(zero)
    );

    function [31:0] enc_r;
        input [6:0] funct7;
        input [2:0] funct3;
        input [6:0] opcode;
        begin
            enc_r = {funct7, 5'd2, 5'd1, funct3, 5'd3, opcode};
        end
    endfunction

    function [31:0] enc_i;
        input [11:0] imm;
        input [2:0] funct3;
        input [6:0] opcode;
        begin
            enc_i = {imm, 5'd1, funct3, 5'd3, opcode};
        end
    endfunction

    function [31:0] enc_b;
        input [2:0] funct3;
        begin
            enc_b = {7'b0000000, 5'd2, 5'd1, funct3,
                     5'b00000, 7'b1100011};
        end
    endfunction

    task check_result;
        input [31:0] inst;
        input [63:0] a;
        input [63:0] b;
        input [63:0] expected;
        input [255:0] description;
        begin
            instruction = inst;
            operand_a = a;
            operand_b = b;
            #1;
            if (illegal_instruction !== 1'b0 ||
                alu_control === 5'h1f ||
                alu_result !== expected)
                $fatal(1,
                       "%0s failed: illegal=%b control=%h result=%h expected=%h",
                       description, illegal_instruction, alu_control,
                       alu_result, expected);
        end
    endtask

    initial begin
        check_result(enc_r(7'b0000000, 3'b011, 7'b0110011),
                     64'd1, 64'd2, 64'd1, "SLTU");
        check_result(enc_i(12'hfff, 3'b011, 7'b0010011),
                     64'd1, 64'hffff_ffff_ffff_ffff, 64'd1, "SLTIU");
        check_result(enc_i({6'b000000, 6'd4}, 3'b101, 7'b0010011),
                     64'h8000_0000_0000_0000, 64'd4,
                     64'h0800_0000_0000_0000, "SRLI");
        check_result(enc_i({6'b010000, 6'd4}, 3'b101, 7'b0010011),
                     64'h8000_0000_0000_0000, 64'd4,
                     64'hf800_0000_0000_0000, "SRAI");

        check_result(enc_i({7'b0000000, 5'd31}, 3'b001, 7'b0011011),
                     64'd1, 64'd31,
                     64'hffff_ffff_8000_0000, "SLLIW");
        check_result(enc_i({7'b0000000, 5'd31}, 3'b101, 7'b0011011),
                     64'h0000_0000_8000_0000, 64'd31,
                     64'd1, "SRLIW");
        check_result(enc_i({7'b0100000, 5'd31}, 3'b101, 7'b0011011),
                     64'h0000_0000_8000_0000, 64'd31,
                     64'hffff_ffff_ffff_ffff, "SRAIW");

        check_result(enc_r(7'b0000001, 3'b000, 7'b0110011),
                     64'hffff_ffff_ffff_ffff, 64'd2,
                     64'hffff_ffff_ffff_fffe, "MUL");
        check_result(enc_r(7'b0000001, 3'b011, 7'b0110011),
                     64'hffff_ffff_ffff_ffff, 64'd2,
                     64'd1, "MULHU");
        check_result(enc_r(7'b0000001, 3'b000, 7'b0111011),
                     64'h0000_0000_7fff_ffff, 64'd2,
                     64'hffff_ffff_ffff_fffe, "MULW");
        check_result(enc_r(7'b0000001, 3'b101, 7'b0111011),
                     64'h0000_0000_ffff_ffff, 64'd2,
                     64'h0000_0000_7fff_ffff, "DIVUW");
        check_result(enc_r(7'b0000001, 3'b101, 7'b0111011),
                     64'h1234_5678_9abc_def0, 64'd0,
                     64'hffff_ffff_ffff_ffff, "DIVUW by zero");
        check_result(enc_r(7'b0100000, 3'b000, 7'b0111011),
                     64'h0000_0000_8000_0000, 64'd1,
                     64'h0000_0000_7fff_ffff, "SUBW positive");
        check_result(enc_r(7'b0100000, 3'b000, 7'b0111011),
                     64'd0, 64'd1,
                     64'hffff_ffff_ffff_ffff, "SUBW sign extension");

        check_result(enc_b(3'b110), 64'd1, 64'd2, 64'd1, "BLTU compare");
        if (branch !== 1'b1)
            $fatal(1, "BLTU was not decoded as a branch");
        check_result(enc_b(3'b111), 64'd2, 64'd1, 64'd1, "BGEU compare");
        if (branch !== 1'b1)
            $fatal(1, "BGEU was not decoded as a branch");

        $display("PASS: CoreMark ALU, word-shift, unsigned-branch and M operations.");
        $finish;
    end
endmodule
