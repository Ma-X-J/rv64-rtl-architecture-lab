module CacheBackingMemory(
    input clk,
    input reset,
    input req_valid,
    input req_write,
    input [63:0]req_addr,
    input [63:0]req_wdata,
    output reg req_ready,
    output reg resp_valid,
    output reg [63:0]resp_rdata

);
//从请求被接受的时钟沿，到响应有效之间间隔 3 个周期
localparam LATENCY = 3;

//256个64位字
reg [63:0]memory[0:255];

//FSM preparation
localparam IDLE = 2'b00;
localparam WAIT = 2'b01;
localparam RESP = 2'b10;
reg [1:0]state;

//在req_fire成立才接收事件
wire req_fire = req_valid && req_ready;//只有req_fire成立的时钟沿才锁存req_addr,req_write,req_wdata


//锁存已经接收的请求
reg [63:0]pending_addr;
reg pending_write;
reg [63:0]pending_wdata;

//8位延迟计数器
reg [7:0]delay_count;

//根据锁存地址得到存储器的下标
wire [7:0] word_index = pending_addr[10:3];

// 地址范围0x000～0x7FF，并且8字节对齐
wire address_legal = (pending_addr[63:11] == 53'b0) && (pending_addr[2:0]   == 3'b000);
       
        

//FSM
always @( *) begin
    req_ready = 1'b0;
    resp_valid = 1'b0;
    case(state)
    IDLE:
      req_ready = 1'b1;
    WAIT:
      req_ready = 1'b0;
      
    RESP:
      resp_valid = 1'b1;

    endcase
end

always @(posedge clk) begin
    if(reset) begin
    state <= IDLE;
    pending_addr <= 64'b0;
    pending_write <= 1'b0;
    pending_wdata <= 64'b0;
    delay_count <= 3'b0;
    resp_rdata <= 64'b0;
    end
    else begin
        case(state)
        IDLE:begin
            if(req_fire) begin
                pending_addr <= req_addr;
                pending_write <= req_write;
                pending_wdata <= req_wdata;
                delay_count <= LATENCY;
                state <= WAIT ;
            end
        end
        WAIT:begin
            if(delay_count > 1) begin
                delay_count <= delay_count - 1'b1;//延迟3个周期
            end
            else begin
                if(address_legal) begin
                    if(pending_write) begin//这里要用锁存值，因为req_write调用者可以改变
                        //写请求
                        memory[word_index] <= pending_wdata;
                        resp_rdata <= 64'b0;//why?
                    end
                    else
                        //读请求
                        resp_rdata <= memory[word_index];


                end
                else begin
                    resp_rdata <= 64'b0;
                end
                state <= RESP;
            end
            
        end
        RESP:begin
            state <= IDLE;
     
                
        end
        endcase

    end
end















endmodule