`timescale 1ns/1ps

module CLANG_INT_ADD_tb;
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
    localparam [63:0] HALT_PC = 64'h0000_0000_0000_000c;
    localparam [63:0] EXPECTED_MAIN_RETURN = 64'd42;
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

        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'd0;

        for (i = 0; i < 256; i = i + 1) begin
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            dut.u_dcache_backing_memory.memory[i] = 64'd0;
        end

        // program.bin is 56 bytes, so program.hex contains seven 64-bit words.
        $readmemh("tb/fixtures/programs/int_add/program.hex",
                  dut.u_icache_backing_memory.memory, 0, 6);

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        while (!halt_seen && cycle_count < 1000) begin
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
            if (dut.valid_mem === 1'b1 &&
                dut.current_pc_mem === HALT_PC &&
                dut.Jump_mem === 1'b1)
                halt_seen = 1'b1;
        end

        if (!halt_seen)
            $fatal(1, "timeout: int_add program did not reach halt at PC 0xC");

        if (dut.u_register.registers[10] !== EXPECTED_MAIN_RETURN)
            $fatal(1,
                   "main returned %0d (0x%016h), expected %0d",
                   dut.u_register.registers[10],
                   dut.u_register.registers[10],
                   EXPECTED_MAIN_RETURN);

        if (dut.u_register.registers[2] !== EXPECTED_STACK_TOP)
            $fatal(1, "stack pointer was not restored: sp=%h expected=%h",
                   dut.u_register.registers[2], EXPECTED_STACK_TOP);

        // main saves its caller's return address (halt at 0x0C) at
        // sp-8 = 0x7F8 before the later call to add changes ra to 0x2C.
        if (dut.u_dcache_backing_memory.memory[255] !== 64'h0c)
            $fatal(1, "stack save is incorrect: memory[0x7F8]=%h expected=0x0C",
                   dut.u_dcache_backing_memory.memory[255]);

        cpi = $itor(cycle_count) / $itor(retired_instruction_count);
        $display("Performance counters (int_add):");
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
        $display("PASS: Clang int_add returned %0d, restored sp, and preserved its stack save.",
                 dut.u_register.registers[10]);
        $finish;
    end
endmodule
