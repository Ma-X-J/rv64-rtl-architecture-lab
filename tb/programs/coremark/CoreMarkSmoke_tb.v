`timescale 1ns/1ps

module CoreMarkSmoke_tb;
    reg clk;
    reg reset;
    integer i;
    integer cycles;
    integer retired;
    reg halt_seen;

    localparam [63:0] COREMARK_HALT_PC = 64'h0000_0000_0000_003c;
    localparam [63:0] MAILBOX_MAGIC = 64'h434f_5245_4d41_524b;
    localparam [63:0] STATUS_PASS = 64'd2;

    PIPELINED_CPU dut (
        .reset(reset),
        .clk(clk),
        .external_interrupt_pending(1'b0)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (reset)
            retired <= 0;
        else if (dut.valid_mem && !dut.dcache_stall)
            retired <= retired + 1;
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        cycles = 0;
        retired = 0;
        halt_seen = 1'b0;

        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'd0;
        for (i = 0; i < 2048; i = i + 1)
            dut.u_icache_backing_memory.memory[i] = 64'd0;
        for (i = 0; i < 1024; i = i + 1)
            dut.u_dcache_backing_memory.memory[i] = 64'd0;

        $readmemh("tb/fixtures/programs/coremark/imem.hex",
                  dut.u_icache_backing_memory.memory);
        $readmemh("tb/fixtures/programs/coremark/dmem.hex",
                  dut.u_dcache_backing_memory.memory);

        if (dut.u_dcache_backing_memory.memory[0] !== MAILBOX_MAGIC)
            $fatal(1, "CoreMark DMEM image/mailbox was not loaded");

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        while (cycles < 5_000_000 && !halt_seen) begin
            @(negedge clk);
            cycles = cycles + 1;
            if (dut.current_pc_if == COREMARK_HALT_PC &&
                dut.u_dcache_backing_memory.memory[1] != 64'd1)
                halt_seen = 1'b1;
        end

        if (!halt_seen)
            $fatal(1,
                   "CoreMark timeout: cycles=%0d retired=%0d pc=%h status=%0d",
                   cycles, retired, dut.current_pc_if,
                   dut.u_dcache_backing_memory.memory[1]);
        if (dut.u_dcache_backing_memory.memory[1] !== STATUS_PASS)
            $fatal(1, "CoreMark CRC validation failed: status=%0d",
                   dut.u_dcache_backing_memory.memory[1]);
        if (dut.u_dcache_backing_memory.memory[5] !== 64'd0)
            $fatal(1, "CoreMark main returned %0d",
                   dut.u_dcache_backing_memory.memory[5]);

        $display("PASS: CoreMark upstream CRC validation completed.");
        $display("  cycles=%0d retired_at_MEM=%0d mailbox_printf_calls=%0d",
                 cycles, retired, dut.u_dcache_backing_memory.memory[3]);
        $display("  Functional run only: fixed timer, not a reportable score.");
        $finish;
    end
endmodule
