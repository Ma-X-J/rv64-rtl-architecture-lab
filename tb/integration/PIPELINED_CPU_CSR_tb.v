`timescale 1ns/1ps

module PIPELINED_CPU_CSR_tb;
    reg clk;
    reg reset;
    integer i;

    localparam [31:0] NOP = 32'h00000033;
    localparam [11:0] CSR_MTVEC  = 12'h305;
    localparam [11:0] CSR_MCAUSE = 12'h342;

    PIPELINED_CPU #(.DCACHE_BACKING_BASE_ADDR(64'h0)) dut (
        .reset(reset),
        .clk(clk),
        .external_interrupt_pending(1'b0)
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

    function [31:0] enc_csr;
        input [11:0] csr;
        input [4:0] rs1_or_zimm;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            enc_csr = {csr, rs1_or_zimm, funct3, rd, 7'b1110011};
        end
    endfunction

    // Store one 32-bit instruction in the 64-bit I-Cache backing memory.
    task write_instr;
        input integer instruction_index;
        input [31:0] instruction;
        integer backend_word_index;
        begin
            backend_word_index = instruction_index >> 1;
            if ((instruction_index & 1) == 0)
                dut.u_icache_backing_memory.memory[backend_word_index][31:0] = instruction;
            else
                dut.u_icache_backing_memory.memory[backend_word_index][63:32] = instruction;
        end
    endtask
    task start_phase;
        input [511:0] phase_name;
        begin
            reset = 1'b1;
            @(posedge clk);
            #1;
            if (dut.current_pc_if !== 64'd0)
                $fatal(1, "%0s: reset did not clear PC", phase_name);

            @(negedge clk);
            reset = 1'b0;

            for (i = 0; i < 32; i = i + 1)
                dut.u_register.registers[i] = 64'd0;
            for (i = 0; i < 256; i = i + 1) begin
                dut.u_dcache_backing_memory.memory[i] = 64'd0;
                dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            end

            $display("\n[PHASE] %0s", phase_name);
        end
    endtask

    task run_cycles;
        input integer count;
        integer cycle;
        begin
            for (cycle = 0; cycle < count; cycle = cycle + 1) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    task wait_for_reg;
        input [4:0] index;
        input [63:0] expected;
        input integer max_cycles;
        input [511:0] description;
        integer waited;
        begin
            waited = 0;
            while ((dut.u_register.registers[index] !== expected) &&
                   (waited < max_cycles)) begin
                @(posedge clk);
                #1;
                waited = waited + 1;
            end
            if (waited >= max_cycles)
                $fatal(1, "%0s: timeout waiting for x%0d=%h (got %h)",
                       description, index, expected,
                       dut.u_register.registers[index]);
        end
    endtask

    task check_reg;
        input [4:0] index;
        input [63:0] expected;
        input [511:0] description;
        begin
            if (dut.u_register.registers[index] !== expected)
                $fatal(1, "%0s: x%0d = %h, expected %h",
                       description, index,
                       dut.u_register.registers[index], expected);
        end
    endtask

    task check64;
        input [63:0] actual;
        input [63:0] expected;
        input [511:0] description;
        begin
            if (actual !== expected)
                $fatal(1, "%0s: got %h, expected %h",
                       description, actual, expected);
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;

        force dut.u_csrfile.trap_enter = 1'b0;
        force dut.u_csrfile.trap_pc = 64'b0;
        force dut.u_csrfile.trap_cause = 64'b0;
        force dut.u_csrfile.mret = 1'b0;

        start_phase("CSRRW writes CSR, returns old value, and forwards rd");
        dut.u_register.registers[6] = 64'h0000_0000_0000_0205;
        write_instr(0, enc_csr(CSR_MTVEC, 5'd6, 3'b001, 5'd5));
        write_instr(1, enc_r(7'b0000000, 5'd0, 5'd5, 3'b000, 5'd7));
        wait_for_reg(5'd7, 64'h0000_0000_0000_0100, 160,
                     "CSRRW and dependent instruction completion");
        check64(dut.u_csrfile.mtvec_out, 64'h0000_0000_0000_0204,
                "CSRRW writes aligned mtvec value");
        check_reg(5'd5, 64'h0000_0000_0000_0100,
                  "CSRRW returns old mtvec");
        check_reg(5'd7, 64'h0000_0000_0000_0100,
                  "CSR rd value forwards from MEM to following instruction");

        start_phase("CSRRS register mask sets selected bits");
        dut.u_csrfile.mcause_out = 64'h80;
        dut.u_register.registers[6] = 64'h08;
        write_instr(0, enc_csr(CSR_MCAUSE, 5'd6, 3'b010, 5'd5));
        wait_for_reg(5'd5, 64'h80, 140, "CSRRS completion");
        check64(dut.u_csrfile.mcause_out, 64'h88,
                "CSRRS sets selected mcause bits");
        check_reg(5'd5, 64'h80, "CSRRS returns old mcause");

        start_phase("CSRRC register mask clears selected bits");
        dut.u_csrfile.mcause_out = 64'h88;
        dut.u_register.registers[6] = 64'h08;
        write_instr(0, enc_csr(CSR_MCAUSE, 5'd6, 3'b011, 5'd5));
        wait_for_reg(5'd5, 64'h88, 140, "CSRRC completion");
        check64(dut.u_csrfile.mcause_out, 64'h80,
                "CSRRC clears selected mcause bits");
        check_reg(5'd5, 64'h88, "CSRRC returns old mcause");

        start_phase("CSRRWI writes zero-extended zimm");
        dut.u_csrfile.mcause_out = 64'h55;
        write_instr(0, enc_csr(CSR_MCAUSE, 5'h12, 3'b101, 5'd5));
        wait_for_reg(5'd5, 64'h55, 140, "CSRRWI completion");
        check64(dut.u_csrfile.mcause_out, 64'h12,
                "CSRRWI writes zimm to mcause");
        check_reg(5'd5, 64'h55, "CSRRWI returns old mcause");

        start_phase("CSRRSI immediate mask sets selected bits");
        dut.u_csrfile.mcause_out = 64'h80;
        write_instr(0, enc_csr(CSR_MCAUSE, 5'h08, 3'b110, 5'd5));
        wait_for_reg(5'd5, 64'h80, 140, "CSRRSI completion");
        check64(dut.u_csrfile.mcause_out, 64'h88,
                "CSRRSI sets selected mcause bits");
        check_reg(5'd5, 64'h80, "CSRRSI returns old mcause");

        start_phase("CSRRCI immediate mask clears selected bits");
        dut.u_csrfile.mcause_out = 64'h88;
        write_instr(0, enc_csr(CSR_MCAUSE, 5'h08, 3'b111, 5'd5));
        wait_for_reg(5'd5, 64'h88, 140, "CSRRCI completion");
        check64(dut.u_csrfile.mcause_out, 64'h80,
                "CSRRCI clears selected mcause bits");
        check_reg(5'd5, 64'h88, "CSRRCI returns old mcause");

        start_phase("CSRRS with rs1 x0 reads without writing");
        dut.u_csrfile.mcause_out = 64'h55;
        write_instr(0, enc_csr(CSR_MCAUSE, 5'd0, 3'b010, 5'd5));
        wait_for_reg(5'd5, 64'h55, 140, "CSRRS read-only completion");
        check64(dut.u_csrfile.mcause_out, 64'h55,
                "CSRRS x0 leaves mcause unchanged");
        check_reg(5'd5, 64'h55, "CSRRS x0 still returns old mcause");

        start_phase("CSRRCI with zimm zero reads without writing");
        dut.u_csrfile.mcause_out = 64'haa;
        write_instr(0, enc_csr(CSR_MCAUSE, 5'd0, 3'b111, 5'd5));
        wait_for_reg(5'd5, 64'haa, 140, "CSRRCI read-only completion");
        check64(dut.u_csrfile.mcause_out, 64'haa,
                "CSRRCI zero leaves mcause unchanged");
        check_reg(5'd5, 64'haa, "CSRRCI zero still returns old mcause");

        start_phase("register result forwards into CSR operand");
        dut.u_csrfile.mcause_out = 64'h80;
        write_instr(0, enc_i(12'd8, 5'd0, 3'b000, 5'd6, 7'b0010011));
        write_instr(1, enc_csr(CSR_MCAUSE, 5'd6, 3'b010, 5'd5));
        wait_for_reg(5'd5, 64'h80, 160,
                     "forwarded CSR operand sequence completion");
        check64(dut.u_csrfile.mcause_out, 64'h88,
                "EX MEM forwarding supplies CSR register operand");
        check_reg(5'd5, 64'h80,
                  "CSR instruction with forwarded operand returns old value");

        $display("\nPASS: all six CSR instructions, read-only forms, CSR rd forwarding, and CSR operand forwarding passed.");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Timeout: CSR pipeline testbench did not finish");
    end

endmodule
