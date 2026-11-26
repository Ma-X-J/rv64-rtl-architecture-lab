`timescale 1ns/1ps

module ADDIW_BLT_tb;
    reg  [31:0] instruction;
    reg  [63:0] operand_a;
    reg  [63:0] operand_b;
    wire [1:0]  alu_op;
    wire        alu_src;
    wire        branch;
    wire        regwrite;
    wire        use_rs1;
    wire        use_rs2;
    wire        illegal_instruction;
    wire [63:0] immediate;
wire [4:0]  alu_control;
    wire [63:0] alu_input_b = alu_src ? immediate : operand_b;
    wire [63:0] alu_result;
    wire        zero;

    Control u_control (
        .instruction(instruction),
        .Branch(branch),
        .ALUOp(alu_op),
        .ALUSrc(alu_src),
        .Regwrite(regwrite),
        .UseRs1(use_rs1),
        .UseRs2(use_rs2),
        .IllegalInstruction(illegal_instruction)
    );

    Immgen u_immgen (
        .instruction(instruction),
        .instruction64(immediate)
    );

    ALUControl u_alu_control (
        .ALUOp(alu_op),
        .instruction(instruction),
        .ALUControl(alu_control)
    );

    ALU u_alu (
        .A(operand_a),
        .B(alu_input_b),
        .ALUControl(alu_control),
        .ALUResult(alu_result),
        .Zero(zero)
    );

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

    task check_result;
        input [63:0] expected;
        input [255:0] description;
        begin
            #1;
            if (alu_result !== expected)
                $fatal(1, "%0s: result=%h expected=%h",
                       description, alu_result, expected);
        end
    endtask

    initial begin
        operand_b = 64'd0;

        instruction = enc_i(12'd1, 5'd10, 3'b000,
                            5'd10, 7'b0011011); // addiw a0, a0, 1
        operand_a = 64'd41;
        #1;
        if (illegal_instruction !== 1'b0 || regwrite !== 1'b1 ||
            use_rs1 !== 1'b1 || use_rs2 !== 1'b0 ||
            alu_src !== 1'b1 || alu_control !== 4'b1000 ||
            immediate !== 64'd1)
            $fatal(1, "ADDIW decode or immediate generation failed");
        check_result(64'd42, "positive ADDIW result");

        operand_a = 64'h0000_0000_7fff_ffff;
        check_result(64'hffff_ffff_8000_0000,
                     "ADDIW sign extension after overflow");

        instruction = enc_i(12'hfff, 5'd10, 3'b000,
                            5'd10, 7'b0011011); // addiw a0, a0, -1
        operand_a = 64'd0;
        #1;
        if (immediate !== 64'hffff_ffff_ffff_ffff)
            $fatal(1, "ADDIW negative immediate was not sign-extended");
        check_result(64'hffff_ffff_ffff_ffff,
                     "negative ADDIW result");

        instruction = enc_b(13'd8, 5'd11, 5'd10,
                            3'b100); // blt a0, a1, +8
        operand_a = 64'hffff_ffff_ffff_ffff;
        operand_b = 64'd1;
        #1;
        if (illegal_instruction !== 1'b0 || branch !== 1'b1 ||
            regwrite !== 1'b0 || use_rs1 !== 1'b1 || use_rs2 !== 1'b1 ||
            alu_src !== 1'b0 || alu_control !== 4'b0100 ||
            alu_result !== 64'd1 || zero !== 1'b0)
            $fatal(1, "taken signed BLT decode or comparison failed");

        operand_a = 64'd5;
        operand_b = 64'd2;
        #1;
        if (alu_result !== 64'd0 || zero !== 1'b1)
            $fatal(1, "not-taken signed BLT comparison failed");

        instruction = enc_b(13'd8, 5'd11, 5'd10,
                            3'b101); // bge a0, a1, +8
        operand_a = 64'd5;
        operand_b = 64'd2;
        #1;
        if (illegal_instruction !== 1'b0 || branch !== 1'b1 ||
            regwrite !== 1'b0 || use_rs1 !== 1'b1 || use_rs2 !== 1'b1 ||
            alu_src !== 1'b0 || alu_control !== 4'b1001 ||
            alu_result !== 64'd1 || zero !== 1'b0)
            $fatal(1, "taken signed BGE decode or comparison failed");

        operand_a = 64'd2;
        operand_b = 64'd2;
        #1;
        if (alu_result !== 64'd1 || zero !== 1'b0)
            $fatal(1, "equal operands did not satisfy BGE");

        operand_a = 64'hffff_ffff_ffff_ffff;
        operand_b = 64'd1;
        #1;
        if (alu_result !== 64'd0 || zero !== 1'b1)
            $fatal(1, "not-taken signed BGE comparison failed");

        $display("PASS: ADDIW plus signed BLT/BGE decode and comparison passed.");
        $finish;
    end
endmodule
