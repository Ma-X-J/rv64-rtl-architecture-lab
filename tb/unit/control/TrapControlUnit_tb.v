`timescale 1ns/1ps

module TrapControlUnit_tb;

    localparam [63:0] CAUSE_INSTRUCTION_MISALIGNED = 64'h0;
    localparam [63:0] CAUSE_ILLEGAL_INSTRUCTION    = 64'h2;
    localparam [63:0] CAUSE_LOAD_MISALIGNED        = 64'h4;
    localparam [63:0] CAUSE_STORE_MISALIGNED       = 64'h6;
    localparam [63:0] CAUSE_ECALL_MMODE            = 64'hB;
    localparam [63:0] CAUSE_EXTERNAL_INTERRUPT     = 64'h8000_0000_0000_000B;

    reg         valid_mem;
    reg  [63:0] pc_mem;
    reg         external_interrupt_pending;
    reg         global_interrupt_enable;
    reg         instruction_misaligned_mem;
    reg         illegal_instruction_mem;
    reg         load_misaligned_mem;
    reg         store_misaligned_mem;
    reg         ecall_mem;

    wire        trap_enter;
    wire [63:0] trap_pc;
    wire [63:0] trap_cause;

    TrapControlUnit dut (
        .valid_mem(valid_mem),
        .pc_mem(pc_mem),
        .external_interrupt_pending(external_interrupt_pending),
        .global_interrupt_enable(global_interrupt_enable),
        .instruction_misaligned_mem(instruction_misaligned_mem),
        .illegal_instruction_mem(illegal_instruction_mem),
        .load_misaligned_mem(load_misaligned_mem),
        .store_misaligned_mem(store_misaligned_mem),
        .ecall_mem(ecall_mem),
        .trap_enter(trap_enter),
        .trap_pc(trap_pc),
        .trap_cause(trap_cause)
    );

    task clear_events;
        begin
            external_interrupt_pending = 1'b0;
            global_interrupt_enable     = 1'b0;
            instruction_misaligned_mem  = 1'b0;
            illegal_instruction_mem     = 1'b0;
            load_misaligned_mem          = 1'b0;
            store_misaligned_mem         = 1'b0;
            ecall_mem                    = 1'b0;
        end
    endtask

    task check_outputs;
        input         expected_enter;
        input [63:0]  expected_pc;
        input [63:0]  expected_cause;
        input [511:0] description;
        begin
            #1;
            if (trap_enter !== expected_enter ||
                trap_pc    !== expected_pc    ||
                trap_cause !== expected_cause) begin
                $fatal(1,
                    "%0s: enter=%b/%b pc=%h/%h cause=%h/%h",
                    description,
                    trap_enter, expected_enter,
                    trap_pc, expected_pc,
                    trap_cause, expected_cause);
            end
        end
    endtask

    initial begin
        valid_mem = 1'b0;
        pc_mem    = 64'h0000_0000_0000_0100;
        clear_events;

        $display("[PHASE] invalid entry and normal instruction");
        instruction_misaligned_mem = 1'b1;
        external_interrupt_pending = 1'b1;
        global_interrupt_enable    = 1'b1;
        check_outputs(1'b0, 64'b0, 64'b0,
                      "invalid MEM entry must never enter trap");

        clear_events;
        valid_mem = 1'b1;
        check_outputs(1'b0, 64'b0, 64'b0,
                      "valid normal instruction must not enter trap");

        $display("[PHASE] individual synchronous exceptions");
        pc_mem = 64'h0000_0000_0000_0200;
        instruction_misaligned_mem = 1'b1;
        check_outputs(1'b1, pc_mem, CAUSE_INSTRUCTION_MISALIGNED,
                      "instruction-address-misaligned exception");

        clear_events;
        illegal_instruction_mem = 1'b1;
        check_outputs(1'b1, pc_mem, CAUSE_ILLEGAL_INSTRUCTION,
                      "illegal-instruction exception");

        clear_events;
        ecall_mem = 1'b1;
        check_outputs(1'b1, pc_mem, CAUSE_ECALL_MMODE,
                      "machine-mode ECALL exception");

        clear_events;
        load_misaligned_mem = 1'b1;
        check_outputs(1'b1, pc_mem, CAUSE_LOAD_MISALIGNED,
                      "load-address-misaligned exception");

        clear_events;
        store_misaligned_mem = 1'b1;
        check_outputs(1'b1, pc_mem, CAUSE_STORE_MISALIGNED,
                      "store-address-misaligned exception");

        $display("[PHASE] external interrupt qualification");
        clear_events;
        external_interrupt_pending = 1'b1;
        check_outputs(1'b0, 64'b0, 64'b0,
                      "pending interrupt is blocked while MIE is zero");

        clear_events;
        global_interrupt_enable = 1'b1;
        check_outputs(1'b0, 64'b0, 64'b0,
                      "MIE alone does not create an interrupt");

        external_interrupt_pending = 1'b1;
        check_outputs(1'b1, pc_mem, CAUSE_EXTERNAL_INTERRUPT,
                      "enabled pending external interrupt enters trap");

        $display("[PHASE] trap priority");
        clear_events;
        instruction_misaligned_mem  = 1'b1;
        illegal_instruction_mem     = 1'b1;
        ecall_mem                    = 1'b1;
        load_misaligned_mem          = 1'b1;
        store_misaligned_mem         = 1'b1;
        external_interrupt_pending  = 1'b1;
        global_interrupt_enable      = 1'b1;
        check_outputs(1'b1, pc_mem, CAUSE_INSTRUCTION_MISALIGNED,
                      "instruction misalignment has highest priority");

        instruction_misaligned_mem = 1'b0;
        check_outputs(1'b1, pc_mem, CAUSE_ILLEGAL_INSTRUCTION,
                      "illegal instruction has second priority");

        illegal_instruction_mem = 1'b0;
        check_outputs(1'b1, pc_mem, CAUSE_ECALL_MMODE,
                      "ECALL has priority over memory exceptions and interrupt");

        ecall_mem = 1'b0;
        check_outputs(1'b1, pc_mem, CAUSE_LOAD_MISALIGNED,
                      "load misalignment has priority over store and interrupt");

        load_misaligned_mem = 1'b0;
        check_outputs(1'b1, pc_mem, CAUSE_STORE_MISALIGNED,
                      "store misalignment has priority over external interrupt");

        store_misaligned_mem = 1'b0;
        check_outputs(1'b1, pc_mem, CAUSE_EXTERNAL_INTERRUPT,
                      "external interrupt is selected after synchronous exceptions");

        $display("PASS: TrapControlUnit normal, exception, interrupt, valid, PC, cause, and priority checks passed.");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout: TrapControlUnit testbench did not finish");
    end

endmodule
