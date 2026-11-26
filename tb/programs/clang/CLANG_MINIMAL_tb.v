`timescale 1ns/1ps

module CLANG_MINIMAL_tb;
    reg clk;
    reg reset;
    integer i;
    integer cycle_count;
    integer retired_instruction_count;
    integer dcache_load_count;
    integer icache_miss_count;
    integer dcache_miss_count;
    integer icache_wait_cycles;
    integer dcache_stall_cycles;
    integer load_use_stall_cycles;
    integer branch_count;
    integer branch_taken_count;
    integer branch_mispredict_count;
    real cpi;
    reg halt_seen;

    localparam [31:0] NOP = 32'h00000013; // addi x0, x0, 0
    localparam [63:0] HALT_PC = 64'h0000_0000_0000_0004;
    localparam [63:0] EXPECTED_MAIN_RETURN = 64'd42;

    PIPELINED_CPU #(.DCACHE_BACKING_BASE_ADDR(64'h0)) dut (
        .reset(reset),
        .clk(clk),
        .external_interrupt_pending(1'b0)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            retired_instruction_count = 0;
            dcache_load_count = 0;
            icache_miss_count = 0;
            dcache_miss_count = 0;
            icache_wait_cycles = 0;
            dcache_stall_cycles = 0;
            load_use_stall_cycles = 0;
            branch_count = 0;
            branch_taken_count = 0;
            branch_mispredict_count = 0;
        end
        else begin
            if (dut.valid_mem === 1'b1 &&
                dut.MEM_WB_write_final === 1'b1 &&
                dut.trap_enter !== 1'b1 &&
                dut.current_pc_mem !== HALT_PC) begin
                retired_instruction_count = retired_instruction_count + 1;
                if (dut.MemRead_mem === 1'b1)
                    dcache_load_count = dcache_load_count + 1;
                if (dut.Branch_mem === 1'b1) begin
                    branch_count = branch_count + 1;
                    if (dut.branch_taken_mem === 1'b1)
                        branch_taken_count = branch_taken_count + 1;
                    if (dut.branch_mispredict_mem === 1'b1)
                        branch_mispredict_count = branch_mispredict_count + 1;
                end
            end

            if (dut.u_icache.cpu_instr_miss_fire === 1'b1)
                icache_miss_count = icache_miss_count + 1;
            if (dut.u_dcache.cpu_load_miss_fire === 1'b1)
                dcache_miss_count = dcache_miss_count + 1;
            if (dut.icache_cpu_req_valid === 1'b1 &&
                dut.icache_resp_usable !== 1'b1)
                icache_wait_cycles = icache_wait_cycles + 1;
            if (dut.dcache_stall === 1'b1)
                dcache_stall_cycles = dcache_stall_cycles + 1;
            if (dut.PCwrite_hazard === 1'b0)
                load_use_stall_cycles = load_use_stall_cycles + 1;
        end
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        halt_seen = 1'b0;
        cycle_count = 0;
        retired_instruction_count = 0;
        dcache_load_count = 0;
        icache_miss_count = 0;
        dcache_miss_count = 0;
        icache_wait_cycles = 0;
        dcache_stall_cycles = 0;
        load_use_stall_cycles = 0;
        branch_count = 0;
        branch_taken_count = 0;
        branch_mispredict_count = 0;
        cpi = 0.0;

        // The register file has no reset input, so initialize it explicitly.
        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'd0;

        // Give all unused instruction locations a legal NOP, then overwrite
        // the first two 64-bit words with the image produced from program.elf.
        for (i = 0; i < 256; i = i + 1) begin
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            dut.u_dcache_backing_memory.memory[i] = 64'd0;
        end
        $readmemh("tb/fixtures/programs/minimal/program.hex",
                  dut.u_icache_backing_memory.memory, 0, 1);

        // Apply reset for two clock edges so that the PC, caches, pipeline
        // registers, predictor, and trap state all reach their reset values.
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // start.s places the terminal self-loop at address 0x4. Waiting for
        // that JAL to reach MEM proves that main returned to _start.
        while (!halt_seen && cycle_count < 500) begin
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
            if (dut.valid_mem === 1'b1 &&
                dut.current_pc_mem === HALT_PC &&
                dut.Jump_mem === 1'b1)
                halt_seen = 1'b1;
        end

        if (!halt_seen)
            $fatal(1, "timeout: program did not reach halt at PC 0x4");

        if (dut.u_register.registers[10] !== EXPECTED_MAIN_RETURN)
            $fatal(1,
                   "main returned %0d (0x%016h), expected %0d",
                   dut.u_register.registers[10],
                   dut.u_register.registers[10],
                   EXPECTED_MAIN_RETURN);

        cpi = $itor(cycle_count) / $itor(retired_instruction_count);
        $display("Performance counters (minimal):");
        $display("  Cycles               = %0d", cycle_count);
        $display("  Retired instructions = %0d", retired_instruction_count);
        $display("  CPI                  = %0.3f", cpi);
        $display("  I-Cache misses       = %0d", icache_miss_count);
        $display("  D-Cache load misses  = %0d / %0d", dcache_miss_count,
                 dcache_load_count);
        $display("  I-Cache wait cycles  = %0d", icache_wait_cycles);
        $display("  D-Cache stall cycles = %0d", dcache_stall_cycles);
        $display("  Load-use stall cycles= %0d", load_use_stall_cycles);
        $display("  Taken branches       = %0d / %0d", branch_taken_count,
                 branch_count);
        $display("  Branch mispredictions= %0d / %0d", branch_mispredict_count,
                 branch_count);
        $display("PASS: Clang RV64 program reached halt; main returned %0d in a0.",
                 dut.u_register.registers[10]);
        $finish;
    end
endmodule
