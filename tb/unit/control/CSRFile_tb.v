`timescale 1ns/1ps

module CSRFile_tb;

    localparam [11:0] CSR_MSTATUS = 12'h300;
    localparam [11:0] CSR_MTVEC   = 12'h305;
    localparam [11:0] CSR_MEPC    = 12'h341;
    localparam [11:0] CSR_MCAUSE  = 12'h342;

    reg         clk;
    reg         reset;
    reg         trap_enter;
    reg  [63:0] trap_pc;
    reg  [63:0] trap_cause;
    reg         mret;
    reg         csr_we;
    reg  [11:0] csr_raddr;
    reg  [11:0] csr_waddr;
    reg  [63:0] csr_wdata;

    wire [63:0] csr_rdata;
    wire [63:0] mtvec_out;
    wire [63:0] mepc_out;
    wire [63:0] mcause_out;
    wire        global_interrupt_enable;

    CSRFile dut (
        .clk(clk),
        .reset(reset),
        .trap_enter(trap_enter),
        .trap_pc(trap_pc),
        .trap_cause(trap_cause),
        .mret(mret),
        .csr_we(csr_we),
        .csr_raddr(csr_raddr),
        .csr_waddr(csr_waddr),
        .csr_wdata(csr_wdata),
        .csr_rdata(csr_rdata),
        .mtvec_out(mtvec_out),
        .mepc_out(mepc_out),
        .mcause_out(mcause_out),
        .global_interrupt_enable(global_interrupt_enable)
    );

    always #5 clk = ~clk;

    task check64;
        input [63:0] actual;
        input [63:0] expected;
        input [511:0] description;
        begin
            if (actual !== expected)
                $fatal(1, "%0s: actual=%h expected=%h",
                       description, actual, expected);
        end
    endtask

    task check1;
        input actual;
        input expected;
        input [511:0] description;
        begin
            if (actual !== expected)
                $fatal(1, "%0s: actual=%b expected=%b",
                       description, actual, expected);
        end
    endtask

    task write_csr;
        input [11:0] address;
        input [63:0] data;
        begin
            @(negedge clk);
            csr_waddr = address;
            csr_wdata = data;
            csr_we    = 1'b1;
            @(posedge clk);
            #1;
            @(negedge clk);
            csr_we = 1'b0;
        end
    endtask

    task read_and_check;
        input [11:0] address;
        input [63:0] expected;
        input [511:0] description;
        begin
            csr_raddr = address;
            #1;
            check64(csr_rdata, expected, description);
        end
    endtask

    initial begin
        clk        = 1'b0;
        reset      = 1'b1;
        trap_enter = 1'b0;
        trap_pc    = 64'b0;
        trap_cause = 64'b0;
        mret       = 1'b0;
        csr_we     = 1'b0;
        csr_raddr  = 12'b0;
        csr_waddr  = 12'b0;
        csr_wdata  = 64'b0;

        // Synchronous reset values.
        @(posedge clk);
        #1;
        check64(mtvec_out, 64'h0000_0000_0000_0100, "reset mtvec");
        check64(mepc_out, 64'b0, "reset mepc");
        check64(mcause_out, 64'b0, "reset mcause");
        check1(global_interrupt_enable, 1'b0, "reset MIE");

        @(negedge clk);
        reset = 1'b0;

        $display("[PHASE] combinational CSR reads after reset");
        read_and_check(CSR_MSTATUS, 64'b0, "read reset mstatus");
        read_and_check(CSR_MTVEC, 64'h100, "read reset mtvec");
        read_and_check(CSR_MEPC, 64'b0, "read reset mepc");
        read_and_check(CSR_MCAUSE, 64'b0, "read reset mcause");
        read_and_check(12'hfff, 64'b0, "unsupported CSR read returns zero");

        $display("[PHASE] software CSR writes and address alignment");
        write_csr(CSR_MSTATUS, 64'hffff_ffff_ffff_ffff);
        read_and_check(CSR_MSTATUS, 64'h0000_0000_0000_0088,
                       "only implemented mstatus bits are writable");
        check1(global_interrupt_enable, 1'b1, "software enables MIE");

        write_csr(CSR_MTVEC, 64'h0000_0000_0000_0205);
        check64(mtvec_out, 64'h0000_0000_0000_0204,
                "mtvec low bits forced to zero");

        write_csr(CSR_MEPC, 64'h0000_0000_0000_0123);
        check64(mepc_out, 64'h0000_0000_0000_0120,
                "mepc low bits forced to zero");

        write_csr(CSR_MCAUSE, 64'h8000_0000_0000_000b);
        check64(mcause_out, 64'h8000_0000_0000_000b,
                "software writes mcause");

        write_csr(12'h999, 64'hffff_ffff_ffff_ffff);
        check64(mtvec_out, 64'h204, "unsupported write preserves mtvec");
        check64(mepc_out, 64'h120, "unsupported write preserves mepc");
        check64(mcause_out, 64'h8000_0000_0000_000b,
                "unsupported write preserves mcause");
        read_and_check(CSR_MSTATUS, 64'h88,
                       "unsupported write preserves mstatus");

        $display("[PHASE] independent CSR read and write addresses");
        @(negedge clk);
        csr_raddr = CSR_MSTATUS;
        csr_waddr = CSR_MCAUSE;
        csr_wdata = 64'h0000_0000_0000_0055;
        csr_we    = 1'b1;
        #1;
        check64(csr_rdata, 64'h88,
                "read address selects mstatus while write address differs");
        @(posedge clk);
        #1;
        check64(csr_rdata, 64'h88,
                "mstatus read remains selected during mcause write");
        check64(mcause_out, 64'h55,
                "write address independently selects mcause");
        @(negedge clk);
        csr_we = 1'b0;

        $display("[PHASE] trap entry saves state and disables interrupts");
        @(negedge clk);
        trap_pc    = 64'h0000_0000_0000_0088;
        trap_cause = 64'h0000_0000_0000_0002;
        trap_enter = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        trap_enter = 1'b0;

        check64(mepc_out, 64'h88, "trap saves trap_pc in mepc");
        check64(mcause_out, 64'h2, "trap saves trap_cause in mcause");
        read_and_check(CSR_MSTATUS, 64'h80,
                       "trap copies MIE to MPIE and clears MIE");
        check1(global_interrupt_enable, 1'b0, "trap disables interrupts");
        check64(mtvec_out, 64'h204, "trap preserves mtvec");

        $display("[PHASE] mret restores interrupt state");
        @(negedge clk);
        mret = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        mret = 1'b0;

        read_and_check(CSR_MSTATUS, 64'h88,
                       "mret restores MIE and sets MPIE");
        check1(global_interrupt_enable, 1'b1, "mret restores interrupts");
        check64(mepc_out, 64'h88, "mret preserves mepc");
        check64(mcause_out, 64'h2, "mret preserves mcause");

        $display("[PHASE] trap priority over mret and software write");
        @(negedge clk);
        trap_pc    = 64'h0000_0000_0000_0444;
        trap_cause = 64'h8000_0000_0000_000b;
        trap_enter = 1'b1;
        mret       = 1'b1;
        csr_we     = 1'b1;
        csr_waddr  = CSR_MTVEC;
        csr_wdata  = 64'h0000_0000_0000_0888;
        @(posedge clk);
        #1;
        @(negedge clk);
        trap_enter = 1'b0;
        mret       = 1'b0;
        csr_we     = 1'b0;

        check64(mepc_out, 64'h444, "trap wins and updates mepc");
        check64(mcause_out, 64'h8000_0000_0000_000b,
                "trap wins and updates mcause");
        check64(mtvec_out, 64'h204, "trap blocks simultaneous CSR write");
        read_and_check(CSR_MSTATUS, 64'h80,
                       "trap wins and saves interrupt state");

        $display("[PHASE] mret priority over software write");
        @(negedge clk);
        mret      = 1'b1;
        csr_we    = 1'b1;
        csr_waddr = CSR_MTVEC;
        csr_wdata = 64'h0000_0000_0000_0888;
        @(posedge clk);
        #1;
        @(negedge clk);
        mret   = 1'b0;
        csr_we = 1'b0;

        read_and_check(CSR_MSTATUS, 64'h88,
                       "mret wins and restores mstatus");
        check64(mtvec_out, 64'h204, "mret blocks simultaneous CSR write");

        $display("[PHASE] reset priority over all other operations");
        @(negedge clk);
        reset      = 1'b1;
        trap_enter = 1'b1;
        mret       = 1'b1;
        csr_we     = 1'b1;
        csr_waddr  = CSR_MCAUSE;
        csr_wdata  = 64'hffff_ffff_ffff_ffff;
        @(posedge clk);
        #1;

        check64(mtvec_out, 64'h100, "reset wins and restores mtvec");
        check64(mepc_out, 64'b0, "reset wins and clears mepc");
        check64(mcause_out, 64'b0, "reset wins and clears mcause");
        check1(global_interrupt_enable, 1'b0, "reset wins and clears MIE");

        $display("PASS: CSRFile reset, reads, writes, trap, mret, alignment, and priority checks passed.");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout: CSRFile testbench did not finish");
    end

endmodule
