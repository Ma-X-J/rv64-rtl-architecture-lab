`timescale 1ns/1ps

// Full-pipeline integration test for the custom SUM2W instruction.
//
// Program:
//   addi   x1,  x0, 10
//   addi   x2,  x0, 12
//   slli   x2,  x2, 32
//   addi   x2,  x2, 20       // x2 = {32'd12, 32'd20}
//   sum2w x10,  x1, x2       // x10 = 10 + 20 + 12 = 42
//   addi  x11, x10, 1        // x11 = 43; checks SUM2W result forwarding
//   jal    x0,   0            // halt loop
//
// The instruction-fetch net is forced from this small program ROM.  The
// complete CPU pipeline, decode, forwarding, ALU and write-back paths remain
// active; only the external program image source is replaced by the TB ROM.
module SUM2W_PIPELINE_tb;
    reg clk;
    reg reset;

    reg [31:0] program_rom [0:6];
    reg [31:0] tb_instruction;

    integer cycles;
    integer errors;
    reg saw_sum2w_writeback;
    reg saw_dependent_writeback;

    PIPELINED_CPU #(.DCACHE_BACKING_BASE_ADDR(64'h0)) dut (
        .clk   (clk),
        .reset (reset)
    );

    always #5 clk = ~clk;

    // Convert the byte PC into a word index.  Unknown/out-of-range addresses
    // receive the self-loop instruction so the test remains deterministic.
    always @(*) begin
        case (dut.current_pc_if[4:2])
            3'd0: tb_instruction = program_rom[0];
            3'd1: tb_instruction = program_rom[1];
            3'd2: tb_instruction = program_rom[2];
            3'd3: tb_instruction = program_rom[3];
            3'd4: tb_instruction = program_rom[4];
            3'd5: tb_instruction = program_rom[5];
            3'd6: tb_instruction = program_rom[6];
            default: tb_instruction = 32'h0000006f;
        endcase
    end

    // Observe architectural write-back instead of peeking into the register
    // array.  This checks the same value that is actually presented to rd.
    always @(posedge clk) begin
        if (!reset) begin
            cycles <= cycles + 1;

            if (dut.Regwrite_wb && (dut.instruction_wb[11:7] == 5'd10)) begin
                saw_sum2w_writeback <= 1'b1;
                if (dut.writedata_wb !== 64'd42) begin
                    $display("FAIL: SUM2W wrote x10=%h, expected 000000000000002a",
                             dut.writedata_wb);
                    errors <= errors + 1;
                end
                else begin
                    $display("PASS: SUM2W wrote x10=42 at cycle %0d", cycles);
                end
            end

            if (dut.Regwrite_wb && (dut.instruction_wb[11:7] == 5'd11)) begin
                saw_dependent_writeback <= 1'b1;
                if (dut.writedata_wb !== 64'd43) begin
                    $display("FAIL: dependent ADDI wrote x11=%h, expected 000000000000002b",
                             dut.writedata_wb);
                    errors <= errors + 1;
                end
                else begin
                    $display("PASS: dependent ADDI wrote x11=43 at cycle %0d", cycles);
                end
            end
        end
    end

    initial begin
        clk  = 1'b0;
        reset = 1'b1;
        cycles = 0;
        errors = 0;
        saw_sum2w_writeback = 1'b0;
        saw_dependent_writeback = 1'b0;

        program_rom[0] = 32'h00a00093; // addi x1,  x0, 10
        program_rom[1] = 32'h00c00113; // addi x2,  x0, 12
        program_rom[2] = 32'h02011113; // slli x2,  x2, 32
        program_rom[3] = 32'h01410113; // addi x2,  x2, 20
        program_rom[4] = 32'h0020850b; // sum2w x10, x1, x2
        program_rom[5] = 32'h00150593; // addi x11, x10, 1
        program_rom[6] = 32'h0000006f; // jal x0, 0

        // Override only the fetched instruction.  This avoids depending on a
        // particular backing-memory hierarchy in the integration test.
        force dut.instruction_if = tb_instruction;

        repeat (4) @(posedge clk);
        reset = 1'b0;

        repeat (300) begin
            @(posedge clk);
            if (saw_sum2w_writeback && saw_dependent_writeback) begin
                if (errors == 0)
                    $display("SUM2W_PIPELINE_tb PASS");
                else
                    $display("SUM2W_PIPELINE_tb FAIL: %0d error(s)", errors);
                release dut.instruction_if;
                $finish;
            end
        end

        if (!saw_sum2w_writeback)
            $display("FAIL: timeout waiting for SUM2W write-back to x10");
        if (!saw_dependent_writeback)
            $display("FAIL: timeout waiting for dependent write-back to x11");
        $display("SUM2W_PIPELINE_tb FAIL: timeout after %0d cycles", cycles);
        release dut.instruction_if;
        $finish;
    end
endmodule
