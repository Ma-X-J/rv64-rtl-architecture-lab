
module DataMemory(
    input clk,
    input [63:0]Address,
    input [63:0]Writedata,
    input wire MemWrite,
    input wire MemRead,
    output reg [63:0]Readdata


);
reg [63:0]data_mem[0:63];//貌似只有6位，可以再优化看看

always @(*) begin
    case(MemRead)
       1'b0:Readdata = 64'b0;
       1'b1:Readdata = data_mem[Address[8:3]];
    endcase
end

always @(posedge clk) begin
    if(MemWrite)
      data_mem[Address[8:3]] <= Writedata;

    
end
endmodule
        
    
