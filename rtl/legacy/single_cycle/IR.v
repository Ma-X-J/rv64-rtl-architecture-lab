

module IR(
    input wire [63:0]CurrentPC,
    output wire [31:0]instruction

);
   reg [31:0] rom[0:255];
   integer i;

   initial begin
    for (i = 0;i < 256;i = i + 1)
      rom[i] = 32'h0000033;
    rom[0] = 32'h002081B3; // add x3, x1, x2
    rom[1] = 32'h00013283; // ld  x5, 0(x2)
    rom[2] = 32'h00513423; // sd  x5, 8(x2)
    rom[3] = 32'h00208463; // beq x1, x2, +8
    end
    
    assign instruction = ((CurrentPC[63:10] == 54'd0) && (CurrentPC[1:0] == 2'b00)) ? rom[CurrentPC[9:2]]:32'b0;

   

   
   






endmodule