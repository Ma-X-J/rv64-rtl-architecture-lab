`timescale 1ns/1ps

module BranchPredictionTournamentUnit_tb;
    reg clk;
    reg reset;

    reg [63:0] pc_if;
    reg [31:0] instruction_if;
    reg        branch_mem;
    reg        branch_taken_mem;

    reg [3:0] bht_index_mem_bht;
    reg [5:0] global_index_mem_bht;
    reg       bimodal_prediction_mem_bht;
    reg       global_prediction_mem_bht;

    reg [3:0] bht_index_mem_global;
    reg [5:0] global_index_mem_global;
    reg       bimodal_prediction_mem_global;
    reg       global_prediction_mem_global;

    reg [3:0] bht_index_mem_tournament;
    reg [5:0] global_index_mem_tournament;
    reg       bimodal_prediction_mem_tournament;
    reg       global_prediction_mem_tournament;

    wire predicted_taken_bht;
    wire [3:0] bht_index_if_bht;
    wire [5:0] global_index_if_bht;
    wire bimodal_prediction_if_bht;
    wire global_prediction_if_bht;
    wire chooser_prefers_global_if_bht;

    wire predicted_taken_global;
    wire [3:0] bht_index_if_global;
    wire [5:0] global_index_if_global;
    wire bimodal_prediction_if_global;
    wire global_prediction_if_global;
    wire chooser_prefers_global_if_global;

    wire predicted_taken_tournament;
    wire [3:0] bht_index_if_tournament;
    wire [5:0] global_index_if_tournament;
    wire bimodal_prediction_if_tournament;
    wire global_prediction_if_tournament;
    wire chooser_prefers_global_if_tournament;

    integer iteration;
    integer bht_b_misses;
    integer global_b_misses;
    integer tournament_b_misses;

    localparam [31:0] BRANCH_INSTRUCTION = 32'h00000063;
    localparam [31:0] NOP_INSTRUCTION    = 32'h00000013;
    localparam [63:0] BRANCH_A_PC = 64'h0000_0000_0000_0040;
    localparam [63:0] BRANCH_B_PC = 64'h0000_0000_0000_0044;
    localparam [63:0] CHOOSER_PC  = 64'h0000_0000_0000_0048;

    BranchPredictionUnit #(
        .PREDICTOR_MODE(0)
    ) dut_bht (
        .clk(clk),
        .reset(reset),
        .pc_if(pc_if),
        .instruction_if(instruction_if),
        .branch_mem(branch_mem),
        .branch_taken_mem(branch_taken_mem),
        .bht_index_mem(bht_index_mem_bht),
        .global_index_mem(global_index_mem_bht),
        .bimodal_prediction_mem(bimodal_prediction_mem_bht),
        .global_prediction_mem(global_prediction_mem_bht),
        .predicted_taken_if(predicted_taken_bht),
        .bht_index_if(bht_index_if_bht),
        .global_index_if(global_index_if_bht),
        .bimodal_prediction_if(bimodal_prediction_if_bht),
        .global_prediction_if(global_prediction_if_bht),
        .chooser_prefers_global_if(chooser_prefers_global_if_bht)
    );

    BranchPredictionUnit #(
        .PREDICTOR_MODE(1)
    ) dut_global (
        .clk(clk),
        .reset(reset),
        .pc_if(pc_if),
        .instruction_if(instruction_if),
        .branch_mem(branch_mem),
        .branch_taken_mem(branch_taken_mem),
        .bht_index_mem(bht_index_mem_global),
        .global_index_mem(global_index_mem_global),
        .bimodal_prediction_mem(bimodal_prediction_mem_global),
        .global_prediction_mem(global_prediction_mem_global),
        .predicted_taken_if(predicted_taken_global),
        .bht_index_if(bht_index_if_global),
        .global_index_if(global_index_if_global),
        .bimodal_prediction_if(bimodal_prediction_if_global),
        .global_prediction_if(global_prediction_if_global),
        .chooser_prefers_global_if(chooser_prefers_global_if_global)
    );

    BranchPredictionUnit #(
        .PREDICTOR_MODE(2)
    ) dut_tournament (
        .clk(clk),
        .reset(reset),
        .pc_if(pc_if),
        .instruction_if(instruction_if),
        .branch_mem(branch_mem),
        .branch_taken_mem(branch_taken_mem),
        .bht_index_mem(bht_index_mem_tournament),
        .global_index_mem(global_index_mem_tournament),
        .bimodal_prediction_mem(bimodal_prediction_mem_tournament),
        .global_prediction_mem(global_prediction_mem_tournament),
        .predicted_taken_if(predicted_taken_tournament),
        .bht_index_if(bht_index_if_tournament),
        .global_index_if(global_index_if_tournament),
        .bimodal_prediction_if(bimodal_prediction_if_tournament),
        .global_prediction_if(global_prediction_if_tournament),
        .chooser_prefers_global_if(chooser_prefers_global_if_tournament)
    );

    always #5 clk = ~clk;

    task pulse_reset;
        begin
            reset = 1'b1;
            branch_mem = 1'b0;
            repeat (2) @(posedge clk);
            @(negedge clk);
            reset = 1'b0;
            #1;
        end
    endtask

    // Look up one branch, capture each instance's prediction-time metadata,
    // and resolve it on the following rising edge.
    task execute_branch;
        input [63:0] branch_pc;
        input        actual_taken;
        input        count_branch_b;
        begin
            @(negedge clk);
            pc_if = branch_pc;
            instruction_if = BRANCH_INSTRUCTION;
            branch_mem = 1'b0;
            #1;

            if (count_branch_b) begin
                if (predicted_taken_bht != actual_taken)
                    bht_b_misses = bht_b_misses + 1;
                if (predicted_taken_global != actual_taken)
                    global_b_misses = global_b_misses + 1;
                if (predicted_taken_tournament != actual_taken)
                    tournament_b_misses = tournament_b_misses + 1;
            end

            bht_index_mem_bht = bht_index_if_bht;
            global_index_mem_bht = global_index_if_bht;
            bimodal_prediction_mem_bht = bimodal_prediction_if_bht;
            global_prediction_mem_bht = global_prediction_if_bht;

            bht_index_mem_global = bht_index_if_global;
            global_index_mem_global = global_index_if_global;
            bimodal_prediction_mem_global = bimodal_prediction_if_global;
            global_prediction_mem_global = global_prediction_if_global;

            bht_index_mem_tournament = bht_index_if_tournament;
            global_index_mem_tournament = global_index_if_tournament;
            bimodal_prediction_mem_tournament =
                bimodal_prediction_if_tournament;
            global_prediction_mem_tournament =
                global_prediction_if_tournament;

            branch_taken_mem = actual_taken;
            branch_mem = 1'b1;
            @(posedge clk);
            #1;
            branch_mem = 1'b0;
        end
    endtask

    // Directly exercise the tournament chooser with prediction metadata that
    // could have arrived through a real pipeline.
    task train_chooser;
        input [3:0] choice_index;
        input       bimodal_prediction;
        input       global_prediction;
        input       actual_taken;
        begin
            @(negedge clk);
            branch_mem = 1'b1;
            branch_taken_mem = actual_taken;

            bht_index_mem_bht = choice_index;
            global_index_mem_bht = {2'b00, choice_index};
            bimodal_prediction_mem_bht = bimodal_prediction;
            global_prediction_mem_bht = global_prediction;

            bht_index_mem_global = choice_index;
            global_index_mem_global = {2'b00, choice_index};
            bimodal_prediction_mem_global = bimodal_prediction;
            global_prediction_mem_global = global_prediction;

            bht_index_mem_tournament = choice_index;
            global_index_mem_tournament = {2'b00, choice_index};
            bimodal_prediction_mem_tournament = bimodal_prediction;
            global_prediction_mem_tournament = global_prediction;

            @(posedge clk);
            #1;
            branch_mem = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b0;
        pc_if = 64'b0;
        instruction_if = NOP_INSTRUCTION;
        branch_mem = 1'b0;
        branch_taken_mem = 1'b0;

        bht_index_mem_bht = 4'b0;
        global_index_mem_bht = 6'b0;
        bimodal_prediction_mem_bht = 1'b0;
        global_prediction_mem_bht = 1'b0;
        bht_index_mem_global = 4'b0;
        global_index_mem_global = 6'b0;
        bimodal_prediction_mem_global = 1'b0;
        global_prediction_mem_global = 1'b0;
        bht_index_mem_tournament = 4'b0;
        global_index_mem_tournament = 6'b0;
        bimodal_prediction_mem_tournament = 1'b0;
        global_prediction_mem_tournament = 1'b0;

        bht_b_misses = 0;
        global_b_misses = 0;
        tournament_b_misses = 0;

        pulse_reset();

        // Reset state: weakly not-taken and chooser weakly prefers BHT.
        pc_if = BRANCH_A_PC;
        instruction_if = BRANCH_INSTRUCTION;
        #1;
        if (predicted_taken_bht !== 1'b0 ||
            predicted_taken_global !== 1'b0 ||
            predicted_taken_tournament !== 1'b0)
            $fatal(1, "reset predictions must all be not-taken");
        if (global_index_if_global[5:4] !== 2'b00)
            $fatal(1, "reset GHR must be 00");
        if (chooser_prefers_global_if_tournament !== 1'b0)
            $fatal(1, "chooser must initially prefer the bimodal BHT");

        // Opcode gating: component tables may be read, but a non-branch must
        // never request a taken redirect.
        instruction_if = NOP_INSTRUCTION;
        #1;
        if (predicted_taken_bht !== 1'b0 ||
            predicted_taken_global !== 1'b0 ||
            predicted_taken_tournament !== 1'b0)
            $fatal(1, "non-branch instruction produced a redirect");

        // Non-speculative GHR update uses resolved real outcomes only.
        execute_branch(BRANCH_A_PC, 1'b1, 1'b0);
        pc_if = BRANCH_B_PC;
        instruction_if = BRANCH_INSTRUCTION;
        #1;
        if (global_index_if_global[5:4] !== 2'b01)
            $fatal(1, "GHR after resolved T is %b, expected 01",
                   global_index_if_global[5:4]);

        execute_branch(BRANCH_B_PC, 1'b0, 1'b0);
        pc_if = BRANCH_A_PC;
        instruction_if = BRANCH_INSTRUCTION;
        #1;
        if (global_index_if_global[5:4] !== 2'b10)
            $fatal(1, "GHR after resolved T,N is %b, expected 10",
                   global_index_if_global[5:4]);

        // Start the correlation experiment from clean predictor state.
        pulse_reset();
        bht_b_misses = 0;
        global_b_misses = 0;
        tournament_b_misses = 0;

        // A and B have the same outcome in each iteration, while the outcome
        // alternates between iterations. BHT cannot learn B's alternation;
        // the global predictor learns that B follows the immediately prior A.
        for (iteration = 0; iteration < 20; iteration = iteration + 1) begin
            execute_branch(BRANCH_A_PC, ~iteration[0], 1'b0);
            execute_branch(BRANCH_B_PC, ~iteration[0], 1'b1);
        end

        if (global_b_misses >= bht_b_misses)
            $fatal(1,
                   "global predictor did not beat BHT on correlated B: %0d vs %0d",
                   global_b_misses, bht_b_misses);
        if (tournament_b_misses >= bht_b_misses)
            $fatal(1,
                   "tournament did not beat BHT on correlated B: %0d vs %0d",
                   tournament_b_misses, bht_b_misses);

        pc_if = BRANCH_B_PC;
        instruction_if = BRANCH_INSTRUCTION;
        #1;
        if (chooser_prefers_global_if_tournament !== 1'b1)
            $fatal(1, "chooser did not learn to prefer global for branch B");

        // Test both chooser directions on an otherwise unused PC index.
        train_chooser(CHOOSER_PC[5:2], 1'b0, 1'b1, 1'b1);
        train_chooser(CHOOSER_PC[5:2], 1'b0, 1'b1, 1'b1);
        pc_if = CHOOSER_PC;
        #1;
        if (chooser_prefers_global_if_tournament !== 1'b1)
            $fatal(1, "chooser failed to move toward global");

        train_chooser(CHOOSER_PC[5:2], 1'b1, 1'b0, 1'b1);
        train_chooser(CHOOSER_PC[5:2], 1'b1, 1'b0, 1'b1);
        #1;
        if (chooser_prefers_global_if_tournament !== 1'b0)
            $fatal(1, "chooser failed to move back toward bimodal");

        $display("Predictor unit results on correlated branch B:");
        $display("  BHT misses        = %0d / 20", bht_b_misses);
        $display("  Global misses     = %0d / 20", global_b_misses);
        $display("  Tournament misses = %0d / 20", tournament_b_misses);
        $display("PASS: non-speculative tournament predictor unit test.");
        $finish;
    end

endmodule
