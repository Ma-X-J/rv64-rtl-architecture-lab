`timescale 1ns/1ps

module SLLI_tb;
    reg  [31:0] instruction;
    reg  [63:0] operand_a;
    wire [1:0]  alu_op;
    wire        alu_src;
    wire        regwrite;
    wire        use_rs1;
    wire        use_rs2;
    wire        illegal_instruction;
    wire [63:0] immediate;
    wire [4:0]  alu_control;
    wire [63:0] alu_result;
    wire        zero;

    Control u_control (
        .instruction(instruction),
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
        .B(immediate),
        .ALUControl(alu_control),
        .ALUResult(alu_result),
        .Zero(zero)
    );

    function [31:0] enc_slli;
        input [5:0] shamt;
        input [4:0] rs1;
        input [4:0] rd;
        begin
            enc_slli = {6'b000000, shamt, rs1, 3'b001,
                        rd, 7'b0010011};
        end
    endfunction

    initial begin
        instruction = enc_slli(6'd2, 5'd11, 5'd11);
        operand_a = 64'd8;
        #1;
        if (illegal_instruction !== 1'b0 || regwrite !== 1'b1 ||
            use_rs1 !== 1'b1 || use_rs2 !== 1'b0 ||
            alu_src !== 1'b1 || alu_op !== 2'b10 ||
            alu_control !== 4'b0101 || immediate !== 64'd2 ||
            alu_result !== 64'd32)
            $fatal(1, "SLLI by 2 decode or execution failed");

        instruction = enc_slli(6'd63, 5'd11, 5'd11);
        operand_a = 64'd1;
        #1;
        if (immediate !== 64'd63 ||
            alu_result !== 64'h8000_0000_0000_0000)
            $fatal(1, "RV64 SLLI did not use the full 6-bit shamt");

        instruction = {6'b000001, 6'd2, 5'd11, 3'b001,
                       5'd11, 7'b0010011};
        #1;
        if (illegal_instruction !== 1'b1 || regwrite !== 1'b0 ||
            alu_control !== 5'h1f)
            $fatal(1, "illegal SLLI funct6 encoding was accepted");

        $display("PASS: RV64 SLLI decode, 6-bit shamt, and execution passed.");
        $finish;
    end
endmodule
