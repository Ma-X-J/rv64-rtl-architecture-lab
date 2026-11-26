`timescale 1ns/1ps

module ADDW_tb;
    reg  [31:0] instruction;
    reg  [63:0] operand_a;
    reg  [63:0] operand_b;
    wire [1:0]  alu_op;
    wire        regwrite;
    wire        use_rs1;
    wire        use_rs2;
    wire        illegal_instruction;
    wire [4:0]  alu_control;
    wire [63:0] alu_result;
    wire        zero;

    Control u_control (
        .instruction(instruction),
        .ALUOp(alu_op),
        .Regwrite(regwrite),
        .UseRs1(use_rs1),
        .UseRs2(use_rs2),
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

    function [31:0] enc_op32;
        input [6:0] funct7;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            enc_op32 = {funct7, rs2, rs1, funct3, rd, 7'b0111011};
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
        instruction = enc_op32(7'b0000000, 5'd10, 5'd11,
                               3'b000, 5'd10); // addw a0, a1, a0
        operand_a = 64'd20;
        operand_b = 64'd22;
        #1;

        if (illegal_instruction !== 1'b0 || regwrite !== 1'b1 ||
            use_rs1 !== 1'b1 || use_rs2 !== 1'b1 ||
            alu_op !== 2'b10 || alu_control !== 4'b1000)
            $fatal(1,
                   "ADDW decode failed: illegal=%b regwrite=%b use_rs1=%b use_rs2=%b alu_op=%b alu_control=%b",
                   illegal_instruction, regwrite, use_rs1, use_rs2,
                   alu_op, alu_control);

        check_result(64'h0000_0000_0000_002a,
                     "positive ADDW result");

        operand_a = 64'h0000_0000_7fff_ffff;
        operand_b = 64'h0000_0000_0000_0001;
        check_result(64'hffff_ffff_8000_0000,
                     "ADDW sign extension after positive overflow");

        operand_a = 64'hffff_ffff_ffff_ffff;
        operand_b = 64'h0000_0000_0000_0001;
        check_result(64'h0000_0000_0000_0000,
                     "ADDW discards carry above bit 31");

        operand_a = 64'h1234_5678_0000_0001;
        operand_b = 64'hfedc_ba98_0000_0002;
        check_result(64'h0000_0000_0000_0003,
                     "ADDW ignores source bits 63 through 32");

        instruction = enc_op32(7'b0100000, 5'd10, 5'd11,
                               3'b000, 5'd10); // subw a0, a1, a0
        operand_a = 64'h0000_0000_8000_0000;
        operand_b = 64'h0000_0000_0000_0001;
        #1;
        if (illegal_instruction !== 1'b0 || regwrite !== 1'b1 ||
            use_rs1 !== 1'b1 || use_rs2 !== 1'b1 ||
            alu_control !== 5'h15)
            $fatal(1,
                   "SUBW decode failed: illegal=%b regwrite=%b alu_control=%b",
                   illegal_instruction, regwrite, alu_control);
        check_result(64'h0000_0000_7fff_ffff,
                     "SUBW 32-bit result and sign extension");

        instruction = enc_op32(7'b0000000, 5'd10, 5'd11,
                               3'b100, 5'd10); // XORW remains unsupported
        #1;
        if (illegal_instruction !== 1'b1 || regwrite !== 1'b0 ||
            alu_control !== 5'h1f)
            $fatal(1,
                   "unsupported OP-32 encoding was accepted: illegal=%b regwrite=%b alu_control=%b",
                   illegal_instruction, regwrite, alu_control);

        $display("PASS: ADDW/SUBW decode, wraparound, and sign extension passed.");
        $finish;
    end
endmodule
