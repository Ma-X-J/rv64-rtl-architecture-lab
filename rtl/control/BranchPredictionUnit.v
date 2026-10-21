module BranchPredictionUnit(
    input  wire        clk,
    input  wire        reset,

    // IF stage: read the prediction for the instruction being fetched.
    input  wire [63:0] pc_if,
    input  wire [31:0] instruction_if,

    // MEM stage: update the entry used by the resolved branch.
    input  wire        branch_mem,
    input  wire        branch_taken_mem,
    input  wire [3:0]  bht_index_mem,

    output wire        predicted_taken_if,
    output wire [3:0]  bht_index_if
);

    localparam STRONGLY_NOT_TAKEN = 2'b00;
    localparam WEAKLY_NOT_TAKEN   = 2'b01;
    localparam WEAKLY_TAKEN       = 2'b10;
    localparam STRONGLY_TAKEN     = 2'b11;

    reg [1:0] bht [0:15];
    integer i;

    wire is_branch_if;

    // Instructions are 4-byte aligned, so PC[5:2] selects one of 16 entries.
    assign bht_index_if = pc_if[5:2];
    assign is_branch_if = (instruction_if[6:0] == 7'b1100011);

    // The high bit of a two-bit counter is its taken/not-taken prediction.
    // Non-branch instructions must never redirect the PC through this unit.
    assign predicted_taken_if = is_branch_if && bht[bht_index_if][1];

    // Each BHT entry is an independent two-bit saturating state machine.
    always @(posedge clk) begin
        if (reset) begin
            // Start from weakly not taken.
            for (i = 0; i < 16; i = i + 1) begin
                bht[i] <= WEAKLY_NOT_TAKEN;
            end
        end
        else if (branch_mem) begin
            case (bht[bht_index_mem])
                STRONGLY_NOT_TAKEN: begin
                    if (branch_taken_mem)
                        bht[bht_index_mem] <= WEAKLY_NOT_TAKEN;
                    else
                        bht[bht_index_mem] <= STRONGLY_NOT_TAKEN;
                end

                WEAKLY_NOT_TAKEN: begin
                    if (branch_taken_mem)
                        bht[bht_index_mem] <= WEAKLY_TAKEN;
                    else
                        bht[bht_index_mem] <= STRONGLY_NOT_TAKEN;
                end

                WEAKLY_TAKEN: begin
                    if (branch_taken_mem)
                        bht[bht_index_mem] <= STRONGLY_TAKEN;
                    else
                        bht[bht_index_mem] <= WEAKLY_NOT_TAKEN;
                end

                STRONGLY_TAKEN: begin
                    if (branch_taken_mem)
                        bht[bht_index_mem] <= STRONGLY_TAKEN;
                    else
                        bht[bht_index_mem] <= WEAKLY_TAKEN;
                end

                default: begin
                    bht[bht_index_mem] <= WEAKLY_NOT_TAKEN;
                end
            endcase
        end
    end

endmodule
