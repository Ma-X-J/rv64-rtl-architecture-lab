module BranchPredictionUnit #(
    // 0: original bimodal BHT
    // 1: non-speculative global-history predictor
    // 2: tournament predictor (bimodal BHT vs. global predictor)
    parameter PREDICTOR_MODE = 0
)(
    input  wire        clk,
    input  wire        reset,

    // IF stage: read all component predictions in parallel.
    input  wire [63:0] pc_if,
    input  wire [31:0] instruction_if,

    // MEM stage: update the entries used by the resolved valid branch.
    // branch_mem is expected to be asserted for one valid conditional branch.
    input  wire        branch_mem,
    input  wire        branch_taken_mem,
    input  wire [3:0]  bht_index_mem,

    // Prediction-time global metadata transported with the branch to MEM.
    // The old top-level does not connect these ports while PREDICTOR_MODE=0;
    // they are only consumed by the global and tournament modes.
    input  wire [5:0]  global_index_mem,
    input  wire        bimodal_prediction_mem,
    input  wire        global_prediction_mem,

    // Final direction prediction selected by PREDICTOR_MODE.
    output wire        predicted_taken_if,

    // Prediction metadata that must eventually travel through the pipeline.
    output wire [3:0]  bht_index_if,
    output wire [5:0]  global_index_if,
    output wire        bimodal_prediction_if,
    output wire        global_prediction_if,
    output wire        chooser_prefers_global_if
);

    localparam MODE_BIMODAL    = 0;
    localparam MODE_GLOBAL     = 1;
    localparam MODE_TOURNAMENT = 2;

    localparam STRONGLY_NOT_TAKEN = 2'b00;
    localparam WEAKLY_NOT_TAKEN   = 2'b01;
    localparam WEAKLY_TAKEN       = 2'b10;
    localparam STRONGLY_TAKEN     = 2'b11;

    // Original 16-entry PC-indexed bimodal predictor.
    reg [1:0] bht [0:15];

    // Four 16-entry banks selected by the two-bit global history.
    // The flattened index is {GHR[1:0], PC[5:2]}.
    reg [1:0] global_pht [0:63];

    // 00/01 prefer bimodal; 10/11 prefer the global predictor.
    reg [1:0] choice_table [0:15];

    // Non-speculative global history: updated only with resolved outcomes.
    // ghr[0] is the most recent resolved conditional branch outcome.
    reg [1:0] ghr;

    integer i;
    integer j;

    wire is_branch_if;
    wire selected_prediction_if;

    // Shared two-bit saturating-counter transition function.
    function [1:0] update_counter;
        input [1:0] old_counter;
        input       taken;
        begin
            case (old_counter)
                STRONGLY_NOT_TAKEN:
                    update_counter = taken ? WEAKLY_NOT_TAKEN
                                           : STRONGLY_NOT_TAKEN;
                WEAKLY_NOT_TAKEN:
                    update_counter = taken ? WEAKLY_TAKEN
                                           : STRONGLY_NOT_TAKEN;
                WEAKLY_TAKEN:
                    update_counter = taken ? STRONGLY_TAKEN
                                           : WEAKLY_NOT_TAKEN;
                STRONGLY_TAKEN:
                    update_counter = taken ? STRONGLY_TAKEN
                                           : WEAKLY_TAKEN;
                default:
                    update_counter = WEAKLY_NOT_TAKEN;
            endcase
        end
    endfunction

    // Instructions are 4-byte aligned, so PC[5:2] selects one of 16 entries.
    assign bht_index_if = pc_if[5:2];

    // The prediction-time GHR is part of the global-PHT index and must be
    // saved with the instruction; the MEM-stage GHR may already be different.
    assign global_index_if = {ghr, bht_index_if};

    assign is_branch_if = (instruction_if[6:0] == 7'b1100011);

    assign bimodal_prediction_if = bht[bht_index_if][1];
    assign global_prediction_if  = global_pht[global_index_if][1];
    assign chooser_prefers_global_if = choice_table[bht_index_if][1];

    // Mode 1 always uses the global predictor. Mode 2 uses the per-PC chooser.
    // The default mode preserves the original BHT behavior.
    assign selected_prediction_if =
        (PREDICTOR_MODE == MODE_GLOBAL) ? global_prediction_if :
        ((PREDICTOR_MODE == MODE_TOURNAMENT) &&
         chooser_prefers_global_if)     ? global_prediction_if :
                                          bimodal_prediction_if;

    // Non-branch instructions must never redirect the PC through this unit.
    assign predicted_taken_if = is_branch_if && selected_prediction_if;

    always @(posedge clk) begin
        if (reset) begin
            ghr <= 2'b00;

            // Direction counters begin weakly not-taken. The chooser also
            // begins by weakly preferring the original, known-good BHT.
            for (i = 0; i < 16; i = i + 1) begin
                bht[i] <= WEAKLY_NOT_TAKEN;
                choice_table[i] <= WEAKLY_NOT_TAKEN;
            end

            for (j = 0; j < 64; j = j + 1)
                global_pht[j] <= WEAKLY_NOT_TAKEN;
        end
        else if (branch_mem) begin
            // Always keep the original BHT trained. Tournament mode needs
            // both component predictors ready even when one is not selected.
            bht[bht_index_mem] <= update_counter(
                bht[bht_index_mem],
                branch_taken_mem
            );

            if (PREDICTOR_MODE != MODE_BIMODAL) begin
                // Train exactly the global entry read in IF, not an index
                // recomputed from the newer MEM-stage GHR.
                global_pht[global_index_mem] <= update_counter(
                    global_pht[global_index_mem],
                    branch_taken_mem
                );

                // Commit the real outcome after the branch resolves. No
                // predicted outcome is inserted, so no rollback is required.
                ghr <= {ghr[0], branch_taken_mem};
            end

            if ((PREDICTOR_MODE == MODE_TOURNAMENT) &&
                (bimodal_prediction_mem != global_prediction_mem)) begin
                // When the component predictions disagree, exactly one is
                // correct. Increment toward global or decrement toward BHT.
                choice_table[bht_index_mem] <= update_counter(
                    choice_table[bht_index_mem],
                    global_prediction_mem == branch_taken_mem
                );
            end
        end
    end

endmodule
