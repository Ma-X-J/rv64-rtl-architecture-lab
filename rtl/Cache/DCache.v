module DCache(
    //CPU to D-Cache ports
    input clk,
    input reset,
    input cpu_req_valid,//CPU is offering a valid request
    input [63:0]cpu_req_addr,
    input cpu_req_write,
    input [63:0]cpu_req_wdata,
    output cpu_req_ready,//Cache is ready for a new request
    output cpu_resp_valid,//the request has been done(response valid)
    output reg [63:0]cpu_resp_rdata,//the data from LOAD

    //D-Cache to backend memory ports
    input mem_req_ready,//backend takes the request
    input mem_resp_valid,//readdata returned or write finished
    input [63:0]mem_resp_rdata,//readdata from the backend
    output mem_req_valid,//have a request for 访问 backend
    output mem_req_write,//read or write backend
    output reg [63:0]mem_req_addr,//Byte address
    output [63:0]mem_req_wdata//write data

   


);
  // Fixed geometry of the first teaching-oriented D-Cache.
  localparam integer ADDR_WIDTH             = 64;
  localparam integer BACKEND_DATA_WIDTH     = 64;
  localparam integer CACHE_LINES            = 8;
  localparam integer LINE_BYTES             = 32;
  localparam integer BACKEND_WORD_BYTES     = 8;
  localparam integer WORDS_PER_LINE         = 4;
  localparam integer BYTE_OFFSET_BITS       = 3;
  localparam integer WORD_OFFSET_BITS       = 2;
  localparam integer BLOCK_OFFSET_BITS      = 5;
  localparam integer INDEX_BITS             = 3;
  localparam integer TAG_WIDTH              = 56;
  localparam integer CACHE_CAPACITY_BYTES   = CACHE_LINES * LINE_BYTES;

 //SEVEN STATES
  localparam STATE_IDLE = 3'd0;
  localparam STATE_REFILL_REQ = 3'd1;//准备向后端发一次读请求
  localparam STATE_REFILL_WAIT = 3'd2;//后端已经接收请求，等待返回64位数据
  localparam STATE_RESP = 3'd3;//cache line已经填充完成，向cpu返回原始load数据
  localparam STATE_STORE_REQ = 3'd4;
  localparam STATE_STORE_WAIT = 3'd5;
  localparam STATE_STORE_RESP = 3'd6;
  reg [2:0]state;







  reg [CACHE_LINES-1:0]valid_array;
  reg [TAG_WIDTH-1:0]tag_array[0:CACHE_LINES-1];//8个cache line，每个line保存一个56位tag
  reg [BACKEND_DATA_WIDTH-1:0]data_array[0:CACHE_LINES-1][0:WORDS_PER_LINE-1];//8个cache line，每个line包含4个word，每个word64位

 
//LOAD 
 wire cpu_load_hit;
 wire cpu_line_hit;
 wire [BACKEND_DATA_WIDTH-1:0] cpu_hit_rdata;
 wire cpu_load_miss_fire;
 wire cpu_req_fire;
 
 wire mem_req_fire;
 wire mem_resp_fire;

 reg [WORD_OFFSET_BITS-1:0]refill_word_index;
 wire [63:0]refill_word_byte_offset;
 wire [63:0]refill_resp_rdata;


//STORE
 wire cpu_store_fire;
 reg store_hit_reg;//Store 被接受的那个周期，目标 Cache Line 是否命中。
 wire store_mem_resp_fire;


 //当前CPU地址的拆分
  wire [55:0]cpu_addr_tag = cpu_req_addr[63:8];
  wire [2:0]cpu_addr_index = cpu_req_addr[7:5];
  wire [1:0]cpu_addr_word_offset = cpu_req_addr[4:3];
  wire [2:0]cpu_addr_byte_offset = cpu_req_addr[2:0];
  wire cpu_addr_aligned = cpu_addr_byte_offset == 0;
  wire [63:0]cpu_line_base = {cpu_req_addr[63:5],5'b0};





 //prepare for the FSM(已经锁存的地址的拆分)
  reg [63:0]req_addr_reg;//保存原始请求地址
  reg req_write_reg;//保存ld/sd的类型
  reg [63:0]req_wdata_reg;//save the data of SD
  wire [55:0]req_tag = req_addr_reg[63:8];
  wire [2:0]req_index = req_addr_reg[7:5];
  wire [1:0]req_word_offset = req_addr_reg[4:3];//byte offset = 地址低3位 = 3‘b000，这里直接不写
  wire [2:0]req_byte_offset = req_addr_reg[2:0];
  wire req_addr_aligned = req_byte_offset == 0;
  wire [63:0]req_line_base = {req_addr_reg[63:5],5'b0};//CACHE的起始地址

//为了判断CACHE是否命中而服务（cache内部的判断结果
  //valid复位逻辑（合并到FSM中）


  //基础LINE命中判断(tag相同，且均有效)
  assign cpu_line_hit = valid_array[cpu_addr_index] && (tag_array[cpu_addr_index] == cpu_addr_tag);

  //完整的load hit判断
  assign cpu_load_hit = cpu_req_valid && !cpu_req_write && cpu_addr_aligned && cpu_line_hit;
  
  //选择命中数据
  assign cpu_hit_rdata = data_array[cpu_addr_index][cpu_addr_word_offset];

//让已经验证正确的 Load hit 通过CPU侧正式接口在同一周期完成。(cpu需要正式接口来知道cache的这些结果）
  //驱动cpu_req_ready
  assign cpu_req_ready = !reset && 
                        // !cpu_req_write && (删除后允许store)
                         cpu_addr_aligned &&  
                         state == STATE_IDLE;
                         

  //驱动cpu_resp_valid
  assign cpu_resp_valid = !reset && 
                       ((cpu_load_hit && 
                       state == STATE_IDLE) || 
                       state == STATE_RESP ||
                       state == STATE_STORE_RESP);//请求已经完成
  assign cpu_req_fire = cpu_req_valid && cpu_req_ready;//请求被接收

  //驱动cpu_resp_rdata//10/14修改成组合逻辑驱动来支持miss时的数据
  //注：miss完成响应>当前CPU地址的HIT数据
  always @( *) begin
    if(!cpu_resp_valid)
      cpu_resp_rdata = 64'b0;
    else if(state == STATE_STORE_RESP)
      cpu_resp_rdata = 64'b0;
    else if(state == STATE_RESP)
      cpu_resp_rdata = data_array[req_index][req_word_offset];
    else
      cpu_resp_rdata = cpu_hit_rdata;
        
  end



//让D-CACHE接收并记住一个load miss请求
  //表示一个 Load miss 请求在这个周期真正被 Cache 接受了。
  assign cpu_load_miss_fire = cpu_req_fire && 
                             !cpu_line_hit &&
                             !cpu_req_write;

  
      
        
  //在STATE_REFILL_REQ阶段DCACHE向后端发送一个64位请求，然后后端接受，并进入STATE_REFILL_WAIT
    //握手信号的声明
    assign mem_req_valid = !reset && 
                (state == STATE_REFILL_REQ || state == STATE_STORE_REQ);
                           
    


    
    assign mem_req_fire = mem_req_valid && mem_req_ready;
    assign mem_resp_fire = !reset && 
                            state == STATE_REFILL_WAIT &&
                            mem_resp_valid;
    //根据计数器来生成后端地址
    assign refill_word_byte_offset = {59'b0, refill_word_index, 3'b0};
    
  //在 STATE_RESP中正式提交已经填充完成的 Cache Line，向 CPU 返回原始 Load 需要的 word，并结束这次 miss。
    assign refill_resp_rdata = data_array[req_index][req_word_offset];


//STORE的相关信号声明
    //CPU接收部分
    assign cpu_store_fire = cpu_req_fire && cpu_req_write;
    ///改动cpu_req_ready,允许接收store
    ///扩展mem_req_valid,让其在STATE_STORE_REQ时能够写请求

    assign mem_req_write = mem_req_valid && (state == STATE_STORE_REQ);
    
    assign mem_req_wdata = mem_req_write ? req_wdata_reg : 64'b0;

    //修改mem_req_addr的输出逻辑，如果是store则写入req_addr_reg
    always @(*) begin
      if(~mem_req_valid)
        mem_req_addr = 64'b0;
      else if(mem_req_write)
        mem_req_addr = req_addr_reg;
      else
        mem_req_addr = req_line_base + refill_word_byte_offset;
    end

    //
    assign store_mem_resp_fire = !reset && 
                              state == STATE_STORE_WAIT &&
                              mem_resp_valid;
    














//FSM
  always @(posedge clk) begin
    if(reset) begin
    state <= STATE_IDLE;
    req_addr_reg <= 64'b0;
    req_write_reg <= 1'b0;
    req_wdata_reg <= 64'b0;
    refill_word_index <= 2'b0;
    valid_array <= {CACHE_LINES{1'b0}};
    store_hit_reg <= 1'b0;
    end
    else
    case(state)
    STATE_IDLE:
      if(cpu_store_fire) begin
        req_addr_reg <= cpu_req_addr;
        req_write_reg <= cpu_req_write;
        req_wdata_reg <= cpu_req_wdata;
        store_hit_reg <= cpu_line_hit;
        state <= STATE_STORE_REQ;
      end

      else if(cpu_load_miss_fire) begin
        req_addr_reg <= cpu_req_addr;
        req_write_reg <= cpu_req_write;
        req_wdata_reg <= cpu_req_wdata;
        refill_word_index <= 2'b0;
        state <= STATE_REFILL_REQ;
      end
      else
        state <= STATE_IDLE;
    STATE_REFILL_REQ:
       if(mem_req_fire) 
        state <= STATE_REFILL_WAIT;
       else
        state <= STATE_REFILL_REQ;
       
    STATE_REFILL_WAIT:
       if(mem_resp_fire && refill_word_index != 3)begin
        data_array[req_index][refill_word_index] <= mem_resp_rdata;
        refill_word_index <= refill_word_index + 1;
        state <= STATE_REFILL_REQ;
       end
       else if(mem_resp_fire && refill_word_index == 3) begin
        data_array[req_index][3] <= mem_resp_rdata;
        state <= STATE_RESP;
       end
       else begin
        state <= STATE_REFILL_WAIT;
        refill_word_index <= refill_word_index;
       end
    STATE_RESP: begin
        tag_array[req_index] <= req_tag;
        valid_array[req_index] <= 1'b1;
        state <= STATE_IDLE;
      end
    STATE_STORE_REQ:begin
      if(mem_req_fire)
      state <= STATE_STORE_WAIT;
      else
      state <= STATE_STORE_REQ;
    end
    STATE_STORE_WAIT:begin
      if(store_mem_resp_fire) begin
        
       if(store_hit_reg) begin
          data_array[req_index][req_word_offset] <= req_wdata_reg;
        end  
       state <= STATE_STORE_RESP;
      end
      
        
      else
        state <= STATE_STORE_WAIT;
      
        
        
    end
    STATE_STORE_RESP:begin
      state <= STATE_IDLE;
    end
        
        
       
       
    default:state <= STATE_IDLE;
   endcase
  end





endmodule
