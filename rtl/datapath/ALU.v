// 64-bit ALU for the datapath in the diagram.
// ALUControl: 0000=AND, 0001=OR, 0010=ADD, 0110=SUB.0011=XOR
module ALU (
    input  wire [63:0] A,
    input  wire [63:0] B,
    input  wire [3:0]  ALUControl,
    
    output reg  [63:0] ALUResult,
    output wire        Zero
);

    // Combinational logic: the result depends only on the current inputs.
    always @(*) begin
        case (ALUControl)
            4'b0000: ALUResult = A & B;
            4'b0001: ALUResult = A | B;
            4'b0010: ALUResult = A + B;
            4'b0011: ALUResult = A ^ B;
            4'b0110: ALUResult = A - B;
            4'b0100: ALUResult = ($signed(A) < $signed(B)) ?64'd1:64'd0;
            4'b0101: ALUResult = A << B[5:0];//ALUResult = A * 2^B（实际上就是左移的逻辑）
            4'b0111: ALUResult = A >> B[5:0];//ALUResult = A/2^B
            default: ALUResult = 64'b0;
        endcase
    end




    // For beq, subtraction yields zero exactly when A and B are equal.
    assign Zero = (ALUResult == 64'b0);

endmodule
