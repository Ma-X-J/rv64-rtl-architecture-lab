`timescale 1ns/1ps

// Short, deterministic program used only to generate the README waveform.
// The first branch is taken while all predictor counters begin weakly
// not-taken, so the trace contains one real misprediction and recovery.
module BranchRecoveryWaveformDemo;
    reg clk;
    reg reset;
    integer i;
    integer cycle;
    integer cycles_after_mispredict;
    reg mispredict_seen;

    localparam [31:0] NOP = 32'h00000013; // addi x0, x0, 0

    PIPELINED_CPU #(
        .BRANCH_PREDICTOR_MODE(2),
        .DCACHE_BACKING_BASE_ADDR(64'h0)
    ) dut (
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

    // Readable top-level aliases keep the GTKWave trace free of long
    // implementation hierarchy names.
    wire        CLK                    = clk;
    wire        RESET                  = reset;
    wire [15:0] IF_PC                  = dut.current_pc_if[15:0];
    wire [15:0] ID_PC                  = dut.pc_id[15:0];
    wire [15:0] EX_PC                  = dut.current_pc_ex[15:0];
    wire [15:0] MEM_PC                 = dut.current_pc_mem[15:0];
    wire        IF_VALID               = dut.valid_if;
    wire        ID_VALID               = dut.valid_id;
    wire        EX_VALID               = dut.valid_ex;
    wire        MEM_VALID              = dut.valid_mem;
    wire        PREDICTED_TAKEN_IF     = dut.predicted_taken_if;
    wire [1:0]  GHR                    = dut.u_branchpredictionunit.ghr;
    wire        BRANCH_RESOLVE_MEM     = dut.branch_resolve_valid_mem;
    wire        PREDICTED_TAKEN_MEM    = dut.predicted_taken_mem;
    wire        ACTUAL_TAKEN_MEM       = dut.branch_taken_mem;
    wire        MISPREDICT_MEM         = dut.branch_mispredict_mem;
    wire        FLUSH_PIPELINE         = dut.control_flush_mem;
    wire [15:0] REDIRECT_PC            = dut.next_pc[15:0];

    initial begin
        $dumpfile("build/readme-waveform/branch-recovery.vcd");
        $dumpvars(0, CLK);
        $dumpvars(0, RESET);
        $dumpvars(0, IF_PC, ID_PC, EX_PC, MEM_PC);
        $dumpvars(0, IF_VALID, ID_VALID, EX_VALID, MEM_VALID);
        $dumpvars(0, PREDICTED_TAKEN_IF);
        $dumpvars(0, GHR);
        $dumpvars(0, BRANCH_RESOLVE_MEM, PREDICTED_TAKEN_MEM);
        $dumpvars(0, ACTUAL_TAKEN_MEM, MISPREDICT_MEM);
        $dumpvars(0, FLUSH_PIPELINE, REDIRECT_PC);
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        cycle = 0;
        cycles_after_mispredict = 0;
        mispredict_seen = 1'b0;

        for (i = 0; i < 16; i = i + 1)
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};

        // PC 0: branch to PC 16. PCs 4, 8, and 12 are wrong-path writes.
        write_instr(0, enc_b(13'd16, 5'd2, 5'd1, 3'b000));
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd3, 7'b0010011));
        write_instr(2, enc_i(12'd2, 5'd0, 3'b000, 5'd3, 7'b0010011));
        write_instr(3, enc_i(12'd3, 5'd0, 3'b000, 5'd3, 7'b0010011));
        write_instr(4, enc_i(12'h033, 5'd0, 3'b000, 5'd3, 7'b0010011));

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        dut.u_register.registers[1] = 64'd1;
        dut.u_register.registers[2] = 64'd1;

        while (!mispredict_seen && cycle < 100) begin
            @(posedge clk);
            #1;
            cycle = cycle + 1;
            if (dut.branch_mispredict_mem === 1'b1)
                mispredict_seen = 1'b1;
        end

        if (!mispredict_seen)
            $fatal(1, "expected branch misprediction was not observed");

        while (cycles_after_mispredict < 10) begin
            @(posedge clk);
            #1;
            cycles_after_mispredict = cycles_after_mispredict + 1;
        end

        if (dut.u_register.registers[3] !== 64'h33)
            $fatal(1, "recovered path did not write x3=0x33 (got %h)",
                   dut.u_register.registers[3]);

        $display("PASS: README branch recovery waveform generated.");
        $finish;
    end
endmodule
