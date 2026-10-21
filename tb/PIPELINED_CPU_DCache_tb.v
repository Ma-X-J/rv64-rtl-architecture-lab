`timescale 1ns/1ps

module PIPELINED_CPU_DCache_tb;
    reg clk;
    reg reset;
    integer i;
    integer cycle_count;
    integer cache_stall_cycles;
    integer cache_stall_episodes;
    integer backend_read_fires;
    integer backend_write_fires;
    integer cpu_request_fires;
    integer load_complete_count;
    integer x5_write_count;
    integer x6_write_count;
    integer x7_write_count;
    reg previous_cache_stall;

    reg stall_before_edge;
    reg [63:0] held_pc_if;
    reg [63:0] held_pc_id;
    reg [31:0] held_instruction_id;
    reg [63:0] held_pc_ex;
    reg [31:0] held_instruction_ex;
    reg [63:0] held_pc_mem;
    reg [31:0] held_instruction_mem;
    reg [63:0] held_address_mem;
    reg [63:0] held_store_data_mem;

    localparam [31:0] NOP = 32'h0000_0033;
    localparam [63:0] TEST_ADDRESS = 64'h0000_0000_0000_0108;
    localparam [63:0] BACKING_VALUE = 64'h1122_3344_5566_7788;
    localparam [63:0] STORE_VALUE = 64'haaaa_bbbb_cccc_dddd;

    PIPELINED_CPU dut (
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

    function [31:0] enc_s;
        input [11:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        begin
            enc_s = {imm[11:5], rs2, rs1, funct3,
                     imm[4:0], 7'b0100011};
        end
    endfunction

    // Store one 32-bit instruction in the 64-bit I-Cache backing memory.
    task write_instr;
        input integer instruction_index;
        input [31:0] instruction;
        integer backend_word_index;
        begin
            backend_word_index = instruction_index >> 1;
            if ((instruction_index & 1) == 0)
                dut.u_icache_backing_memory.memory[backend_word_index][31:0] = instruction;
            else
                dut.u_icache_backing_memory.memory[backend_word_index][63:32] = instruction;
        end
    endtask
    always @(posedge clk) begin
        if (reset) begin
            cycle_count <= 0;
            cache_stall_cycles <= 0;
            cache_stall_episodes <= 0;
            backend_read_fires <= 0;
            backend_write_fires <= 0;
            cpu_request_fires <= 0;
            load_complete_count <= 0;
            x5_write_count <= 0;
            x6_write_count <= 0;
            x7_write_count <= 0;
            previous_cache_stall <= 1'b0;
        end
        else begin
            cycle_count <= cycle_count + 1;

            if (dut.dcache_stall)
                cache_stall_cycles <= cache_stall_cycles + 1;

            if (dut.dcache_stall && !previous_cache_stall)
                cache_stall_episodes <= cache_stall_episodes + 1;

            previous_cache_stall <= dut.dcache_stall;

            if (dut.dcache_mem_req_valid && dut.dcache_mem_req_ready) begin
                if (dut.dcache_mem_req_write)
                    backend_write_fires <= backend_write_fires + 1;
                else
                    backend_read_fires <= backend_read_fires + 1;
            end

            if (dut.dcache_cpu_req_fire)
                cpu_request_fires <= cpu_request_fires + 1;

            if (dut.load_complete_mem)
                load_complete_count <= load_complete_count + 1;

            if (dut.Regwrite_wb && dut.instruction_wb[11:7] == 5'd5)
                x5_write_count <= x5_write_count + 1;
            if (dut.Regwrite_wb && dut.instruction_wb[11:7] == 5'd6)
                x6_write_count <= x6_write_count + 1;
            if (dut.Regwrite_wb && dut.instruction_wb[11:7] == 5'd7)
                x7_write_count <= x7_write_count + 1;
        end
    end

    // A cache stall must preserve every pipeline register at and before MEM.
    always @(posedge clk) begin
        stall_before_edge = !reset && dut.dcache_stall && !dut.control_flush_mem;
        held_pc_if = dut.current_pc_if;
        held_pc_id = dut.pc_id;
        held_instruction_id = dut.instruction_id;
        held_pc_ex = dut.current_pc_ex;
        held_instruction_ex = dut.instruction_ex;
        held_pc_mem = dut.current_pc_mem;
        held_instruction_mem = dut.instruction_mem;
        held_address_mem = dut.aluresult_mem;
        held_store_data_mem = dut.storedata_mem;

        #1;
        if (stall_before_edge) begin
            if (dut.current_pc_if !== held_pc_if)
                $fatal(1, "PC changed during cache stall");
            if (dut.pc_id !== held_pc_id ||
                dut.instruction_id !== held_instruction_id)
                $fatal(1, "IF/ID changed during cache stall");
            if (dut.current_pc_ex !== held_pc_ex ||
                dut.instruction_ex !== held_instruction_ex)
                $fatal(1, "ID/EX changed during cache stall");
            if (dut.current_pc_mem !== held_pc_mem ||
                dut.instruction_mem !== held_instruction_mem ||
                dut.aluresult_mem !== held_address_mem ||
                dut.storedata_mem !== held_store_data_mem)
                $fatal(1, "EX/MEM changed during cache stall");
        end
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        previous_cache_stall = 1'b0;

        for (i = 0; i < 32; i = i + 1)
            dut.u_register.registers[i] = 64'b0;
        for (i = 0; i < 256; i = i + 1) begin
            dut.u_icache_backing_memory.memory[i] = {NOP, NOP};
            dut.u_dcache_backing_memory.memory[i] = 64'b0;
        end

        // Address 0x108 is word 1 of the 32-byte line beginning at 0x100.
        dut.u_dcache_backing_memory.memory[8'h20] = 64'h0101_0101_0101_0101;
        dut.u_dcache_backing_memory.memory[8'h21] = BACKING_VALUE;
        dut.u_dcache_backing_memory.memory[8'h22] = 64'h0202_0202_0202_0202;
        dut.u_dcache_backing_memory.memory[8'h23] = 64'h0303_0303_0303_0303;

        dut.u_register.registers[10] = STORE_VALUE;

        write_instr(0, enc_i(12'h108, 5'd0, 3'b011, 5'd5,
                                7'b0000011)); // ld x5, 0x108(x0): miss
        write_instr(1, enc_i(12'd1, 5'd0, 3'b000, 5'd20,
                                7'b0010011)); // younger instruction
        write_instr(2, enc_i(12'h108, 5'd0, 3'b011, 5'd6,
                                7'b0000011)); // same-line Load: hit
        write_instr(3, enc_s(12'h108, 5'd10, 5'd0,
                                3'b011));     // write-through Store hit
        write_instr(4, enc_i(12'h108, 5'd0, 3'b011, 5'd7,
                                7'b0000011)); // Load updated cached word

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        begin : wait_for_completion
            integer timeout;
            timeout = 0;
            while ((x7_write_count == 0 || backend_write_fires == 0) &&
                   timeout < 200) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
            end
            if (timeout >= 200)
                $fatal(1, "timeout waiting for CPU-DCache sequence");
        end

        // Let the final WB edge and counters settle.
        repeat (3) begin
            @(posedge clk);
            #1;
        end

        if (dut.u_register.registers[5] !== BACKING_VALUE)
            $fatal(1, "first miss Load x5=%h expected=%h",
                   dut.u_register.registers[5], BACKING_VALUE);
        if (dut.u_register.registers[6] !== BACKING_VALUE)
            $fatal(1, "same-line hit Load x6=%h expected=%h",
                   dut.u_register.registers[6], BACKING_VALUE);
        if (dut.u_register.registers[7] !== STORE_VALUE)
            $fatal(1, "Load after Store x7=%h expected=%h",
                   dut.u_register.registers[7], STORE_VALUE);
        if (dut.u_register.registers[20] !== 64'd1)
            $fatal(1, "younger instruction was lost while pipeline stalled");

        if (dut.u_dcache_backing_memory.memory[8'h21] !== STORE_VALUE)
            $fatal(1, "write-through backing memory=%h expected=%h",
                   dut.u_dcache_backing_memory.memory[8'h21], STORE_VALUE);
        if (dut.u_dcache.valid_array[0] !== 1'b1 ||
            dut.u_dcache.tag_array[0] !== 56'h1 ||
            dut.u_dcache.data_array[0][1] !== STORE_VALUE)
            $fatal(1, "DCache line metadata/data incorrect after refill and Store");

        if (backend_read_fires !== 4)
            $fatal(1, "backend read requests=%0d expected=4",
                   backend_read_fires);
        if (backend_write_fires !== 1)
            $fatal(1, "backend write requests=%0d expected=1",
                   backend_write_fires);
        if (cpu_request_fires !== 4)
            $fatal(1, "CPU requests accepted=%0d expected=4",
                   cpu_request_fires);
        if (load_complete_count !== 3)
            $fatal(1, "completed Loads=%0d expected=3",
                   load_complete_count);
        if (x5_write_count !== 1 || x6_write_count !== 1 ||
            x7_write_count !== 1)
            $fatal(1, "Load WB counts x5=%0d x6=%0d x7=%0d expected=1 each",
                   x5_write_count, x6_write_count, x7_write_count);
        if (cache_stall_episodes !== 2)
            $fatal(1, "cache stall episodes=%0d expected=2 (miss and Store)",
                   cache_stall_episodes);
        if (cache_stall_cycles <= 2)
            $fatal(1, "cache stall duration unexpectedly short: %0d cycles",
                   cache_stall_cycles);

        $display("[PASS] CPU-DCache integration");
        $display("       cycles=%0d stall_cycles=%0d stall_episodes=%0d",
                 cycle_count, cache_stall_cycles, cache_stall_episodes);
        $display("       backend_reads=%0d backend_writes=%0d cpu_requests=%0d",
                 backend_read_fires, backend_write_fires, cpu_request_fires);
        $finish;
    end

endmodule
