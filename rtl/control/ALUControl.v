
module ALUControl (
    input wire [1:0]ALUOp,
    input wire [31:0]instruction,
    output reg [4:0]ALUControl
);
   always @(*) begin
    ALUControl = 5'h1f;
    case(ALUOp)
        2'b00:ALUControl = 4'b0010;
        2'b01:begin
            case(instruction[14:12])
                3'b000, 3'b001: ALUControl = 4'b0110; // BEQ/BNE: subtract
                3'b100:         ALUControl = 4'b0100; // BLT: signed less-than
                3'b101:         ALUControl = 4'b1001; // BGE: signed greater-than-or-equal
                3'b110:         ALUControl = 5'h0b; // BLTU
                3'b111:         ALUControl = 5'h14; // BGEU
                default:        ALUControl = 5'h1f;
            endcase
        end
        2'b10:begin
            case(instruction[6:0])
            7'b0010011:begin
                case(instruction[14:12])
                3'b111:ALUControl = 4'b0000;//andi
                3'b000:ALUControl = 4'b0010;//addi
                3'b011:ALUControl = 5'h0b;//sltiu
                3'b110:ALUControl = 4'b0001;//ori
                3'b100:ALUControl = 4'b0011;//xori
                3'b001:begin // SLLI
                    if (instruction[31:26] == 6'b000000)
                        ALUControl = 4'b0101;
                end
                3'b101:begin // SRLI/SRAI
                    if (instruction[31:26] == 6'b000000)
                        ALUControl = 5'h07;
                    else if (instruction[31:26] == 6'b010000)
                        ALUControl = 5'h0c;
                end
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
                default:ALUControl = 5'h1f;
                endcase

                // Operations that cannot be distinguished by funct3 and
                // instruction[30] alone override the legacy decode above.
                case ({instruction[31:25], instruction[14:12]})
                    10'b0000000_011: ALUControl = 5'h0b; // SLTU
                    10'b0100000_101: ALUControl = 5'h0c; // SRA
                    10'b0000001_000: ALUControl = 5'h10; // MUL
                    10'b0000001_011: ALUControl = 5'h11; // MULHU
                    default: begin end
                endcase
        
            end
            7'b0111011:begin
                case({instruction[31:25],instruction[14:12]})
                   10'b0000000_000:ALUControl = 4'b1000;//ADDW
                   10'b0100000_000:ALUControl = 5'h15;//SUBW
                   10'b0000000_001:ALUControl = 5'h0d;//SLLW
                   10'b0000000_101:ALUControl = 5'h0e;//SRLW
                   10'b0100000_101:ALUControl = 5'h0f;//SRAW
                   10'b0000001_000:ALUControl = 5'h12;//MULW
                   10'b0000001_101:ALUControl = 5'h13;//DIVUW
                   default :ALUControl = 5'h1f;

                endcase
            end
            7'b0011011:begin
                case(instruction[14:12])
                    3'b000: ALUControl = 4'b1000; // ADDIW
                    3'b001: if (instruction[31:25] == 7'b0000000)
                                ALUControl = 5'h0d; // SLLIW
                    3'b101: if (instruction[31:25] == 7'b0000000)
                                ALUControl = 5'h0e; // SRLIW
                            else if (instruction[31:25] == 7'b0100000)
                                ALUControl = 5'h0f; // SRAIW
                    default: ALUControl = 5'h1f;
                endcase
            end
            7'b0001011:begin // custom-0: SUM2W
                case({instruction[31:25],instruction[14:12]})
                    10'b0000000_000: ALUControl = 4'b1010;
                    default: ALUControl = 5'h1f;
                endcase
            end
            endcase
       
        end

        
        
        
        

    endcase





   end





  
endmodule

