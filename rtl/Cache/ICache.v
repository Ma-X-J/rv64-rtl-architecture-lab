module ICache(
    input clk,
    input reset,
    
    input cpu_req_valid,
    input [63:0]cpu_req_addr,
    output cpu_req_ready,
    output cpu_resp_valid,
    output reg [31:0]cpu_resp_instr,

    output mem_req_valid,
    output [63:0]mem_req_addr,

    input mem_req_ready,
    input mem_resp_valid,
    input [63:0]mem_resp_rdata 
    



);
  // Fixed geometry of the first teaching-oriented I-Cache.
  localparam integer ADDR_WIDTH             = 64;
  localparam integer BACKEND_DATA_WIDTH     = 64;
  localparam integer CACHE_LINES            = 8;
  localparam integer LINE_BYTES             = 32;
  localparam integer BACKEND_WORD_BYTES     = 8;
  localparam integer WORDS_PER_LINE         = 4;
  localparam integer WORD_OFFSET_BITS       = 2;
  localparam integer HALF_SELECT            = 1;
  localparam integer BYTE_OFFSET_BITS       = 2;
  localparam integer BLOCK_OFFSET_BITS      = 5;
  localparam integer INDEX_BITS             = 3;
  localparam integer TAG_WIDTH              = 56;
  localparam integer CACHE_CAPACITY_BYTES   = CACHE_LINES * LINE_BYTES;
   
  //STATE MACHINE
  reg [1:0]state;
  localparam STATE_IDLE = 2'd0;
  localparam STATE_REFILL_REQ = 2'd1;
  localparam STATE_REFILL_WAIT = 2'd2;
  localparam STATE_RESP = 2'd3;









  //当前CPU地址的拆分
  wire [55:0]cpu_addr_tag = cpu_req_addr[63:8];
  wire [2:0]cpu_addr_index = cpu_req_addr[7:5];
  wire [1:0]cpu_addr_word_offset = cpu_req_addr[4:3];
  wire cpu_addr_half_select = cpu_req_addr[2];
  wire [1:0]cpu_addr_byte_offset = cpu_req_addr[1:0];
  wire cpu_addr_aligned = cpu_addr_byte_offset == 0;
  wire [63:0]cpu_line_base = {cpu_req_addr[63:5],5'b0};


  //backend锁存地址的拆分
  reg [63:0]req_addr_reg;
  wire [55:0]req_tag = req_addr_reg[63:8];
  wire [2:0]req_index = req_addr_reg[7:5];
  wire [1:0]req_word_offset = req_addr_reg[4:3];
  wire req_half_select = req_addr_reg[2];
  wire [1:0]req_byte_offset = req_addr_reg[1:0];
  wire req_addr_aligned = req_byte_offset == 0;
  wire [63:0]req_line_base = {req_addr_reg[63:5],5'b0};

  //Cache array
  reg [CACHE_LINES-1:0]valid_array;
  reg [TAG_WIDTH-1:0]tag_array[0:CACHE_LINES-1];
  reg [BACKEND_DATA_WIDTH-1:0]data_array[0:CACHE_LINES-1][0:WORDS_PER_LINE-1];

//basic hit logic
  wire cpu_line_hit;
  wire cpu_instr_hit;
  assign cpu_line_hit = valid_array[cpu_addr_index] && 
                        (tag_array[cpu_addr_index] == cpu_addr_tag); 
  assign cpu_instr_hit = cpu_req_valid && 
                          cpu_addr_aligned &&
                        cpu_line_hit;


  //choose the width=32 instr
  wire [63:0]selected_word64 = data_array[cpu_addr_index][cpu_addr_word_offset];
  wire [31:0]cpu_hit_instr;
  assign cpu_hit_instr = cpu_addr_half_select ? selected_word64[63:32] : selected_word64[31:0];
  


  //cpu_resp logic
  assign cpu_req_ready = ~reset &&
                         state == STATE_IDLE &&
                         cpu_addr_aligned;

  assign cpu_resp_valid = ~reset &&
                         ((state == STATE_IDLE && cpu_instr_hit) ||
                          state == STATE_RESP);
                         

  wire cpu_req_fire = cpu_req_ready && cpu_req_valid;

  always @( *) begin
    if(~cpu_resp_valid) begin
      cpu_resp_instr = 32'b0;
    end
    else if(state == STATE_RESP) begin
      if(req_half_select)
      cpu_resp_instr = data_array[req_index][req_word_offset][63:32];
      else
      cpu_resp_instr = data_array[req_index][req_word_offset][31:0];
    end
    else begin
      cpu_resp_instr = cpu_hit_instr;
    end
  end

 


//MISS logic
  //miss validate
  
  wire cpu_instr_miss_fire = cpu_req_fire && ~cpu_line_hit;

  //bias calculation logic
  reg [1:0]refill_word_index;
  wire [63:0]refill_word_byte_offset;
  assign refill_word_byte_offset = {59'b0, refill_word_index, 3'b0};

  //backend mem signals declaration
  assign mem_req_valid = ~reset && state == STATE_REFILL_REQ;

  assign mem_req_addr = req_line_base + refill_word_byte_offset;

  wire mem_req_fire = mem_req_valid && mem_req_ready;

  wire mem_resp_fire = !reset && 
                       state == STATE_REFILL_WAIT &&
                       mem_resp_valid;



















  //FSM
  always @(posedge clk) begin
    if(reset)begin
        valid_array <= {CACHE_LINES{1'b0}};
        state <= STATE_IDLE;
        req_addr_reg <= 64'b0;
        refill_word_index <= 2'b0;
    end
    else
    case(state)
    STATE_IDLE:begin
        if(cpu_instr_miss_fire) begin
            req_addr_reg <= cpu_req_addr;

            refill_word_index <= 2'b00;
            state <= STATE_REFILL_REQ;
        end
        else
          state <= STATE_IDLE;
          end

    STATE_REFILL_REQ:begin

        if(mem_req_fire) begin
          state <= STATE_REFILL_WAIT;
        end
        else
          state <= STATE_REFILL_REQ;
       
    end

    STATE_REFILL_WAIT:begin
      if(mem_resp_fire && refill_word_index != 2'd3) begin
        data_array[req_index][refill_word_index] <= mem_resp_rdata;
        refill_word_index <= refill_word_index + 1;
        state <= STATE_REFILL_REQ;
      end

      else if(mem_resp_fire && refill_word_index == 2'd3) begin
        data_array[req_index][3] <= mem_resp_rdata;
       
        state <= STATE_RESP;
      end
      else begin


        refill_word_index <= refill_word_index;
        state <= STATE_REFILL_WAIT;
        

      end
    end

    STATE_RESP:begin
        tag_array[req_index] <= req_tag;
        valid_array[req_index] <= 1'b1;
        state <= STATE_IDLE;
      
    end
    default:
      state <= STATE_IDLE;
      
    





    endcase

      
  end



















endmodule