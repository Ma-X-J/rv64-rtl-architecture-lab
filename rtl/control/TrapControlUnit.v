//本模块作用：接收已经检测出的异常事件和中断请求，判断是否进入 Trap，并从多个请求中选择最高优先级的一个。

module TrapControlUnit(
    //Input:valid（valid是1代表是真实的指令）,abnormal pc,5 symbols of abnormal phenomenons,
    //external_interrupt_pending,globalinterruptenable(外部中断必须满足两个都是1)
    input valid_mem,
    input [63:0]pc_mem,
    input external_interrupt_pending,
    input global_interrupt_enable,
    input instruction_misaligned_mem,
    input illegal_instruction_mem,
    input load_misaligned_mem,
    input store_misaligned_mem,
    input ecall_mem,
    output reg trap_enter,
    output reg [63:0]trap_pc,
    output reg [63:0]trap_cause


);
localparam CAUSE_INSTRUCTION_MISALIGNED = 64'h0;
localparam CAUSE_ILLEGAL_INSTRUCTION    = 64'h2;
localparam CAUSE_LOAD_MISALIGNED        = 64'h4;

localparam CAUSE_STORE_MISALIGNED       = 64'h6;
localparam CAUSE_ECALL_MMODE            = 64'hB;
localparam CAUSE_EXTERNAL_INTERRUPT     = 64'h800000000000000B;
always @(*) begin
    if(valid_mem) begin
         if(instruction_misaligned_mem) begin
        trap_enter = 1'b1;
        trap_pc = pc_mem;
        trap_cause = CAUSE_INSTRUCTION_MISALIGNED;
    end
        else if(illegal_instruction_mem) begin
            trap_enter = 1'b1;
            trap_pc = pc_mem;
            trap_cause = CAUSE_ILLEGAL_INSTRUCTION;

        end
        else if(ecall_mem) begin
            trap_enter = 1'b1;
            trap_pc = pc_mem;
            trap_cause = CAUSE_ECALL_MMODE;
        end
        
        else if(load_misaligned_mem) begin
            trap_enter = 1'b1;
            trap_pc = pc_mem;
            trap_cause = CAUSE_LOAD_MISALIGNED;

        end
        else if(store_misaligned_mem) begin
            trap_enter = 1'b1;
            trap_pc = pc_mem;
            trap_cause = CAUSE_STORE_MISALIGNED;
        end
        else if(external_interrupt_pending && global_interrupt_enable) begin
            trap_enter = 1'b1;
            trap_pc = pc_mem;
            trap_cause = CAUSE_EXTERNAL_INTERRUPT;
        end
        else begin
            
        
            
            trap_enter = 1'b0;
            trap_pc = 64'b0;
            trap_cause = 64'b0;

        end
    end
    else begin
        trap_enter = 1'b0;
        trap_pc = 64'b0;
        trap_cause = 64'b0;
    end
        
   

  


    
end




endmodule
