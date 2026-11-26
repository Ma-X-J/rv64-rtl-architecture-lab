


module CPU(
    input wire clk,
    input wire reset



);
   wire [63:0] current_pc;
   reg  [63:0] next_pc;
   wire [31:0] instruction;
   wire [63:0] instruction64;
   wire [63:0] readdata1;
   wire [63:0] readdata2;
   wire [63:0] aluresult;
   wire [63:0] mem_readdata;
   reg [63:0] writedata;
   wire [63:0] branch_offset = instruction64 << 1;//左移1位
   wire [63:0] jalr_pc;
   wire Branch;
   wire MemRead;
   wire [1:0]MemtoReg;//由于1位的写回mux已经不够用了，我需要从readdata，ALUResult和instruction64（LUI）里面3选1，所以现在扩展成2位
   wire [1:0]ALUOp;
   wire MemWrite;
   wire ALUSrc;
   wire Regwrite;
wire [4:0]ALUControl;
   wire zero;
   wire ALUASrc;
   wire Jump;
   wire JumpReg;
   wire branch_and_zero = Branch & zero;
   wire branch_and_not_zero = Branch & ~zero;
    
    



   PC u_pc(
    .clk(clk),
    .NextPC(next_pc),
    .CurrentPC(current_pc),
    .reset(reset),
    .PCwrite(1'b1)

   );

   IR u_ir(
    .CurrentPC(current_pc),
    .instruction(instruction)
   );

   Control u_control(
    .instruction(instruction),
    .Branch(Branch),
    .MemRead(MemRead),
    .MemtoReg(MemtoReg),
    .ALUOp(ALUOp),
    .MemWrite(MemWrite),
    .ALUSrc(ALUSrc),
    .Regwrite(Regwrite),
    .ALUASrc(ALUASrc),
    .Jump(Jump),
    .JumpReg(JumpReg)



   );

   ALUControl u_alucontrol(
    .ALUOp(ALUOp),
    .instruction(instruction),
    .ALUControl(ALUControl)






   );
   Immgen u_immgen(
    .instruction(instruction),
    .instruction64(instruction64)
   );

   Register u_register(
    .Readregister1(instruction[19:15]),
    .Readregister2(instruction[24:20]),
    .Writeregister(instruction[11:7]),
    .clk(clk),
    .Readdata1(readdata1),
    .Readdata2(readdata2),
    .Writedata(writedata),
    .Regwrite(Regwrite)


   );

   ALU u_alu(
    .A(ALUASrc ? current_pc : readdata1),
    .B(ALUSrc ? instruction64:readdata2),
    .ALUControl(ALUControl),
    .ALUResult(aluresult),
    .Zero(zero)

   );

   DataMemory u_datamemory(
    .clk(clk),
    .Address(aluresult),
    .Writedata(readdata2),
    .MemRead(MemRead),
    .Readdata(mem_readdata),
    .MemWrite(MemWrite)
   );
   always @(*) begin
    case(MemtoReg)
    2'b00:writedata = aluresult;
    2'b01:writedata = mem_readdata;
    2'b10:writedata = instruction64;
    2'b11:writedata = pc_plus4;
    default:writedata = 64'b0;
    endcase
   end
   
   wire [63:0]branch_pc = current_pc + branch_offset;
   wire [63:0]pc_plus4 = current_pc + 64'd4;
   assign jalr_pc = {aluresult[63:1],1'b0};
   


    always @(*) begin
        if(Jump)
        next_pc = branch_pc;
        else if(JumpReg) begin
            
            next_pc = jalr_pc;
            
        end
        else begin
            case(instruction[14:12])
           3'b000:next_pc = branch_and_zero ? branch_pc : pc_plus4;
           3'b001:next_pc = branch_and_not_zero ? branch_pc : pc_plus4;
           default:next_pc = pc_plus4;
        endcase
        end
        
    end
   

















endmodule
