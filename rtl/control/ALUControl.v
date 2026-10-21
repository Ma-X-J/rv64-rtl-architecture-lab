
module ALUControl (
    input wire [1:0]ALUOp,
    input wire [31:0]instruction,
    output reg [3:0]ALUControl
);
   always @(*) begin
    ALUControl = 4'b1111;
    case(ALUOp)
        2'b00:ALUControl = 4'b0010;
        2'b01:ALUControl = 4'b0110;
        2'b10:begin
            case(instruction[6:0])
            7'b0010011:begin
                case(instruction[14:12])
                3'b111:ALUControl = 4'b0000;//andi
                3'b000:ALUControl = 4'b0010;//addi
                3'b110:ALUControl = 4'b0001;//ori
                3'b100:ALUControl = 4'b0011;//xori
                endcase
            end
            7'b0110011:begin
                case({instruction[30],instruction[14:12]})
                4'b0000:ALUControl = 4'b0010;//add
                4'b1000:ALUControl = 4'b0110;//beq(SUB)
                4'b0111:ALUControl = 4'b0000;//AND
                4'b0110:ALUControl = 4'b0001;//OR
                4'b0100:ALUControl = 4'b0011;//xor
                4'b0010:ALUControl = 4'b0100;//slt（有符号数比较）
                4'b0001:ALUControl = 4'b0101;//sll（逻辑左移）
                4'b0101:ALUControl = 4'b0111;//srl(逻辑右移)
                default:ALUControl = 4'b1111;
                endcase
        
            end
            endcase
       
        end

        
        
        
        

    endcase





   end





  
endmodule

