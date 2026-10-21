`timescale 1ns/1ps

module CPU_tb;
    reg clk;
    reg reset;
    integer i;

    CPU dut (
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    function [31:0] enc_r;
        input [6:0] funct7;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            enc_r = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
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

    function [31:0] enc_u;
        input [19:0] imm;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            enc_u = {imm, rd, opcode};
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

    task start_phase;
        input [255:0] phase_name;
        begin
            reset = 1'b1;
            @(posedge clk);
            #1;
            if (dut.current_pc !== 64'd0)
                $fatal(1, "%0s: reset did not clear PC", phase_name);

            @(negedge clk);
            reset = 1'b0;

            for (i = 0; i < 32; i = i + 1)
                dut.u_register.registers[i] = 64'd0;
            for (i = 0; i < 64; i = i + 1)
                dut.u_datamemory.data_mem[i] = 64'd0;
            for (i = 0; i < 256; i = i + 1)
                dut.u_ir.rom[i] = 32'h00000033;

            $display("\n[PHASE] %0s", phase_name);
        end
    endtask

    task step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task check_reg;
        input [4:0] index;
        input [63:0] expected;
        input [255:0] description;
        begin
            if (dut.u_register.registers[index] !== expected)
                $fatal(1, "%0s: x%0d = %h, expected %h",
                       description, index,
                       dut.u_register.registers[index], expected);
        end
    endtask

    task check_pc;
        input [63:0] expected;
        input [255:0] description;
        begin
            if (dut.current_pc !== expected)
                $fatal(1, "%0s: PC = %0d, expected %0d",
                       description, dut.current_pc, expected);
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;

        // Phase 1: eight R-type instructions.
        start_phase("R-type ALU instructions");
        dut.u_register.registers[1] = 64'd12;
        dut.u_register.registers[2] = 64'd5;
        dut.u_register.registers[3] = 64'h000000000000f0f5;
        dut.u_register.registers[4] = 64'h0000000000000ff0;
        dut.u_register.registers[5] = 64'hffffffffffffffff;
        dut.u_register.registers[6] = 64'd1;
        dut.u_register.registers[7] = 64'd13;
        dut.u_register.registers[8] = 64'd2;
        dut.u_register.registers[9] = 64'h8000000000000000;

        dut.u_ir.rom[0] = enc_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd10); // add
        dut.u_ir.rom[1] = enc_r(7'b0100000, 5'd2, 5'd1, 3'b000, 5'd11); // sub
        dut.u_ir.rom[2] = enc_r(7'b0000000, 5'd4, 5'd3, 3'b111, 5'd12); // and
        dut.u_ir.rom[3] = enc_r(7'b0000000, 5'd4, 5'd3, 3'b110, 5'd13); // or
        dut.u_ir.rom[4] = enc_r(7'b0000000, 5'd4, 5'd3, 3'b100, 5'd14); // xor
        dut.u_ir.rom[5] = enc_r(7'b0000000, 5'd6, 5'd5, 3'b010, 5'd15); // slt
        dut.u_ir.rom[6] = enc_r(7'b0000000, 5'd8, 5'd7, 3'b001, 5'd16); // sll
        dut.u_ir.rom[7] = enc_r(7'b0000000, 5'd8, 5'd9, 3'b101, 5'd17); // srl

        repeat (8) step;
        check_reg(5'd10, 64'd17, "add");
        check_reg(5'd11, 64'd7, "sub");
        check_reg(5'd12, 64'h00000000000000f0, "and");
        check_reg(5'd13, 64'h000000000000fff5, "or");
        check_reg(5'd14, 64'h000000000000ff05, "xor");
        check_reg(5'd15, 64'd1, "signed slt");
        check_reg(5'd16, 64'd52, "sll");
        check_reg(5'd17, 64'h2000000000000000, "srl");

        // Phase 2: four I-type ALU instructions.
        start_phase("I-type ALU instructions");
        dut.u_register.registers[1] = 64'd10;
        dut.u_register.registers[2] = 64'h000000000000f0f5;
        dut.u_register.registers[3] = 64'h0000000000000f0f;

        dut.u_ir.rom[0] = enc_i(12'hffb, 5'd1, 3'b000, 5'd10, 7'b0010011); // addi -5
        dut.u_ir.rom[1] = enc_i(12'h0ff, 5'd2, 3'b111, 5'd11, 7'b0010011); // andi
        dut.u_ir.rom[2] = enc_i(12'h00a, 5'd2, 3'b110, 5'd12, 7'b0010011); // ori
        dut.u_ir.rom[3] = enc_i(12'hfff, 5'd3, 3'b100, 5'd13, 7'b0010011); // xori -1

        repeat (4) step;
        check_reg(5'd10, 64'd5, "addi");
        check_reg(5'd11, 64'h00000000000000f5, "andi");
        check_reg(5'd12, 64'h000000000000f0ff, "ori");
        check_reg(5'd13, 64'hfffffffffffff0f0, "xori");

        // Phase 3: load and store.
        start_phase("load and store");
        dut.u_register.registers[1] = 64'd8;
        dut.u_register.registers[2] = 64'h1122334455667788;
        dut.u_datamemory.data_mem[1] = 64'haabbccddeeff0011;

        dut.u_ir.rom[0] = enc_i(12'd0, 5'd1, 3'b011, 5'd10, 7'b0000011); // ld x10,0(x1)
        dut.u_ir.rom[1] = enc_s(12'd8, 5'd2, 5'd1, 3'b011);              // sd x2,8(x1)

        repeat (2) step;
        check_reg(5'd10, 64'haabbccddeeff0011, "ld");
        if (dut.u_datamemory.data_mem[2] !== 64'h1122334455667788)
            $fatal(1, "sd: memory[2] = %h, expected 1122334455667788",
                   dut.u_datamemory.data_mem[2]);

        // Phase 4: BEQ/BNE, with both taken and not-taken cases.
        start_phase("conditional branches");
        dut.u_register.registers[1] = 64'd7;
        dut.u_register.registers[2] = 64'd7;
        dut.u_register.registers[3] = 64'd9;

        dut.u_ir.rom[0] = enc_b(13'd8, 5'd2, 5'd1, 3'b000); // beq taken -> PC 8
        dut.u_ir.rom[1] = enc_i(12'd1, 5'd0, 3'b000, 5'd10, 7'b0010011); // skipped
        dut.u_ir.rom[2] = enc_b(13'd8, 5'd3, 5'd1, 3'b001); // bne taken -> PC 16
        dut.u_ir.rom[3] = enc_i(12'd1, 5'd0, 3'b000, 5'd11, 7'b0010011); // skipped
        dut.u_ir.rom[4] = enc_b(13'd8, 5'd3, 5'd1, 3'b000); // beq not taken
        dut.u_ir.rom[5] = enc_b(13'd8, 5'd2, 5'd1, 3'b001); // bne not taken
        dut.u_ir.rom[6] = enc_i(12'd12, 5'd0, 3'b000, 5'd12, 7'b0010011);

        step;
        check_pc(64'd8, "taken beq");
        step;
        check_pc(64'd16, "taken bne");
        step;
        check_pc(64'd20, "not-taken beq");
        step;
        check_pc(64'd24, "not-taken bne");
        step;
        check_reg(5'd10, 64'd0, "beq skipped instruction");
        check_reg(5'd11, 64'd0, "bne skipped instruction");
        check_reg(5'd12, 64'd12, "branch fall-through");

        // Phase 5: U-type instructions, including a negative U-immediate.
        start_phase("LUI and AUIPC");
        dut.u_ir.rom[0] = enc_u(20'h12345, 5'd10, 7'b0110111); // lui
        dut.u_ir.rom[1] = enc_u(20'h00002, 5'd11, 7'b0010111); // auipc at PC=4
        dut.u_ir.rom[2] = enc_u(20'h80000, 5'd12, 7'b0110111); // sign-extended lui
        dut.u_ir.rom[3] = enc_u(20'hfffff, 5'd13, 7'b0010111); // auipc at PC=12

        repeat (4) step;
        check_reg(5'd10, 64'h0000000012345000, "lui");
        check_reg(5'd11, 64'h0000000000002004, "auipc");
        check_reg(5'd12, 64'hffffffff80000000, "negative lui");
        check_reg(5'd13, 64'hfffffffffffff00c, "negative auipc");

        // Phase 6: JAL and JALR. This also checks link addresses,
        // negative offsets, and JALR clearing target bit 0.
        start_phase("JAL and JALR");
        dut.u_register.registers[5] = 64'd8;
        dut.u_register.registers[6] = 64'd12;

        dut.u_ir.rom[0] = enc_j(21'd8, 5'd1); // jal x1,+8 -> PC 8, x1=4
        dut.u_ir.rom[1] = enc_i(12'hff9, 5'd6, 3'b000, 5'd4, 7'b1100111);
                                                    // jalr x4,-7(x6): 12-7=5 -> PC 4
        dut.u_ir.rom[2] = enc_i(12'd5, 5'd5, 3'b000, 5'd2, 7'b1100111);
                                                    // jalr x2,5(x5): 8+5=13 -> PC 12
        dut.u_ir.rom[3] = enc_j(21'h1ffff8, 5'd3); // jal x3,-8 -> PC 4

        step;
        check_pc(64'd8, "forward jal target");
        check_reg(5'd1, 64'd4, "jal link");
        step;
        check_pc(64'd12, "jalr target with bit 0 cleared");
        check_reg(5'd2, 64'd12, "jalr link at PC 8");
        step;
        check_pc(64'd4, "backward jal target");
        check_reg(5'd3, 64'd16, "backward jal link");
        step;
        check_pc(64'd4, "negative jalr target with bit 0 cleared");
        check_reg(5'd4, 64'd8, "jalr link at PC 4");

        $display("\nPASS: all 20 supported instructions passed.");
        $finish;
    end

    initial begin
        #1500;
        $fatal(1, "Timeout: CPU testbench did not finish");
    end
endmodule
