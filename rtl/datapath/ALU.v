// 64-bit ALU for the datapath in the diagram.
// ALUControl: 0000=AND, 0001=OR, 0010=ADD, 0110=SUB.0011=XOR
module ALU (
    input  wire [63:0] A,
    input  wire [63:0] B,
    input  wire [4:0]  ALUControl,
    
    output reg  [63:0] ALUResult,
    output wire        Zero
);
   wire [31:0]addw_result = A[31:0] + B[31:0];
   wire [31:0]subw_result = A[31:0] - B[31:0];
   wire [31:0]sum2w_result = A[31:0] + B[31:0] + B[63:32];
   wire [127:0]unsigned_product = A * B;
   wire [31:0]mulw_result = A[31:0] * B[31:0];
   wire [31:0]divuw_result = (B[31:0] == 32'b0) ?
                             32'hffff_ffff : (A[31:0] / B[31:0]);
   wire [31:0]sllw_result = A[31:0] << B[4:0];
   wire [31:0]srlw_result = A[31:0] >> B[4:0];
   wire signed [31:0]signed_a_word = A[31:0];
   wire [31:0]sraw_result = signed_a_word >>> B[4:0];

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
            4'b1000: ALUResult = {{32{addw_result[31]}},addw_result};
            4'b1001: ALUResult = ($signed(A) >= $signed(B)) ? 64'd1 : 64'd0;
            4'b1010: ALUResult = {{32{sum2w_result[31]}},sum2w_result};
            5'h0b: ALUResult = (A < B) ? 64'd1 : 64'd0;
            5'h0c: ALUResult = $signed(A) >>> B[5:0];
            5'h0d: ALUResult = {{32{sllw_result[31]}},sllw_result};
            5'h0e: ALUResult = {{32{srlw_result[31]}},srlw_result};
            5'h0f: ALUResult = {{32{sraw_result[31]}},sraw_result};
            5'h10: ALUResult = unsigned_product[63:0];
            5'h11: ALUResult = unsigned_product[127:64];
            5'h12: ALUResult = {{32{mulw_result[31]}},mulw_result};
            5'h13: ALUResult = {{32{divuw_result[31]}},divuw_result};
            5'h14: ALUResult = (A >= B) ? 64'd1 : 64'd0;
            5'h15: ALUResult = {{32{subw_result[31]}},subw_result};
            default: ALUResult = 64'b0;
        endcase
    end




    // For beq, subtraction yields zero exactly when A and B are equal.
    assign Zero = (ALUResult == 64'b0);

endmodule
