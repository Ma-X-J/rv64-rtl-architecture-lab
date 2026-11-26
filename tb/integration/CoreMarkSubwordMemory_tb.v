`timescale 1ns/1ps

module CoreMarkSubwordMemory_tb;
    reg clk;
    reg reset;
    integer i;
    integer cycles;
    reg halt_seen;

    localparam [31:0] NOP = 32'h00000013;
    localparam [63:0] HALT_PC = 64'd36;

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
        halt_seen = 1'b0;

        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'd0;
        for (i = 0; i < 256; i = i + 1) begin
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            dut.u_dcache_backing_memory.memory[i] = 64'd0;
        end

        // Byte layout at address 0 is 11 22 33 44 55 66 77 88.
        dut.u_dcache_backing_memory.memory[0] = 64'h8877_6655_4433_2211;
        dut.u_dcache_backing_memory.memory[1] = 64'h1122_3344_5566_7788;

        write_instr(0, enc_i(12'd0, 5'd0, 3'b100, 5'd5, 7'b0000011)); // LBU
        write_instr(1, enc_i(12'd7, 5'd0, 3'b000, 5'd6, 7'b0000011)); // LB
        write_instr(2, enc_i(12'd2, 5'd0, 3'b101, 5'd7, 7'b0000011)); // LHU
        write_instr(3, enc_i(12'd6, 5'd0, 3'b001, 5'd8, 7'b0000011)); // LH
        write_instr(4, enc_i(12'd4, 5'd0, 3'b110, 5'd9, 7'b0000011)); // LWU
        write_instr(5, enc_s(12'd9, 5'd5, 5'd0, 3'b000)); // SB
        write_instr(6, enc_s(12'd10, 5'd7, 5'd0, 3'b001)); // SH
        write_instr(7, enc_s(12'd12, 5'd9, 5'd0, 3'b010)); // SW
        write_instr(8, enc_i(12'd8, 5'd0, 3'b011, 5'd10, 7'b0000011)); // LD
        write_instr(9, enc_j(21'd0, 5'd0));

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        while (cycles < 2500 && !halt_seen) begin
            @(negedge clk);
            cycles = cycles + 1;
            if (dut.current_pc_if == HALT_PC &&
                dut.u_register.registers[10] ==
                    64'h8877_6655_4433_1188)
                halt_seen = 1'b1;
        end

        if (!halt_seen)
            $fatal(1, "timed out waiting for subword memory program");
        if (dut.u_register.registers[5] !== 64'h11)
            $fatal(1, "LBU failed: x5=%h", dut.u_register.registers[5]);
        if (dut.u_register.registers[6] !== 64'hffff_ffff_ffff_ff88)
            $fatal(1, "LB failed: x6=%h", dut.u_register.registers[6]);
        if (dut.u_register.registers[7] !== 64'h4433)
            $fatal(1, "LHU failed: x7=%h", dut.u_register.registers[7]);
        if (dut.u_register.registers[8] !== 64'hffff_ffff_ffff_8877)
            $fatal(1, "LH failed: x8=%h", dut.u_register.registers[8]);
        if (dut.u_register.registers[9] !== 64'h0000_0000_8877_6655)
            $fatal(1, "LWU failed: x9=%h", dut.u_register.registers[9]);
        if (dut.u_dcache_backing_memory.memory[1] !==
            64'h8877_6655_4433_1188)
            $fatal(1, "byte-strobe stores corrupted memory: %h",
                   dut.u_dcache_backing_memory.memory[1]);

        $display("PASS: LB/LBU/LH/LHU/LWU and SB/SH/SW preserved byte lanes.");
        $finish;
    end
endmodule
