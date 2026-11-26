`timescale 1ns/1ps

module SUM2W_DECODE_ALU_tb;
    reg [31:0] instruction;
    wire Branch;
    wire MemRead;
    wire [1:0] MemtoReg;
    wire [1:0] ALUOp;
    wire MemWrite;
    wire ALUSrc;
    wire Regwrite;
    wire ALUASrc;
    wire Jump;
    wire JumpReg;
    wire UseRs1;
    wire UseRs2;
    wire IllegalInstruction;
    wire Ecall;
    wire Mret;
    wire CSRWrite;
    wire [1:0] CSROp;
    wire CSRUseImm;
    wire CSRtoReg;
    wire [4:0] alu_control;

    reg [63:0] alu_a;
    reg [63:0] alu_b;
    wire [63:0] alu_result;
    wire alu_zero;

    Control control_dut (
        .instruction(instruction),
        .Branch(Branch),
        .MemRead(MemRead),
        .MemtoReg(MemtoReg),
        .ALUOp(ALUOp),
        .MemWrite(MemWrite),
        .ALUSrc(ALUSrc),
        .Regwrite(Regwrite),
        .ALUASrc(ALUASrc),
        .Jump(Jump),
        .JumpReg(JumpReg),
        .UseRs1(UseRs1),
        .UseRs2(UseRs2),
        .IllegalInstruction(IllegalInstruction),
        .Ecall(Ecall),
        .Mret(Mret),
        .CSRWrite(CSRWrite),
        .CSROp(CSROp),
        .CSRUseImm(CSRUseImm),
        .CSRtoReg(CSRtoReg)
    );

    ALUControl alu_control_dut (
        .ALUOp(ALUOp),
        .instruction(instruction),
        .ALUControl(alu_control)
    );

    ALU alu_dut (
        .A(alu_a),
        .B(alu_b),
        .ALUControl(alu_control),
        .ALUResult(alu_result),
        .Zero(alu_zero)
    );

    task check_sum2w;
        input [63:0] accumulator;
        input [63:0] packed_values;
        input [63:0] expected;
        begin
            alu_a = accumulator;
            alu_b = packed_values;
            #1;
            if (alu_result !== expected)
                $fatal(1,
                       "SUM2W A=%h B=%h produced %h, expected %h",
                       accumulator, packed_values, alu_result, expected);
        end
    endtask

    initial begin
        // sum2w a0, a0, a1 = 0x00b5050b
        instruction = 32'h00b5050b;
        alu_a = 64'd0;
        alu_b = 64'd0;
        #1;

        if (IllegalInstruction !== 1'b0 || Regwrite !== 1'b1 ||
            UseRs1 !== 1'b1 || UseRs2 !== 1'b1 || ALUOp !== 2'b10 ||
            ALUSrc !== 1'b0 || MemRead !== 1'b0 || MemWrite !== 1'b0 ||
            Branch !== 1'b0 || Jump !== 1'b0 || JumpReg !== 1'b0)
            $fatal(1, "valid SUM2W control decode is incorrect");

        if (alu_control !== 4'b1010)
            $fatal(1, "SUM2W ALUControl=%b, expected 1010", alu_control);

        check_sum2w(64'd10, 64'h0000000c_00000014, 64'd42);
        check_sum2w(64'd10, 64'hfffffffe_fffffffd, 64'd5);
        check_sum2w(64'h00000000_7fffffff,
                    64'h00000000_00000001,
                    64'hffffffff_80000000);
        check_sum2w(64'hffffffff_ffffffff,
                    64'h00000000_00000000,
                    64'hffffffff_ffffffff);
        check_sum2w(64'd0,
                    64'h00000001_ffffffff,
                    64'd0);
        if (alu_zero !== 1'b1)
            $fatal(1, "SUM2W Zero flag should be asserted for zero result");

        // Same custom opcode with a different funct3 must remain illegal.
        instruction = 32'h00b5150b;
        #1;
        if (IllegalInstruction !== 1'b1 || Regwrite !== 1'b0 ||
            alu_control !== 5'h1f)
            $fatal(1, "invalid SUM2W funct3 was accepted");

        // Same custom opcode with a different funct7 must remain illegal.
        instruction = 32'h02b5050b;
        #1;
        if (IllegalInstruction !== 1'b1 || Regwrite !== 1'b0 ||
            alu_control !== 5'h1f)
            $fatal(1, "invalid SUM2W funct7 was accepted");

        $display("PASS: SUM2W control, ALUControl, arithmetic and illegal encodings.");
        $finish;
    end
endmodule
