`timescale 1ns/1ps

module CLANG_ARRAY_SUM_tb;
    reg clk;
    reg reset;
    integer i;
    integer cycle_count;
    integer retired_instruction_count;
    integer load_count;
    integer icache_miss_count;
    integer dcache_miss_count;
    integer icache_wait_cycles;
    integer dcache_stall_cycles;
    integer load_use_stall_cycles;
    integer branch_count;
    integer branch_taken_count;
    integer branch_mispredict_count;
    real cpi;
    real dcache_miss_rate;
    real branch_prediction_accuracy;
    reg halt_seen;

    localparam [31:0] NOP = 32'h00000013; // addi x0, x0, 0
    localparam [63:0] HALT_PC = 64'h0000_0000_0000_000c;
    localparam [63:0] EXPECTED_MAIN_RETURN = 64'd31;
    localparam [63:0] EXPECTED_STACK_TOP = 64'h0000_0000_0000_0800;
    localparam integer EXPECTED_RETIRED_INSTRUCTIONS = 44;

    PIPELINED_CPU #(.DCACHE_BACKING_BASE_ADDR(64'h0)) dut (
        .reset(reset),
        .clk(clk),
        .external_interrupt_pending(1'b0)
    );

    always #5 clk = ~clk;

    // Count an instruction when the valid MEM-stage entry is accepted by
    // MEM/WB. MEM_WB_write_final goes low during a D-Cache stall, so a load
    // held in MEM for several cycles is counted only once. This event also
    // includes branches, jumps, and stores even though they do not write a
    // general-purpose register. The artificial halt loop is excluded from
    // the benchmark's instruction count.
    always @(posedge clk) begin
        if (reset)
            retired_instruction_count = 0;
        else if (dut.valid_mem === 1'b1 &&
                 dut.MEM_WB_write_final === 1'b1 &&
                 dut.trap_enter !== 1'b1 &&
                 dut.current_pc_mem !== HALT_PC)
            retired_instruction_count = retired_instruction_count + 1;
    end

    // Count cache and pipeline events. The Cache miss_fire signals pulse only
    // when a new CPU request is accepted as a miss, rather than once for each
    // backend word transferred during the line refill.
    always @(posedge clk) begin
        if (reset) begin
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
            if (dut.u_icache.cpu_instr_miss_fire === 1'b1)
                icache_miss_count = icache_miss_count + 1;

            if (dut.u_dcache.cpu_load_miss_fire === 1'b1)
                dcache_miss_count = dcache_miss_count + 1;

            // Count cycles in which the front end requests an instruction but
            // cannot consume a usable I-Cache response.
            if (dut.icache_cpu_req_valid === 1'b1 &&
                dut.icache_resp_usable !== 1'b1)
                icache_wait_cycles = icache_wait_cycles + 1;

            if (dut.dcache_stall === 1'b1)
                dcache_stall_cycles = dcache_stall_cycles + 1;

            if (dut.PCwrite_hazard === 1'b0)
                load_use_stall_cycles = load_use_stall_cycles + 1;

            // Count only valid branches that are leaving MEM. This prevents a
            // held instruction from being counted repeatedly during a stall.
            if (dut.valid_mem === 1'b1 &&
                dut.MEM_WB_write_final === 1'b1 &&
                dut.trap_enter !== 1'b1 &&
                dut.Branch_mem === 1'b1) begin
                branch_count = branch_count + 1;
                if (dut.branch_taken_mem === 1'b1)
                    branch_taken_count = branch_taken_count + 1;
                if (dut.branch_mispredict_mem === 1'b1)
                    branch_mispredict_count = branch_mispredict_count + 1;
            end
        end
    end

    // sum_array's LW is at PC 0x20. Count completed architectural loads so
    // that a coincidentally correct final register value cannot hide a loop
    // or cache-handshake failure.
    always @(posedge clk) begin
        if (reset)
            load_count = 0;
        else begin
            #1;
            if (dut.valid_mem === 1'b1 &&
                dut.current_pc_mem === 64'h20 &&
                dut.load_complete_mem === 1'b1)
                load_count = load_count + 1;
        end
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        halt_seen = 1'b0;
        cycle_count = 0;
        retired_instruction_count = 0;
        load_count = 0;
        icache_miss_count = 0;
        dcache_miss_count = 0;
        icache_wait_cycles = 0;
        dcache_stall_cycles = 0;
        load_use_stall_cycles = 0;
        branch_count = 0;
        branch_taken_count = 0;
        branch_mispredict_count = 0;
        cpi = 0.0;
        dcache_miss_rate = 0.0;
        branch_prediction_accuracy = 0.0;

        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'd0;

        for (i = 0; i < 256; i = i + 1) begin
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            dut.u_dcache_backing_memory.memory[i] = 64'd0;
        end

        // The flat image contains both .text and .data. Load it into both
        // independent backing memories: I-Cache fetches .text, while D-Cache
        // reads the initialized array at byte addresses 0x48 through 0x67.
        $readmemh("tb/fixtures/programs/array_sum/program.hex",
                  dut.u_icache_backing_memory.memory, 0, 12);
        $readmemh("tb/fixtures/programs/array_sum/program.hex",
                  dut.u_dcache_backing_memory.memory, 0, 12);

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        while (!halt_seen && cycle_count < 10000) begin
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
            if (dut.valid_mem === 1'b1 &&
                dut.current_pc_mem === HALT_PC &&
                dut.Jump_mem === 1'b1)
                halt_seen = 1'b1;
        end

        if (!halt_seen)
            $fatal(1, "timeout: array_sum did not reach halt at PC 0xC");

        if (dut.u_register.registers[10] !== EXPECTED_MAIN_RETURN)
            $fatal(1,
                   "array_sum returned %0d (0x%016h), expected %0d",
                   dut.u_register.registers[10],
                   dut.u_register.registers[10],
                   EXPECTED_MAIN_RETURN);

        if (load_count !== 8)
            $fatal(1, "sum loop completed %0d LW operations, expected 8",
                   load_count);

        if (retired_instruction_count !== EXPECTED_RETIRED_INSTRUCTIONS)
            $fatal(1,
                   "retired %0d instructions, expected %0d",
                   retired_instruction_count,
                   EXPECTED_RETIRED_INSTRUCTIONS);

        if (dut.u_register.registers[2] !== EXPECTED_STACK_TOP)
            $fatal(1, "stack pointer changed: sp=%h expected=%h",
                   dut.u_register.registers[2], EXPECTED_STACK_TOP);

        cpi = $itor(cycle_count) / $itor(retired_instruction_count);
        dcache_miss_rate = 100.0 * $itor(dcache_miss_count) /
                           $itor(load_count);
        branch_prediction_accuracy =
            100.0 * $itor(branch_count - branch_mispredict_count) /
            $itor(branch_count);
        $display("Performance counters:");
        $display("  Cycles               = %0d", cycle_count);
        $display("  Retired instructions = %0d", retired_instruction_count);
        $display("  CPI                  = %0.3f", cpi);
        $display("  I-Cache misses       = %0d", icache_miss_count);
        $display("  D-Cache load misses  = %0d / %0d (%0.1f%%)",
                 dcache_miss_count, load_count, dcache_miss_rate);
        $display("  I-Cache wait cycles  = %0d", icache_wait_cycles);
        $display("  D-Cache stall cycles = %0d", dcache_stall_cycles);
        $display("  Load-use stall cycles= %0d", load_use_stall_cycles);
        $display("  Taken branches       = %0d / %0d", branch_taken_count,
                 branch_count);
        $display("  Branch mispredictions= %0d / %0d (accuracy %0.1f%%)",
                 branch_mispredict_count, branch_count,
                 branch_prediction_accuracy);
        $display("PASS: Clang array_sum completed 8 loads and returned %0d.",
                 dut.u_register.registers[10]);
        $finish;
    end
endmodule
