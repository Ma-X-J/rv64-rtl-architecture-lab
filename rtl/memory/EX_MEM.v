module EX_MEM(
    input [63:0]branch_pc_in,
    input zero_in,
    input [63:0]ALUresult_in,
    input [63:0]writedata_in,
    input [63:0]instruction64_in,
    input [31:0]instruction_in,
    input [63:0]pc_plus4_in,
    input clk,
    input reset,
    input Branch_in,
    input Jump_in,
    input JumpReg_in,
    input MemWrite_in,
    input MemRead_in,
    input [1:0]MemtoReg_in,
    input Regwrite_in,
    input IllegalInstruction_in,
    input Ecall_in,
    input Mret_in,
    input CSRWrite_in,
    input CSRtoReg_in,
    input EX_MEM_flush,
    input EX_MEM_write,
    input predicted_taken_in,//branch prediction transportation(2026/9/28)
    input [3:0]bht_index_in,
    input valid_in,
    input [63:0]CSR_wdata_in,
    input [63:0]CSR_rdata_in,
    input [63:0]pc_in,
    

    output reg [63:0]branch_pc_out,
    output reg zero_out,
    output reg [63:0]ALUresult_out,
    output reg [63:0]writedata_out,
    output reg [63:0]instruction64_out,
    output reg [31:0]instruction_out,
    output reg [63:0]pc_plus4_out,
    output reg Branch_out,
    output reg Jump_out,
    output reg JumpReg_out,
    output reg MemWrite_out,
    output reg MemRead_out,
    output reg [1:0]MemtoReg_out,
    output reg Regwrite_out,
    output reg IllegalInstruction_out,
    output reg Ecall_out,
    output reg Mret_out,
    output reg CSRWrite_out,
    output reg CSRtoReg_out,
    output reg predicted_taken_out,
    output reg [3:0]bht_index_out,
    output reg valid_out,
    output reg [63:0]CSR_wdata_out,
    output reg [63:0]CSR_rdata_out,
    output reg [63:0]pc_out

    



);

    always @(posedge clk) begin
        if (reset || EX_MEM_flush) begin
            branch_pc_out     <= 64'b0;
            zero_out          <= 1'b0;
            ALUresult_out     <= 64'b0;
            writedata_out     <= 64'b0;
            instruction64_out <= 64'b0;
            instruction_out   <= 32'b0;
            pc_plus4_out      <= 64'b0;
            Branch_out        <= 1'b0;
            Jump_out          <= 1'b0;
            JumpReg_out       <= 1'b0;
            MemWrite_out      <= 1'b0;
            MemRead_out       <= 1'b0;
            MemtoReg_out      <= 2'b0;
            Regwrite_out      <= 1'b0;
            IllegalInstruction_out <= 1'b0;
            Ecall_out        <= 1'b0;
            Mret_out         <= 1'b0;
            CSRWrite_out     <= 1'b0;
            CSRtoReg_out     <= 1'b0;
            predicted_taken_out <= 1'b0;
            bht_index_out <= 4'b0;
            valid_out <= 1'b0;
            CSR_wdata_out <= 64'b0;
            CSR_rdata_out <= 64'b0;
            pc_out <= 64'b0;
        end
        else if(~EX_MEM_write) begin
            branch_pc_out          <= branch_pc_out;
            zero_out               <= zero_out;
            ALUresult_out          <= ALUresult_out;
            writedata_out          <= writedata_out;
            instruction64_out      <= instruction64_out;
            instruction_out        <= instruction_out;
            pc_plus4_out           <= pc_plus4_out;
            Branch_out             <= Branch_out;
            Jump_out               <= Jump_out;
            JumpReg_out            <= JumpReg_out;
            MemWrite_out           <= MemWrite_out;
            MemRead_out            <= MemRead_out;
            MemtoReg_out           <= MemtoReg_out;
            Regwrite_out           <= Regwrite_out;
            IllegalInstruction_out <= IllegalInstruction_out;
            Ecall_out              <= Ecall_out;
            Mret_out               <= Mret_out;
            CSRWrite_out           <= CSRWrite_out;
            CSRtoReg_out           <= CSRtoReg_out;
            predicted_taken_out    <= predicted_taken_out;
            bht_index_out          <= bht_index_out;
            valid_out              <= valid_out;
            CSR_wdata_out          <= CSR_wdata_out;
            CSR_rdata_out          <= CSR_rdata_out;
            pc_out                 <= pc_out;
        end
        else begin
            branch_pc_out     <= branch_pc_in;
            zero_out          <= zero_in;
            ALUresult_out     <= ALUresult_in;
            writedata_out     <= writedata_in;
            instruction64_out <= instruction64_in;
            instruction_out   <= instruction_in;
            pc_plus4_out      <= pc_plus4_in;
            Branch_out        <= Branch_in;
            Jump_out          <= Jump_in;
            JumpReg_out       <= JumpReg_in;
            MemWrite_out      <= MemWrite_in;
            MemRead_out       <= MemRead_in;
            MemtoReg_out      <= MemtoReg_in;
            Regwrite_out      <= Regwrite_in;
            IllegalInstruction_out <= IllegalInstruction_in;
            Ecall_out        <= Ecall_in;
            Mret_out         <= Mret_in;
            CSRWrite_out     <= CSRWrite_in;
            CSRtoReg_out     <= CSRtoReg_in;
            predicted_taken_out <= predicted_taken_in;
            bht_index_out <= bht_index_in;
            valid_out <= valid_in;
            CSR_wdata_out <= CSR_wdata_in;
            CSR_rdata_out <= CSR_rdata_in;
            pc_out <= pc_in;
        end
    end

endmodule
