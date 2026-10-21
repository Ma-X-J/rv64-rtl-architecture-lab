module MEM_WB(
    input [63:0]readdata_in,
    input [63:0]ALUresult_in,
    input [1:0]MemtoReg_in,
    input [63:0]instruction64_in,
    input [31:0]instruction_in,
    input [63:0]pc_plus4_in,
    input Regwrite_in,
    input clk,
    input reset,
    input [63:0]CSR_rdata_in,
    input CSRtoReg_in,
    output reg [63:0]readdata_out,
    output reg [63:0]ALUresult_out,
    output reg [1:0]MemtoReg_out,
    output reg [63:0]instruction64_out,
    output reg [31:0]instruction_out,
    output reg [63:0]pc_plus4_out,
    output reg Regwrite_out,
    output reg [63:0]CSR_rdata_out,
    output reg CSRtoReg_out







);
  always @(posedge clk) begin
    if(reset)begin
      readdata_out      <= 64'b0;
      ALUresult_out     <= 64'b0;
      MemtoReg_out      <= 2'b0;
      instruction64_out <= 64'b0;
      instruction_out   <= 32'b0;
      pc_plus4_out      <= 64'b0;
      Regwrite_out      <= 1'b0;
      CSR_rdata_out     <= 64'b0;
      CSRtoReg_out      <= 1'b0;
    end
    else begin
      readdata_out      <= readdata_in;
      ALUresult_out     <= ALUresult_in;
      MemtoReg_out      <= MemtoReg_in;
      instruction64_out <= instruction64_in;
      instruction_out   <= instruction_in;
      pc_plus4_out      <= pc_plus4_in;
      Regwrite_out      <= Regwrite_in;
      CSR_rdata_out     <= CSR_rdata_in;
      CSRtoReg_out      <= CSRtoReg_in;
    end
      
  end
endmodule
