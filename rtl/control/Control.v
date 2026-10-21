

module Control(
    input wire [31:0]instruction,
    output  reg Branch,
    output reg MemRead,
    output reg [1:0]MemtoReg,
    output reg [1:0]ALUOp,
    output reg MemWrite,
    output reg ALUSrc,
    output reg Regwrite,
    output reg ALUASrc,
    output reg Jump,
    output reg JumpReg,
    output reg UseRs1,
    output reg UseRs2,
    output reg IllegalInstruction,
    output reg Ecall,
    output reg Mret,
    output reg CSRWrite,
    output reg [1:0]CSROp,
    output reg CSRUseImm,
    output reg CSRtoReg
);
always @(*) begin
    // Give every output a safe value before decoding the opcode.
    Branch = 1'b0;
    MemRead = 1'b0;
    MemtoReg = 2'b00;
    ALUOp = 2'b11;
    ALUASrc = 1'b0;//为了区分ALU的A输入是readdata1还是current_pc（用于auipc指令）//
    MemWrite = 1'b0;
    ALUSrc = 1'b0;
    Regwrite = 1'b0;
    Jump = 1'b0;
    JumpReg = 1'b0;
    UseRs1 = 1'b0;
    UseRs2 = 1'b0;
    IllegalInstruction = 1'b1;
    Ecall = 1'b0;
    Mret = 1'b0;
    CSRWrite = 1'b0;
    CSROp = 2'b11;
    CSRUseImm = 1'b0;
    CSRtoReg = 1'b0;


    case (instruction[6:0])
        7'b0110011: begin // R-type
            case ({instruction[31:25], instruction[14:12]})
                10'b0000000_000, // ADD
                10'b0100000_000, // SUB
                10'b0000000_111, // AND
                10'b0000000_110, // OR
                10'b0000000_100, // XOR
                10'b0000000_010, // SLT
                10'b0000000_001, // SLL
                10'b0000000_101: begin // SRL
                    ALUOp              = 2'b10;
                    Regwrite           = 1'b1;
                    UseRs1             = 1'b1;
                    UseRs2             = 1'b1;
                    IllegalInstruction = 1'b0;
                end
                default: begin end
            endcase
        end
        7'b0000011: begin // LD
            if (instruction[14:12] == 3'b011) begin
                MemRead            = 1'b1;
                MemtoReg           = 2'b01;
                ALUOp              = 2'b00;
                ALUSrc             = 1'b1;
                Regwrite           = 1'b1;
                UseRs1             = 1'b1;
                IllegalInstruction = 1'b0;
            end
        end
        7'b0100011: begin // SD
            if (instruction[14:12] == 3'b011) begin
                ALUOp              = 2'b00;
                MemWrite           = 1'b1;
                ALUSrc             = 1'b1;
                UseRs1             = 1'b1;
                UseRs2             = 1'b1;
                IllegalInstruction = 1'b0;
            end
        end
        7'b1100011: begin // BEQ/BNE
            case (instruction[14:12])
                3'b000, 3'b001: begin
                    Branch             = 1'b1;
                    ALUOp              = 2'b01;
                    UseRs1             = 1'b1;
                    UseRs2             = 1'b1;
                    IllegalInstruction = 1'b0;
                end
                default: begin end
            endcase
        end
        7'b0010011:begin //addi/andi/ori/xori
            case(instruction[14:12])
            3'b000:begin
                //因为可能存在负立即数的原因，所以要ALUOp要写为00保证做的是add操作，如果是10则是R型指令，可能会变成减法
                
                ALUOp = 2'b00;
                Regwrite = 1'b1;
                UseRs1 = 1'b1;
                IllegalInstruction = 1'b0;
                ALUSrc = 1'b1;//要保证ALUSrc的MUX走的是立即数那一条线
            end
            3'b111:begin
                ALUOp = 2'b10;
                Regwrite = 1'b1;
                ALUSrc = 1'b1;
                UseRs1 = 1'b1;
                IllegalInstruction = 1'b0;
            end
            3'b110:begin
                ALUOp = 2'b10;
                Regwrite = 1'b1;
                ALUSrc = 1'b1;
                UseRs1 = 1'b1;
                IllegalInstruction = 1'b0;
            end
            3'b100:begin
                ALUOp = 2'b10;
                Regwrite = 1'b1;
                ALUSrc = 1'b1;
                UseRs1 = 1'b1;
                IllegalInstruction = 1'b0;
            end
            default: begin end
            endcase
            
            
            
        end
        7'b0110111:begin // LUI
            MemtoReg = 2'b10;
            Regwrite = 1'b1;
            IllegalInstruction = 1'b0;
        end
        7'b0010111:begin // AUIPC
            MemtoReg = 2'b00;
            Regwrite = 1'b1;
            ALUSrc = 1'b1;
            ALUASrc = 1'b1;
            ALUOp = 2'b00;
            IllegalInstruction = 1'b0;
            
        end
        7'b1101111:begin//jal
            Jump = 1'b1;
            Regwrite = 1'b1;
            MemtoReg = 2'b11;
            IllegalInstruction = 1'b0;
        end
        7'b1100111:begin//jalr
            if (instruction[14:12] == 3'b000) begin
                Regwrite = 1'b1;
                MemtoReg = 2'b11;
                ALUOp = 2'b00;
                ALUSrc = 1'b1;
                JumpReg = 1'b1;
                UseRs1 = 1'b1;
                IllegalInstruction = 1'b0;
            end
        end
        7'b1110011:begin
            case(instruction[14:12])
            3'b000:begin
                if(instruction == 32'h00000073) begin//ECALL
                    Ecall = 1'b1;
                    IllegalInstruction = 1'b0;
                end
                else if(instruction == 32'h30200073) begin//MRET
                    Mret = 1'b1;
                    IllegalInstruction = 1'b0;
                end
                else begin
                    IllegalInstruction = 1'b1;
                end
            end
            3'b001:begin//CSRRW
                CSRWrite = 1'b1;
                Regwrite = 1'b1;
                UseRs1 = 1'b1;
                CSRtoReg = 1'b1;
                CSROp = 2'b00;//CSROp:2'b00= write
                IllegalInstruction = 1'b0;

                
            end
            3'b010:begin//CSRRS
                CSRWrite = (instruction[19:15] != 5'd0);
                Regwrite = 1'b1;
                CSRtoReg = 1'b1;
                UseRs1 = 1'b1;
                CSRUseImm = 1'b0;
                CSROp = 2'b01;//2'b01 = SET
                IllegalInstruction = 1'b0;

                 
            end
            3'b011:begin//CSRRC
                CSRWrite = (instruction[19:15] != 5'd0);
                Regwrite = 1'b1;
                CSRtoReg = 1'b1;
                UseRs1 = 1'b1;
                CSRUseImm = 1'b0;
                CSROp = 2'b10;//2'b10 = CLEAR
                IllegalInstruction = 1'b0;
            end
            3'b101:begin//CSRRWI
                CSRWrite = 1'b1;
                Regwrite = 1'b1;
                CSRtoReg = 1'b1;
                CSRUseImm = 1'b1;
                CSROp = 2'b00;//2'b00 = WRITE
                IllegalInstruction = 1'b0;
            end
            3'b110:begin//CSRRSI
                CSRWrite = (instruction[19:15] != 5'd0);
                Regwrite = 1'b1;
                CSRtoReg = 1'b1;
                CSRUseImm = 1'b1;
                CSROp = 2'b01;//2'b01 = SET
                IllegalInstruction = 1'b0;
            end
            3'b111:begin//CSRRCI
                CSRWrite = (instruction[19:15] != 5'd0);
                Regwrite = 1'b1;
                CSRtoReg = 1'b1;
                CSRUseImm = 1'b1;
                CSROp = 2'b10;//2'b10 = CLEAR
                IllegalInstruction = 1'b0;
            end
            default: begin end
            











            endcase
        end

    endcase



end




endmodule
