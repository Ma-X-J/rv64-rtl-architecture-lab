`timescale 1ns/1ps

module CLANG_BRANCH_PREDICTOR_BENCH_tb #(
    parameter PREDICTOR_MODE = 0
);
    reg clk;
    reg reset;
    integer i;
    integer cycle_count;
    integer retired_instruction_count;
    integer branch_count;
    integer branch_taken_count;
    integer branch_mispredict_count;
    integer correlated_a_count;
    integer correlated_a_miss;
    integer correlated_b_count;
    integer correlated_b_miss;
    integer noisy_run_count;
    integer noisy_run_miss;
    integer noise0_count;
    integer noise0_miss;
    integer noise1_count;
    integer noise1_miss;
    integer icache_miss_count;
    integer dcache_miss_count;
    integer icache_wait_cycles;
    integer dcache_stall_cycles;
    real cpi;
    real branch_prediction_accuracy;
    reg halt_seen;

    localparam [31:0] NOP = 32'h00000013;
    localparam [63:0] HALT_PC = 64'h0000_0000_0000_000c;
    localparam [63:0] EXPECTED_MAIN_RETURN = 64'd0;
    localparam [63:0] EXPECTED_STACK_TOP = 64'h0000_0000_0000_0800;

    // Key conditional-branch PCs verified against program.disasm.txt.
    localparam [63:0] CORRELATED_A_PC = 64'h0000_0000_0000_0084;
    localparam [63:0] CORRELATED_B_PC = 64'h0000_0000_0000_00a8;
    localparam [63:0] NOISE0_PC       = 64'h0000_0000_0000_0118;
    localparam [63:0] NOISE1_PC       = 64'h0000_0000_0000_0148;
    localparam [63:0] NOISY_RUN_PC    = 64'h0000_0000_0000_016c;

    PIPELINED_CPU #(
        .BRANCH_PREDICTOR_MODE(PREDICTOR_MODE),
        .DCACHE_BACKING_BASE_ADDR(64'h0)
    ) dut (
        .reset(reset),
        .clk(clk),
        .external_interrupt_pending(1'b0)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            retired_instruction_count = 0;
            branch_count = 0;
            branch_taken_count = 0;
            branch_mispredict_count = 0;
            correlated_a_count = 0;
            correlated_a_miss = 0;
            correlated_b_count = 0;
            correlated_b_miss = 0;
            noisy_run_count = 0;
            noisy_run_miss = 0;
            noise0_count = 0;
            noise0_miss = 0;
            noise1_count = 0;
            noise1_miss = 0;
            icache_miss_count = 0;
            dcache_miss_count = 0;
            icache_wait_cycles = 0;
            dcache_stall_cycles = 0;
        end
        else begin
            if (dut.u_icache.cpu_instr_miss_fire === 1'b1)
                icache_miss_count = icache_miss_count + 1;
            if (dut.u_dcache.cpu_load_miss_fire === 1'b1)
                dcache_miss_count = dcache_miss_count + 1;
            if (dut.icache_cpu_req_valid === 1'b1 &&
                dut.icache_resp_usable !== 1'b1)
                icache_wait_cycles = icache_wait_cycles + 1;
            if (dut.dcache_stall === 1'b1)
                dcache_stall_cycles = dcache_stall_cycles + 1;

            if (dut.valid_mem === 1'b1 &&
                dut.MEM_WB_write_final === 1'b1 &&
                dut.trap_enter !== 1'b1 &&
                dut.current_pc_mem !== HALT_PC) begin
                retired_instruction_count = retired_instruction_count + 1;

                if (dut.Branch_mem === 1'b1) begin
                    branch_count = branch_count + 1;
                    if (dut.branch_taken_mem === 1'b1)
                        branch_taken_count = branch_taken_count + 1;
                    if (dut.branch_mispredict_mem === 1'b1)
                        branch_mispredict_count = branch_mispredict_count + 1;

                    case (dut.current_pc_mem)
                        CORRELATED_A_PC: begin
                            correlated_a_count = correlated_a_count + 1;
                            if (dut.branch_mispredict_mem === 1'b1)
                                correlated_a_miss = correlated_a_miss + 1;
                        end
                        CORRELATED_B_PC: begin
                            correlated_b_count = correlated_b_count + 1;
                            if (dut.branch_mispredict_mem === 1'b1)
                                correlated_b_miss = correlated_b_miss + 1;
                        end
                        NOISE0_PC: begin
                            noise0_count = noise0_count + 1;
                            if (dut.branch_mispredict_mem === 1'b1)
                                noise0_miss = noise0_miss + 1;
                        end
                        NOISE1_PC: begin
                            noise1_count = noise1_count + 1;
                            if (dut.branch_mispredict_mem === 1'b1)
                                noise1_miss = noise1_miss + 1;
                        end
                        NOISY_RUN_PC: begin
                            noisy_run_count = noisy_run_count + 1;
                            if (dut.branch_mispredict_mem === 1'b1)
                                noisy_run_miss = noisy_run_miss + 1;
                        end
                    endcase
                end
            end
        end
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        halt_seen = 1'b0;
        cycle_count = 0;
        retired_instruction_count = 0;
        branch_count = 0;
        branch_taken_count = 0;
        branch_mispredict_count = 0;
        correlated_a_count = 0;
        correlated_a_miss = 0;
        correlated_b_count = 0;
        correlated_b_miss = 0;
        noisy_run_count = 0;
        noisy_run_miss = 0;
        noise0_count = 0;
        noise0_miss = 0;
        noise1_count = 0;
        noise1_miss = 0;
        icache_miss_count = 0;
        dcache_miss_count = 0;
        icache_wait_cycles = 0;
        dcache_stall_cycles = 0;
        cpi = 0.0;
        branch_prediction_accuracy = 0.0;

        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'd0;

        for (i = 0; i < 256; i = i + 1) begin
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            dut.u_dcache_backing_memory.memory[i] = 64'd0;
        end

        $readmemh("tb/fixtures/programs/branch_predictor/program.hex",
                  dut.u_icache_backing_memory.memory, 0, 50);
        $readmemh("tb/fixtures/programs/branch_predictor/program.hex",
                  dut.u_dcache_backing_memory.memory, 0, 50);

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        while (!halt_seen && cycle_count < 200000) begin
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
            if (dut.valid_mem === 1'b1 &&
                dut.current_pc_mem === HALT_PC &&
                dut.Jump_mem === 1'b1)
                halt_seen = 1'b1;
        end

        if (!halt_seen)
            $fatal(1, "timeout: branch benchmark did not reach halt");

        if (dut.u_register.registers[10] !== EXPECTED_MAIN_RETURN)
            $fatal(1,
                   "benchmark returned %0d (0x%016h), expected %0d",
                   dut.u_register.registers[10],
                   dut.u_register.registers[10],
                   EXPECTED_MAIN_RETURN);

        if (dut.u_register.registers[2] !== EXPECTED_STACK_TOP)
            $fatal(1, "stack pointer changed: sp=%h expected=%h",
                   dut.u_register.registers[2], EXPECTED_STACK_TOP);

        if (correlated_a_count !== 512 || correlated_b_count !== 512 ||
            noisy_run_count !== 512 || noise0_count !== 512 ||
            noise1_count !== 512)
            $fatal(1,
                   "key branch counts A=%0d B=%0d noise0=%0d noise1=%0d run=%0d",
                   correlated_a_count, correlated_b_count,
                   noise0_count, noise1_count, noisy_run_count);

        cpi = $itor(cycle_count) / $itor(retired_instruction_count);
        branch_prediction_accuracy =
            100.0 * $itor(branch_count - branch_mispredict_count) /
            $itor(branch_count);

        $display("Branch predictor benchmark (mode %0d):", PREDICTOR_MODE);
        $display("  Cycles                 = %0d", cycle_count);
        $display("  Retired instructions   = %0d", retired_instruction_count);
        $display("  CPI                    = %0.3f", cpi);
        $display("  Conditional branches   = %0d", branch_count);
        $display("  Taken branches         = %0d", branch_taken_count);
        $display("  Total mispredictions   = %0d (accuracy %0.2f%%)",
                 branch_mispredict_count, branch_prediction_accuracy);
        $display("  Correlated A misses    = %0d / %0d",
                 correlated_a_miss, correlated_a_count);
        $display("  Correlated B misses    = %0d / %0d",
                 correlated_b_miss, correlated_b_count);
        $display("  Noise branch 0 misses  = %0d / %0d",
                 noise0_miss, noise0_count);
        $display("  Noise branch 1 misses  = %0d / %0d",
                 noise1_miss, noise1_count);
        $display("  Run-biased misses      = %0d / %0d",
                 noisy_run_miss, noisy_run_count);
        $display("  I-Cache misses         = %0d", icache_miss_count);
        $display("  D-Cache load misses    = %0d", dcache_miss_count);
        $display("  I-Cache wait cycles    = %0d", icache_wait_cycles);
        $display("  D-Cache stall cycles   = %0d", dcache_stall_cycles);
        $display("PASS: RV64I branch predictor benchmark completed.");
        $finish;
    end
endmodule
