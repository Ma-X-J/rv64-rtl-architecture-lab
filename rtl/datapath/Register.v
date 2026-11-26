




module Register(
    input clk,
    input [4:0]Readregister1,
    input [4:0]Readregister2,
    input [4:0]Writeregister,
    input wire Regwrite,
    input [63:0]Writedata,
    output reg [63:0]Readdata1,
    output reg [63:0]Readdata2
);
   reg [63:0] registers[0:31];
   always @(*) begin
    if (Readregister1 == 5'd0)
       Readdata1 = 64'b0;
    else if (Regwrite && (Writeregister != 5'd0) &&
             (Writeregister == Readregister1))
       Readdata1 = Writedata;
    else
       Readdata1 = registers[Readregister1];
    if (Readregister2 == 5'd0)
       Readdata2 = 64'b0;
    else if (Regwrite && (Writeregister != 5'd0) &&
             (Writeregister == Readregister2))
       Readdata2 = Writedata;
    else
       Readdata2 = registers[Readregister2];


   end
   
   always @(posedge clk) begin
    if(Regwrite && (Writeregister != 5'd0))
      registers[Writeregister] <= Writedata ;
    
   end










endmodule
