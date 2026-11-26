


module PIPELINED_CPU #(
    // 0: bimodal BHT, 1: non-speculative global predictor,
    // 2: tournament predictor selecting between the two.
    parameter BRANCH_PREDICTOR_MODE = 0,
    // Smallest practical capacities for the current CoreMark build:
    // about 11.7 KiB text plus startup, and 2 KiB static data plus stack.
    parameter integer ICACHE_BACKING_WORDS = 2048, // 16 KiB
    parameter integer DCACHE_BACKING_WORDS = 1024, // 8 KiB
    // Unified CPU address map over separate instruction/data arrays.
    parameter [63:0] ICACHE_BACKING_BASE_ADDR = 64'h0000_0000_0000_0000,
    parameter [63:0] DCACHE_BACKING_BASE_ADDR = 64'h0000_0000_0000_4000
)(
    input reset,
    input clk,
    input external_interrupt_pending//需要连接外部的驱动，所以要放在input里
);

   // IF stage
   wire [63:0] current_pc_if;
   reg  [63:0] next_pc;
   wire [31:0] instruction_if = icache_resp_usable ? icache_cpu_resp_instr:32'b0;
   wire [63:0]pc_plus4_if = current_pc_if +64'd4;

   // ID stage
   wire [63:0] pc_id;
   wire [31:0] instruction_id;
   wire [63:0] instruction64_id;
   wire [63:0] readdata1_id;
   wire [63:0] readdata2_id;
   wire        Branch_id;
   wire        MemRead_id;
   wire [1:0]  MemtoReg_id;
   wire [1:0]  ALUOp_id;
   wire        MemWrite_id;
   wire        ALUSrc_id;
   wire        Regwrite_id;
   wire        ALUASrc_id;
   wire        Jump_id;
   wire        JumpReg_id;
   wire        illegal_instruction_id;
   wire        ecall_id;
   wire        mret_id;
   wire        CSRWrite_id;
   wire [1:0]  CSROp_id;
   wire        CSRUseImm_id;
   wire        CSRtoReg_id;
   wire [63:0] CSR_rdata_id;//表示ID阶段当前指令读到的CSR值

   wire [1:0]  CSRForward_id;//两位CSR前递逻辑
   reg [63:0] CSR_rdata_effective_id;

   



   // EX stage
   wire [63:0] current_pc_ex;
   wire [63:0] readdata1_ex;
   wire [63:0] readdata2_ex;
   wire [63:0] instruction64_ex;
   wire [31:0] instruction_ex;
   wire        Branch_ex;
   wire        MemRead_ex;
   wire [1:0]  MemtoReg_ex;
   wire [1:0]  ALUOp_ex;
   wire        MemWrite_ex;
   wire        ALUSrc_ex;
   wire        Regwrite_ex;
   wire        ALUASrc_ex;
   wire        Jump_ex;
   wire        JumpReg_ex;
   wire        illegal_instruction_ex;
   wire        ecall_ex;
   wire        mret_ex;
   wire        CSRWrite_ex;
   wire [1:0]  CSROp_ex;
   wire        CSRUseImm_ex;
   wire        CSRtoReg_ex;
   wire [4:0]  ALUControl_ex;
   wire [63:0] aluresult_ex;
   wire        zero_ex;
   wire [63:0] branch_pc_ex;
   wire [63:0] pc_plus4_ex;
   wire [63:0] CSR_rdata_ex;//表示ID阶段读出来的值通过ID/EX寄存器输出用于EX阶段的运算
    reg [63:0] CSR_wdata_ex;
   



   //Forwarding unit stage
   wire [1:0]forwardA;
   wire [1:0]forwardB;
   reg [63:0]forwardA_result;
   reg [63:0]forwardB_result;
   reg [63:0]forward_data_mem;

   //load-use HazardDetectionUnit stage
   wire users1_id;
   wire users2_id;
   wire PCwrite_hazard;
   wire IF_ID_write_hazard;
   wire ID_EX_flush_hazard;

   //branch hazard detection
   reg  control_flush_mem;
   wire beq_taken_mem =
    Branch_mem &&
    (instruction_mem[14:12] == 3'b000) &&
    zero_mem;//必须要结合funct3来判断是beq还是bne，不然只用branch，bne和beq都是1，判断不出

   wire bne_taken_mem = Branch_mem && (instruction_mem[14:12] == 3'b001) && !zero_mem;
   wire blt_taken_mem = Branch_mem && (instruction_mem[14:12] == 3'b100) && !zero_mem;
   wire bge_taken_mem = Branch_mem && (instruction_mem[14:12] == 3'b101) && !zero_mem;
   wire bltu_taken_mem = Branch_mem && (instruction_mem[14:12] == 3'b110) && !zero_mem;
   wire bgeu_taken_mem = Branch_mem && (instruction_mem[14:12] == 3'b111) && !zero_mem;
    

    wire branch_taken_mem = beq_taken_mem || bne_taken_mem ||
                            blt_taken_mem || bge_taken_mem ||
                            bltu_taken_mem || bgeu_taken_mem;
    ///wire ID_EX_flush_final = ID_EX_flush_hazard || control_flush_mem;
    ///wire PCwrite_final = PCwrite_hazard || control_flush_mem;

    //branch prediction unit
    wire predicted_taken_if;
    wire [3:0]bht_index_if;
    wire [5:0]global_index_if;
    wire bimodal_prediction_if;
    wire global_prediction_if;
    wire chooser_prefers_global_if;
    wire predicted_taken_id;
    wire [3:0]bht_index_id;
    wire [5:0]global_index_id;
    wire bimodal_prediction_id;
    wire global_prediction_id;
    wire predicted_taken_ex;
    wire [3:0]bht_index_ex;
    wire [5:0]global_index_ex;
    wire bimodal_prediction_ex;
    wire global_prediction_ex;
    wire predicted_taken_mem;
    wire [3:0]bht_index_mem;
    wire [5:0]global_index_mem;
    wire bimodal_prediction_mem;
    wire global_prediction_mem;

    //for IF immgen to calculate the branch prediction address
    wire [63:0]instruction64_if;
    wire [63:0]predicted_branch_pc_if;

    //CSR and trap control unit
    wire valid_if = icache_resp_usable;
    wire valid_id;
    wire valid_ex;
    wire valid_mem;
    wire trap_enter;
    wire [63:0]trap_pc;
    wire [63:0]trap_cause;
    wire global_interrupt_enable;
    wire [63:0]mepc_csr;
    wire [63:0]mtvec_csr;
    wire [63:0]mcause_csr;
    



       

   // MEM stage
   wire [63:0] branch_pc_mem;
   wire        zero_mem;
   wire [63:0] aluresult_mem;
   wire [63:0] storedata_mem;
   wire [63:0] instruction64_mem;
   wire [31:0] instruction_mem;
   wire [63:0] pc_plus4_mem;
   wire        Branch_mem;
   wire        Jump_mem;
   wire        JumpReg_mem;
   wire        MemWrite_mem;
   wire        MemRead_mem;
   wire [1:0]  MemtoReg_mem;
   wire        Regwrite_mem;
   wire [63:0] mem_readdata_mem;

    wire [63:0]jalr_pc_mem = {aluresult_mem[63:1], 1'b0};
    wire branch_and_zero_mem = Branch_mem && zero_mem;
    wire branch_and_not_zero_mem = Branch_mem && ~zero_mem;
    
   wire        illegal_instruction_mem;
   wire        ecall_mem;
   wire        mret_mem;
   wire        CSRWrite_mem;
   wire        CSRtoReg_mem;
   wire [63:0] CSR_rdata_mem;
   wire [63:0] CSR_wdata_mem;

   reg  instruction_misaligned_mem;
   reg  load_misaligned_mem;
   reg  store_misaligned_mem; 

   wire [63:0]current_pc_mem;
   
   //MEM whether change CSRFile or not
    wire CSRvalid_mem = valid_mem && CSRWrite_mem && ~trap_enter;

    //MEM avoid CSR memwrite(sd) and regwrite(ld) in datamemory when trap
    wire MemWrite_valid_mem = valid_mem && MemWrite_mem && ~trap_enter;
    wire Regwrite_valid_mem = valid_mem && Regwrite_mem && ~trap_enter;

   //MEM 合法信号检测
    wire MemRead_valid_mem = valid_mem &&  
                              MemRead_mem &&
                              ~trap_enter;
    ///MemWrite_valid_mem已经在上面声明


 //I-Cache

    //I-cache wait logic
    reg icache_request_inflight;
    reg [63:0]icache_pending_pc;

    //CPU send req to I-cache
    wire icache_cpu_req_valid = ~reset && ~control_flush_mem;
                               
                               
    wire [63:0]icache_cpu_req_addr = current_pc_if;
    wire icache_cpu_req_ready;
    wire icache_cpu_req_fire = icache_cpu_req_valid && icache_cpu_req_ready;


    //I-Cache provide CPU the instr
    wire icache_cpu_resp_valid;
    wire [31:0]icache_cpu_resp_instr;
    wire icache_hit_resp_usable = icache_cpu_resp_valid &&
                                 ~icache_request_inflight;
    wire icache_miss_resp_usable = icache_cpu_resp_valid &&
                                  icache_request_inflight &&
                                  (icache_pending_pc == current_pc_if);
    wire icache_resp_usable = ~control_flush_mem && (icache_hit_resp_usable || icache_miss_resp_usable);




    //I-Cache to backend
    wire icache_mem_req_valid;
    wire [63:0]icache_mem_req_addr;

    //backend to I-Cache
    wire icache_mem_req_ready;
    wire icache_mem_resp_valid;
    wire [63:0]icache_mem_resp_rdata;

    always @(posedge clk) begin
      if(reset)
        icache_request_inflight <= 1'b0;
      else if(icache_cpu_resp_valid)
        icache_request_inflight <= 1'b0;
      else if(icache_cpu_req_fire)
        icache_request_inflight <= 1'b1;
      else
        icache_request_inflight <= icache_request_inflight;
    end

    always @(posedge clk) begin
      if(reset)
       icache_pending_pc <= 64'b0;
       else if(icache_cpu_req_fire && ~icache_cpu_resp_valid)
        icache_pending_pc <= current_pc_if;
      else
        icache_pending_pc <= icache_pending_pc;
    end


    

    
    
 //D-Cache
   //MEM to D-Cache request
    wire dcache_cpu_req_valid = MemWrite_valid_mem || MemRead_valid_mem;
    wire [63:0]dcache_cpu_req_addr = aluresult_mem;
    wire dcache_cpu_req_write = MemWrite_valid_mem;
    wire [5:0]store_shift_bits = {aluresult_mem[2:0], 3'b000};
    reg [7:0]store_base_wstrb;
    always @(*) begin
      case (instruction_mem[14:12])
        3'b000: store_base_wstrb = 8'h01; // SB
        3'b001: store_base_wstrb = 8'h03; // SH
        3'b010: store_base_wstrb = 8'h0f; // SW
        3'b011: store_base_wstrb = 8'hff; // SD
        default: store_base_wstrb = 8'h00;
      endcase
    end
    wire [7:0]dcache_cpu_req_wstrb =
      store_base_wstrb << aluresult_mem[2:0];
    wire [63:0]dcache_cpu_req_wdata =
      storedata_mem << store_shift_bits;

    //MEM D_Cache to CPU feedback(dcache_cpu)
    wire dcache_cpu_req_ready;
    wire dcache_cpu_resp_valid;
    wire [63:0]dcache_cpu_resp_rdata;
    wire [63:0]shifted_load_word =
      dcache_cpu_resp_rdata >> store_shift_bits;
    reg [63:0]load_data_mem;
    always @(*) begin
      case (instruction_mem[14:12])
        3'b000: load_data_mem = {{56{shifted_load_word[7]}},
                                 shifted_load_word[7:0]};  // LB
        3'b001: load_data_mem = {{48{shifted_load_word[15]}},
                                 shifted_load_word[15:0]}; // LH
        3'b010: load_data_mem = {{32{shifted_load_word[31]}},
                                 shifted_load_word[31:0]}; // LW
        3'b011: load_data_mem = shifted_load_word;         // LD
        3'b100: load_data_mem = {56'b0, shifted_load_word[7:0]};
        3'b101: load_data_mem = {48'b0, shifted_load_word[15:0]};
        3'b110: load_data_mem = {32'b0, shifted_load_word[31:0]};
        default: load_data_mem = 64'b0;
      endcase
    end
    wire dcache_cpu_req_fire = dcache_cpu_req_valid &&
                               dcache_cpu_req_ready;
    //MEM D-Cache to backend memory(dcache_mem)
    wire dcache_mem_req_valid;
    wire dcache_mem_req_write;
    wire [63:0]dcache_mem_req_addr;
    wire [63:0]dcache_mem_req_wdata;
    wire [7:0]dcache_mem_req_wstrb;

    wire dcache_mem_req_ready;
    wire dcache_mem_resp_valid;
    wire[63:0]dcache_mem_resp_rdata;

    //D-cache stall logic
    wire dcache_stall = dcache_cpu_req_valid &&
                        ~dcache_cpu_resp_valid;
    wire IF_ID_write_final = IF_ID_write_hazard &&
                             ~dcache_stall;
    wire ID_EX_write_final = ~dcache_stall;
    wire EX_MEM_write_final = ~dcache_stall;
    wire MEM_WB_write_final = ~dcache_stall;
    wire ID_EX_flush_final = control_flush_mem ||
                               (ID_EX_flush_hazard && ~dcache_stall);

    wire PCwrite_final = control_flush_mem ||
                          (PCwrite_hazard && ~dcache_stall && icache_resp_usable);
    wire Regwrite_commit_mem = Regwrite_valid_mem &&
                                ~dcache_stall;
   // wire MemWrite_commit_mem = MemWrite_valid_mem &&~cache_stall;
                               
    wire load_complete_mem = MemRead_valid_mem && 
                              dcache_cpu_resp_valid;//Mem阶段有一条有效的load，且Dcache完成了该load
    assign mem_readdata_mem = load_complete_mem ? load_data_mem : 64'b0;
    ///wire [63:0] legacy_mem_readdata;

    //D-cache and Trap control
    reg dcache_request_inflight;//用于表示D-cache接收了一个不能当周期完成的请求但还没有产生完成响应
        
    always @(posedge clk) begin
        if(reset)
          dcache_request_inflight <= 1'b0;
        else if(dcache_cpu_resp_valid)
          dcache_request_inflight <= 1'b0;
        else if(dcache_cpu_req_fire)
          dcache_request_inflight <= 1'b1;
        else
          dcache_request_inflight <= dcache_request_inflight;
          
    end

    wire external_interrupt_pending_effective = external_interrupt_pending && ~dcache_request_inflight;




   // WB stage
   wire [63:0] mem_readdata_wb;
   wire [63:0] aluresult_wb;
   wire [1:0]  MemtoReg_wb;
   wire [63:0] instruction64_wb;
   wire [31:0] instruction_wb;
   wire [63:0] pc_plus4_wb;
   wire        Regwrite_wb;
   wire        Regwrite_forward_wb;
   reg         wb_stall_commit_done;
   wire        CSRtoReg_wb;
   reg  [63:0] writedata_wb;
   wire [63:0] CSR_rdata_wb;
   wire mret_valid = valid_mem && mret_mem;

  





















  PC u_pc(
    .clk(clk),
    .NextPC(next_pc),
    .CurrentPC(current_pc_if),
    .reset(reset),
    .PCwrite(PCwrite_final)

   );

   Control u_control(
    .instruction(instruction_id),
    .Branch(Branch_id),
    .MemRead(MemRead_id),
    .MemtoReg(MemtoReg_id),
    .ALUOp(ALUOp_id),
    .MemWrite(MemWrite_id),
    .ALUSrc(ALUSrc_id),
    .Regwrite(Regwrite_id),
    .ALUASrc(ALUASrc_id),
    .Jump(Jump_id),
     .JumpReg(JumpReg_id),
     .UseRs1(users1_id),
     .UseRs2(users2_id),
     .IllegalInstruction(illegal_instruction_id),
     .Ecall(ecall_id),
     .Mret(mret_id),
     .CSRWrite(CSRWrite_id),
     .CSROp(CSROp_id),
     .CSRUseImm(CSRUseImm_id),
     .CSRtoReg(CSRtoReg_id)
     );

    ALUControl u_alucontrol(
    .ALUOp(ALUOp_ex),
    .instruction(instruction_ex),
    .ALUControl(ALUControl_ex)
    );

    Immgen u_immgen(
    .instruction(instruction_id),
    .instruction64(instruction64_id)
   );

    Register u_register(
    .Readregister1(instruction_id[19:15]),
    .Readregister2(instruction_id[24:20]),
    .Writeregister(instruction_wb[11:7]),
    .clk(clk),
    .Readdata1(readdata1_id),
    .Readdata2(readdata2_id),
    .Writedata(writedata_wb),
    .Regwrite(Regwrite_wb)


   );
    
    ALU u_alu(
    .A(ALUASrc_ex ? current_pc_ex : forwardA_result),
    .B(ALUSrc_ex ? instruction64_ex :forwardB_result),
    .ALUControl(ALUControl_ex),
    .ALUResult(aluresult_ex),
    .Zero(zero_ex)

   );
   IF_ID u_if_id(
    .current_pc(current_pc_if),
    .instruction_in(instruction_if),
    .reset(reset),
    .clk(clk),
    .instruction_out(instruction_id),
    .pc_out(pc_id),
    .IF_IDwrite(IF_ID_write_final),
    .IF_ID_flush(control_flush_mem),
    .predicted_taken_in(predicted_taken_if),
    .bht_index_in(bht_index_if),
    .global_index_in(global_index_if),
    .bimodal_prediction_in(bimodal_prediction_if),
    .global_prediction_in(global_prediction_if),
    .predicted_taken_out(predicted_taken_id),
    .bht_index_out(bht_index_id),
    .global_index_out(global_index_id),
    .bimodal_prediction_out(bimodal_prediction_id),
    .global_prediction_out(global_prediction_id),
    .valid_in(valid_if),
    .valid_out(valid_id)
   );
   ID_EX u_id_ex(
    .pc_in(pc_id),
    .readdata1_in(readdata1_id),
    .readdata2_in(readdata2_id),
    .instruction64_in(instruction64_id),
    .instruction_in(instruction_id),
    .clk(clk),
    .reset(reset),
    .Branch_in(Branch_id),
    .MemRead_in(MemRead_id),
    .MemtoReg_in(MemtoReg_id),
    .ALUOp_in(ALUOp_id),
    .MemWrite_in(MemWrite_id),
    .ALUSrc_in(ALUSrc_id),
    .Regwrite_in(Regwrite_id),
    .ALUASrc_in(ALUASrc_id),
      .Jump_in(Jump_id),
      .JumpReg_in(JumpReg_id),
      .IllegalInstruction_in(illegal_instruction_id),
      .Ecall_in(ecall_id),
      .Mret_in(mret_id),
      .CSRWrite_in(CSRWrite_id),
      .CSROp_in(CSROp_id),
      .CSRUseImm_in(CSRUseImm_id),
      .CSRtoReg_in(CSRtoReg_id),
      .csr_rdata_in(CSR_rdata_effective_id),
      .predicted_taken_in(predicted_taken_id),
     .bht_index_in(bht_index_id),
     .global_index_in(global_index_id),
     .bimodal_prediction_in(bimodal_prediction_id),
     .global_prediction_in(global_prediction_id),
     .ID_EX_write(ID_EX_write_final),

     .pc_out(current_pc_ex),
    .readdata1_out(readdata1_ex),
    .readdata2_out(readdata2_ex),
    .instruction64_out(instruction64_ex),
    .instruction_out(instruction_ex),
    .Branch_out(Branch_ex),
    .MemRead_out(MemRead_ex),
    .MemtoReg_out(MemtoReg_ex),
    .ALUOp_out(ALUOp_ex),
    .MemWrite_out(MemWrite_ex),
    .ALUSrc_out(ALUSrc_ex),
    .Regwrite_out(Regwrite_ex),
    .ALUASrc_out(ALUASrc_ex),
      .Jump_out(Jump_ex),
      .JumpReg_out(JumpReg_ex),
      .IllegalInstruction_out(illegal_instruction_ex),
      .Ecall_out(ecall_ex),
      .Mret_out(mret_ex),
      .CSRWrite_out(CSRWrite_ex),
      .CSROp_out(CSROp_ex),
      .CSRUseImm_out(CSRUseImm_ex),
      .CSRtoReg_out(CSRtoReg_ex),
      .csr_rdata_out(CSR_rdata_ex),
      .predicted_taken_out(predicted_taken_ex),
     .bht_index_out(bht_index_ex),
     .global_index_out(global_index_ex),
     .bimodal_prediction_out(bimodal_prediction_ex),
     .global_prediction_out(global_prediction_ex),
     .ID_EX_flush(ID_EX_flush_final),
     .valid_in(valid_id),
     .valid_out(valid_ex)
   );

   EX_MEM u_ex_mem(
    .branch_pc_in(branch_pc_ex),
    .zero_in(zero_ex),
    .ALUresult_in(aluresult_ex),
    .writedata_in(forwardB_result),
    .instruction64_in(instruction64_ex),
    .instruction_in(instruction_ex),
    .pc_plus4_in(pc_plus4_ex),
    .clk(clk),
    .reset(reset),
    .Branch_in(Branch_ex),
    .Jump_in(Jump_ex),
    .JumpReg_in(JumpReg_ex),
    .MemWrite_in(MemWrite_ex),
    .MemRead_in(MemRead_ex),
      .MemtoReg_in(MemtoReg_ex),
      .Regwrite_in(Regwrite_ex),
      .IllegalInstruction_in(illegal_instruction_ex),
      .Ecall_in(ecall_ex),
      .Mret_in(mret_ex),
      .CSRWrite_in(CSRWrite_ex),
      .CSRtoReg_in(CSRtoReg_ex),
      .CSR_wdata_in(CSR_wdata_ex),
      .CSR_rdata_in(CSR_rdata_ex),
      .predicted_taken_in(predicted_taken_ex),
     .bht_index_in(bht_index_ex),
     .global_index_in(global_index_ex),
     .bimodal_prediction_in(bimodal_prediction_ex),
     .global_prediction_in(global_prediction_ex),
     .EX_MEM_write(EX_MEM_write_final),


     .branch_pc_out(branch_pc_mem),
    .zero_out(zero_mem),
    .ALUresult_out(aluresult_mem),
    .writedata_out(storedata_mem),
    .instruction64_out(instruction64_mem),
    .instruction_out(instruction_mem),
    .pc_plus4_out(pc_plus4_mem),
    .Branch_out(Branch_mem),
    .Jump_out(Jump_mem),
    .JumpReg_out(JumpReg_mem),
    .MemWrite_out(MemWrite_mem),
    .MemRead_out(MemRead_mem),
      .MemtoReg_out(MemtoReg_mem),
      .Regwrite_out(Regwrite_mem),
      .IllegalInstruction_out(illegal_instruction_mem),
      .Ecall_out(ecall_mem),
      .Mret_out(mret_mem),
      .CSRWrite_out(CSRWrite_mem),
      .CSRtoReg_out(CSRtoReg_mem),
      .CSR_rdata_out(CSR_rdata_mem),
      .CSR_wdata_out(CSR_wdata_mem),
      
      .predicted_taken_out(predicted_taken_mem),
     .bht_index_out(bht_index_mem),
     .global_index_out(global_index_mem),
     .bimodal_prediction_out(bimodal_prediction_mem),
     .global_prediction_out(global_prediction_mem),
     .EX_MEM_flush(control_flush_mem),
     .valid_in(valid_ex),
     .valid_out(valid_mem),
     .pc_in(current_pc_ex),
     .pc_out(current_pc_mem)
   );

   MEM_WB u_mem_wb(
    .readdata_in(mem_readdata_mem),
    .ALUresult_in(aluresult_mem),
    .MemtoReg_in(MemtoReg_mem),
    .instruction64_in(instruction64_mem),
    .instruction_in(instruction_mem),
    .pc_plus4_in(pc_plus4_mem),
    .Regwrite_in(Regwrite_commit_mem),
    .clk(clk),
    .reset(reset),
    .MEM_WB_write(MEM_WB_write_final),
    .CSR_rdata_in(CSR_rdata_mem),
    .CSRtoReg_in(CSRtoReg_mem),

    .readdata_out(mem_readdata_wb),
    .ALUresult_out(aluresult_wb),
    .MemtoReg_out(MemtoReg_wb),
    .instruction64_out(instruction64_wb),
    .instruction_out(instruction_wb),
    .pc_plus4_out(pc_plus4_wb),
    .Regwrite_out(Regwrite_forward_wb),
    .CSR_rdata_out(CSR_rdata_wb),
    .CSRtoReg_out(CSRtoReg_wb)

   );
   ForwardingUnit u_forwardingunit(
    .rs1_ex(instruction_ex[19:15]),
    .rs2_ex(instruction_ex[24:20]),
    .rd_mem(instruction_mem[11:7]),
    .rd_wb(instruction_wb[11:7]),
    .Regwrite_mem(Regwrite_commit_mem),
    .Regwrite_wb(Regwrite_forward_wb),
    .forwardA(forwardA),
    .forwardB(forwardB)

   );

   // MEM/WB is held during a D-Cache stall so its value remains available
   // to EX forwarding.  The older WB instruction may still retire once at
   // the beginning of the stall, but must not be written repeatedly.
   always @(posedge clk) begin
     if(reset)
       wb_stall_commit_done <= 1'b0;
     else if(dcache_stall)
       wb_stall_commit_done <= 1'b1;
     else
       wb_stall_commit_done <= 1'b0;
   end

   assign Regwrite_wb = Regwrite_forward_wb && ~wb_stall_commit_done;

   HazardDetectionUnit u_hazarddetectionunit(
    .MemRead_ex(MemRead_ex),
    .rd_ex(instruction_ex[11:7]),
    .rs1_id(instruction_id[19:15]),
    .rs2_id(instruction_id[24:20]),
    .UseRs1_id(users1_id),
    .UseRs2_id(users2_id),
    .PCwrite(PCwrite_hazard),
    .IF_IDwrite(IF_ID_write_hazard),
    .ID_EX_flush(ID_EX_flush_hazard)




   );
   wire branch_resolve_valid_mem = valid_mem && Branch_mem && ~trap_enter;

   BranchPredictionUnit #(
    .PREDICTOR_MODE(BRANCH_PREDICTOR_MODE)
   ) u_branchpredictionunit(
    .clk(clk),
    .reset(reset),
    .pc_if(current_pc_if),
    .instruction_if(instruction_if),
    .branch_mem(branch_resolve_valid_mem),
    .branch_taken_mem(branch_taken_mem),
    .bht_index_mem(bht_index_mem),
    .global_index_mem(global_index_mem),
    .bimodal_prediction_mem(bimodal_prediction_mem),
    .global_prediction_mem(global_prediction_mem),
    .predicted_taken_if(predicted_taken_if),
    .bht_index_if(bht_index_if),
    .global_index_if(global_index_if),
    .bimodal_prediction_if(bimodal_prediction_if),
    .global_prediction_if(global_prediction_if),
    .chooser_prefers_global_if(chooser_prefers_global_if)






   );
   Immgen u_immgen_if(
    .instruction(instruction_if),
    .instruction64(instruction64_if)
   );

   CSRFile u_csrfile(
    .clk(clk),
    .reset(reset),
    .trap_enter(trap_enter),
    .trap_pc(trap_pc),
    .trap_cause(trap_cause),
    .mret(mret_valid),
    .csr_we(CSRvalid_mem),
    .csr_raddr(instruction_id[31:20]),
    .csr_waddr(instruction_mem[31:20]),
    .csr_wdata(CSR_wdata_mem),
    .csr_rdata(CSR_rdata_id),
    .mtvec_out(mtvec_csr),
    .mepc_out(mepc_csr),
    .mcause_out(mcause_csr),
    .global_interrupt_enable(global_interrupt_enable)



   );
   CSRForwardingUnit u_csrforwardingunit(
    .CSR_addr_id(instruction_id[31:20]),
    .CSR_addr_ex(instruction_ex[31:20]),
    .CSR_addr_mem(instruction_mem[31:20]),
    .valid_ex(valid_ex),
    .CSRWrite_ex(CSRWrite_ex),
    .valid_mem(valid_mem),
    .CSRWrite_mem(CSRWrite_mem),
    .CSRForward_id(CSRForward_id)


   );

   TrapControlUnit u_trapcontrolunit(
    .valid_mem(valid_mem),
    .pc_mem(current_pc_mem),
    .external_interrupt_pending(external_interrupt_pending_effective),
    .global_interrupt_enable(global_interrupt_enable),
    .instruction_misaligned_mem(instruction_misaligned_mem),
    .illegal_instruction_mem(illegal_instruction_mem),
    .load_misaligned_mem(load_misaligned_mem),
    .store_misaligned_mem(store_misaligned_mem),
    .ecall_mem(ecall_mem),
    .trap_enter(trap_enter),
    .trap_pc(trap_pc),
    .trap_cause(trap_cause)

   );

   DCache u_dcache(
    .clk(clk),
    .reset(reset),
    .cpu_req_valid(dcache_cpu_req_valid),
    .cpu_req_addr(dcache_cpu_req_addr),
    .cpu_req_write(dcache_cpu_req_write),
    .cpu_req_wdata(dcache_cpu_req_wdata),
    .cpu_req_wstrb(dcache_cpu_req_wstrb),

    .cpu_req_ready(dcache_cpu_req_ready),
    .cpu_resp_valid(dcache_cpu_resp_valid),
    .cpu_resp_rdata(dcache_cpu_resp_rdata),

    .mem_req_ready(dcache_mem_req_ready),
    .mem_resp_valid(dcache_mem_resp_valid),
    .mem_resp_rdata(dcache_mem_resp_rdata),

    .mem_req_valid(dcache_mem_req_valid),
    .mem_req_write(dcache_mem_req_write),
    .mem_req_addr(dcache_mem_req_addr),
    .mem_req_wdata(dcache_mem_req_wdata),
    .mem_req_wstrb(dcache_mem_req_wstrb)
    


   );
   CacheBackingMemory #(
    .MEM_WORDS(DCACHE_BACKING_WORDS),
    .BASE_ADDR(DCACHE_BACKING_BASE_ADDR)
   ) u_dcache_backing_memory(
    .clk(clk),
    .reset(reset),

    .req_valid(dcache_mem_req_valid),
    .req_write(dcache_mem_req_write),
    .req_addr(dcache_mem_req_addr),
    .req_wdata(dcache_mem_req_wdata),
    .req_wstrb(dcache_mem_req_wstrb),

    .req_ready(dcache_mem_req_ready),
    .resp_valid(dcache_mem_resp_valid),
    .resp_rdata(dcache_mem_resp_rdata)
);
   
   ICache u_icache(
    .clk(clk),
    .reset(reset),
    .cpu_req_valid(icache_cpu_req_valid),
    .cpu_req_addr(icache_cpu_req_addr),
    
    .cpu_req_ready(icache_cpu_req_ready),
    .cpu_resp_valid(icache_cpu_resp_valid),
    .cpu_resp_instr(icache_cpu_resp_instr),

    .mem_req_valid(icache_mem_req_valid),
    .mem_req_addr(icache_mem_req_addr),

    .mem_req_ready(icache_mem_req_ready),
    .mem_resp_valid(icache_mem_resp_valid),
    .mem_resp_rdata(icache_mem_resp_rdata)

   );

   CacheBackingMemory #(
    .MEM_WORDS(ICACHE_BACKING_WORDS),
    .BASE_ADDR(ICACHE_BACKING_BASE_ADDR)
   ) u_icache_backing_memory(
    .clk(clk),
    .reset(reset),

    .req_valid(icache_mem_req_valid),
    .req_write(1'b0),
    .req_addr(icache_mem_req_addr),
    .req_wdata(64'b0),
    .req_wstrb(8'b0),

    .req_ready(icache_mem_req_ready),
    .resp_valid(icache_mem_resp_valid),
    .resp_rdata(icache_mem_resp_rdata)


   );

    
    
    //EX address calculation
    assign branch_pc_ex = current_pc_ex + (instruction64_ex << 1);
    assign pc_plus4_ex = current_pc_ex + 64'd4;



    //Forwarding unit
    
    always @(*) begin
        if(CSRtoReg_mem)
        forward_data_mem = CSR_rdata_mem;
        else begin
            case(MemtoReg_mem)
        2'b00:forward_data_mem = aluresult_mem;
        2'b01:forward_data_mem = mem_readdata_mem;
        2'b10:forward_data_mem = instruction64_mem;
        2'b11:forward_data_mem = pc_plus4_mem;
        default :forward_data_mem = aluresult_mem;
           
        endcase
    end 
        case(forwardA)
         2'b00:forwardA_result = readdata1_ex;
         2'b01:forwardA_result = writedata_wb;
         2'b10:forwardA_result = forward_data_mem;
         default:forwardA_result = readdata1_ex;
        endcase
        case(forwardB)
         2'b00:forwardB_result = readdata2_ex;
         2'b01:forwardB_result = writedata_wb;
         2'b10:forwardB_result = forward_data_mem;
         default :forwardB_result = readdata2_ex;
        endcase
    end
    //CSR forwarding unit
    always @( *) begin
        case(CSRForward_id)
        2'b00:CSR_rdata_effective_id = CSR_rdata_id;
        2'b01:CSR_rdata_effective_id = CSR_wdata_mem;
        2'b10:CSR_rdata_effective_id = CSR_wdata_ex;
        default:CSR_rdata_effective_id = CSR_rdata_id;
            
        endcase
    end

    //Load misaligned unit
    always @(*) begin
        load_misaligned_mem = 1'b0;
        if(MemRead_mem == 1'b1 && valid_mem == 1'b1) begin
          case(instruction_mem[14:12])
            3'b000, 3'b100: load_misaligned_mem = 1'b0; // LB/LBU
            3'b001, 3'b101: load_misaligned_mem = aluresult_mem[0]; // LH/LHU
            3'b010: load_misaligned_mem = (aluresult_mem[1:0] != 2'b00); // LW
            3'b011: load_misaligned_mem = (aluresult_mem[2:0] != 3'b000); // LD
            3'b110: load_misaligned_mem = (aluresult_mem[1:0] != 2'b00); // LWU
            default: load_misaligned_mem = 1'b1;
          endcase
        end
            
    end

    //store misaligned unit
    always @(*) begin
        store_misaligned_mem = 1'b0;
        if(MemWrite_mem == 1'b1 && valid_mem == 1'b1) begin
          case(instruction_mem[14:12])
            3'b000: store_misaligned_mem = 1'b0; // SB
            3'b001: store_misaligned_mem = aluresult_mem[0]; // SH
            3'b010: store_misaligned_mem = (aluresult_mem[1:0] != 2'b00); // SW
            3'b011: store_misaligned_mem = (aluresult_mem[2:0] != 3'b000); // SD
            default: store_misaligned_mem = 1'b1;
          endcase
        end
            
    end

    //instruction address misaligned unit
    always @( *) begin
        if(Jump_mem == 1'b1 && branch_pc_mem[1:0] != 2'b00 && valid_mem == 1'b1)//JAL
          instruction_misaligned_mem = 1'b1;
        else if(JumpReg_mem == 1'b1 && jalr_pc_mem[1:0] != 2'b00 && valid_mem == 1'b1)//JALR
          instruction_misaligned_mem = 1'b1;
        else if(Branch_mem == 1'b1 && branch_taken_mem == 1'b1 && branch_pc_mem[1:0] != 2'b00 && valid_mem == 1'b1)
          instruction_misaligned_mem = 1'b1;
        else
          instruction_misaligned_mem = 1'b0;
    end


    
    
        

        
        
            
            
    
    //IF calculate the branch prediction address(previouly,we calculated in EX stage,but this time we need the address in IF stage to make the prediction)
    assign predicted_branch_pc_if = current_pc_if + (instruction64_if << 1);

    //check whether the prediction is wrong or not

    wire branch_mispredict_mem = branch_resolve_valid_mem &&
                                 (predicted_taken_mem != branch_taken_mem);
    



    //MEM NextPC logic
   

    always @(*) begin
        if(trap_enter)//trap has the priority to other ones
        next_pc = mtvec_csr;
        else if(mret_valid)
            next_pc = mepc_csr;
        else if(Jump_mem)
        next_pc = branch_pc_mem;
        else if(JumpReg_mem) begin
            
            next_pc = jalr_pc_mem;
            
        end
        //suppose the prediction is wrong
        else if(branch_mispredict_mem)begin
            if(branch_taken_mem)//suppose the prediction is not branch but actually it branched,we should excecute in branch ways
                next_pc = branch_pc_mem;
            else
                next_pc = pc_plus4_mem;


        end
        //suppose the prediction is right
        else if(predicted_taken_if)//predicted_taken has been declared in BranchPredictionUnit.v
            next_pc = predicted_branch_pc_if;
        else
            next_pc = pc_plus4_if;
            
        
    end
    //Branch control flush
    always @(*) begin
        control_flush_mem = Jump_mem || JumpReg_mem || branch_mispredict_mem || trap_enter || mret_valid;

        
    end


    //WB write back MUX logic
    always @(*) begin
        if(CSRtoReg_wb == 1)begin
            writedata_wb = CSR_rdata_wb;
        end
        else 
            case(MemtoReg_wb)
      2'b00:writedata_wb = aluresult_wb;
      2'b01:writedata_wb = mem_readdata_wb;
      2'b10:writedata_wb = instruction64_wb;
      2'b11:writedata_wb = pc_plus4_wb;
      default:writedata_wb = 64'b0;
     endcase
     
    end

    //EX trap control logic and immgen logic
    wire [63:0]CSRimm64 = {59'b0,{instruction_ex[19:15]}};
    wire [63:0]csr_operand_ex = (CSRUseImm_ex ? CSRimm64 : forwardA_result);

    always @(*) begin
        case(CSROp_ex)//详细逻辑见日志
         2'b00:CSR_wdata_ex = csr_operand_ex;//WRITE
         2'b01:CSR_wdata_ex = CSR_rdata_ex | csr_operand_ex;//SET
         2'b10:CSR_wdata_ex = CSR_rdata_ex & (~csr_operand_ex);//CLEAR
         default:CSR_wdata_ex = CSR_rdata_ex;
        endcase
    end



    



    












   
























































endmodule
