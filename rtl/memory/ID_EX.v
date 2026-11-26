module ID_EX(
    input [63:0]pc_in,
    input [63:0]readdata1_in,
    input [63:0]readdata2_in,
    input [63:0]instruction64_in,
    input [31:0]instruction_in,
    input clk,
    input reset,
    input Branch_in,
    input MemRead_in,
    input [1:0]MemtoReg_in,
    input [1:0]ALUOp_in,
    input MemWrite_in,
    input ALUSrc_in,
    input Regwrite_in,
    input ALUASrc_in,
    input Jump_in,
    input JumpReg_in,
    //2026/10/8 for trap controlunit
    input IllegalInstruction_in,
    input Ecall_in,
    input Mret_in,
    input CSRWrite_in,
    input [1:0]CSROp_in,
    input CSRUseImm_in,
    input CSRtoReg_in,
    input [63:0]csr_rdata_in,//

    input ID_EX_flush,
    input ID_EX_write,//用于在必要情况下禁止更新，保留原指令和控制信号
    input predicted_taken_in,//for branch prediction transportation(2026/9/28)
    input [3:0]bht_index_in,
    input [5:0]global_index_in,
    input bimodal_prediction_in,
    input global_prediction_in,
    input valid_in,
    


    output reg [63:0]pc_out,
    output reg [63:0]readdata1_out,
    output reg [63:0]readdata2_out,
    output reg [63:0]instruction64_out,
    output reg [31:0]instruction_out,
    output reg Branch_out,
    output reg MemRead_out,
    output reg [1:0]MemtoReg_out,
    output reg [1:0]ALUOp_out,
    output reg MemWrite_out,
    output reg ALUSrc_out,
    output reg Regwrite_out,
    output reg ALUASrc_out,
    output reg Jump_out,
    output reg JumpReg_out,
    output reg IllegalInstruction_out,
    output reg Ecall_out,
    output reg Mret_out,
    output reg CSRWrite_out,
    output reg [1:0]CSROp_out,
    output reg CSRUseImm_out,
    output reg CSRtoReg_out,
    output reg [63:0]csr_rdata_out,
    output reg predicted_taken_out,
    output reg [3:0]bht_index_out,
    output reg [5:0]global_index_out,
    output reg bimodal_prediction_out,
    output reg global_prediction_out,
    output reg valid_out


);
  always @(posedge clk) begin
    if(reset || ID_EX_flush) begin
        pc_out            <= 64'b0;
        readdata1_out     <= 64'b0;
        readdata2_out     <= 64'b0;
        instruction64_out <= 64'b0;
        instruction_out   <= 32'b0;
        Branch_out        <= 1'b0;
        MemRead_out       <= 1'b0;
        MemtoReg_out      <= 2'b0;
        ALUOp_out         <= 2'b0;
        MemWrite_out      <= 1'b0;
        ALUSrc_out        <= 1'b0;
        Regwrite_out      <= 1'b0;
        ALUASrc_out       <= 1'b0;
        Jump_out          <= 1'b0;
        JumpReg_out       <= 1'b0;
        IllegalInstruction_out <= 1'b0;
        Ecall_out          <= 1'b0;
        Mret_out           <= 1'b0;
        CSRWrite_out       <= 1'b0;
        CSROp_out          <= 2'b0;
        CSRUseImm_out      <= 1'b0;
        CSRtoReg_out       <= 1'b0;
        csr_rdata_out      <= 64'b0;
        predicted_taken_out <= 1'b0;
        bht_index_out <= 4'b0;
        global_index_out <= 6'b0;
        bimodal_prediction_out <= 1'b0;
        global_prediction_out <= 1'b0;
        valid_out <= 1'b0;
    end
    else if(~ID_EX_write) begin
        pc_out                 <= pc_out;
        readdata1_out          <= readdata1_out;
        readdata2_out          <= readdata2_out;
        instruction64_out      <= instruction64_out;
        instruction_out        <= instruction_out;
        Branch_out             <= Branch_out;
        MemRead_out            <= MemRead_out;
        MemtoReg_out           <= MemtoReg_out;
        ALUOp_out              <= ALUOp_out;
        MemWrite_out           <= MemWrite_out;
        ALUSrc_out             <= ALUSrc_out;
        Regwrite_out           <= Regwrite_out;
        ALUASrc_out            <= ALUASrc_out;
        Jump_out               <= Jump_out;
        JumpReg_out            <= JumpReg_out;
        IllegalInstruction_out <= IllegalInstruction_out;
        Ecall_out              <= Ecall_out;
        Mret_out               <= Mret_out;
        CSRWrite_out           <= CSRWrite_out;
        CSROp_out              <= CSROp_out;
        CSRUseImm_out          <= CSRUseImm_out;
        CSRtoReg_out           <= CSRtoReg_out;
        csr_rdata_out          <= csr_rdata_out;
        predicted_taken_out    <= predicted_taken_out;
        bht_index_out          <= bht_index_out;
        global_index_out       <= global_index_out;
        bimodal_prediction_out <= bimodal_prediction_out;
        global_prediction_out  <= global_prediction_out;
        valid_out              <= valid_out;
    end

    else begin
        pc_out <= pc_in;
        readdata1_out <= readdata1_in;
        readdata2_out <= readdata2_in;
        instruction64_out <= instruction64_in;
        instruction_out <= instruction_in;
        Branch_out        <= Branch_in;
        MemRead_out       <= MemRead_in;
        MemtoReg_out      <= MemtoReg_in;
        ALUOp_out         <= ALUOp_in;
        MemWrite_out      <= MemWrite_in;
        ALUSrc_out        <= ALUSrc_in;
        Regwrite_out      <= Regwrite_in;
        ALUASrc_out       <= ALUASrc_in;
        Jump_out          <= Jump_in;
        JumpReg_out       <= JumpReg_in;
        IllegalInstruction_out <= IllegalInstruction_in;
        Ecall_out          <= Ecall_in;
        Mret_out           <= Mret_in;
        CSRWrite_out       <= CSRWrite_in;
        CSROp_out          <= CSROp_in;
        CSRUseImm_out      <= CSRUseImm_in;
        CSRtoReg_out       <= CSRtoReg_in;
        csr_rdata_out      <= csr_rdata_in;
        predicted_taken_out <= predicted_taken_in;
        bht_index_out <= bht_index_in;
        global_index_out <= global_index_in;
        bimodal_prediction_out <= bimodal_prediction_in;
        global_prediction_out <= global_prediction_in;
        valid_out <= valid_in;

    

      







    end
  end






endmodule
