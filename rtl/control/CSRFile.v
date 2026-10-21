module CSRFile(
    input clk,
    input reset,
    input trap_enter,
    input [63:0]trap_pc,
    input [63:0]trap_cause,
    input mret,//正在实行异常返回指令
    input csr_we,//CSR软件写使能
    input [11:0]csr_raddr,//指定要读取或写入哪个CSR
    input [11:0]csr_waddr,//把读写分开为了让ID阶段读CSR和MEM阶段写CSR能同时进行
    input [63:0]csr_wdata,//软件准备写入 CSR 的值
    output reg [63:0]csr_rdata,//读取 csr_addr 指定的 CSR
    output reg [63:0]mtvec_out,//Trap 发生时作为入口地址
    output reg [63:0]mepc_out,//mret 时作为返回地址
    output reg [63:0]mcause_out,//查看 Trap 原因
    output wire global_interrupt_enable//对应64位mstatus中的MIE（1）位，决定是否允许响应中断



);
localparam [11:0] CSR_MSTATUS = 12'h300;
localparam [11:0] CSR_MTVEC   = 12'h305;
localparam [11:0] CSR_MEPC    = 12'h341;
localparam [11:0] CSR_MCAUSE  = 12'h342;
reg [63:0]mstatus;
localparam MSTATUS_MIE  = 3;
localparam MSTATUS_MPIE = 7;
assign global_interrupt_enable = mstatus[MSTATUS_MIE];//实际上就是mstatus中的第三位称为MIE位，有特殊作用
always @(*) begin
    case(csr_raddr)//根据12位CSR读地址来选择读取的寄存器
       CSR_MSTATUS:csr_rdata = mstatus;
       CSR_MTVEC:csr_rdata = mtvec_out;
       CSR_MEPC:csr_rdata = mepc_out;
       CSR_MCAUSE:csr_rdata = mcause_out;
       default: csr_rdata = 64'b0;
        
    endcase
end
always @(posedge clk) begin
    if(reset) begin
        mtvec_out <= 64'h0000_0000_0000_0100;//约定的跳转地址
        mepc_out <= 64'b0;
        mcause_out <= 64'b0;
        mstatus <= 64'b0;
        
    end
    else if(trap_enter) begin//进入中断状态
        mepc_out <= trap_pc;
        mcause_out <= trap_cause;
        
        mstatus[MSTATUS_MPIE] <= mstatus[MSTATUS_MIE];
         mstatus[MSTATUS_MIE] <= 1'b0;
    
    end
    else if(mret) begin//恢复中断状态
        mstatus[MSTATUS_MIE] <= mstatus[MSTATUS_MPIE];//恢复原来的值
        mstatus[MSTATUS_MPIE] <= 1'b1;
    end
    else if(csr_we) begin
        case(csr_waddr)//根据12位CSR写地址来选择要写的寄存器
          CSR_MSTATUS:begin mstatus[3] <= csr_wdata[3];
                            mstatus[7] <= csr_wdata[7];end
          CSR_MTVEC:mtvec_out <= {csr_wdata[63:2],2'b0};
          CSR_MEPC:mepc_out <= {csr_wdata[63:2],2'b0};
          CSR_MCAUSE:mcause_out <= csr_wdata;
          default:begin end//default什么都不修改 不支持的CSR地址，不执行写入
        endcase
    end

end





endmodule