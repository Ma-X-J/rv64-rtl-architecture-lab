
module PC(
    input clk,
    input [63:0]NextPC,
    input reset,
    input PCwrite,
    output reg [63:0]CurrentPC


);
   always @(posedge clk) begin
    if(reset) begin
        CurrentPC <= 64'b0;
    end
    else if(PCwrite) begin
        CurrentPC <= NextPC;
    end


      
   end




endmodule
