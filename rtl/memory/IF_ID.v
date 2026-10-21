module IF_ID(
    input [63:0]current_pc,
    input [31:0]instruction_in,
    input reset,
    input clk,
    input IF_IDwrite,
    input IF_ID_flush,
    input [3:0]bht_index_in,
    input predicted_taken_in,
    input valid_in,//用于异常，中断模块
    output reg [3:0]bht_index_out,
    output reg predicted_taken_out,
    output reg [31:0]instruction_out,
    output reg [63:0]pc_out,
    output reg valid_out

);
  always @(posedge clk) begin
    if(reset) begin
      instruction_out <= 32'b0;
      pc_out <= 64'b0;
      predicted_taken_out <= 1'b0;
      bht_index_out <= 4'b0;
      valid_out <= 1'b0;
    end
    else if(IF_ID_flush) begin
      instruction_out <= 32'b0;
      pc_out <= 64'b0;
      predicted_taken_out <= 1'b0;
      bht_index_out <= 4'b0;
      valid_out <= 1'b0;
    end
    else if(~IF_IDwrite) begin
        instruction_out <= instruction_out;
        pc_out <= pc_out;
        predicted_taken_out <= predicted_taken_out;
        bht_index_out <= bht_index_out;
        valid_out <= valid_out;
    end
    else begin
      instruction_out <= instruction_in;
      pc_out <= current_pc;
      predicted_taken_out <= predicted_taken_in;
      bht_index_out <= bht_index_in;
      valid_out <= valid_in;

    end
      
end








endmodule
