`timescale 1ns/1ps

module PIPELINED_CPU_tb;
    reg clk;
    reg reset;
    integer i;
    integer stall_count;
    integer branch_resolve_count;
    integer branch_mispredict_count;
    integer correct_prediction_count;
    integer control_flush_count;

    localparam [31:0] NOP = 32'h00000033; // add x0, x0, x0

    PIPELINED_CPU dut (
        .reset(reset),
        .clk(clk),
        .external_interrupt_pending(1'b0)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            stall_count <= 0;
            branch_resolve_count <= 0;
            branch_mispredict_count <= 0;
            correct_prediction_count <= 0;
            control_flush_count <= 0;
        end
        else begin
            if (dut.PCwrite_hazard === 1'b0)
                stall_count <= stall_count + 1;

            if (dut.Branch_mem === 1'b1) begin
                branch_resolve_count <= branch_resolve_count + 1;

                if (dut.branch_mispredict_mem === 1'b1)
                    branch_mispredict_count <= branch_mispredict_count + 1;
                else
                    correct_prediction_count <= correct_prediction_count + 1;
            end

            if (dut.control_flush_mem === 1'b1)
                control_flush_count <= control_flush_count + 1;
        end
    end

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
            enc_s = {imm[11:5], rs2, rs1, funct3,
                     imm[4:0], 7'b0100011};
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

    task wait_for_memory;
        input integer word_index;
        input [63:0] expected;
        input integer max_cycles;
        input [511:0] description;
        integer waited;
        begin
            waited = 0;
            while ((dut.u_dcache_backing_memory.memory[word_index] !== expected) &&
                   (waited < max_cycles)) begin
                @(posedge clk);
                #1;
                waited = waited + 1;
            end
            if (waited >= max_cycles)
                $fatal(1, "%0s: timeout waiting for memory[%0d]=%h (got %h)",
                       description, word_index, expected,
                       dut.u_dcache_backing_memory.memory[word_index]);
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

    initial begin
        clk = 1'b0;
        reset = 1'b1;

        // All instructions in this phase use preinitialized source registers,
        // so no result is consumed before it reaches WB.
        start_phase("independent ALU and U-type instructions");
        dut.u_register.registers[1] = 64'd12;
        dut.u_register.registers[2] = 64'd5;
        dut.u_register.registers[3] = 64'h000000000000f0f5;
        dut.u_register.registers[4] = 64'h0000000000000ff0;
        dut.u_register.registers[5] = 64'hffffffffffffffff;
        dut.u_register.registers[6] = 64'd1;
        dut.u_register.registers[7] = 64'd13;
        dut.u_register.registers[8] = 64'd2;
        dut.u_register.registers[9] = 64'h8000000000000000;

        write_instr(0, enc_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd10)); // add
        write_instr(1, enc_r(7'b0100000, 5'd2, 5'd1, 3'b000, 5'd11)); // sub
        write_instr(2, enc_r(7'b0000000, 5'd4, 5'd3, 3'b111, 5'd12)); // and
        write_instr(3, enc_r(7'b0000000, 5'd4, 5'd3, 3'b110, 5'd13)); // or
        write_instr(4, enc_r(7'b0000000, 5'd4, 5'd3, 3'b100, 5'd14)); // xor
        write_instr(5, enc_r(7'b0000000, 5'd6, 5'd5, 3'b010, 5'd15)); // slt
        write_instr(6, enc_r(7'b0000000, 5'd8, 5'd7, 3'b001, 5'd16)); // sll
        write_instr(7, enc_r(7'b0000000, 5'd8, 5'd9, 3'b101, 5'd17)); // srl
        write_instr(8, enc_i(12'hffb, 5'd1, 3'b000, 5'd18, 7'b0010011)); // addi -5
        write_instr(9, enc_i(12'h0ff, 5'd3, 3'b111, 5'd19, 7'b0010011)); // andi
        write_instr(10, enc_i(12'h00a, 5'd3, 3'b110, 5'd20, 7'b0010011)); // ori
        write_instr(11, enc_i(12'hfff, 5'd4, 3'b100, 5'd21, 7'b0010011)); // xori -1
        write_instr(12, enc_u(20'h12345, 5'd22, 7'b0110111));             // lui
        write_instr(13, enc_u(20'h00002, 5'd23, 7'b0010111));             // auipc at PC=52

        wait_for_reg(5'd23, 64'h0000000000002034, 200,
                     "independent ALU/U-type program completion");
        check_reg(5'd10, 64'd17, "add");
        check_reg(5'd11, 64'd7, "sub");
        check_reg(5'd12, 64'h00000000000000f0, "and");
        check_reg(5'd13, 64'h000000000000fff5, "or");
        check_reg(5'd14, 64'h000000000000ff05, "xor");
        check_reg(5'd15, 64'd1, "signed slt");
        check_reg(5'd16, 64'd52, "sll");
        check_reg(5'd17, 64'h2000000000000000, "srl");
        check_reg(5'd18, 64'd7, "addi");
        check_reg(5'd19, 64'h00000000000000f5, "andi");
        check_reg(5'd20, 64'h000000000000f0ff, "ori");
        check_reg(5'd21, 64'hfffffffffffff00f, "xori");
        check_reg(5'd22, 64'h0000000012345000, "lui");
        check_reg(5'd23, 64'h0000000000002034, "auipc");

        start_phase("load and store without dependency");
        dut.u_register.registers[1] = 64'd8;
        dut.u_register.registers[2] = 64'h1122334455667788;
        dut.u_dcache_backing_memory.memory[1] = 64'haabbccddeeff0011;
        write_instr(0, enc_i(12'd0, 5'd1, 3'b011, 5'd10, 7'b0000011)); // ld
        write_instr(1, enc_s(12'd8, 5'd2, 5'd1, 3'b011));              // sd

        wait_for_memory(2, 64'h1122334455667788, 240,
                        "load/store program completion");
        check_reg(5'd10, 64'haabbccddeeff0011, "ld");
        if (dut.u_dcache_backing_memory.memory[2] !== 64'h1122334455667788)
            $fatal(1, "sd: memory[2] = %h, expected 1122334455667788",
                   dut.u_dcache_backing_memory.memory[2]);

        // Back-to-back dependencies exercise EX/MEM forwarding, simultaneous
        // MEM/WB forwarding, and MEM priority over an older WB result.
        start_phase("ALU forwarding without NOPs");
        write_instr(0, enc_i(12'd5, 5'd0, 3'b000, 5'd1, 7'b0010011)); // x1 = 5
        write_instr(1, enc_r(7'b0000000, 5'd1, 5'd1, 3'b000, 5'd2));   // x2 = 10, MEM -> A/B
        write_instr(2, enc_r(7'b0000000, 5'd1, 5'd2, 3'b000, 5'd3));   // x3 = 15, MEM + WB
        write_instr(3, enc_i(12'd9, 5'd0, 3'b000, 5'd4, 7'b0010011)); // x4 = 9
        write_instr(4, enc_i(12'd1, 5'd0, 3'b000, 5'd31, 7'b0010011));// independent
        write_instr(5, enc_r(7'b0000000, 5'd0, 5'd4, 3'b000, 5'd5));   // x5 = 9, WB -> A

        wait_for_reg(5'd5, 64'd9, 160,
                     "ALU forwarding program completion");
        check_reg(5'd1, 64'd5, "forwarding producer");
        check_reg(5'd2, 64'd10, "EX/MEM forwarding to both ALU inputs");
        check_reg(5'd3, 64'd15, "simultaneous MEM and WB forwarding");
        check_reg(5'd5, 64'd9, "MEM/WB forwarding");
        if (stall_count !== 0)
            $fatal(1, "ALU forwarding unexpectedly stalled %0d cycles", stall_count);

        // Store consumes rs2 even though its ALU B input is the immediate.
        start_phase("store-data forwarding without NOPs");
        write_instr(0, enc_i(12'd42, 5'd0, 3'b000, 5'd6, 7'b0010011));
        write_instr(1, enc_s(12'd0, 5'd6, 5'd0, 3'b011));

        wait_for_memory(0, 64'd42, 180,
                        "store-data forwarding completion");
        if (dut.u_dcache_backing_memory.memory[0] !== 64'd42)
            $fatal(1, "store forwarding: memory[0] = %h, expected 42",
                   dut.u_dcache_backing_memory.memory[0]);
        if (stall_count !== 0)
            $fatal(1, "store forwarding unexpectedly stalled %0d cycles", stall_count);

        // The consumer immediately follows ld, so the pipeline must stall once
        // and then use the MEM/WB forwarding path.
        start_phase("load-use hazard stall");
        dut.u_dcache_backing_memory.memory[1] = 64'd11;
        write_instr(0, enc_i(12'd8, 5'd0, 3'b011, 5'd7, 7'b0000011));  // x7 = 11
        write_instr(1, enc_r(7'b0000000, 5'd7, 5'd7, 3'b000, 5'd8));   // x8 = 22
        write_instr(2, enc_i(12'd1, 5'd8, 3'b000, 5'd9, 7'b0010011));  // x9 = 23

        wait_for_reg(5'd9, 64'd23, 240,
                     "load-use sequence completion");
        check_reg(5'd7, 64'd11, "load-use producer");
        check_reg(5'd8, 64'd22, "load-use consumer");
        check_reg(5'd9, 64'd23, "post-stall forwarding");
        if (stall_count !== 1)
            $fatal(1, "load-use stalled %0d cycles, expected exactly 1", stall_count);

        // Store really uses rs2, so an immediately preceding load must also
        // cause one stall before the loaded value can be stored.
        start_phase("load-to-store hazard stall");
        dut.u_dcache_backing_memory.memory[2] = 64'h0123456789abcdef;
        write_instr(0, enc_i(12'd16, 5'd0, 3'b011, 5'd10, 7'b0000011));
        write_instr(1, enc_s(12'd24, 5'd10, 5'd0, 3'b011));

        wait_for_memory(3, 64'h0123456789abcdef, 260,
                        "load-to-store sequence completion");
        if (dut.u_dcache_backing_memory.memory[3] !== 64'h0123456789abcdef)
            $fatal(1, "load-to-store: memory[3] = %h, expected 0123456789abcdef",
                   dut.u_dcache_backing_memory.memory[3]);
        if (stall_count !== 1)
            $fatal(1, "load-to-store stalled %0d cycles, expected exactly 1", stall_count);

        // For I-type instructions, instruction[24:20] is immediate data rather
        // than rs2. Its value matches x5 here and must not cause a false stall.
        start_phase("no false rs2 hazard on I-type instruction");
        dut.u_dcache_backing_memory.memory[0] = 64'd123;
        write_instr(0, enc_i(12'd0, 5'd0, 3'b011, 5'd5, 7'b0000011));  // ld x5, 0(x0)
        write_instr(1, enc_i(12'd5, 5'd0, 3'b000, 5'd6, 7'b0010011));  // imm[4:0] == 5

        wait_for_reg(5'd6, 64'd5, 220,
                     "I-type false-hazard sequence completion");
        check_reg(5'd5, 64'd123, "I-type false-hazard load");
        check_reg(5'd6, 64'd5, "I-type instruction after load");
        if (stall_count !== 0)
            $fatal(1, "I-type immediate caused %0d false stall cycles", stall_count);

        // The taken branch reaches MEM while a wrong-path load is in EX and
        // its consumer is in ID. Control redirect must override the simultaneous
        // load-use stall, and all three younger instructions must be flushed.
        start_phase("control flush overrides load-use stall");
        dut.u_register.registers[1] = 64'd7;
        dut.u_register.registers[2] = 64'd7;
        dut.u_dcache_backing_memory.memory[0] = 64'd99;
        write_instr(0, enc_b(13'd24, 5'd2, 5'd1, 3'b000));             // taken beq
        write_instr(1, enc_i(12'd0, 5'd0, 3'b011, 5'd5, 7'b0000011)); // wrong EX: ld
        write_instr(2, enc_r(7'b0000000, 5'd5, 5'd5, 3'b000, 5'd6));  // wrong ID: add
        write_instr(3, enc_i(12'd3, 5'd0, 3'b000, 5'd30, 7'b0010011));// wrong IF
        write_instr(4, enc_i(12'd4, 5'd0, 3'b000, 5'd20, 7'b0010011));// executes if redirect lost
        write_instr(5, enc_i(12'd5, 5'd0, 3'b000, 5'd21, 7'b0010011));// executes if redirect lost
        write_instr(6, enc_i(12'd7, 5'd0, 3'b000, 5'd7, 7'b0010011)); // branch target

        wait_for_reg(5'd7, 64'd7, 200,
                     "control-flush target completion");
        check_reg(5'd5, 64'd0, "EX/MEM wrong-path load flushed");
        check_reg(5'd6, 64'd0, "ID/EX wrong-path consumer flushed");
        check_reg(5'd30, 64'd0, "IF/ID wrong-path instruction flushed");
        check_reg(5'd20, 64'd0, "branch redirect did not fall through PC+16");
        check_reg(5'd21, 64'd0, "branch redirect did not fall through PC+20");
        check_reg(5'd7, 64'd7, "branch target after simultaneous hazard");
        if (stall_count !== 1)
            $fatal(1, "simultaneous control/data hazard count = %0d, expected 1", stall_count);

        // Branch is resolved after EX/MEM. The wrong-path instructions are
        // flushed before they can produce architectural side effects.
        start_phase("taken beq");
        dut.u_register.registers[1] = 64'd7;
        dut.u_register.registers[2] = 64'd7;
        write_instr(0, enc_b(13'd24, 5'd2, 5'd1, 3'b000));
        write_instr(4, enc_i(12'd1, 5'd0, 3'b000, 5'd20, 7'b0010011)); // skipped
        write_instr(5, enc_i(12'd1, 5'd0, 3'b000, 5'd21, 7'b0010011)); // skipped
        write_instr(6, enc_i(12'd7, 5'd0, 3'b000, 5'd22, 7'b0010011)); // target

        wait_for_reg(5'd22, 64'd7, 200,
                     "taken BEQ target completion");
        check_reg(5'd20, 64'd0, "beq skipped PC+16");
        check_reg(5'd21, 64'd0, "beq skipped PC+20");
        check_reg(5'd22, 64'd7, "beq target");

        start_phase("taken bne");
        dut.u_register.registers[1] = 64'd7;
        dut.u_register.registers[2] = 64'd9;
        write_instr(0, enc_b(13'd24, 5'd2, 5'd1, 3'b001));
        write_instr(4, enc_i(12'd1, 5'd0, 3'b000, 5'd20, 7'b0010011)); // skipped
        write_instr(5, enc_i(12'd1, 5'd0, 3'b000, 5'd21, 7'b0010011)); // skipped
        write_instr(6, enc_i(12'd9, 5'd0, 3'b000, 5'd22, 7'b0010011)); // target

        wait_for_reg(5'd22, 64'd9, 200,
                     "taken BNE target completion");
        check_reg(5'd20, 64'd0, "bne skipped PC+16");
        check_reg(5'd21, 64'd0, "bne skipped PC+20");
        check_reg(5'd22, 64'd9, "bne target");

        start_phase("not-taken branches");
        dut.u_register.registers[1] = 64'd7;
        dut.u_register.registers[2] = 64'd9;
        write_instr(0, enc_b(13'd24, 5'd2, 5'd1, 3'b000)); // beq not taken
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd10, 7'b0010011));
        write_instr(2, enc_b(13'd24, 5'd1, 5'd1, 3'b001)); // bne not taken
        write_instr(3, enc_i(12'd2, 5'd0, 3'b000, 5'd11, 7'b0010011));

        wait_for_reg(5'd11, 64'd2, 160,
                     "not-taken branch sequence completion");
        check_reg(5'd10, 64'd1, "beq fall-through");
        check_reg(5'd11, 64'd2, "bne fall-through");

        // The branch at PC=4 uses BHT entry 1. Its actual outcomes are
        // taken, taken, taken, not-taken, so the counter follows:
        // 01 -> 10 -> 11 -> 11 -> 10.
        // Only the first and last outcomes should be mispredictions. The two
        // middle taken outcomes must follow the predicted target without a
        // pipeline flush.
        start_phase("two-bit branch predictor training and recovery");
        dut.u_register.registers[2] = 64'd4;
        write_instr(0, enc_i(12'd1, 5'd1, 3'b000, 5'd1, 7'b0010011)); // x1++
        write_instr(1, enc_b(13'h1ffc, 5'd2, 5'd1, 3'b001));           // bne x1,x2,-4
        write_instr(2, enc_i(12'd1, 5'd3, 3'b000, 5'd3, 7'b0010011)); // exit: x3++
        write_instr(3, enc_i(12'd9, 5'd0, 3'b000, 5'd4, 7'b0010011)); // after loop

        wait_for_reg(5'd4, 64'd9, 320,
                     "branch predictor training loop completion");
        check_reg(5'd1, 64'd4, "branch-predicted loop iteration count");
        check_reg(5'd3, 64'd1, "loop fall-through executes exactly once");
        check_reg(5'd4, 64'd9, "execution continues after loop recovery");
        if (branch_resolve_count !== 4)
            $fatal(1, "branch predictor resolved %0d branches, expected 4",
                   branch_resolve_count);
        if (branch_mispredict_count !== 2)
            $fatal(1, "branch predictor produced %0d mispredictions, expected 2",
                   branch_mispredict_count);
        if (correct_prediction_count !== 2)
            $fatal(1, "branch predictor produced %0d correct predictions, expected 2",
                   correct_prediction_count);
        if (control_flush_count !== 2)
            $fatal(1, "branch predictor caused %0d control flushes, expected 2",
                   control_flush_count);
        if (dut.u_branchpredictionunit.bht[1] !== 2'b10)
            $fatal(1, "BHT[1] final state = %b, expected weakly taken (10)",
                   dut.u_branchpredictionunit.bht[1]);

        start_phase("jal flushes harmful wrong path");
        write_instr(0, enc_j(21'd24, 5'd1));
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd20, 7'b0010011)); // wrong EX
        write_instr(2, enc_i(12'd2, 5'd0, 3'b000, 5'd21, 7'b0010011)); // wrong ID
        write_instr(3, enc_i(12'd3, 5'd0, 3'b000, 5'd22, 7'b0010011)); // wrong IF
        write_instr(6, enc_i(12'd6, 5'd0, 3'b000, 5'd2, 7'b0010011));  // target

        wait_for_reg(5'd2, 64'd6, 200,
                     "JAL target completion");
        check_reg(5'd1, 64'd4, "jal link");
        check_reg(5'd20, 64'd0, "jal flushed EX instruction");
        check_reg(5'd21, 64'd0, "jal flushed ID instruction");
        check_reg(5'd22, 64'd0, "jal flushed IF instruction");
        check_reg(5'd2, 64'd6, "jal target");

        start_phase("jalr flushes harmful wrong path");
        dut.u_register.registers[5] = 64'd24;
        write_instr(0, enc_i(12'd1, 5'd5, 3'b000, 5'd4, 7'b1100111));
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd20, 7'b0010011)); // wrong EX
        write_instr(2, enc_i(12'd2, 5'd0, 3'b000, 5'd21, 7'b0010011)); // wrong ID
        write_instr(3, enc_i(12'd3, 5'd0, 3'b000, 5'd22, 7'b0010011)); // wrong IF
        write_instr(6, enc_i(12'd8, 5'd0, 3'b000, 5'd6, 7'b0010011));  // target

        wait_for_reg(5'd6, 64'd8, 200,
                     "JALR target completion");
        check_reg(5'd4, 64'd4, "jalr link");
        check_reg(5'd20, 64'd0, "jalr flushed EX instruction");
        check_reg(5'd21, 64'd0, "jalr flushed ID instruction");
        check_reg(5'd22, 64'd0, "jalr flushed IF instruction");
        check_reg(5'd6, 64'd8, "jalr target");

        $display("\nPASS: all 20 instructions, forwarding, stalls, control flushes, and two-bit branch prediction passed.");
        $finish;
    end

    initial begin
        #30000;
        $fatal(1, "Timeout: pipelined CPU testbench did not finish");
    end

endmodule
