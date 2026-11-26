`timescale 1ns/1ps

`ifdef ARRAY_SUM_SUM2W_PASS
`define PREPARED_HEX_PATH "tb/fixtures/programs/array_sum_unroll/llvm_unroll/cpu_unrolled2_o2.hex"
`define PREPARED_HEX_LAST 23
`define UNROLLED_HEX_PATH "tb/fixtures/programs/array_sum_unroll/sum2w/pass_o2.hex"
`define UNROLLED_HEX_LAST 23
`define CODEGEN_LABEL "O2, normal 2-way vs SUM2W Pass"
`define PREPARED_EXPECTED_LOADS 8
`define UNROLLED_EXPECTED_LOADS 4
`define SUM2W_COMPARE_MODE
`elsif ARRAY_SUM_SUM2W
`define PREPARED_HEX_PATH "tb/fixtures/programs/array_sum_unroll/llvm_unroll/cpu_unrolled2_o2.hex"
`define PREPARED_HEX_LAST 23
`define UNROLLED_HEX_PATH "tb/fixtures/programs/array_sum_unroll/sum2w/manual_o2.hex"
`define UNROLLED_HEX_LAST 23
`define CODEGEN_LABEL "O2, normal 2-way vs SUM2W"
`define PREPARED_EXPECTED_LOADS 8
`define UNROLLED_EXPECTED_LOADS 4
`define SUM2W_COMPARE_MODE
`elsif ARRAY_SUM_CUSTOM_PASS_O2
`define PREPARED_HEX_PATH "tb/fixtures/programs/array_sum_unroll/baseline/prepared_o2.hex"
`define PREPARED_HEX_LAST 19
`define UNROLLED_HEX_PATH "tb/fixtures/programs/array_sum_unroll/llvm_unroll/cpu_unrolled2_o2.hex"
`define UNROLLED_HEX_LAST 23
`define CODEGEN_LABEL "O2, custom CPUUnrollHintPass"
`elsif ARRAY_SUM_CODEGEN_O2_UNROLL2
`define PREPARED_HEX_PATH "tb/fixtures/programs/array_sum_unroll/baseline/prepared_o2.hex"
`define PREPARED_HEX_LAST 19
`define UNROLLED_HEX_PATH "tb/fixtures/programs/array_sum_unroll/manual_unroll/unrolled2_o2.hex"
`define UNROLLED_HEX_LAST 23
`define CODEGEN_LABEL "O2, 2-way"
`elsif ARRAY_SUM_CODEGEN_O2
`define PREPARED_HEX_PATH "tb/fixtures/programs/array_sum_unroll/baseline/prepared_o2.hex"
`define PREPARED_HEX_LAST 19
`define UNROLLED_HEX_PATH "tb/fixtures/programs/array_sum_unroll/manual_unroll/unrolled4_o2.hex"
`define UNROLLED_HEX_LAST 27
`define CODEGEN_LABEL "O2"
`else
`define PREPARED_HEX_PATH "tb/fixtures/programs/array_sum_unroll/baseline/prepared.hex"
`define PREPARED_HEX_LAST 30
`define UNROLLED_HEX_PATH "tb/fixtures/programs/array_sum_unroll/manual_unroll/unrolled4.hex"
`define UNROLLED_HEX_LAST 56
`define CODEGEN_LABEL "O0"
`endif

`ifndef PREPARED_EXPECTED_LOADS
`define PREPARED_EXPECTED_LOADS 8
`endif
`ifndef UNROLLED_EXPECTED_LOADS
`define UNROLLED_EXPECTED_LOADS 8
`endif

module CLANG_ARRAY_SUM_UNROLL_COMPARE_tb;
    reg clk;
    reg reset;
    integer i;
    integer timeout_cycles;

    integer prepared_cycles;
    integer prepared_retired;
    integer prepared_loads;
    integer prepared_icache_misses;
    integer prepared_icache_wait_cycles;
    integer prepared_dcache_stall_cycles;
    reg prepared_done;

    integer unrolled_cycles;
    integer unrolled_retired;
    integer unrolled_loads;
    integer unrolled_icache_misses;
    integer unrolled_icache_wait_cycles;
    integer unrolled_dcache_stall_cycles;
    reg unrolled_done;

    real prepared_cpi;
    real unrolled_cpi;
    real cycle_change_percent;
    real instruction_change_percent;

    localparam [31:0] NOP = 32'h00000013;
    localparam [63:0] HALT_PC = 64'h0000_0000_0000_000c;
    localparam [63:0] EXPECTED_RETURN = 64'd31;
    localparam [63:0] EXPECTED_STACK_TOP = 64'h0000_0000_0000_0800;

    PIPELINED_CPU #(.DCACHE_BACKING_BASE_ADDR(64'h0)) prepared_dut (
        .reset(reset),
        .clk(clk),
        .external_interrupt_pending(1'b0)
    );

    PIPELINED_CPU #(.DCACHE_BACKING_BASE_ADDR(64'h0)) unrolled_dut (
        .reset(reset),
        .clk(clk),
        .external_interrupt_pending(1'b0)
    );

    always #5 clk = ~clk;

    // Count each valid MEM-stage instruction exactly once when MEM/WB accepts
    // it. The artificial halt loop is excluded from both measurements.
    always @(posedge clk) begin
        if (reset) begin
            prepared_retired = 0;
            prepared_loads = 0;
            prepared_icache_misses = 0;
            prepared_icache_wait_cycles = 0;
            prepared_dcache_stall_cycles = 0;
            unrolled_retired = 0;
            unrolled_loads = 0;
            unrolled_icache_misses = 0;
            unrolled_icache_wait_cycles = 0;
            unrolled_dcache_stall_cycles = 0;
        end
        else begin
            if (!prepared_done) begin
                if (prepared_dut.u_icache.cpu_instr_miss_fire === 1'b1)
                    prepared_icache_misses = prepared_icache_misses + 1;
                if (prepared_dut.icache_cpu_req_valid === 1'b1 &&
                    prepared_dut.icache_resp_usable !== 1'b1)
                    prepared_icache_wait_cycles =
                        prepared_icache_wait_cycles + 1;
                if (prepared_dut.dcache_stall === 1'b1)
                    prepared_dcache_stall_cycles =
                        prepared_dcache_stall_cycles + 1;
            end

            if (!unrolled_done) begin
                if (unrolled_dut.u_icache.cpu_instr_miss_fire === 1'b1)
                    unrolled_icache_misses = unrolled_icache_misses + 1;
                if (unrolled_dut.icache_cpu_req_valid === 1'b1 &&
                    unrolled_dut.icache_resp_usable !== 1'b1)
                    unrolled_icache_wait_cycles =
                        unrolled_icache_wait_cycles + 1;
                if (unrolled_dut.dcache_stall === 1'b1)
                    unrolled_dcache_stall_cycles =
                        unrolled_dcache_stall_cycles + 1;
            end

            if (!prepared_done &&
                prepared_dut.valid_mem === 1'b1 &&
                prepared_dut.MEM_WB_write_final === 1'b1 &&
                prepared_dut.trap_enter !== 1'b1 &&
                prepared_dut.current_pc_mem !== HALT_PC) begin
                prepared_retired = prepared_retired + 1;
`ifdef SUM2W_COMPARE_MODE
                if (prepared_dut.MemRead_mem === 1'b1 &&
                    prepared_dut.aluresult_mem >= 64'h0000_0000_0000_00a0 &&
                    prepared_dut.aluresult_mem < 64'h0000_0000_0000_00c0)
`else
                if (prepared_dut.MemRead_mem === 1'b1 &&
                    prepared_dut.instruction_mem[14:12] == 3'b010)
`endif
                    prepared_loads = prepared_loads + 1;
            end

            if (!unrolled_done &&
                unrolled_dut.valid_mem === 1'b1 &&
                unrolled_dut.MEM_WB_write_final === 1'b1 &&
                unrolled_dut.trap_enter !== 1'b1 &&
                unrolled_dut.current_pc_mem !== HALT_PC) begin
                unrolled_retired = unrolled_retired + 1;
`ifdef SUM2W_COMPARE_MODE
                if (unrolled_dut.MemRead_mem === 1'b1 &&
                    unrolled_dut.aluresult_mem >= 64'h0000_0000_0000_00a0 &&
                    unrolled_dut.aluresult_mem < 64'h0000_0000_0000_00c0)
`else
                if (unrolled_dut.MemRead_mem === 1'b1 &&
                    unrolled_dut.instruction_mem[14:12] == 3'b010)
`endif
                    unrolled_loads = unrolled_loads + 1;
            end
        end
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        timeout_cycles = 0;
        prepared_cycles = 0;
        prepared_retired = 0;
        prepared_loads = 0;
        prepared_icache_misses = 0;
        prepared_icache_wait_cycles = 0;
        prepared_dcache_stall_cycles = 0;
        prepared_done = 1'b0;
        unrolled_cycles = 0;
        unrolled_retired = 0;
        unrolled_loads = 0;
        unrolled_icache_misses = 0;
        unrolled_icache_wait_cycles = 0;
        unrolled_dcache_stall_cycles = 0;
        unrolled_done = 1'b0;
        prepared_cpi = 0.0;
        unrolled_cpi = 0.0;
        cycle_change_percent = 0.0;
        instruction_change_percent = 0.0;

        for (i = 0; i < 32; i = i + 1) begin
            prepared_dut.u_register.registers[i] = 64'd0;
            unrolled_dut.u_register.registers[i] = 64'd0;
        end

        for (i = 0; i < 256; i = i + 1) begin
            prepared_dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            prepared_dut.u_dcache_backing_memory.memory[i] = 64'd0;
            unrolled_dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            unrolled_dut.u_dcache_backing_memory.memory[i] = 64'd0;
        end

        // Each flat image contains its own code and initialized data at the
        // addresses selected by its linker result.
        $readmemh(`PREPARED_HEX_PATH,
                  prepared_dut.u_icache_backing_memory.memory,
                  0, `PREPARED_HEX_LAST);
        $readmemh(`PREPARED_HEX_PATH,
                  prepared_dut.u_dcache_backing_memory.memory,
                  0, `PREPARED_HEX_LAST);
        $readmemh(`UNROLLED_HEX_PATH,
                  unrolled_dut.u_icache_backing_memory.memory,
                  0, `UNROLLED_HEX_LAST);
        $readmemh(`UNROLLED_HEX_PATH,
                  unrolled_dut.u_dcache_backing_memory.memory,
                  0, `UNROLLED_HEX_LAST);

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        while (!(prepared_done && unrolled_done) &&
               timeout_cycles < 50000) begin
            @(posedge clk);
            #1;
            timeout_cycles = timeout_cycles + 1;

            if (!prepared_done) begin
                prepared_cycles = prepared_cycles + 1;
                if (prepared_dut.trap_enter === 1'b1)
                    $fatal(1, "prepared program entered a trap at PC=%h",
                           prepared_dut.current_pc_mem);
                if (prepared_dut.valid_mem === 1'b1 &&
                    prepared_dut.current_pc_mem === HALT_PC &&
                    prepared_dut.Jump_mem === 1'b1)
                    prepared_done = 1'b1;
            end

            if (!unrolled_done) begin
                unrolled_cycles = unrolled_cycles + 1;
                if (unrolled_dut.trap_enter === 1'b1)
                    $fatal(1, "unrolled program entered a trap at PC=%h",
                           unrolled_dut.current_pc_mem);
                if (unrolled_dut.valid_mem === 1'b1 &&
                    unrolled_dut.current_pc_mem === HALT_PC &&
                    unrolled_dut.Jump_mem === 1'b1)
                    unrolled_done = 1'b1;
            end
        end

        if (!prepared_done)
            $fatal(1, "timeout: prepared program did not reach halt");
        if (!unrolled_done)
            $fatal(1, "timeout: unrolled program did not reach halt");

        if (prepared_dut.u_register.registers[10] !== EXPECTED_RETURN)
            $fatal(1, "prepared returned %0d, expected %0d",
                   prepared_dut.u_register.registers[10], EXPECTED_RETURN);
        if (unrolled_dut.u_register.registers[10] !== EXPECTED_RETURN)
            $fatal(1, "unrolled returned %0d, expected %0d",
                   unrolled_dut.u_register.registers[10], EXPECTED_RETURN);

        if (prepared_loads !== `PREPARED_EXPECTED_LOADS)
            $fatal(1, "reference completed %0d array loads, expected %0d",
                   prepared_loads, `PREPARED_EXPECTED_LOADS);
        if (unrolled_loads !== `UNROLLED_EXPECTED_LOADS)
            $fatal(1, "candidate completed %0d array loads, expected %0d",
                   unrolled_loads, `UNROLLED_EXPECTED_LOADS);

        if (prepared_dut.u_register.registers[2] !== EXPECTED_STACK_TOP)
            $fatal(1, "prepared stack pointer changed: %h",
                   prepared_dut.u_register.registers[2]);
        if (unrolled_dut.u_register.registers[2] !== EXPECTED_STACK_TOP)
            $fatal(1, "unrolled stack pointer changed: %h",
                   unrolled_dut.u_register.registers[2]);

        prepared_cpi = $itor(prepared_cycles) / $itor(prepared_retired);
        unrolled_cpi = $itor(unrolled_cycles) / $itor(unrolled_retired);
        cycle_change_percent =
            100.0 * $itor(unrolled_cycles - prepared_cycles) /
            $itor(prepared_cycles);
        instruction_change_percent =
            100.0 * $itor(unrolled_retired - prepared_retired) /
            $itor(prepared_retired);

        $display("Array-sum loop-unroll comparison (%s codegen):",
                 `CODEGEN_LABEL);
        $display("  Prepared: cycles=%0d retired=%0d CPI=%0.3f",
                 prepared_cycles, prepared_retired, prepared_cpi);
        $display("            I$ misses=%0d wait=%0d D$ stall=%0d",
                 prepared_icache_misses, prepared_icache_wait_cycles,
                 prepared_dcache_stall_cycles);
        $display("  Unrolled: cycles=%0d retired=%0d CPI=%0.3f",
                 unrolled_cycles, unrolled_retired, unrolled_cpi);
        $display("            I$ misses=%0d wait=%0d D$ stall=%0d",
                 unrolled_icache_misses, unrolled_icache_wait_cycles,
                 unrolled_dcache_stall_cycles);
        $display("  Cycle change      = %0.1f%%", cycle_change_percent);
        $display("  Instruction change= %0.1f%%", instruction_change_percent);
        $display("  Array loads: reference=%0d candidate=%0d",
                 prepared_loads, unrolled_loads);
        $display("PASS: both programs returned %0d.", EXPECTED_RETURN);
        $finish;
    end
endmodule

`undef PREPARED_HEX_PATH
`undef PREPARED_HEX_LAST
`undef UNROLLED_HEX_PATH
`undef UNROLLED_HEX_LAST
`undef CODEGEN_LABEL
`undef PREPARED_EXPECTED_LOADS
`undef UNROLLED_EXPECTED_LOADS
`ifdef SUM2W_COMPARE_MODE
`undef SUM2W_COMPARE_MODE
`endif
