`timescale 1ns/1ps

module CLANG_FIBONACCI_tb;
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
    integer call_depth;
    integer argument_stack [0:31];
    reg [63:0] saved_s0_stack [0:31];
    reg [63:0] saved_s1_stack [0:31];
    reg [63:0] saved_ra_stack [0:31];
    real cpi;
    real dcache_miss_rate;
    real branch_prediction_accuracy;
    reg halt_seen;

    localparam [31:0] NOP = 32'h00000013; // addi x0, x0, 0
    localparam [63:0] HALT_PC = 64'h0000_0000_0000_000c;
    localparam [63:0] EXPECTED_MAIN_RETURN = 64'd55;
    localparam [63:0] EXPECTED_STACK_TOP = 64'h0000_0000_0000_0800;

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

    function integer reference_fib;
        input integer n;
        integer a;
        integer b;
        integer next_value;
        integer index;
        begin
            a = 0;
            b = 1;
            for (index = 0; index < n; index = index + 1) begin
                next_value = a + b;
                a = b;
                b = next_value;
            end
            reference_fib = a;
        end
    endfunction

    // Track architectural entries and returns of fib. This identifies the
    // first incorrect recursive result instead of reporting only main's value.
    always @(posedge clk) begin
        if (reset) begin
            call_depth = 0;
        end
        else begin
            #1;
            if (dut.valid_mem === 1'b1 &&
                dut.current_pc_mem === 64'h10) begin
                argument_stack[call_depth] = dut.u_register.registers[10];
                saved_s0_stack[call_depth] = dut.u_register.registers[8];
                saved_s1_stack[call_depth] = dut.u_register.registers[9];
                saved_ra_stack[call_depth] = dut.u_register.registers[1];
                call_depth = call_depth + 1;
            end

            if (dut.valid_mem === 1'b1 &&
                dut.current_pc_mem === 64'h20) begin
                if (call_depth <= 0)
                    $fatal(1, "fib s0 store observed with an empty call stack");
                if (dut.storedata_mem !== saved_s0_stack[call_depth - 1])
                    $fatal(1,
                           "fib(%0d) stores wrong s0 at address %h: data=%h expected=%h",
                           argument_stack[call_depth - 1],
                           dut.aluresult_mem,
                           dut.storedata_mem,
                           saved_s0_stack[call_depth - 1]);
            end

            if (dut.valid_mem === 1'b1 &&
                dut.current_pc_mem === 64'h4c &&
                dut.load_complete_mem === 1'b1) begin
                if (call_depth <= 0)
                    $fatal(1, "fib s0 load observed with an empty call stack");
                if (dut.mem_readdata_mem !== saved_s0_stack[call_depth - 1])
                    $fatal(1,
                           "fib(%0d) loads wrong s0 from address %h: load=%h backend=%h expected=%h",
                           argument_stack[call_depth - 1],
                           dut.aluresult_mem,
                           dut.mem_readdata_mem,
                           dut.u_dcache_backing_memory.memory[dut.aluresult_mem[10:3]],
                           saved_s0_stack[call_depth - 1]);
            end

            if (dut.valid_mem === 1'b1 &&
                dut.current_pc_mem === 64'h58) begin
                if (call_depth <= 0)
                    $fatal(1, "fib return observed with an empty call stack");
                call_depth = call_depth - 1;
                if (dut.u_register.registers[8] !== saved_s0_stack[call_depth])
                    $fatal(1,
                           "fib(%0d) did not restore s0: got %h expected %h",
                           argument_stack[call_depth],
                           dut.u_register.registers[8],
                           saved_s0_stack[call_depth]);
                if (dut.u_register.registers[9] !== saved_s1_stack[call_depth])
                    $fatal(1,
                           "fib(%0d) did not restore s1: got %h expected %h",
                           argument_stack[call_depth],
                           dut.u_register.registers[9],
                           saved_s1_stack[call_depth]);
                if (dut.u_register.registers[1] !== saved_ra_stack[call_depth])
                    $fatal(1,
                           "fib(%0d) did not restore ra: got %h expected %h",
                           argument_stack[call_depth],
                           dut.u_register.registers[1],
                           saved_ra_stack[call_depth]);
                if (dut.u_register.registers[10] !==
                    reference_fib(argument_stack[call_depth]))
                    $fatal(1,
                           "first incorrect recursive result: fib(%0d) returned %0d, expected %0d",
                           argument_stack[call_depth],
                           dut.u_register.registers[10],
                           reference_fib(argument_stack[call_depth]));
            end
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
        call_depth = 0;
        cpi = 0.0;
        dcache_miss_rate = 0.0;
        branch_prediction_accuracy = 0.0;

        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'd0;

        for (i = 0; i < 256; i = i + 1) begin
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            dut.u_dcache_backing_memory.memory[i] = 64'd0;
        end

        // program.bin is 120 bytes, so program.hex has fifteen 64-bit words.
        $readmemh("tb/fixtures/programs/fibonacci/program.hex",
                  dut.u_icache_backing_memory.memory, 0, 14);

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        while (!halt_seen && cycle_count < 100000) begin
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
            if (dut.valid_mem === 1'b1 &&
                dut.current_pc_mem === HALT_PC &&
                dut.Jump_mem === 1'b1)
                halt_seen = 1'b1;
        end

        if (!halt_seen)
            $fatal(1, "timeout: Fibonacci program did not reach halt at PC 0xC");

        if (dut.u_register.registers[10] !== EXPECTED_MAIN_RETURN)
            $fatal(1,
                   "fib(10) returned %0d (0x%016h), expected %0d",
                   dut.u_register.registers[10],
                   dut.u_register.registers[10],
                   EXPECTED_MAIN_RETURN);

        if (dut.u_register.registers[2] !== EXPECTED_STACK_TOP)
            $fatal(1, "stack pointer was not restored: sp=%h expected=%h",
                   dut.u_register.registers[2], EXPECTED_STACK_TOP);

        cpi = $itor(cycle_count) / $itor(retired_instruction_count);
        dcache_miss_rate = 100.0 * $itor(dcache_miss_count) /
                           $itor(dcache_load_count);
        branch_prediction_accuracy =
            100.0 * $itor(branch_count - branch_mispredict_count) /
            $itor(branch_count);
        $display("Performance counters (fibonacci):");
        $display("  Cycles               = %0d", cycle_count);
        $display("  Retired instructions = %0d", retired_instruction_count);
        $display("  CPI                  = %0.3f", cpi);
        $display("  I-Cache misses       = %0d", icache_miss_count);
        $display("  D-Cache load misses  = %0d / %0d (%0.1f%%)",
                 dcache_miss_count, dcache_load_count, dcache_miss_rate);
        $display("  I-Cache wait cycles  = %0d", icache_wait_cycles);
        $display("  D-Cache stall cycles = %0d", dcache_stall_cycles);
        $display("  Load-use stall cycles= %0d", load_use_stall_cycles);
        $display("  Taken branches       = %0d / %0d", branch_taken_count,
                 branch_count);
        $display("  Branch mispredictions= %0d / %0d (accuracy %0.1f%%)",
                 branch_mispredict_count, branch_count,
                 branch_prediction_accuracy);
        $display("PASS: recursive Clang Fibonacci returned %0d and restored sp.",
                 dut.u_register.registers[10]);
        $finish;
    end
endmodule
