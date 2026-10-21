module HazardDetectionUnit(
    input MemRead_ex,
    input [4:0]rd_ex,
    input [4:0]rs1_id,
    input [4:0]rs2_id,
    input UseRs1_id,
    input UseRs2_id,
    output reg PCwrite,
    output reg IF_IDwrite,
    output reg ID_EX_flush
);

always @(*) begin
    if(MemRead_ex == 1'b1 && rd_ex != 5'd0 &&
       ((UseRs1_id && rd_ex == rs1_id) ||
        (UseRs2_id && rd_ex == rs2_id))) begin
        PCwrite = 1'b0;
        IF_IDwrite = 1'b0;
        ID_EX_flush = 1'b1;
    end
    else begin
        PCwrite = 1'b1;
        IF_IDwrite = 1'b1;
        ID_EX_flush = 1'b0;
    end
end
           



















endmodule
