# IF_ID

IF/ID 流水线寄存器在时钟上升沿锁存取指阶段产生的 PC 和 32 位指令，使它们在下一个周期作为译码阶段的稳定输入。当前版本只实现同步复位和正常锁存，暂未加入暂停与冲刷功能。

| 输入信号 | 输入位宽 | 对应输出信号 | 输出位宽 | 作用 |
| --- | ---: | --- | ---: | --- |
| `current_pc` | 64 | `pc_out` | 64 | 保存当前取出指令对应的 PC |
| `instruction` | 32 | `instruction_out` | 32 | 保存当前取出的 RISC-V 指令 |
| `clk` | 1 | — | — | 在时钟上升沿锁存输入信号 |
| `reset` | 1 | — | — | 同步复位；有效时将两个输出清零 |

# ID_EX

ID/EX 流水线寄存器在时钟上升沿同时锁存译码阶段产生的数据和控制信号，使属于同一条指令的信息能够在下一个周期一起进入执行阶段。当前版本只实现同步复位和正常锁存，暂未加入暂停与冲刷功能。

## 数据信号

| 输入信号 | 输入位宽 | 对应输出信号 | 输出位宽 | 作用 |
| --- | ---: | --- | ---: | --- |
| `pc_in` | 64 | `pc_out` | 64 | 保存该指令对应的 PC |
| `readdata1_in` | 64 | `readdata1_out` | 64 | 保存寄存器堆第一个读端口的数据 |
| `readdata2_in` | 64 | `readdata2_out` | 64 | 保存寄存器堆第二个读端口的数据 |
| `instruction64_in` | 64 | `instruction64_out` | 64 | 保存 Immgen 生成的 64 位立即数 |
| `instruction_in` | 32 | `instruction_out` | 32 | 保存原始指令，供后续 ALUControl 等逻辑使用 |

## 控制信号

| 输入信号 | 输入位宽 | 对应输出信号 | 输出位宽 | 作用 |
| --- | ---: | --- | ---: | --- |
| `Branch_in` | 1 | `Branch_out` | 1 | 表示条件分支指令 |
| `MemRead_in` | 1 | `MemRead_out` | 1 | 控制数据存储器读取 |
| `MemtoReg_in` | 2 | `MemtoReg_out` | 2 | 选择寄存器写回数据来源 |
| `ALUOp_in` | 2 | `ALUOp_out` | 2 | 向后传递 ALU 运算类别 |
| `MemWrite_in` | 1 | `MemWrite_out` | 1 | 控制数据存储器写入 |
| `ALUSrc_in` | 1 | `ALUSrc_out` | 1 | 选择 ALU 的 B 输入来源 |
| `Regwrite_in` | 1 | `Regwrite_out` | 1 | 控制寄存器堆写回 |
| `ALUASrc_in` | 1 | `ALUASrc_out` | 1 | 选择 ALU 的 A 输入来源 |
| `Jump_in` | 1 | `Jump_out` | 1 | 表示 JAL 跳转 |
| `JumpReg_in` | 1 | `JumpReg_out` | 1 | 表示 JALR 跳转 |
| `clk` | 1 | — | — | 在时钟上升沿锁存全部数据和控制信号 |
| `reset` | 1 | — | — | 同步复位；有效时将全部输出清零 |

# EX_MEM

EX/MEM 流水线寄存器在时钟上升沿锁存执行阶段产生的数据、分支判断信息以及后续 MEM、WB 阶段仍然需要的控制信号。当前版本只实现同步复位和正常锁存，暂未加入暂停与冲刷功能。

<sub>说明：当前设计将 Branch、Jump 和 JumpReg 的最终 PC 选择逻辑统一放在 EX/MEM 之后完成。</sub>

## 数据信号

| 输入信号 | 输入位宽 | 对应输出信号 | 输出位宽 | 作用 |
| --- | ---: | --- | ---: | --- |
| `branch_pc_in` | 64 | `branch_pc_out` | 64 | 保存 EX 阶段计算出的分支或 PC 相对跳转目标地址 |
| `zero_in` | 1 | `zero_out` | 1 | 保存 ALU 的零标志，供条件分支判断使用 |
| `ALUresult_in` | 64 | `ALUresult_out` | 64 | 保存 ALU 运算结果或访存地址 |
| `writedata_in` | 64 | `writedata_out` | 64 | 保存 `sd` 指令需要写入数据存储器的数据 |
| `instruction64_in` | 64 | `instruction64_out` | 64 | 保存 Immgen 生成的 64 位立即数 |
| `instruction_in` | 32 | `instruction_out` | 32 | 保存原始指令，供分支类型等后续判断使用 |
| `pc_plus4_in` | 64 | `pc_plus4_out` | 64 | 保存该指令的 `PC+4`，供 JAL/JALR 后续写回链接地址 |

## 控制信号

| 输入信号 | 输入位宽 | 对应输出信号 | 输出位宽 | 作用 |
| --- | ---: | --- | ---: | --- |
| `Branch_in` | 1 | `Branch_out` | 1 | 表示条件分支指令 |
| `Jump_in` | 1 | `Jump_out` | 1 | 表示 JAL 跳转 |
| `JumpReg_in` | 1 | `JumpReg_out` | 1 | 表示 JALR 跳转 |
| `MemWrite_in` | 1 | `MemWrite_out` | 1 | 控制 MEM 阶段写入数据存储器 |
| `MemRead_in` | 1 | `MemRead_out` | 1 | 控制 MEM 阶段读取数据存储器 |
| `MemtoReg_in` | 2 | `MemtoReg_out` | 2 | 向后传递寄存器写回数据来源选择信号 |
| `Regwrite_in` | 1 | `Regwrite_out` | 1 | 向后传递寄存器堆写使能信号 |
| `clk` | 1 | — | — | 在时钟上升沿锁存全部数据和控制信号 |
| `reset` | 1 | — | — | 同步复位；有效时将全部输出清零 |

# MEM_WB

MEM/WB 流水线寄存器在时钟上升沿锁存 MEM 阶段产生的数据以及 WB 阶段需要的控制信号，使写回阶段能够从四种数据来源中选择结果并写入正确的目的寄存器。当前版本只实现同步复位和正常锁存。

## 数据信号

| 输入信号 | 输入位宽 | 对应输出信号 | 输出位宽 | 作用 |
| --- | ---: | --- | ---: | --- |
| `readdata_in` | 64 | `readdata_out` | 64 | 保存 DataMemory 读取的数据，供 `ld` 写回 |
| `ALUresult_in` | 64 | `ALUresult_out` | 64 | 保存 ALU 运算结果，供运算指令、AUIPC 等写回 |
| `instruction64_in` | 64 | `instruction64_out` | 64 | 保存 64 位立即数，供 LUI 写回 |
| `instruction_in` | 32 | `instruction_out` | 32 | 保存原始指令；WB 阶段使用 `[11:7]` 取得目的寄存器 `rd` |
| `pc_plus4_in` | 64 | `pc_plus4_out` | 64 | 保存 `PC+4`，供 JAL/JALR 写回链接地址 |

## 控制信号

| 输入信号 | 输入位宽 | 对应输出信号 | 输出位宽 | 作用 |
| --- | ---: | --- | ---: | --- |
| `MemtoReg_in` | 2 | `MemtoReg_out` | 2 | 选择 ALU结果、内存数据、立即数或 `PC+4` 作为写回数据 |
| `Regwrite_in` | 1 | `Regwrite_out` | 1 | 控制 WB 阶段是否写入寄存器堆 |
| `clk` | 1 | — | — | 在时钟上升沿锁存全部数据和控制信号 |
| `reset` | 1 | — | — | 同步复位；有效时将全部输出清零 |


2026/9/22 18:46做到以上部分，说实话今天没做什么有技术含量的工作，那些流水线寄存器的输入输出也就只有个改个名in还是out的工作量，倒是想接口想了很长时间，明天准备把pipelined.cpu也就是顶层接线给做了，明天课有点多估计做不了太多，后天更是一点时间都没给我留，可能不开电脑了，中秋可以把冒险的部分做了，然后这个五周期流水线cpu就成了，想想就有点激动，好了不说了，上课去了。

# PIPELINED_CPU 顶层连接与五级流水线划分

2026/9/23 完成了 `PIPELINED_CPU.v` 的基本顶层接线：复用了单周期 CPU 中的主要功能模块，并用 IF/ID、ID/EX、EX/MEM、MEM/WB 四个流水线寄存器把数据和控制信号按阶段隔开。当前版本已经形成 IF、ID、EX、MEM、WB 五级数据通路，但尚未加入前递、冒险检测、暂停和冲刷逻辑。

## 五个流水阶段总览

| 阶段 | 顶层代码中的主要信号或位置 | 本阶段涉及的模块 | 本阶段的主要工作 | 送往下一阶段的主要内容 |
| --- | --- | --- | --- | --- |
| IF（取指） | `current_pc_if`、`instruction_if`、`pc_plus4_if`、`next_pc` | `PC`、`IR`、`IF_ID` | PC 保存当前取指地址；IR 根据 PC 读取指令；计算顺序地址 `PC+4`；接收后级产生的 `next_pc` | 通过 IF/ID 保存当前 PC 和指令 |
| ID（译码） | `pc_id`、`instruction_id`、带 `_id` 后缀的控制信号 | `Control`、`Immgen`、`Register` 的读端口、`ID_EX` | 对 opcode 译码；生成立即数；从寄存器堆读取 `rs1`、`rs2`；产生该指令所需的控制信号 | 通过 ID/EX 保存 PC、原始指令、立即数、两个源操作数及全部后续控制信号 |
| EX（执行） | `current_pc_ex`、`readdata1_ex`、`readdata2_ex`、`instruction64_ex`、`aluresult_ex` | `ALUControl`、`ALU`、`EX_MEM` | 根据 `ALUOp` 和指令字段确定 ALU 操作；选择 ALU 两个输入；完成算术/逻辑运算或地址计算；计算分支目标和该指令的 `PC+4` | 通过 EX/MEM 保存 ALU 结果、Zero、分支目标、Store 数据、原始指令、立即数、`PC+4` 及 MEM/WB 控制信号 |
| MEM（访存及控制转移决定） | `aluresult_mem`、`storedata_mem`、`mem_readdata_mem`、`branch_pc_mem` | `DataMemory`、`MEM_WB` | 对 `ld`/`sd` 访问数据存储器；在 EX/MEM 之后判断 Branch、Jump、JumpReg，并选择下一条 PC | 通过 MEM/WB 保存内存读数、ALU 结果、立即数、原始指令、`PC+4` 以及写回控制信号 |
| WB（写回） | `aluresult_wb`、`mem_readdata_wb`、`instruction64_wb`、`pc_plus4_wb`、`writedata_wb` | 写回多路选择逻辑、`Register` 的写端口 | 根据 `MemtoReg_wb` 选择写回值，并在 `Regwrite_wb` 有效时写入 `instruction_wb[11:7]` 指定的 `rd` | 写回完成，本条指令离开流水线 |

> `Register` 只有一个实例，但它同时服务两个阶段：两个读端口属于 ID 阶段，写端口属于 WB 阶段。

## 顶层实例化模块及作用

| 实例化模块 | 所属阶段或边界 | 主要输入 | 主要输出 | 作用 |
| --- | --- | --- | --- | --- |
| `PC` | IF | `next_pc`、`clk`、`reset` | `current_pc_if` | 在时钟沿更新并保存当前 PC |
| `IR` | IF | `current_pc_if` | `instruction_if` | 根据当前 PC 从指令存储区取得 32 位指令 |
| `IF_ID` | IF → ID | `current_pc_if`、`instruction_if` | `pc_id`、`instruction_id` | 隔开取指和译码阶段，使同一条指令的 PC 与指令码同步进入 ID |
| `Control` | ID | `instruction_id[6:0]` | `Branch_id`、`MemRead_id`、`MemtoReg_id`、`ALUOp_id`、`MemWrite_id`、`ALUSrc_id`、`Regwrite_id`、`ALUASrc_id`、`Jump_id`、`JumpReg_id` | 根据 opcode 产生整条指令后续各阶段需要的控制信号 |
| `Immgen` | ID | `instruction_id` | `instruction64_id` | 按指令格式提取并扩展立即数 |
| `Register` | ID 读、WB 写 | ID 阶段的 `rs1`、`rs2`；WB 阶段的 `rd`、`writedata_wb`、`Regwrite_wb` | `readdata1_id`、`readdata2_id` | 在 ID 阶段读源寄存器，在 WB 阶段写目的寄存器 |
| `ID_EX` | ID → EX | ID 阶段数据和控制信号 | 对应的 `_ex` 信号 | 保证一条指令的数据与控制信号在同一时钟沿进入 EX |
| `ALUControl` | EX | `ALUOp_ex`、`instruction_ex` 的功能字段 | ALU 具体操作选择信号 | 将主控制器给出的运算类别细化为具体 ALU 操作 |
| `ALU` | EX | 经过多路选择后的 A、B 操作数和 ALU 控制码 | `aluresult_ex`、`zero_ex` | 完成算术、逻辑、比较以及 Load/Store/JALR 地址计算 |
| `EX_MEM` | EX → MEM | EX 阶段结果及后续控制信号 | 对应的 `_mem` 信号 | 保存执行结果，并把访存、控制转移和写回信息送入 MEM |
| `DataMemory` | MEM | `aluresult_mem`、`storedata_mem`、`MemRead_mem`、`MemWrite_mem` | `mem_readdata_mem` | 使用 ALU 结果作为地址完成数据读取或写入 |
| `MEM_WB` | MEM → WB | MEM 阶段的四类候选写回数据及写回控制信号 | 对应的 `_wb` 信号 | 将写回所需的数据、目的寄存器字段和控制信号送入 WB |

## 顶层组合逻辑的阶段归属

| 组合逻辑 | 所属阶段 | 作用 |
| --- | --- | --- |
| `pc_plus4_if = current_pc_if + 4` | IF | 产生默认的顺序取指地址 |
| ALU A 输入选择 | EX | `ALUASrc_ex` 在 `current_pc_ex` 与 `readdata1_ex` 之间选择，支持普通运算和 AUIPC 等指令 |
| ALU B 输入选择 | EX | `ALUSrc_ex` 在 `readdata2_ex` 与 `instruction64_ex` 之间选择，支持寄存器型和立即数型运算 |
| `branch_pc_ex = current_pc_ex + (instruction64_ex << 1)` | EX | 计算 Branch/JAL 的 PC 相对目标地址，并通过 EX/MEM 传递 |
| `pc_plus4_ex = current_pc_ex + 4` | EX | 保存本条指令的返回地址，供 JAL/JALR 在 WB 阶段写回 |
| `jalr_pc_mem = {aluresult_mem[63:1], 1'b0}` | MEM | 由 EX 阶段算出的 `rs1 + imm` 形成对齐后的 JALR 目标地址 |
| `Branch_mem && zero_mem` | MEM | 判断 BEQ 是否跳转 |
| `Branch_mem && ~zero_mem` | MEM | 判断 BNE 是否跳转 |
| `next_pc` 选择逻辑 | MEM 决策，反馈到 IF | 按 Jump、JumpReg、BEQ/BNE 和顺序 `PC+4` 的优先关系选择下一条取指地址 |
| `MemtoReg_wb` 写回多路选择 | WB | 在 ALU 结果、内存读数、立即数和 `PC+4` 中选择 `writedata_wb` |

这里需要区分“逻辑产生的位置”和“逻辑影响的位置”：例如 `next_pc` 的决定发生在 MEM 阶段，但它的结果会反馈到 IF 阶段的 PC 输入。

## 控制信号的跨阶段路径

| 控制信号 | 产生阶段 | 经过的流水线寄存器 | 最终使用阶段 | 作用 |
| --- | --- | --- | --- | --- |
| `ALUOp` | ID | ID/EX | EX | 参与生成具体 ALU 控制码 |
| `ALUSrc` | ID | ID/EX | EX | 选择 ALU 的 B 输入 |
| `ALUASrc` | ID | ID/EX | EX | 选择 ALU 的 A 输入 |
| `Branch` | ID | ID/EX、EX/MEM | MEM | 配合 Zero 和指令类型判断条件分支是否成立 |
| `Jump` | ID | ID/EX、EX/MEM | MEM | 选择 JAL 的 PC 相对目标地址 |
| `JumpReg` | ID | ID/EX、EX/MEM | MEM | 选择 JALR 的寄存器相对目标地址 |
| `MemRead` | ID | ID/EX、EX/MEM | MEM | 控制 DataMemory 读取 |
| `MemWrite` | ID | ID/EX、EX/MEM | MEM | 控制 DataMemory 写入 |
| `MemtoReg` | ID | ID/EX、EX/MEM、MEM/WB | WB | 选择最终写回数据来源 |
| `Regwrite` | ID | ID/EX、EX/MEM、MEM/WB | WB | 控制是否写入目的寄存器 |

## 2026/9/23 版本的验证结果与限制

- 已使用 `PIPELINED_CPU_tb.v` 对当前顶层进行无数据冒险测试，20 条已支持指令均通过。
- 当前测试在存在数据相关的位置插入了足够的 NOP，因此通过测试只说明五级数据通路和基本控制信号传递能够工作，还不能说明已经具备冒险处理能力。
- 当前尚未实现 Forwarding Unit、Hazard Detection Unit、流水线暂停和控制冒险冲刷。
- Branch、JAL、JALR 在 MEM 阶段才改变 PC；在加入冲刷前，测试程序必须保证错误路径上是无副作用指令，否则错误路径指令仍可能继续执行。

# 2026/9/24：前递单元与冒险检测单元

9 月 24 日主要完成了数据前递通路，并写出了 Load-use 冒险检测单元的第一版内部逻辑。前递单元已经实例化到 `PIPELINED_CPU.v` 并接入 ALU 和 Store 数据通路；冒险检测单元目前只完成独立模块，尚未接入顶层，也还没有为 PC、IF/ID、ID/EX 增加对应的暂停或气泡接口。

## ForwardingUnit

### 作用

寄存器堆的源操作数在 ID 阶段读取，但更早的指令可能还没有到达 WB 阶段，因此 ID/EX 中保存的 `readdata1_ex`、`readdata2_ex` 可能是旧值。Forwarding Unit 不比较数据内容，而是比较不同流水阶段中的源寄存器编号和目的寄存器编号，以判断是否存在 RAW（Read After Write）相关，并控制 EX 阶段前的多路选择器使用更新的数据。

### 输入输出接口

| 端口 | 方向 | 位宽 | 所属阶段 | 作用 |
| --- | --- | ---: | --- | --- |
| `rs1_ex` | 输入 | 5 | EX | 当前 EX 指令的第一个源寄存器编号，来自 `instruction_ex[19:15]` |
| `rs2_ex` | 输入 | 5 | EX | 当前 EX 指令的第二个源寄存器编号，来自 `instruction_ex[24:20]` |
| `rd_mem` | 输入 | 5 | MEM | 当前 MEM 指令的目的寄存器编号，来自 `instruction_mem[11:7]` |
| `rd_wb` | 输入 | 5 | WB | 当前 WB 指令的目的寄存器编号，来自 `instruction_wb[11:7]` |
| `Regwrite_mem` | 输入 | 1 | MEM | 表示 MEM 阶段指令最终是否会写寄存器 |
| `Regwrite_wb` | 输入 | 1 | WB | 表示 WB 阶段指令是否会写寄存器 |
| `forwardA` | 输出 | 2 | EX | 控制 `rs1` 数据的三选一前递多路选择器 |
| `forwardB` | 输出 | 2 | EX | 控制 `rs2` 数据的三选一前递多路选择器 |

### 控制编码

| 控制值 | 数据来源 | 含义 |
| --- | --- | --- |
| `2'b00` | ID/EX | 使用寄存器堆在 ID 阶段读出的原始数据 |
| `2'b01` | MEM/WB | 使用已经完成写回数据选择的 `writedata_wb` |
| `2'b10` | EX/MEM | 使用 MEM 阶段提前旁路的 `forward_data_mem` |
| `2'b11` | 未使用 | 顶层默认退回原始寄存器数据 |

### 内部判断逻辑

`forwardA` 判断 `rs1_ex`，`forwardB` 判断 `rs2_ex`，两者采用相同规则：

1. 如果 `Regwrite_mem` 有效、`rd_mem != x0`，并且 `rd_mem` 等于对应的 EX 源寄存器，则选择 `2'b10`。
2. 否则，如果 `Regwrite_wb` 有效、`rd_wb != x0`，并且 `rd_wb` 等于对应的 EX 源寄存器，则选择 `2'b01`。
3. 否则选择 `2'b00`，继续使用 ID/EX 中原有的寄存器数据。

MEM 必须比 WB 优先，因为当 MEM 和 WB 同时写同一个寄存器时，MEM 中的指令更年轻，它产生的是更新的值。判断时排除 `x0`，是因为 RISC-V 的零寄存器不能被修改，不应作为前递生产者。

## PIPELINED_CPU 中新增的前递接线

### 新增信号

| 信号 | 位宽 | 类型 | 作用 |
| --- | ---: | --- | --- |
| `forwardA` | 2 | `wire` | Forwarding Unit 给出的第一个源操作数选择信号 |
| `forwardB` | 2 | `wire` | Forwarding Unit 给出的第二个源操作数选择信号 |
| `forwardA_result` | 64 | `reg` | 前递选择后的 `rs1` 数据 |
| `forwardB_result` | 64 | `reg` | 前递选择后的 `rs2` 数据 |
| `forward_data_mem` | 64 | `reg` | MEM 阶段当前指令最终准备写回、可提前旁路的数据 |

### ForwardingUnit 实例化连接

| ForwardingUnit 端口 | 顶层连接 |
| --- | --- |
| `rs1_ex` | `instruction_ex[19:15]` |
| `rs2_ex` | `instruction_ex[24:20]` |
| `rd_mem` | `instruction_mem[11:7]` |
| `rd_wb` | `instruction_wb[11:7]` |
| `Regwrite_mem` | `Regwrite_mem` |
| `Regwrite_wb` | `Regwrite_wb` |
| `forwardA` | `forwardA` |
| `forwardB` | `forwardB` |

### MEM 阶段前递数据选择

真正向寄存器堆写入仍然发生在 WB 阶段。`forward_data_mem` 不是提前写寄存器，而是把 MEM 阶段已经产生的结果绕过寄存器堆，提前送回 EX 阶段。由于本 CPU 有四种写回来源，所以 MEM 前递也必须根据 `MemtoReg_mem` 选择正确的数据。

| `MemtoReg_mem` | `forward_data_mem` 来源 | 适用指令 |
| --- | --- | --- |
| `2'b00` | `aluresult_mem` | 普通 ALU 指令、AUIPC 等 |
| `2'b01` | `mem_readdata_mem` | Load；标准 Load-use 情况仍需要暂停 |
| `2'b10` | `instruction64_mem` | LUI |
| `2'b11` | `pc_plus4_mem` | JAL、JALR |

组合逻辑先生成 `forward_data_mem`，再根据 `forwardA`、`forwardB` 选择原始寄存器数据、WB 数据或 MEM 数据，避免在同一个组合块中先读取后赋值导致仿真使用旧值。

### 前递结果接入的数据通路

| 接入位置 | 修改后的数据关系 | 原因 |
| --- | --- | --- |
| ALU A 输入 | `ALUASrc_ex ? current_pc_ex : forwardA_result` | 保留 AUIPC 等指令的 PC 输入，同时让寄存器型 A 操作数支持前递 |
| ALU B 输入 | `ALUSrc_ex ? instruction64_ex : forwardB_result` | 保留立即数选择，同时让寄存器型 B 操作数支持前递 |
| EX/MEM 的 Store 数据输入 | `forwardB_result` | 解决计算结果紧接 Store 时，Store 从旧 `rs2` 写入内存的问题 |

因此前递发生在寄存器数据选择与 ALU 输入来源选择之间：先由 `forwardA/forwardB` 得到更新后的寄存器值，再由 `ALUASrc/ALUSrc` 决定最终使用 PC、立即数还是寄存器值。

## HazardDetectionUnit

### 当前完成范围

已完成针对 Load-use 数据冒险的第一版组合检测逻辑，并通过独立模块语法检查。当前版本会同时比较 ID 指令的 `rs1` 和 `rs2`，属于保守检测；模块尚未在 `PIPELINED_CPU.v` 中实例化，其三个输出也尚未连接到 PC、IF/ID 和 ID/EX。

### 输入输出接口

| 端口 | 方向 | 位宽 | 所属阶段 | 作用 |
| --- | --- | ---: | --- | --- |
| `MemRead_ex` | 输入 | 1 | EX | 表示 EX 阶段指令是否为 Load |
| `rd_ex` | 输入 | 5 | EX | EX 阶段 Load 准备写入的目的寄存器编号 |
| `rs1_id` | 输入 | 5 | ID | 当前 ID 指令的第一个源寄存器编号 |
| `rs2_id` | 输入 | 5 | ID | 当前 ID 指令的第二个源寄存器编号或该位段的原始值 |
| `PCwrite` | 输出 | 1 | IF | 是否允许 PC 在时钟沿更新 |
| `IF_IDwrite` | 输出 | 1 | IF/ID | 是否允许 IF/ID 锁存新的 PC 和指令 |
| `ID_EX_flush` | 输出 | 1 | ID/EX | 是否将即将进入 EX 的控制信号清零并插入气泡 |

### 内部控制逻辑

当前冒险条件为：

```text
MemRead_ex == 1
并且 rd_ex != x0
并且（rd_ex == rs1_id 或 rd_ex == rs2_id）
```

| 状态 | `PCwrite` | `IF_IDwrite` | `ID_EX_flush` | 效果 |
| --- | ---: | ---: | ---: | --- |
| 检测到 Load-use | 0 | 0 | 1 | PC 和 IF/ID 保持原值，ID/EX 插入一个气泡 |
| 没有检测到冒险 | 1 | 1 | 0 | 流水线正常推进 |

这样处理的原因是：紧邻 Load 的消费者在下一周期进入 EX 时，Load 数据才在 MEM 阶段产生，标准五级流水线不能依靠普通 EX/MEM ALU 结果前递解决。因此暂停一个周期，使 Load 进入 WB，再通过 `forwardA/forwardB == 2'b01` 从 `writedata_wb` 前递。

### 当前保守判断的限制与计划

RISC-V 的 `[24:20]` 只有在 R、S、B 型指令中才是真正的 `rs2`；对于 I、U、J 型指令，它可能是立即数字段的一部分。类似地，LUI、AUIPC、JAL 也不真正使用 `[19:15]` 作为 `rs1`。当前无条件比较 `rs1_id`、`rs2_id` 可能造成额外暂停，但不会产生错误计算。

后续计划由 ID 阶段增加 `UseRs1_id`、`UseRs2_id`：R 型、Branch、Store 使用两个源寄存器；I 型 ALU、Load、JALR 只使用 `rs1`；LUI、AUIPC、JAL 两者都不使用。精确冒险条件将变为：

```text
MemRead_ex && rd_ex != x0 &&
((UseRs1_id && rd_ex == rs1_id) ||
 (UseRs2_id && rd_ex == rs2_id))
```

## 9/24 完成状态与下一步

| 项目 | 状态 |
| --- | --- |
| Forwarding Unit 内部比较逻辑 | 已完成 |
| Forwarding Unit 顶层实例化 | 已完成 |
| MEM/WB 两级前递数据选择 | 已完成 |
| ALU 两个输入的前递接线 | 已完成 |
| Store 数据前递 | 已完成 |
| Hazard Detection Unit 保守版内部逻辑 | 已完成，单模块编译通过 |
| `UseRs1_id`、`UseRs2_id` 精确判断 | 未完成 |
| Hazard Detection Unit 顶层实例化 | 未完成 |
| PC 与 IF/ID 暂停接口 | 未完成 |
| ID/EX 气泡接口 | 未完成 |
| Branch/JAL/JALR 控制冒险冲刷 | 未完成 |
| 去除 NOP 后的完整冒险测试 | 未完成 |

# 2026/9/25：精确冒险检测、流水线暂停与控制冒险冲刷

今天在 9/24 已完成的前递通路和保守版 Hazard Detection Unit 基础上，完成了精确的源寄存器使用判断、Load-use 暂停在顶层的数据通路接线，以及 Branch、JAL、JALR 的控制冒险冲刷。最后更新测试平台，使用无 NOP 的数据相关指令和带副作用的错误路径指令完成回归测试。

## 今日修改文件总览

| 文件 | 今日修改内容 | 目的 |
| --- | --- | --- |
| `rtl/control/Control.v` | 新增 `UseRs1`、`UseRs2` 输出，并按 opcode 赋值 | 告诉冒险检测单元当前 ID 指令是否真的读取 `rs1`、`rs2` |
| `rtl/control/HazardDetectionUnit.v` | 新增 `UseRs1_id`、`UseRs2_id` 输入，完善 Load-use 判断条件 | 避免把 I/U/J 型指令的立即数字段误认为源寄存器而产生假暂停 |
| `rtl/datapath/PC.v` | 新增 `PCwrite` 输入；由每周期无条件更新改为写使能控制 | Load-use 发生时冻结取指 PC |
| `rtl/memory/IF_ID.v` | 新增 `IF_IDwrite`、`IF_ID_flush` 输入，并加入保持和冲刷分支 | 数据冒险时保持 ID 指令，控制转移时清除错误路径指令 |
| `rtl/memory/ID_EX.V` | 新增 `ID_EX_flush` 输入，并将其并入清零条件 | Load-use 时插入气泡，控制转移时清除 EX 中的错误路径指令 |
| `rtl/memory/EX_MEM.v` | 新增 `EX_MEM_flush` 输入，并将其并入清零条件 | 控制转移在 MEM 确认时，阻止 EX 中的错误路径指令进入 MEM |
| `rtl/PIPELINED_CPU.v` | 实例化 Hazard Detection Unit；连接暂停和冲刷信号；增加 Branch taken 判断及控制优先级组合 | 完成数据冒险和控制冒险在顶层的闭环控制 |
| `tb/PIPELINED_CPU_tb.v` | 增加暂停计数、无 NOP 前递测试、Load-use 测试和有副作用错误路径冲刷测试 | 验证新控制逻辑的正确性以及不同冒险同时发生时的优先级 |

## Control：增加源寄存器使用信息

### 新增控制信号

| 新信号 | 位宽 | 产生阶段 | 使用阶段 | 含义 |
| --- | ---: | --- | --- | --- |
| `UseRs1` | 1 | ID / Control | ID / Hazard Detection | 当前 ID 指令是否真的读取 `instruction[19:15]` 指定的 `rs1` |
| `UseRs2` | 1 | ID / Control | ID / Hazard Detection | 当前 ID 指令是否真的读取 `instruction[24:20]` 指定的 `rs2` |

两个信号在 Control 组合逻辑开头默认置零，避免非法指令、气泡或未覆盖 opcode 产生锁存器。各类指令的赋值如下：

| 指令类别 | opcode | `UseRs1` | `UseRs2` | 原因 |
| --- | --- | ---: | ---: | --- |
| R 型 | `0110011` | 1 | 1 | ALU 使用两个寄存器操作数 |
| Load | `0000011` | 1 | 0 | 使用 `rs1 + imm` 计算地址，不读取 `rs2` |
| Store | `0100011` | 1 | 1 | `rs1` 用于地址，`rs2` 是写入内存的数据 |
| Branch | `1100011` | 1 | 1 | BEQ/BNE 比较两个寄存器 |
| I 型 ALU | `0010011` | 1 | 0 | 使用 `rs1` 和立即数；`[24:20]` 属于立即数 |
| LUI | `0110111` | 0 | 0 | 只使用立即数 |
| AUIPC | `0010111` | 0 | 0 | 使用 PC 和立即数 |
| JAL | `1101111` | 0 | 0 | 使用 PC 和立即数，不读取通用寄存器源操作数 |
| JALR | `1100111` | 1 | 0 | 使用 `rs1 + imm` 形成跳转地址 |

这里不能直接使用 `ALUSrc` 代替 `UseRs2`。例如 Store 的 ALU B 输入选择立即数，所以 `ALUSrc=1`，但它仍然读取 `rs2` 作为写内存数据。

## HazardDetectionUnit：由保守判断改为精确判断

### 接口变化

| 旧接口 | 新接口 | 变化原因 |
| --- | --- | --- |
| 无 `UseRs1_id` | 新增 `UseRs1_id` 输入 | 只有 ID 指令真正使用 `rs1` 时，`rd_ex == rs1_id` 才构成冒险 |
| 无 `UseRs2_id` | 新增 `UseRs2_id` 输入 | 屏蔽 I/U/J 型指令中并非 `rs2` 的 `[24:20]` 位段 |
| `PCwrite` | 保持不变 | 输出 Load-use 对 PC 的高有效写使能 |
| `IF_IDwrite` | 保持不变 | 输出 Load-use 对 IF/ID 的高有效写使能 |
| `ID_EX_flush` | 保持不变 | 输出 Load-use 气泡请求；顶层将其连接到改名后的 hazard 专用信号 |

### 判断逻辑变化

旧判断无条件比较两个原始字段：

```text
MemRead_ex && rd_ex != x0 &&
(rd_ex == rs1_id || rd_ex == rs2_id)
```

新判断加入源寄存器使用使能：

```text
MemRead_ex && rd_ex != x0 &&
((UseRs1_id && rd_ex == rs1_id) ||
 (UseRs2_id && rd_ex == rs2_id))
```

检测到 Load-use 时仍然输出：

| 输出 | 冒险时 | 无冒险时 | 作用 |
| --- | ---: | ---: | --- |
| `PCwrite` | 0 | 1 | 冻结或允许 PC 更新 |
| `IF_IDwrite` | 0 | 1 | 保持或更新 IF/ID |
| `ID_EX_flush` | 1 | 0 | 向 EX 插入一个气泡 |

## PC：从无条件更新改为写使能更新

### 接口与行为变化

| 旧设计 | 新设计 | 原因 |
| --- | --- | --- |
| 没有 `PCwrite` 输入 | 新增高有效输入 `PCwrite` | 允许 Hazard Detection Unit 暂停取指 |
| 非复位时每周期执行 `CurrentPC <= NextPC` | 只有 `PCwrite=1` 时才更新 | Load-use 发生时保持当前 PC |
| 使用自赋值表达保持 | `PCwrite=0` 时不赋值，由触发器自然保持 | 删除冗余自赋值，使时序意图更清晰 |

当前优先级为：

```text
reset > PCwrite > 保持
```

## IF/ID：同时支持暂停和控制冲刷

### 新增接口

| 新信号 | 有效电平 | 作用 |
| --- | --- | --- |
| `IF_IDwrite` | 1 | 允许锁存新的 IF 阶段 PC 和指令 |
| `IF_ID_flush` | 1 | 将 `instruction_out` 和 `pc_out` 清零，删除错误路径指令 |

行为由“每个时钟沿正常锁存”改为：

```text
reset          → 输出清零
IF_ID_flush=1  → 输出清零
IF_IDwrite=0   → 保持当前输出
IF_IDwrite=1   → 锁存新的PC和指令
```

优先级为：

```text
reset > IF_ID_flush > IF_IDwrite/保持
```

冲刷高于暂停非常重要：如果成立的控制转移与错误路径上的 Load-use 同时出现，IF/ID 必须删除错误路径，而不能继续保持它。

## ID/EX：增加气泡和错误路径清除能力

### 接口与条件变化

| 旧设计 | 新设计 | 原因 |
| --- | --- | --- |
| 只有 `reset` 能清零输出 | 新增 `ID_EX_flush` 输入 | 支持 Load-use 气泡及控制冒险冲刷 |
| 清零条件为 `reset` | 清零条件改为 `reset || ID_EX_flush` | 任一冲刷来源有效时都删除即将进入 EX 的指令 |

冲刷时所有数据和控制输出均清零。数据清零不是避免副作用的必要条件，但控制信号全部清零可以确保气泡不会写寄存器、写内存或再次发起跳转。

## EX/MEM：增加控制冒险冲刷

### 接口与条件变化

| 旧设计 | 新设计 | 原因 |
| --- | --- | --- |
| 只有 `reset` 能清零输出 | 新增 `EX_MEM_flush` 输入 | Branch/JAL/JALR 在 MEM 确认时，EX 中仍有一条错误路径指令 |
| 清零条件为 `reset` | 清零条件改为 `reset || EX_MEM_flush` | 阻止错误路径指令进入 MEM 并产生副作用 |

冲刷时包括 `MemWrite_out`、`Regwrite_out`、`MemRead_out`、`Branch_out`、`Jump_out`、`JumpReg_out` 在内的全部输出清零。MEM/WB 不冲刷，因为其中是控制转移指令本身或更老的正确路径指令。

## PIPELINED_CPU：新增信号、改名和最终控制组合

### ID 阶段源寄存器使用信号

| Control 端口 | 顶层信号 | Hazard Detection 端口 | 说明 |
| --- | --- | --- | --- |
| `UseRs1` | `users1_id` | `UseRs1_id` | 只在 ID 阶段使用，不经过 ID/EX |
| `UseRs2` | `users2_id` | `UseRs2_id` | 只在 ID 阶段使用，不经过 ID/EX |

### 原信号到新信号的变化

| 原顶层信号/行为 | 新顶层信号/行为 | 变化原因 |
| --- | --- | --- |
| `PCwrite` | `PCwrite_hazard` | 明确它只是 Hazard Detection Unit 产生的原始 Load-use 控制，不是送给 PC 的最终信号 |
| PC 直接使用 `PCwrite` | 新增 `PCwrite_final` 并连接 PC | 需要合并数据暂停与控制转移重定向 |
| `ID_EX_flush` | `ID_EX_flush_hazard` | 区分 Load-use 产生的气泡请求和最终冲刷信号 |
| ID/EX 直接使用 Hazard 输出 | 新增 `ID_EX_flush_final` 并连接 ID/EX | 同时响应数据冒险和控制冒险 |
| IF/ID 只有 `IF_IDwrite` | 继续保留 `IF_IDwrite`，并新增 `IF_ID_flush` 连接 | 暂停负责保持，控制冲刷负责删除，二者语义不同 |
| EX/MEM 没有冲刷控制 | 新增 `EX_MEM_flush` 连接 | 清除控制转移确认时仍在 EX 的错误路径指令 |

其中模块端口名称仍为 `PCwrite` 和 `ID_EX_flush`，变化的是顶层连接到这些端口的 wire 名称。例如 Hazard Detection Unit 的 `PCwrite` 端口连接 `PCwrite_hazard`，PC 模块的 `PCwrite` 端口连接 `PCwrite_final`。

### 新增的控制转移判断信号

| 新信号 | 位宽 | 产生条件 | 作用 |
| --- | ---: | --- | --- |
| `beq_taken_mem` | 1 | `Branch_mem && funct3==000 && zero_mem` | 表示 MEM 阶段 BEQ 条件成立 |
| `bne_taken_mem` | 1 | `Branch_mem && funct3==001 && !zero_mem` | 表示 MEM 阶段 BNE 条件成立 |
| `branch_taken_mem` | 1 | `beq_taken_mem || bne_taken_mem` | 汇总实际成立的条件分支 |
| `control_flush_mem` | 1 | `Jump_mem || JumpReg_mem || branch_taken_mem` | 表示发生了实际控制转移，需要删除三条年轻指令 |

不能把 `Branch_mem && zero_mem` 与 `Branch_mem && !zero_mem` 直接相或，因为 `zero_mem || !zero_mem` 恒为真，那样会导致所有 Branch 都被当成跳转。必须结合 `instruction_mem[14:12]` 区分 BEQ 和 BNE。

### 新增的最终控制信号

| 新信号 | 组合关系 | 最终连接 | 原因与优先级 |
| --- | --- | --- | --- |
| `PCwrite_final` | `PCwrite_hazard || control_flush_mem` | `PC.PCwrite` | 控制转移重定向必须覆盖错误路径产生的 Load-use 暂停 |
| `ID_EX_flush_final` | `ID_EX_flush_hazard || control_flush_mem` | `ID_EX.ID_EX_flush` | ID/EX 同时响应数据气泡和错误路径冲刷 |
| `control_flush_mem` | Jump/JALR/成立 Branch 的或逻辑 | `IF_ID.IF_ID_flush`、`EX_MEM.EX_MEM_flush`，同时参与两个 final 信号 | 用一个统一信号冲刷 IF、ID、EX 中的年轻错误路径指令 |

`IF_IDwrite` 没有改名，仍由 Hazard Detection Unit 直接连接 IF/ID。IF/ID 内部的冲刷分支优先于写使能，因此不需要额外生成 `IF_IDwrite_final`。

### 控制转移发生时的最终动作

| 位置 | 动作 | 是否保留 |
| --- | --- | --- |
| PC | `PCwrite_final=1`，写入现有 `next_pc` 逻辑选出的目标地址 | 更新到正确路径 |
| IF/ID | `control_flush_mem=1`，输出清零 | 不保留错误路径 IF 指令 |
| ID/EX | `ID_EX_flush_final=1`，输出清零 | 不保留错误路径 ID 指令 |
| EX/MEM | `control_flush_mem=1`，输出清零 | 不保留错误路径 EX 指令 |
| MEM/WB | 不冲刷 | 保留控制转移指令本身及更老指令 |

因为控制转移在 MEM 阶段确认，发生跳转时 IF、ID、EX 中共有三条年轻指令，所以需要同时冲刷三个流水线寄存器边界。

## 测试平台更新

### 信号名称同步

| 旧测试观察信号 | 新测试观察信号 | 原因 |
| --- | --- | --- |
| `dut.PCwrite` | `dut.PCwrite_hazard` | 测试中的 `stall_count` 只统计 Load-use 检测产生的暂停，而不是最终 PC 写使能 |

### 新增和加强的测试场景

| 测试阶段 | 主要验证内容 | 预期结果 |
| --- | --- | --- |
| `ALU forwarding without NOPs` | EX/MEM 前递、MEM/WB 前递、两个源同时从不同阶段前递 | 结果正确且 `stall_count=0` |
| `store-data forwarding without NOPs` | `forwardB_result` 同时作为 Store 写内存数据 | 内存写入新值且不暂停 |
| `load-use hazard stall` | Load 后紧跟使用其 `rd` 的 ALU 指令 | 恰好暂停 1 周期，之后从 WB 前递 |
| `load-to-store hazard stall` | Load 后紧跟使用加载结果作为 `rs2` 的 Store | 恰好暂停 1 周期并写入正确数据 |
| `no false rs2 hazard on I-type instruction` | I 型立即数低五位与 Load 的 `rd` 相同 | `UseRs2=0` 屏蔽假比较，暂停次数为 0 |
| `control flush overrides load-use stall` | 成立 Branch 位于 MEM，同时错误路径 Load 位于 EX、消费者位于 ID | `control_flush_mem` 覆盖暂停，PC 正确跳转，IF/ID、ID/EX、EX/MEM 均被冲刷 |
| `taken beq`、`taken bne` | 条件分支成立和目标地址执行 | 目标指令执行，错误路径不产生副作用 |
| `not-taken branches` | BEQ/BNE 条件不成立 | 不产生冲刷，顺序指令正常执行 |
| `jal flushes harmful wrong path` | JAL 后的三条错误路径指令会写寄存器 | 三条指令均被清除，链接地址和目标结果正确 |
| `jalr flushes harmful wrong path` | JALR 后的三条错误路径指令会写寄存器 | 三条指令均被清除，链接地址和目标结果正确 |

## 编译与仿真结果

完整 RTL 顶层通过 Icarus Verilog 展开编译。更新后的测试平台运行全部阶段后输出：

```text
PASS: all 20 instructions, forwarding, stalls, and control flushes passed.
```

目前可以确认：20 条指令基本数据通路、EX/MEM 与 MEM/WB 前递、Store 数据前递、精确 Load-use 暂停、BEQ/BNE/JAL/JALR 控制冲刷，以及控制转移高于错误路径数据暂停的优先级均通过测试。现有编译警告仅涉及部分 RTL 文件没有显式 `timescale`，以及寄存器堆和数据存储器组合读取数组的敏感列表提示，不影响本次功能验证结果。

## 9/25 完成状态

| 项目 | 状态 |
| --- | --- |
| `UseRs1`、`UseRs2` 精确源寄存器判断 | 已完成 |
| Hazard Detection Unit 顶层实例化 | 已完成 |
| PC 暂停 | 已完成 |
| IF/ID 暂停 | 已完成 |
| ID/EX Load-use 气泡 | 已完成 |
| BEQ/BNE 成立条件判断 | 已完成 |
| JAL/JALR 控制转移判断 | 已完成 |
| IF/ID、ID/EX、EX/MEM 控制冲刷 | 已完成 |
| 控制转移覆盖 Load-use 暂停的优先级 | 已完成 |
| 无 NOP 数据冒险测试 | 已完成并通过 |
| 有副作用错误路径冲刷测试 | 已完成并通过 |

# 2026/9/28：二位饱和计数分支预测器

本次在原有“条件分支到 MEM 阶段才根据真实结果重定向并冲刷”的设计上，加入了一个基于 BHT（Branch History Table）的二位饱和计数动态分支预测器。当前预测器只预测条件分支 BEQ/BNE；JAL 和 JALR 仍然保留原来的 MEM 阶段确认、重定向和冲刷方式。

## BranchPredictionUnit 输入输出接口

| 方向 | 信号 | 位宽 | 所属阶段 | 作用 |
| --- | --- | ---: | --- | --- |
| 输入 | `clk` | 1 | 全局 | 在时钟上升沿复位或更新 BHT 中对应的二位计数器 |
| 输入 | `reset` | 1 | 全局 | 同步复位；将16个 BHT 表项全部初始化为弱不跳 `01` |
| 输入 | `pc_if` | 64 | IF | 提供当前取指地址，使用 `pc_if[5:2]` 选中16个 BHT 表项中的一个 |
| 输入 | `instruction_if` | 32 | IF | 通过 `instruction_if[6:0]` 判断当前指令是否为条件分支，防止普通指令使用 BHT 结果重定向 PC |
| 输入 | `branch_mem` | 1 | MEM | 表示当前在 MEM 阶段完成判定的指令确实是条件分支；只有它为1时才训练 BHT |
| 输入 | `branch_taken_mem` | 1 | MEM | 条件分支的真实执行结果；1表示实际跳转，0表示实际不跳转 |
| 输入 | `bht_index_mem` | 4 | MEM | 该分支当初在 IF 阶段查询 BHT 时使用的表项编号，用于在 MEM 阶段更新同一个表项 |
| 输出 | `predicted_taken_if` | 1 | IF | 当前 IF 条件分支的方向预测；1预测跳转，0预测不跳转。非 Branch 指令固定输出0 |
| 输出 | `bht_index_if` | 4 | IF | 当前查询使用的 BHT 索引，即 `pc_if[5:2]`；它必须随对应指令经过流水线传到 MEM |

## BHT 与二位饱和状态机

预测器内部声明了16个二位 BHT 表项，每个表项都是一个独立的二位饱和状态机。使用 PC 的 `[5:2]` 位作为索引，是因为当前指令按照4字节对齐，`PC[1:0]` 恒为 `00`，继续使用这两位不能区分不同指令。16项表会产生地址别名，即不同 PC 可能映射到同一表项；这不会影响处理器执行结果，只可能影响预测准确率。

| 状态 | 名称 | 当前预测 | 实际跳转后的状态 | 实际不跳后的状态 |
| --- | --- | --- | --- | --- |
| `00` | 强不跳 | 不跳 | `01` | `00` |
| `01` | 弱不跳 | 不跳 | `10` | `00` |
| `10` | 弱跳转 | 跳转 | `11` | `01` |
| `11` | 强跳转 | 跳转 | `11` | `10` |

预测方向直接取二位状态的最高位，即 `bht[bht_index_if][1]`。计数器采用饱和变化方式：实际跳转时向 `11` 方向加一，但到达 `11` 后不再增加；实际不跳时向 `00` 方向减一，但到达 `00` 后不再减少。复位选择 `01`（弱不跳），使处理器启动时默认沿顺序地址取指，同时一旦第一次实际结果为跳转，就能够立刻进入预测跳转的 `10` 状态。

## 整体实现逻辑与完整数据流说明

在 IF 阶段，指令存储器根据 `current_pc_if` 输出 `instruction_if`，分支预测器同时接收这两个信号。预测器先检查 opcode 是否为条件分支 `1100011`，再使用 `current_pc_if[5:2]` 查询对应 BHT 表项。如果当前不是条件分支，`predicted_taken_if` 固定为0；如果是条件分支，则把表项最高位作为预测方向。同时，顶层新增了一个 IF 阶段的 `Immgen` 实例，根据 `instruction_if` 提前产生分支立即数，并计算 `predicted_branch_pc_if = current_pc_if + (instruction64_if << 1)`。因此在没有更高优先级重定向时，如果 `predicted_taken_if=1`，下一条 PC 选择预测目标地址；如果预测不跳，则选择 `pc_plus4_if`。这使处理器不必等到分支到达 MEM 才开始从可能正确的路径取指。

方向预测完成后，`predicted_taken_if` 和 `bht_index_if` 必须与产生它们的分支指令保持绑定。它们依次通过 IF/ID、ID/EX、EX/MEM 三个流水线寄存器，形成 `predicted_taken_id/ex/mem` 和 `bht_index_id/ex/mem`。这些信号不能在 MEM 阶段重新使用当前 IF 的预测信息，因为此时 IF 和 MEM 中是不同指令。流水线发生 Load-use 暂停时，IF/ID 会将预测信息与 PC、指令一起保持；发生复位或冲刷时，预测信息与错误路径指令一起清零，从而防止无效指令训练 BHT 或参与误预测判断。

分支进入 EX 阶段后，处理器仍然使用原有 ALU 和前递通路比较 `rs1`、`rs2`，产生 `zero_ex`，并计算真实目标地址 `branch_pc_ex`。这些结果通过 EX/MEM 到达 MEM。在 MEM 阶段，顶层结合 `Branch_mem`、`instruction_mem[14:12]` 和 `zero_mem` 分别得到 BEQ、BNE 是否真实成立，最终形成 `branch_taken_mem`。此时用当初随指令传来的 `predicted_taken_mem` 与真实结果比较：`branch_mispredict_mem = Branch_mem && (predicted_taken_mem != branch_taken_mem)`。同一个周期内，预测器还使用 `branch_taken_mem` 和 `bht_index_mem`，在下一个时钟上升沿训练该分支原来查询的 BHT 表项。

如果预测正确，无论实际结果是跳还是不跳，都不冲刷流水线，因为 IF、ID、EX 中的年轻指令已经来自正确路径。如果预测错误，则 `control_flush_mem` 有效，同时清除 IF/ID、ID/EX、EX/MEM 中的三条年轻错误路径指令。预测不跳但实际跳转时，PC 恢复为 `branch_pc_mem`；预测跳转但实际不跳时，PC 恢复为该分支自己的顺序地址 `pc_plus4_mem`，不能使用此时属于另一条指令的 `pc_plus4_if`。

最终 `next_pc` 的优先级为：MEM 阶段的 JAL 重定向最高，其次是 JALR 重定向，然后是条件分支误预测恢复，再之后才是 IF 阶段的新预测，最后是普通的 `PC+4`。这种优先级保证当一条老指令已经证明当前预测路径错误时，真实恢复地址能够覆盖错误路径上更年轻指令产生的新预测。JAL/JALR 当前尚未进入 BHT，因此仍然在 MEM 阶段无条件重定向和冲刷。

用一句完整的话概括当前实现：这是一个在 IF 阶段按 PC 低位查询16项二位饱和 BHT、提前生成条件分支方向和目标地址，在流水线中携带预测方向及表项索引，并在 MEM 阶段使用真实结果完成校验、训练和误预测恢复的动态分支预测结构；正确预测不产生冲刷，错误预测才清除三条年轻指令并恢复正确 PC。

## 顶层 PIPELINED_CPU 修改内容

| 修改位置或信号 | 旧设计 | 当前设计 | 修改原因 |
| --- | --- | --- | --- |
| 预测器实例 | 无 | 实例化 `BranchPredictionUnit`，连接 IF 查询信号与 MEM 更新信号 | 建立预测查询、真实结果反馈和状态训练的闭环 |
| 各阶段预测信号 | 无 | 新增 `predicted_taken_if/id/ex/mem` 和 `bht_index_if/id/ex/mem` | 保证预测元数据与对应分支指令同步前进 |
| IF 阶段立即数生成 | 只有 ID 阶段 `Immgen` | 新增 `u_immgen_if`，产生 `instruction64_if` | 预测跳转时必须在 IF 阶段立即得到目标地址 |
| IF 预测目标 | 无 | 新增 `predicted_branch_pc_if = current_pc_if + (instruction64_if << 1)` | 为预测跳转提供下一条取指地址 |
| 误预测判断 | 无 | 新增 `branch_mispredict_mem = Branch_mem && (predicted_taken_mem != branch_taken_mem)` | 只在预测方向与真实方向不同时恢复和冲刷 |
| Branch 冲刷条件 | `Jump_mem || JumpReg_mem || branch_taken_mem` | `Jump_mem || JumpReg_mem || branch_mispredict_mem` | 实际跳转但预测正确时不应冲刷；实际不跳但预测为跳时必须冲刷 |
| `next_pc` 的正常 Branch 路径 | 等待 MEM 真实结果选择目标或顺序地址 | IF 中使用 `predicted_taken_if` 选择 `predicted_branch_pc_if` 或 `pc_plus4_if` | 让取指沿预测路径提前进行 |
| `next_pc` 的误预测恢复 | 只有实际跳转恢复 | 实际跳转恢复到 `branch_pc_mem`；实际不跳恢复到 `pc_plus4_mem` | 同时覆盖“预测不跳但实际跳”和“预测跳但实际不跳”两种错误 |
| `next_pc` 优先级 | JAL/JALR/真实 Branch/PC+4 | JAL → JALR → Branch 误预测恢复 → IF 预测 → PC+4 | 老指令的真实结果必须覆盖年轻错误路径上的预测 |
| `PCwrite_final` | 数据暂停与控制重定向合并 | 继续使用 `PCwrite_hazard || control_flush_mem` | 即使错误路径同时产生 Load-use 暂停，误预测恢复仍必须更新 PC |

## 流水线寄存器修改内容

| 文件/边界 | 新增输入 | 新增输出 | 时序行为 | 修改原因 |
| --- | --- | --- | --- | --- |
| `rtl/memory/IF_ID.v` | `predicted_taken_in`、`bht_index_in[3:0]` | `predicted_taken_out`、`bht_index_out[3:0]` | 正常时 `out <= in`；`IF_IDwrite=0` 时保持；reset 或 flush 时清零 | 让 IF 预测信息与指令和 PC 一起进入 ID，并在数据暂停时保持一致 |
| `rtl/memory/ID_EX.V` | `predicted_taken_in`、`bht_index_in[3:0]` | `predicted_taken_out`、`bht_index_out[3:0]` | 正常时 `out <= in`；reset 或 `ID_EX_flush` 时清零 | 让预测信息随指令从 ID 进入 EX；气泡或错误路径不能继续携带有效预测 |
| `rtl/memory/EX_MEM.v` | `predicted_taken_in`、`bht_index_in[3:0]` | `predicted_taken_out`、`bht_index_out[3:0]` | 正常时 `out <= in`；reset 或 `EX_MEM_flush` 时清零 | 把原预测方向和原 BHT 索引送到 MEM，与真实分支结果进行比较并更新正确表项 |
| `rtl/memory/MEM_WB.v` | 无 | 无 | 保持不变 | 预测在 MEM 已完成校验和训练，WB 不再需要这些元数据 |

预测元数据的完整流向如下：

```text
BranchPredictionUnit（IF查询）
        ↓ predicted_taken_if / bht_index_if
      IF/ID
        ↓ predicted_taken_id / bht_index_id
      ID/EX
        ↓ predicted_taken_ex / bht_index_ex
      EX/MEM
        ↓ predicted_taken_mem / bht_index_mem
MEM：与 branch_taken_mem 比较，并反馈更新 BranchPredictionUnit
```

## 测试平台补充与验证结果

在 `tb/PIPELINED_CPU_tb.v` 中新增了分支执行次数、预测正确次数、误预测次数和控制冲刷次数统计，并增加 `two-bit branch predictor training and recovery` 测试阶段。同一条位于 PC=4、索引为1的 BNE 被循环执行4次，真实结果依次为跳、跳、跳、不跳，对应状态变化为：

```text
01 → 10 → 11 → 11 → 10
```

测试确认分支共执行4次，其中正确预测2次、误预测2次，并且只发生2次控制冲刷，证明正确预测不会错误冲刷流水线。循环计数寄存器最终为4，退出路径只执行一次，循环后的指令正常执行，最终 `BHT[1]` 为弱跳转 `10`。完整回归仍覆盖原20条指令、前递、Load-use 暂停和 JAL/JALR 控制冲刷，最终输出：

```text
PASS: all 20 instructions, forwarding, stalls, control flushes, and two-bit branch prediction passed.
```

## 9/28 完成状态

| 项目 | 状态 |
| --- | --- |
| 16项二位饱和 BHT | 已完成 |
| IF 阶段条件分支方向预测 | 已完成 |
| IF 阶段预测目标地址计算 | 已完成 |
| 预测方向和 BHT 索引跨流水线传递 | 已完成 |
| MEM 阶段真实结果校验与 BHT 训练 | 已完成 |
| 两类 Branch 误预测恢复 | 已完成 |
| 正确预测不冲刷、误预测才冲刷 | 已完成 |
| 预测器专项训练与恢复测试 | 已完成并通过 |

# 2026/10/8：基础例外、中断与 CSR 模块

以下“当前完成状态”记录的是当天开始集成前的快照；当天后续进展和最新状态见本节末的“继续集成与概念复习”。

本阶段完成了 `CSRFile`、`TrapControlUnit` 的模块设计和独立测试，并在 `Control` 中加入 ECALL、MRET 及六条 CSR 指令的解码。当前三个局部模块已完成，但 CSR/Trap 信号尚未贯通流水线，顶层还不能执行完整的异常进入与返回流程。

## 当前完成状态

| 项目 | 状态 |
| --- | --- |
| `CSRFile` 保存 CSR、进入 Trap、执行 MRET | 已完成，单元测试通过 |
| `TrapControlUnit` 异常/中断仲裁与 Cause 编码 | 已完成，单元测试通过 |
| ECALL、MRET、六条 CSR 指令解码 | 已完成，`Control.v` 编译通过 |
| `valid` 跨流水线传递 | IF/ID、ID/EX 已完成，EX/MEM 待补充 |
| CSR 运算、异常检测、顶层实例化、PC 重定向和冲刷 | 待完成 |

## CSRFile 输入输出

| 方向 | 信号 | 位宽 | 作用 |
| --- | --- | ---: | --- |
| 输入 | `clk`、`reset` | 1 | 时钟与同步复位；复位时清除状态并将 `mtvec` 初始化为 `0x100` |
| 输入 | `trap_enter` | 1 | 通知 CSRFile 进入 Trap |
| 输入 | `trap_pc` | 64 | Trap 对应指令地址，写入 `mepc` |
| 输入 | `trap_cause` | 64 | Trap 原因编码，写入 `mcause` |
| 输入 | `mret` | 1 | 执行异常返回，令 `MIE←MPIE`、`MPIE←1` |
| 输入 | `csr_we` | 1 | CSR 软件写使能 |
| 输入 | `csr_addr` | 12 | 选择读取或写入的 CSR |
| 输入 | `csr_wdata` | 64 | CSR 指令计算出的新值 |
| 输出 | `csr_rdata` | 64 | `csr_addr` 指定 CSR 的旧值，供写回 `rd` 和 CSR 运算使用 |
| 输出 | `mtvec_out` | 64 | Trap 入口地址 |
| 输出 | `mepc_out` | 64 | MRET 返回地址 |
| 输出 | `mcause_out` | 64 | 最近一次 Trap 的原因 |
| 输出 | `global_interrupt_enable` | 1 | `mstatus.MIE`，决定是否响应外部中断 |

CSRFile 当前实现 `mstatus`、`mtvec`、`mepc`、`mcause`，操作优先级为 `reset > trap_enter > mret > csr_we`。流水线接线时还需将共用的 `csr_addr` 拆分或调度为独立读、写地址，避免不同流水级同时访问时发生冲突。

## TrapControlUnit 输入输出

| 方向 | 信号 | 位宽 | 作用 |
| --- | --- | ---: | --- |
| 输入 | `valid_mem`、`pc_mem` | 1、64 | 表示 MEM 中存在真实指令，并提供其 PC |
| 输入 | `instruction_misaligned_mem` | 1 | 指令目标地址未对齐 |
| 输入 | `illegal_instruction_mem` | 1 | 指令编码非法或不受支持 |
| 输入 | `load_misaligned_mem`、`store_misaligned_mem` | 1、1 | Load/Store 有效地址未对齐 |
| 输入 | `ecall_mem` | 1 | 当前指令是机器模式 ECALL |
| 输入 | `external_interrupt_pending` | 1 | 存在尚未处理的机器外部中断请求 |
| 输入 | `global_interrupt_enable` | 1 | 允许响应外部中断 |
| 输出 | `trap_enter` | 1 | 至少一个有效Trap条件成立 |
| 输出 | `trap_pc` | 64 | 送往 `mepc` 的故障/恢复地址 |
| 输出 | `trap_cause` | 64 | 送往 `mcause` 的异常或中断编号 |

优先级为：指令地址未对齐 → 非法指令 → ECALL → Load未对齐 → Store未对齐 → 外部中断；只有 `valid_mem=1` 时才接收这些事件。

## SYSTEM 指令数据通路

以下为已确定的目标数据通路；目前 `Control` 与两个核心模块已经完成，流水线寄存器传递和顶层接线仍待实现。

- **CSRRW**：ID 译码产生 `CSRWrite=1、CSROp=WRITE、UseRs1=1、CSRtoReg=1`；CSRFile按 `instruction[31:20]` 读出旧值，EX用 `rs1` 形成 `csr_wdata`，写端口用新值覆盖CSR，旧值最终写回 `rd`。
- **CSRRS**：数据流与CSRRW相同，但EX计算 `csr_wdata=csr_rdata | rs1`；掩码中的1把对应状态位置1，`rs1=x0` 时 `csr_we=0`，只读取旧CSR。
- **CSRRC**：EX计算 `csr_wdata=csr_rdata & ~rs1`；掩码中的1清除对应状态位，`rs1=x0` 时只读取、不修改CSR。
- **CSRRWI**：以零扩展的 `instruction[19:15]`（`zimm`）代替 `rs1`，直接覆盖CSR；旧CSR仍通过 `CSRtoReg` 写回 `rd`。
- **CSRRSI**：用 `zimm` 对旧CSR按位置位；`zimm=0` 时只读不写。
- **CSRRCI**：用 `zimm` 对旧CSR按位清零；`zimm=0` 时只读不写。
- **ECALL**：Control产生 `Ecall=1` 并随有效指令传到MEM；TrapControlUnit输出 `trap_enter=1、trap_pc=pc_mem、trap_cause=11`，CSRFile随后保存 `mepc/mcause`、保存并清除MIE，顶层最终应把PC重定向到 `mtvec`。
- **MRET**：Control产生 `Mret=1` 并传到提交阶段；CSRFile恢复 `MIE←MPIE`，顶层应将PC重定向到 `mepc` 并冲刷年轻指令。

## 指令、例外与中断对应关系

| 指令或事件 | 类型 | `mcause` | 处理结果 |
| --- | --- | --- | --- |
| CSRRW | CSR操作 | 无 | 读取旧CSR并用 `rs1` 覆盖 |
| CSRRS | CSR操作 | 无 | 读取旧CSR并按掩码置位 |
| CSRRC | CSR操作 | 无 | 读取旧CSR并按掩码清位 |
| CSRRWI | CSR操作 | 无 | 使用 `zimm` 覆盖CSR |
| CSRRSI | CSR操作 | 无 | 使用 `zimm` 置位CSR |
| CSRRCI | CSR操作 | 无 | 使用 `zimm` 清位CSR |
| ECALL | 同步例外 | `11` | 保存现场并进入 `mtvec` |
| MRET | Trap返回 | 无 | 恢复中断状态并返回 `mepc` |
| 非法/不支持指令 | 同步例外 | `2` | 进入非法指令处理 |
| 指令地址未对齐 | 同步例外 | `0` | 阻止错误目标取指并进入Trap |
| Load地址未对齐 | 同步例外 | `4` | 禁止错误访存并进入Trap |
| Store地址未对齐 | 同步例外 | `6` | 禁止错误写内存并进入Trap |
| Machine External Interrupt | 异步中断 | `0x800000000000000B` | MIE开启时保存现场并进入 `mtvec` |

一句话概括：`Control` 识别SYSTEM指令，`TrapControlUnit` 选择并编码Trap，`CSRFile` 保存现场和特权状态，三者共同构成基础例外/中断控制核心。

## 2026/10/8 继续集成与概念复习（当天最新状态）

本节记录从局部模块走向流水线集成的工作。前面的状态表是当天较早的历史快照；**截至本节记录时**，`valid` 已传到 EX/MEM，CSRFile 已拆分读写地址，控制信号已从 Control 传至 MEM，ID 阶段已能读取旧 CSR 值，EX 阶段已写出 CSR 候选新值的组合计算。顶层通过语法及展开编译，但 CSR 写入、Trap 进入与返回仍未形成整机闭环。

### 1. IF/ID、ID/EX、EX/MEM：负责让有效性和控制信息跟随同一条指令

五级流水线的不同阶段同时处理不同指令。因此，`IllegalInstruction`、`Ecall`、`Mret`、`CSRWrite`、`CSRtoReg` 等标志必须与产生它们的指令一起向后移动，不能在 MEM 阶段重新拿当前 ID 阶段的译码结果使用。

| 模块或边界 | 今天的工作与功能 | 当前状态 |
| --- | --- | --- |
| IF/ID | 继续传递指令、PC、预测信息和 `valid`；复位、冲刷时把 `valid` 清零，暂停时保持 | 已有逻辑；SYSTEM 控制信号在 ID 才产生，因此 IF/ID 不需要传这些控制信号 |
| ID/EX | 寄存非法指令、ECALL、MRET、CSR 写使能、CSR 操作类型、立即数选择、旧值写回选择及旧 CSR 值；复位或冲刷时清零 | 端口和顶层接线已完成 |
| EX/MEM | 增加 `valid`，并传递到 MEM 仍需使用的异常和 CSR 控制标志；复位或冲刷时清零 | 端口、寄存逻辑和顶层接线已完成；CSR 新值和旧值的数据端口尚未增加 |

顶层按 ID、EX、MEM、WB 分块声明了控制信号。`CSROp` 与 `CSRUseImm` 只需到 EX，因为新 CSR 值在 EX 计算；`CSRtoReg` 将来还要传至 WB，因为旧 CSR 值最终可能写入通用寄存器 `rd`。目前 WB 阶段的 `CSRtoReg_wb` 仅声明，尚未连到 MEM/WB。

### 2. Control：负责在 ID 识别 SYSTEM 指令并发出控制信号

Control 已能识别 ECALL、MRET 和六条 CSR 指令。今天把 `IllegalInstruction_id`、`Ecall_id`、`Mret_id`、`CSRWrite_id`、`CSROp_id`、`CSRUseImm_id`、`CSRtoReg_id` 从 Control 实例接到顶层，再送入 ID/EX。Control 的职责是回答“这是什么操作、是否准备写 CSR、旧值是否要写入 rd”；它本身不计算 CSR 的新值，也不直接修改 CSRFile。

`CSROp` 的约定为 `00=WRITE`、`01=SET`、`10=CLEAR`，`11` 表示没有有效 CSR 运算。CSRRS/CSRRC 在 `rs1=x0`、CSRRSI/CSRRCI 在 `zimm=0` 时只读不写；CSRRW/CSRRWI 即使操作数为零，仍表示写入零。

### 3. CSRFile：负责保存机器状态，并向 ID 提供旧 CSR 值

CSRFile 是独立于通用寄存器堆的特殊寄存器组。它不是五级流水线中的一个新阶段，也不是为每种异常保存一份地址表。CSR 的编号是固定的，CSRFile 根据读地址选择当前内容：

| CSR | 地址 | 直观含义 |
| --- | --- | --- |
| `mstatus` | `0x300` | 中断状态；本项目重点实现第 3 位 MIE 和第 7 位 MPIE |
| `mtvec` | `0x305` | 处理程序入口；复位后为 `0x100` |
| `mepc` | `0x341` | Trap 后准备返回的 PC |
| `mcause` | `0x342` | 最近一次异常或中断的原因 |

今天 CSRFile 的共用地址接口已拆成 `csr_raddr` 与 `csr_waddr`，使 ID 读地址和以后 MEM 写地址能够分别提供。顶层已实例化 CSRFile，用 `instruction_id[31:20]` 作为读地址，把 `csr_rdata` 接到 `CSR_rdata_id`。Trap 和写入相关的输入端口按当前分阶段开发计划暂时空载，输出 `mtvec_out`、`mepc_out` 等也尚未接入 PC 控制。这些空载输入在编译时会产生告警；当前只能确认读通路接线及组合运算能够编译，不能据此认定整机 CSR 写入或 Trap 行为正确。

**旧值是什么？** “旧 CSR 值”是这条 CSR 指令修改目标 CSR 之前，CSRFile 中已经保存的内容，不等于这条指令的 PC。只有目标为 `mepc` 时，它的内容通常才是一个 PC。例如旧 `mtvec=0x100`，某条 CSRRW 准备写入 `0x200`，那么新值是 `0x200`，但以后写给 `rd` 的旧值仍是 `0x100`。

### 4. ID/EX：负责把旧 CSR 值与指令对齐送入 EX

顶层使用两根 64 位线是为了表示流水线寄存器的两侧，而不是 CSRFile 有两个读端口：

| 信号 | 来源 | 所属阶段 | 含义 |
| --- | --- | --- | --- |
| `CSR_rdata_id` | CSRFile 的组合读输出 | ID | 当前 ID 指令读到的旧 CSR 值 |
| `CSR_rdata_ex` | ID/EX 的寄存输出 | EX | 上一时钟沿锁存、属于当前 EX 指令的旧 CSR 值 |

同一周期，ID 可能在读 `mtvec`，EX 则正在处理更早的一条读取 `mepc` 的指令，所以两根线可以同时不同。真正保存一个周期的是 ID/EX 中的寄存器，`wire` 只是寄存器前后的连线。顶层已接通 `csr_rdata_in` 与 `csr_rdata_out`；ID/EX 复位或冲刷时会清零旧值和对应控制信号。

### 5. 顶层 EX CSR 运算：负责选择操作数并计算候选新值

EX 不在此时写 CSRFile，只计算将来可能写入的 64 位候选新值 `CSR_wdata_ex`。所需输入都属于同一条 EX 指令：旧值 `CSR_rdata_ex`、操作类型 `CSROp_ex`、操作数来源 `CSRUseImm_ex`、指令字段 `instruction_ex[19:15]` 和寄存器前递结果 `forwardA_result`。

| `CSRUseImm_ex` | 指令 | 操作数来源 | 原因 |
| --- | --- | --- | --- |
| 0 | CSRRW、CSRRS、CSRRC | `forwardA_result` | `[19:15]` 此时是 `rs1` 编号，需要其实际值；前递可取得尚未写回的结果 |
| 1 | CSRRWI、CSRRSI、CSRRCI | 零扩展的 `instruction_ex[19:15]` | `[19:15]` 此时直接是无符号 5 位 `zimm`，高 59 位补零即可 |

因此这里不需要另建立即数生成模块。顶层已形成 64 位 `CSRimm64` 和组合选择结果 `csr_operand_ex`。例如前一条 ADDI 刚把 x6 改成 8，后一条寄存器形式的 CSR 指令就应使用前递后的数值 8，而不是把寄存器编号 6 当操作数；立即数形式的 `[19:15]=8` 则直接使用数值 8。

可以把 CSR 的 64 位内容想成一排开关。WRITE 提供整排新的开关状态；SET/CLEAR 的操作数则是掩码，只标出要打开或关闭的位，掩码为 0 的位置保持原样。

| `CSROp_ex` | 功能 | 候选新值与旧值 A、操作数 B 的关系 | 为什么有效 |
| --- | --- | --- | --- |
| `00` | WRITE | 新值 = B | 完全覆盖旧值 A |
| `01` | SET | 新值 = A 按位或 B | B 的 1 使对应结果位必为 1；B 的 0 保留 A |
| `10` | CLEAR | 新值 = A 按位与“B 的逐位取反” | B 的 1 使对应结果位为 0；B 的 0 保留 A |
| 其他 | 无有效操作 | 给出确定默认值，当前取 A | 组合逻辑的所有分支均赋值，避免锁存旧计算结果 |

例：`mstatus` 旧值为 `0x80`、操作数为 `0x08`，WRITE 得 `0x08`，SET 得 `0x88`，CLEAR 仍为 `0x80`；若旧值是 `0x88`，CLEAR `0x08` 得 `0x80`。这说明只想开启或关闭 MIE（第 3 位）时，SET/CLEAR 能保留 MPIE（第 7 位）；直接 WRITE `0x08` 会同时清掉第 7 位。SET/CLEAR 是逐位运算，不是把整个 64 位数当作真假值判断。

当前顶层已写出 WRITE、SET、CLEAR 和默认分支的组合计算，**`CSR_rdata_ex` 仍保持旧值**；新旧两个值的用途不同：`CSR_wdata_ex` 将来送 MEM 准备写 CSR，`CSR_rdata_ex` 将来送 WB 准备写通用寄存器。`CSRWrite_ex` 是以后是否允许写 CSR 的控制标志，不能在 EX 阶段直接作为 CSRFile 的写使能。

### 6. TrapControlUnit：负责统一判断是否进入 Trap，并给出现场信息

TrapControlUnit 的局部模块及单元测试在前一阶段已完成，今天尚未把它实例化到顶层。它接收有效指令、异常标志、外部中断请求和全局中断允许位；输出 `trap_enter`、`trap_pc`、`trap_cause`。异常标志的实际检测逻辑（如跳转目标或 LD/SD 地址未对齐）还需在流水线中生成。`trap_pc` 是要存入 `mepc` 的触发事件指令 PC，**不是**处理程序入口；处理程序入口来自 `mtvec`。

完整 Trap 路径的目标是：检测事件 → TrapControlUnit 选择原因 → CSRFile 保存 `mepc/mcause` 并更新 `mstatus` → NextPC 选择 `mtvec` → 冲刷更年轻指令并禁止错误副作用 → 处理程序用 CSR 指令查看或修改现场 → MRET 恢复中断状态并选择 `mepc` 返回。同步故障若未经修复就原样返回故障指令，可能再次触发相同异常。

### 7. 编译检查、当前边界与下一步

以 `PIPELINED_CPU` 为顶层运行 Icarus Verilog 的 `-g2012 -Wall -tnull` 编译检查，**退出码为 0**。当前告警包括 CSRFile 的 7 个有意暂时空载的输入端口，以及原有寄存器堆、数据存储器数组的敏感列表提示。此次只验证语法和模块端口展开；**尚未运行新的 CSR 整机功能仿真**，不能将“可编译”记作 CSR 指令或 Trap 闭环通过。

| 后续顺序 | 要完成的工作 | 目的 |
| ---: | --- | --- |
| 1 | 用固定旧值、寄存器前递值和 `zimm` 检查 EX 的 WRITE/SET/CLEAR 结果 | 确认候选新值的组合计算正确 |
| 2 | 扩展 EX/MEM，传递 CSR 新值、旧值以及已存在的控制信号和指令地址字段 | 使 MEM 能对同一条指令提交写入，WB 能取得旧值 |
| 3 | 在 MEM 按 `valid_mem`、`CSRWrite_mem` 和 Trap 结果控制 CSRFile 写端口；扩展 MEM/WB 与 WB 选择旧值 | 完成六条 CSR 指令的写 CSR、写 `rd` 数据通路 |
| 4 | 产生未对齐标志，实例化 TrapControlUnit，连接外部中断请求、`mtvec/mepc`、NextPC 和 MRET | 完成异常进入和返回 |
| 5 | 完善冲刷、副作用屏蔽与 CSR 连续访问冒险，再做整机回归 | 保证异常精确，避免错误写入和读到过时 CSR 值 |

## 2026/10/8 CSR 数据通路后半段：EX/MEM、MEM 提交、MEM/WB 与前递

本次工作承接上一节已经完成的两部分：ID 阶段从 CSRFile 读取旧 CSR 值，以及 EX 阶段根据 WRITE、SET、CLEAR 计算候选新值。此前数据只到达 EX，CPU 虽然能够“读出旧值并算出新值”，但新值尚未写回 CSRFile，旧值也尚未写回通用寄存器 `rd`。本次把 CSR 数据继续送过 EX/MEM、MEM/WB，并接入 MEM 写 CSR、WB 写 `rd` 和普通寄存器前递，形成了六条 CSR 指令的基础数据通路。

### 1. 顶层阶段信号：区分 EX 候选结果、MEM 提交数据和 WB 写回数据

顶层按流水级新增或完成使用了以下信号：

| 信号 | 位宽 | 所属阶段 | 来源与用途 |
| --- | ---: | --- | --- |
| `CSR_wdata_ex` | 64 | EX | WRITE、SET、CLEAR 组合运算得到的候选新 CSR 值 |
| `CSR_wdata_mem` | 64 | MEM | `CSR_wdata_ex` 经 EX/MEM 锁存后的结果，用于写 CSRFile |
| `CSR_rdata_mem` | 64 | MEM | 旧 CSR 值经 EX/MEM 锁存后的结果，继续传向 WB，并作为 CSR 指令的 MEM 前递数据 |
| `CSRvalid_mem` | 1 | MEM | 当前阶段的软件 CSR 写使能，等于 `valid_mem && CSRWrite_mem` |
| `CSR_rdata_wb` | 64 | WB | 旧 CSR 值经 MEM/WB 锁存后的结果，用于写入通用寄存器 `rd` |
| `CSRtoReg_wb` | 1 | WB | 表示 WB 当前指令应选择旧 CSR 值，而不是普通 `MemtoReg` 数据 |

`CSR_wdata_mem` 不需要传到 WB，因为候选新值的目的地是 CSRFile，它在 MEM 阶段已经完成写入。WB 的职责是把修改前的旧 CSR 值写入 `rd`，所以只有 `CSR_rdata_mem` 需要继续进入 MEM/WB。

目标数据流现在是：

```text
ID：CSRFile 按 instruction_id[31:20] 读取旧值
        │
        ▼
ID/EX：CSR_rdata_id → CSR_rdata_ex
        │
        ▼
EX：选择 rs1 前递值或 zimm，并计算 CSR_wdata_ex
        │                         │
        │旧值                     │新值
        ▼                         ▼
EX/MEM：CSR_rdata_mem       CSR_wdata_mem
        │                         │
        │                         └──→ MEM 写入 CSRFile
        ▼
MEM/WB：CSR_rdata_wb
        │
        └──→ WB 写入通用寄存器 rd
```

这条路径体现了 CSR 指令的两个同时发生但方向不同的结果：新值写入特殊寄存器 CSR，旧值写入普通寄存器 `rd`。

### 2. EX_MEM：传递 CSR 候选新值和旧值

`rtl/memory/EX_MEM.v` 新增了两组 64 位数据端口：

| 新增端口 | 方向 | 功能 |
| --- | --- | --- |
| `CSR_wdata_in` | 输入 | 接收 EX 阶段算出的候选新值 `CSR_wdata_ex` |
| `CSR_rdata_in` | 输入 | 接收属于同一条指令的旧值 `CSR_rdata_ex` |
| `CSR_wdata_out` | 输出 | 产生 MEM 阶段的 `CSR_wdata_mem` |
| `CSR_rdata_out` | 输出 | 产生 MEM 阶段的 `CSR_rdata_mem` |

复位或 `EX_MEM_flush` 有效时，两个输出均清零；正常时钟上升沿，两者与 `instruction`、`CSRWrite`、`CSRtoReg`、`valid` 等信息一起锁存。这样可以保证 MEM 阶段看到的目标 CSR 地址、候选新值、旧值和控制信号来自同一条指令。

顶层 `u_ex_mem` 已完成如下阶段连接：

```text
CSR_wdata_ex → CSR_wdata_in  → CSR_wdata_out → CSR_wdata_mem
CSR_rdata_ex → CSR_rdata_in  → CSR_rdata_out → CSR_rdata_mem
```

CSR 地址没有额外增加独立流水线信号，因为完整的 `instruction_ex` 已经过 EX/MEM 成为 `instruction_mem`，MEM 可以直接使用 `instruction_mem[31:20]` 作为写地址。

### 3. MEM 提交逻辑与 CSRFile 写端口：把候选新值真正保存

顶层新增 `CSRvalid_mem = valid_mem && CSRWrite_mem`，并将它接到 CSRFile 的 `csr_we`。两个条件的含义分别是：

- `valid_mem=1`：MEM 流水槽中确实有一条有效指令，气泡或被冲刷的错误路径不能产生写入。
- `CSRWrite_mem=1`：Control 判定这条 CSR 指令确实需要修改目标 CSR。CSRRS/CSRRC 的 `rs1=x0` 以及 CSRRSI/CSRRCI 的 `zimm=0` 会令该信号为 0，因此可以只读旧值而不修改 CSR。

CSRFile 软件写端口现已连接为：

| CSRFile 端口 | MEM 阶段来源 | 含义 |
| --- | --- | --- |
| `csr_we` | `CSRvalid_mem` | 当前 MEM 指令有效且允许写 CSR |
| `csr_waddr` | `instruction_mem[31:20]` | 当前 MEM 指令指定的目标 CSR 地址 |
| `csr_wdata` | `CSR_wdata_mem` | EX 已经算好的 WRITE、SET 或 CLEAR 最终候选值 |

CSRFile 在这里不再识别 WRITE、SET、CLEAR，因为三种运算已经在 EX 完成；MEM 只负责提交结果。当前 `CSRvalid_mem` 还没有加入 `!trap_enter`，原因是 TrapControlUnit 尚未接入顶层。完成精确异常控制后，发生 Trap 的 MEM 指令必须禁止 CSR 软件写入，因此最终写使能还需要受 Trap 结果屏蔽。

### 4. MEM_WB：只继续传递旧 CSR 值和写回选择信号

`rtl/memory/MEM_WB.v` 新增了以下端口和寄存器逻辑：

| 新增端口 | 方向 | 功能 |
| --- | --- | --- |
| `CSR_rdata_in` | 输入 | 接收 MEM 阶段的旧 CSR 值 `CSR_rdata_mem` |
| `CSRtoReg_in` | 输入 | 接收当前指令需要把旧 CSR 值写入 `rd` 的控制信号 |
| `CSR_rdata_out` | 输出 | 产生 WB 阶段的 `CSR_rdata_wb` |
| `CSRtoReg_out` | 输出 | 产生 WB 阶段的 `CSRtoReg_wb` |

复位时两个输出清零，正常时钟上升沿进行锁存。`CSR_wdata_mem` 没有进入 MEM/WB，因为它已经在 MEM 用于写 CSRFile，WB 不再需要它。

### 5. WB 写回选择：让 CSR 旧值写入通用寄存器 rd

原 WB 多路选择器只根据 `MemtoReg_wb` 在 ALU 结果、内存读数、立即数和 `PC+4` 中选择。CSR 指令的 `MemtoReg` 没有单独编码，通常仍保持默认值，因此只看 `MemtoReg_wb` 会错误选择普通 ALU 结果。

当前 WB 选择逻辑先检查 `CSRtoReg_wb`：

- `CSRtoReg_wb=1`：`writedata_wb` 选择 `CSR_rdata_wb`。
- `CSRtoReg_wb=0`：继续执行原有 `MemtoReg_wb` 选择，不影响基础 20 条指令。

CSR 指令在 Control 中同时令 `Regwrite=1`，所以 WB 最终使用指令的 `rd=instruction_wb[11:7]`，把旧 CSR 值写入通用寄存器堆。

以 `csrrw x5, mtvec, x6` 为例，若旧 `mtvec=0x100`、`x6=0x200`：

```text
MEM：CSR_wdata_mem=0x200，写入 mtvec
WB ：CSR_rdata_wb=0x100，写入 x5
```

### 6. MEM 前递数据选择：支持紧随 CSR 指令使用 rd

原有 ForwardingUnit 只产生 `forwardA/forwardB` 选择信号，真正的 MEM 前递数据由顶层 `forward_data_mem` 选择。此前它只根据 `MemtoReg_mem` 选择 ALU、内存、立即数或 `PC+4`。对于 CSR 指令，这会错误选择默认的 ALU 结果，而正确的通用寄存器写回值应是 `CSR_rdata_mem`。

顶层现已在普通 `MemtoReg_mem` 选择之前检查 `CSRtoReg_mem`：

- `CSRtoReg_mem=1`：`forward_data_mem` 选择 `CSR_rdata_mem`。
- `CSRtoReg_mem=0`：保持原来的 `MemtoReg_mem` 选择。

之后无论上述条件为何，`forwardA` 和 `forwardB` 都继续执行各自的选择，避免组合逻辑遗漏赋值。这样下面的依赖可以从 MEM 直接前递，不必等待 CSR 指令进入 WB：

```text
csrrw x5, mtvec, x6
add   x7, x5, x0
```

第二条 ADD 需要的是旧 `mtvec` 值，也就是 `CSR_rdata_mem`，不是 CSR 指令无意义或默认产生的普通 ALU 结果。

### 7. 与此前工作的联系及当前边界

此前已经完成的 Control、CSRFile 读端、ID/EX 和 EX 运算解决了以下问题：

```text
识别 CSR 指令 → 读取旧值 → 选择 rs1/zimm → 计算候选新值
```

本次工作继续解决：

```text
候选新值送到 MEM → 写入 CSRFile
旧值送到 WB       → 写入通用寄存器 rd
旧值在 MEM         → 支持普通寄存器数据前递
```

因此，六条 CSR 指令的基础软件读写数据通路已经在结构上贯通。当前以 `PIPELINED_CPU` 为顶层执行 Icarus Verilog `-g2012 -Wall -tnull` 编译，退出码为 0；已消除本次新增信号的隐式线、端口和位宽问题。现有告警只包括 CSRFile 尚未接入的 `trap_enter/trap_pc/trap_cause/mret` 输入，以及原有寄存器堆和数据存储器数组的敏感列表提示。

当前仍不能直接宣称 CSR 指令整机功能通过，原因包括：尚未增加针对六条 CSR 指令的流水线仿真；连续访问同一 CSR 时，ID 读到旧状态的 CSR 相关冒险尚未处理；Trap 尚未参与 CSR 写使能屏蔽；Trap、MRET、PC 重定向和精确冲刷也尚未接入。下一阶段应先对 CSR 软件读写和通用寄存器前递进行专项仿真，再继续异常检测与 TrapControlUnit 的系统集成。

### 8. CSR 流水线专项测试与基础回归结果

新增 `tb/PIPELINED_CPU_CSR_tb.v`，使用独立测试阶段验证当前已经贯通的 CSR 软件读写数据通路。由于 TrapControlUnit 和 MRET 尚未接入顶层，测试平台只在仿真期间将 CSRFile 的 `trap_enter`、`trap_pc`、`trap_cause` 和 `mret` 固定为无效值，从而隔离并验证 CSR 指令本身；该处理不修改综合 RTL。

专项测试覆盖如下：

| 测试内容 | 验证目标 |
| --- | --- |
| CSRRW | 新值写入 CSRFile、旧值写入 `rd`、`mtvec` 低两位对齐 |
| CSRRS | 寄存器掩码对旧 CSR 按位置位，并返回修改前旧值 |
| CSRRC | 寄存器掩码对旧 CSR 按位清零，并返回修改前旧值 |
| CSRRWI | 五位 `zimm` 零扩展后覆盖 CSR，并返回旧值 |
| CSRRSI | 立即数掩码按位置位 |
| CSRRCI | 立即数掩码按位清零 |
| CSRRS，`rs1=x0` | 只读取旧值，不修改 CSRFile |
| CSRRCI，`zimm=0` | 只读取旧值，不修改 CSRFile |
| CSR 指令后立即使用 `rd` | `CSR_rdata_mem` 能通过 MEM 前递供下一条普通指令使用 |
| ADDI 后立即使用结果作为 CSR 操作数 | 普通 EX/MEM 前递能把最新 `rs1` 值送入 CSR EX 运算 |

CSR 专项测试输出：

```text
PASS: all six CSR instructions, read-only forms, CSR rd forwarding, and CSR operand forwarding passed.
```

随后重新运行原有 `tb/PIPELINED_CPU_tb.v`，确认新增 CSR 的 MEM 前递优先级和 WB 选择没有破坏基础流水线。原 20 条指令、普通前递、Load-use 暂停、控制冲刷和二位分支预测全部通过：

```text
PASS: all 20 instructions, forwarding, stalls, control flushes, and two-bit branch prediction passed.
```

至此可以确认：六条 CSR 指令在没有同 CSR 连续相关、没有 Trap 干预的条件下，读取旧值、计算新值、MEM 写 CSRFile、WB 写 `rd`、CSR 结果向下一条普通指令前递，以及普通结果向 CSR 操作数前递均工作正确。尚未覆盖连续指令访问同一 CSR 的相关冒险，这应作为 CSR 数据通路完成前的下一项工作。

# 2026/10/9：CSR 前递、异常检测与 Trap 顶层接线

## 今日修改顺序（简要）

```text
新建 CSRForwardingUnit
    → 顶层新增 CSRForward_id、CSR_rdata_effective_id，并改接 ID/EX
    → 验证 EX/MEM 两级 CSR 前递及 EX 优先级
    → 顶层新增 instruction/load/store 三类未对齐信号
    → EX_MEM 新增 pc_in、pc_out，顶层得到 current_pc_mem
    → 顶层例化 TrapControlUnit，连接异常信号与 CSRFile
    → 新增 trap_enter/trap_pc/trap_cause、mret_valid、global_interrupt_enable
    → 接出 mtvec_csr、mepc_csr、mcause_csr，外部中断暂接 0
    → 统一异常控制信号大小写并完成基础回归
```

## 1. CSRForwardingUnit：处理连续访问同一个 CSR 的相关冒险

此前 ID 阶段直接使用 CSRFile 输出的 `CSR_rdata_id`。当两条 CSR 指令连续访问同一个 CSR 时，后一条指令在 ID 读取旧值，而前一条指令可能仍在 EX 或 MEM，尚未完成对 CSRFile 的时序写入，因此后一条指令可能得到过时值。

今天新增 `rtl/control/CSRForwardingUnit.v`。该模块只负责比较地址和输出选择编码，不直接传递或修改 CSR 数据。

| 输入 | 含义 |
| --- | --- |
| `CSR_addr_id` | 当前 ID 指令访问的 CSR 地址 |
| `CSR_addr_ex` | 当前 EX 指令访问的 CSR 地址 |
| `CSR_addr_mem` | 当前 MEM 指令访问的 CSR 地址 |
| `valid_ex`、`valid_mem` | 对应流水槽中是否存在有效指令 |
| `CSRWrite_ex`、`CSRWrite_mem` | 对应指令是否真的准备修改 CSR |

模块输出两位 `CSRForward_id`：

| `CSRForward_id` | ID 阶段应使用的 CSR 旧值来源 |
| --- | --- |
| `2'b00` | CSRFile 当前读出的 `CSR_rdata_id` |
| `2'b01` | MEM 阶段候选新值 `CSR_wdata_mem` |
| `2'b10` | EX 阶段候选新值 `CSR_wdata_ex` |

判断优先级为 EX 高于 MEM。若 EX 和 MEM 中的两条旧指令都准备写入 ID 当前访问的 CSR，EX 中的指令在程序顺序上离 ID 更近，其结果代表更新的 CSR 状态，因此必须优先选择 `CSR_wdata_ex`。

顶层新增：

- 两位选择信号 `CSRForward_id`；
- 64 位组合选择结果 `CSR_rdata_effective_id`；
- `CSRForwardingUnit` 实例；
- 根据 `CSRForward_id` 在 `CSR_rdata_id`、`CSR_wdata_mem`、`CSR_wdata_ex` 之间选择的组合逻辑。

ID/EX 的 `csr_rdata_in` 从原来的原始读值 `CSR_rdata_id` 改为 `CSR_rdata_effective_id`。因此送入 EX 的“旧 CSR 值”已经是消除同 CSR 相关冒险后的有效值。

实现过程中修正了两处顶层问题：`CSR_rdata_effective_id` 在 `always @(*)` 中赋值，因此声明为 `reg`；`CSRForwardingUnit.CSRWrite_mem` 必须连接一位控制信号 `CSRWrite_mem`，不能误接 64 位 `CSR_rdata_mem`。

临时专项仿真验证了以下情况：

- 两条 CSR 指令背靠背访问同一个 CSR，ID 使用 EX 新值；
- 中间隔一条指令时，ID 使用 MEM 新值；
- EX 与 MEM 同时命中同一 CSR 时，选择更新的 EX 结果；
- 连续三条 CSR 指令对同一 CSR 执行 WRITE、SET、CLEAR，旧值写回和最终状态均正确。

测试结果为：

```text
PASS: dedicated CSR forwarding checks passed.
```

## 2. PIPELINED_CPU 的 MEM 异常检测：产生三类地址未对齐信号

`TrapControlUnit` 的职责是接收已经检测出的异常并选择 `trap_cause`，它本身不负责计算地址是否对齐。今天在顶层 MEM 部分新增三个组合信号：

| 信号 | 检测条件 | 原因 |
| --- | --- | --- |
| `load_misaligned_mem` | `valid_mem && MemRead_mem && aluresult_mem[2:0] != 3'b000` | 当前只支持 64 位 LD，地址必须按 8 字节对齐 |
| `store_misaligned_mem` | `valid_mem && MemWrite_mem && aluresult_mem[2:0] != 3'b000` | 当前只支持 64 位 SD，地址必须按 8 字节对齐 |
| `instruction_misaligned_mem` | 有效的 JAL、JALR 或实际跳转 Branch 的目标地址低两位不是 `00` | 当前不支持压缩指令，取指地址必须按 4 字节对齐 |

Load/Store 使用 `aluresult_mem`，因为 EX 已经计算出基址与立即数之和，并经 EX/MEM 送入 MEM。指令地址检测分别使用 `branch_pc_mem` 和 `jalr_pc_mem`；条件分支只有 `branch_taken_mem=1`、处理器真的准备采用目标地址时才产生异常。

三个信号在顶层 `always @(*)` 中赋值，因此声明为 `reg`。每段组合逻辑都包含完整的 `else` 清零分支，不产生锁存器。这里不需要再给 EX/MEM 增加三个异常标志端口，因为检测所需的实际地址、目标地址和控制信号已经全部存在于 MEM。

## 3. EX_MEM：把异常指令自己的 PC 送到 MEM

`TrapControlUnit` 需要 `pc_mem`，以便把发生同步异常的指令地址送入 `trap_pc`，最终写入 `mepc`。原 EX/MEM 只传递了 `pc_plus4` 和分支目标地址；两者分别表示下一条顺序地址和控制流目标，都不能替代故障指令自己的 PC。

今天在 `rtl/memory/EX_MEM.v` 新增：

| 端口 | 方向 | 功能 |
| --- | --- | --- |
| `pc_in[63:0]` | 输入 | 接收 EX 阶段当前指令 PC，即 `current_pc_ex` |
| `pc_out[63:0]` | 输出 | 产生 MEM 阶段当前指令 PC，即 `current_pc_mem` |

复位或 `EX_MEM_flush` 时 `pc_out` 清零；正常时钟上升沿执行 `pc_out <= pc_in`。顶层实例连接形成：

```text
current_pc_ex → EX_MEM.pc_in → EX_MEM.pc_out → current_pc_mem
```

`TrapControlUnit.pc_mem` 随后连接 `current_pc_mem`。这样 `trap_pc` 保存的是异常指令本身的 PC，而不是 `PC+4` 或错误的跳转目标。

## 4. TrapControlUnit 顶层例化：统一形成 Trap 请求、PC 和 Cause

顶层新增并使用：

| 信号 | 位宽 | 来源与作用 |
| --- | ---: | --- |
| `trap_enter` | 1 | TrapControlUnit 输出，通知 CSRFile 进入 Trap |
| `trap_pc` | 64 | TrapControlUnit 输出，写入 CSRFile 的 `mepc` |
| `trap_cause` | 64 | TrapControlUnit 输出，写入 CSRFile 的 `mcause` |
| `global_interrupt_enable` | 1 | CSRFile 输出的 `mstatus.MIE`，送入 TrapControlUnit |

TrapControlUnit 现已接入：

- `valid_mem` 与 `current_pc_mem`；
- 三类地址未对齐信号；
- `illegal_instruction_mem` 与 `ecall_mem`；
- CSRFile 输出的 `global_interrupt_enable`；
- `trap_enter`、`trap_pc`、`trap_cause` 三个顶层输出连线。

外部中断请求目前尚未作为 CPU 顶层端口接入，因此 `external_interrupt_pending` 显式连接 `1'b0`。这样可以先完成同步异常闭环，同时避免输入空载产生未知值。以后加入真实外部中断时，需要从 `CPU.v` 或测试平台向 `PIPELINED_CPU` 增加并传递该输入。

今天还统一了 `illegal_instruction_id/ex/mem`、`ecall_id/ex/mem`、`mret_id/ex/mem` 的顶层信号大小写。模块端口名仍严格使用各模块定义的名称，括号中的顶层信号统一使用小写阶段后缀，消除了隐式线网和错误端口名。

## 5. CSRFile Trap、MRET 与状态输出连接

CSRFile 的 Trap 输入已从空载改为：

```text
trap_enter → CSRFile.trap_enter
trap_pc    → CSRFile.trap_pc
trap_cause → CSRFile.trap_cause
```

因此 TrapControlUnit 检测到异常后，CSRFile 可以在时钟沿完成：

- `mepc ← trap_pc`；
- `mcause ← trap_cause`；
- `MPIE ← MIE`；
- `MIE ← 0`。

顶层新增 `mret_valid = valid_mem && mret_mem`，并连接 CSRFile 的 `mret` 输入。只有 MEM 中存在有效 MRET 指令时，CSRFile 才恢复中断状态，避免无效流水槽触发状态修改。

CSRFile 的三个状态输出也已接到顶层：

| 顶层信号 | CSRFile输出 | 后续用途 |
| --- | --- | --- |
| `mtvec_csr` | `mtvec_out` | Trap 时作为新的 PC |
| `mepc_csr` | `mepc_out` | MRET 时作为返回 PC |
| `mcause_csr` | `mcause_out` | 观察和验证最近一次 Trap 原因 |

这三个顶层信号声明为 `wire`，因为真正保存并修改状态的是 CSRFile 内部的寄存器；顶层只接收和读取模块输出。后续 `next_pc` 组合逻辑会给 `next_pc` 赋值并读取 `mtvec_csr` 或 `mepc_csr`，不会反向给这三个 CSR 状态信号赋值。

## 6. 当前验证结果

完成上述接线后，以 `PIPELINED_CPU` 为顶层执行 Icarus Verilog 展开编译，新增端口、位宽、隐式线网和大小写错误均已消除。随后重新运行基础 CPU 回归测试，结果为：

```text
PASS: all 20 instructions, forwarding, stalls, control flushes, and two-bit branch prediction passed.
```

这说明新增 CSR 前递、地址异常检测、PC 传递和 Trap 接线没有破坏原有普通指令、数据前递、Load-use 暂停、控制冲刷及分支预测功能。

## 7. 今日结束时的边界与下一步

当前已经形成：

```text
MEM 异常检测
    → TrapControlUnit 选择 trap_pc 与 trap_cause
    → CSRFile 保存 mepc、mcause 并更新 mstatus
```

尚未形成完整闭环的部分是：

1. `next_pc` 尚未在 `trap_enter` 时选择 `mtvec_csr`；
2. `next_pc` 尚未在 `mret_valid` 时选择 `mepc_csr`；
3. `control_flush_mem` 尚未加入 `trap_enter` 与 `mret_valid`，年轻指令还不会因 Trap/MRET 被冲刷；
4. 未对齐 Store 的 DataMemory 写使能尚未受 `trap_enter` 屏蔽；
5. 未对齐 Load 等异常指令的通用寄存器写回尚未受 `trap_enter` 屏蔽；
6. `CSRvalid_mem` 尚未显式加入 Trap 屏蔽；
7. 外部中断请求目前固定为 0，尚未作为真实顶层输入；
8. 尚未建立覆盖非法指令、ECALL、三类未对齐、MRET、PC 重定向和副作用屏蔽的 Trap 整机测试。

下一次应先修改 `next_pc` 的选择优先级，使 `trap_enter` 选择 `mtvec_csr`、`mret_valid` 选择 `mepc_csr`，并把二者加入 `control_flush_mem`。完成控制流重定向后，再集中处理异常指令的内存、通用寄存器和 CSR 写入屏蔽。

# 2026/10/10：Trap 闭环、外部中断接入与整机验证

## 今日修改顺序（总体总结）

```text
next_pc 加入 trap_enter 与 mret_valid
    → control_flush_mem 加入 Trap 与 MRET
    → CSRvalid_mem、MemWrite_valid_mem、Regwrite_valid_mem 加入 Trap 屏蔽
    → 新建并运行 PIPELINED_CPU_TRAP_tb
    → PIPELINED_CPU 新增 external_interrupt_pending 输入
    → 三个整机 TB 接入外部中断输入
    → Trap TB 增加 MIE 开关与外部中断测试
    → Trap TB 增加 JAL、taken Branch、untaken Branch 未对齐测试
    → 运行 Trap、基础流水线、CSR 三组回归测试
```

今天先把昨天已经接到 CSRFile 的 Trap 信息继续接入 PC、冲刷和提交控制，使异常进入与 MRET 返回形成完整闭环；随后把外部中断从临时常量改成真实顶层输入，并扩展整机测试覆盖已有异常入口、外部中断开关和三种控制流地址未对齐路径。

## 1. PIPELINED_CPU 控制流：完成 Trap 进入与 MRET 返回

顶层 `next_pc` 选择逻辑增加了两个最高优先级来源：

| 条件 | `next_pc` 来源 | 目的 |
| --- | --- | --- |
| `trap_enter=1` | `mtvec_csr` | 进入异常或中断处理程序 |
| `mret_valid=1` | `mepc_csr` | 从处理程序返回保存的地址 |

当前先判断 `trap_enter`，再判断 `mret_valid`，之后才处理 JAL、JALR、分支恢复和顺序取指。这样发生 Trap 时不会继续采用故障指令原本的控制流目标；执行有效 MRET 时会直接使用 CSRFile 保存的 `mepc`。

`control_flush_mem` 同时加入 `trap_enter` 与 `mret_valid`。Trap 在 MEM 阶段确定时，位于 EX、ID、IF 的指令都更年轻，不能继续执行；MRET 改变控制流时也要清除已经沿顺序地址进入流水线的指令。

```text
Jump_mem / JumpReg_mem / branch_mispredict_mem / trap_enter / mret_valid
    → control_flush_mem
    → 冲刷 IF/ID、ID/EX、EX/MEM 中的错误路径或年轻指令
```

## 2. PIPELINED_CPU 精确副作用屏蔽：异常指令不能修改体系结构状态

只修改 PC 和冲刷流水线还不够，因为正在 MEM 阶段触发异常的指令可能正准备写内存、写通用寄存器或写 CSR。今天把三个实际写使能统一加入 `~trap_enter`：

| 有效写使能 | 条件 | 连接位置 | 屏蔽的错误副作用 |
| --- | --- | --- | --- |
| `CSRvalid_mem` | `valid_mem && CSRWrite_mem && ~trap_enter` | CSRFile 的 `csr_we` | 异常指令不能进行软件 CSR 写入 |
| `MemWrite_valid_mem` | `valid_mem && MemWrite_mem && ~trap_enter` | DataMemory 的 `MemWrite` | 未对齐 Store 不能修改内存 |
| `Regwrite_valid_mem` | `valid_mem && Regwrite_mem && ~trap_enter` | MEM/WB 的 `Regwrite_in` | 未对齐 Load、JAL/JALR 等异常指令不能在 WB 修改 `rd` |

这部分形成精确异常的基本边界：比异常指令更早、已经进入 WB 的旧指令仍然提交；触发异常的当前 MEM 指令被取消副作用；位于前面流水级的年轻指令通过 `control_flush_mem` 被冲刷。

```text
MEM 检测异常
    → TrapControlUnit 输出 trap_enter、trap_pc、trap_cause
    → 当前 MEM 指令的 CSR、内存、通用寄存器写入被屏蔽
    → CSRFile 保存 mepc、mcause 并更新 mstatus
    → next_pc 选择 mtvec_csr
    → 冲刷年轻指令
```

## 3. PIPELINED_CPU_TRAP_tb：建立同步异常和 MRET 整机测试

新增 `tb/PIPELINED_CPU_TRAP_tb.v`，以完整 `PIPELINED_CPU` 为被测对象。每个测试阶段都会复位 CPU，清理通用寄存器和数据存储器，用 NOP 填充指令存储器，并在复位后的 `mtvec=0x100` 位置放置可观察的处理程序指令。

最初加入并通过了以下测试：

| 测试事件 | 主要检查内容 |
| --- | --- |
| ECALL | `mepc` 保存 ECALL 自身 PC，`mcause=11`，旧指令仍提交，年轻指令被冲刷，处理程序执行 |
| 非法指令 | `mcause=2`，年轻指令被冲刷，PC 进入 `mtvec` |
| 未对齐 LD | `mcause=4`，目标 `rd` 保持原值 |
| 未对齐 SD | `mcause=6`，数据存储器保持原值 |
| 未对齐 JALR | `mcause=0`，链接寄存器不写入，年轻指令被冲刷 |
| MRET | PC 返回 `mepc`，年轻指令被冲刷，`MIE←MPIE` 且 `MPIE←1` |

这些测试同时观察 `mcause`、`mepc`、通用寄存器、数据存储器、处理程序入口和 `mstatus`，用于确认“发现异常、保存现场、取消副作用、跳入处理程序、执行返回”整条路径能够共同工作。

## 4. 外部中断输入：从临时常量改为真实顶层端口

昨天把 `TrapControlUnit.external_interrupt_pending` 暂时接为 0，是为了先完成同步异常闭环，并避免未驱动输入产生 `x`。今天开始验证外部中断后，`PIPELINED_CPU` 增加一位输入端口：

```text
external_interrupt_pending
    → PIPELINED_CPU 顶层输入
    → TrapControlUnit.external_interrupt_pending
```

修改过程中发现，若只在顶层内部声明 `wire external_interrupt_pending`，但没有任何模块输出或连续赋值驱动它，该信号仍然悬空，外部也无法控制。因此最终删除内部悬空声明，把它放入 `PIPELINED_CPU` 的模块输入端口列表。

三个整机测试平台同步处理新增端口：

- `PIPELINED_CPU_tb.v` 固定连接 `1'b0`，保证基础指令测试不受中断影响；
- `PIPELINED_CPU_CSR_tb.v` 固定连接 `1'b0`，保证 CSR 专项测试保持原有环境；
- `PIPELINED_CPU_TRAP_tb.v` 使用可变 `reg external_interrupt_pending`，主动产生和撤销中断请求。

## 5. 外部中断整机测试：验证 MIE 门控、现场保存与状态更新

Trap 测试增加了两种互为对照的场景。

第一种场景保持 `mstatus.MIE=0`，同时令 `external_interrupt_pending=1`。普通 ADDI 应正常提交，处理器不进入 `mtvec`，`mcause` 不改变。这验证外部请求不能绕过全局中断使能。

第二种场景先执行 `CSRRWI x0, mstatus, 8` 打开 MIE，并保持外部请求有效。当下一条指令到达 MEM 时，TrapControlUnit 同时看到 `valid_mem=1`、`external_interrupt_pending=1`、`global_interrupt_enable=1`，随后产生机器外部中断。

| 检查项 | 期望结果 |
| --- | --- |
| `mcause` | `0x8000_0000_0000_000B`，最高位表示中断，低位 11 表示机器外部中断 |
| `mepc` | 保存当前被中断指令的 PC |
| 当前 MEM 指令 | 按本设计的中断采样边界取消提交 |
| 年轻指令 | 全部冲刷 |
| 新 PC | 跳到 `mtvec=0x100` |
| `mstatus` | 原 MIE 保存到 MPIE，MIE 清零，结果为 `0x80` |

该测试说明顶层端口、TrapControlUnit 的 MIE 门控、CSRFile 的 Trap 状态更新、PC 重定向和副作用屏蔽已经连成一条可运行的外部中断路径。

## 6. 指令地址未对齐测试：补齐 JAL 与条件分支路径

此前已经测试 JALR 未对齐，但顶层 `instruction_misaligned_mem` 实际覆盖 JAL、JALR 和 taken Branch 三个来源。今天在 Trap TB 中新增 B 型和 J 型指令编码函数，并补充三种场景：

| 场景 | 目的和检查 |
| --- | --- |
| `JAL x5, +2` | 目标地址为 `0x2`，不满足 4 字节对齐；检查 cause 0、`mepc=0`、链接寄存器 x5 不修改、年轻指令冲刷 |
| `BEQ x6, x6, +2` | 分支实际成立且目标为 `0x2`；检查 cause 0、`mepc=0`、进入 `mtvec` |
| `BNE x6, x6, +2` | 分支不成立，目标地址不会成为 PC；检查不触发异常、顺序指令正常执行 |

这部分与 LD/SD 未对齐的区别是：LD/SD 检查将要访问的数据地址，分别产生 cause 4 和 cause 6；JAL/JALR/Branch 检查将要采用的下一条指令地址，产生 cause 0。条件分支只有实际 taken 时才会使用分支目标，所以未跳转分支即使编码出的目标未对齐，也不能产生异常。

顶层原有逻辑已经同时判断 `Jump_mem`、`JumpReg_mem`、`Branch_mem && branch_taken_mem` 和相应目标地址，因此本次只增加测试，没有继续修改 RTL。

## 7. 今日最终回归结果

使用 Icarus Verilog 重新编译并运行三组整机测试，结果全部通过：

```text
PASS: trap entry, misaligned control-transfer paths, untaken-branch gating,
      external interrupt gating, precise side-effect suppression, flushing,
      and MRET return passed.

PASS: all 20 instructions, forwarding, stalls, control flushes,
      and two-bit branch prediction passed.

PASS: all six CSR instructions, read-only forms, CSR rd forwarding,
      and CSR operand forwarding passed.
```

编译中只剩原有的 `timescale` 继承提示，以及寄存器堆和数据存储器数组被组合逻辑读取时的敏感列表提示；没有新增端口、位宽、悬空信号或功能仿真错误。

## 8. 例外/中断模块完成情况

### 当前基础设计范围内已经完成

| 模块或功能 | 状态 | 已完成的作用 |
| --- | --- | --- |
| `Control.v` | 已完成 | 识别非法指令、ECALL、MRET 和六条 CSR 指令，产生对应控制信号 |
| `CSRFile.v` | 已完成 | 保存 `mstatus/mtvec/mepc/mcause`，支持软件读写、Trap 现场保存和 MRET 状态恢复 |
| `TrapControlUnit.v` | 已完成 | 对已有同步异常和机器外部中断进行优先级选择，产生 `trap_enter/trap_pc/trap_cause` |
| `CSRForwardingUnit.v` | 已完成 | 解决连续访问同一 CSR 时 ID 读取过时值的问题 |
| ID/EX、EX/MEM、MEM/WB CSR 通路 | 已完成 | 传递 CSR 控制、旧值和新值，在 MEM 写 CSRFile、在 WB 写回旧值 |
| EX/MEM 当前 PC 通路 | 已完成 | 把触发异常指令自身的 PC 送到 MEM，供 `mepc` 保存 |
| 顶层地址异常检测 | 已完成 | 检测 LD、SD、JAL、JALR 和 taken Branch 的地址未对齐 |
| 顶层 Trap/MRET 控制 | 已完成 | PC 重定向、年轻指令冲刷以及 CSR、内存、通用寄存器副作用屏蔽 |
| 外部中断顶层接口 | 已完成 | `external_interrupt_pending` 已成为真实输入，并受 `mstatus.MIE` 控制 |
| `PIPELINED_CPU_TRAP_tb.v` | 已完成当前覆盖 | 覆盖非法指令、ECALL、地址未对齐、MRET、外部中断和精确副作用 |

按照目前项目定义的异常种类和单一机器外部中断需求，基础异常/中断闭环已经完成：

```text
事件检测 → Trap 仲裁 → 保存 mepc/mcause/mstatus
         → 屏蔽错误副作用 → 跳转 mtvec → MRET 返回 mepc
```

### 尚未完成或属于后续扩展的部分

| 后续模块或功能 | 当前状态 | 后续作用 |
| --- | --- | --- |
| CPU 外部的真实中断源或顶层封装 | 未接入 | 目前中断输入由测试平台驱动；上板或接 SoC 时还需由外设或中断控制器连接该端口 |
| 外部异步信号同步与保持/清除协议 | 未实现 | 真实中断若与 CPU 时钟异步，需要同步；处理程序还需与中断源配合清除 pending，避免持续重复进入 |
| `mie/mip` 及多中断源仲裁 | 未实现 | 当前只有 `mstatus.MIE` 和一根机器外部中断请求线，没有软件中断、定时器中断和独立屏蔽位 |
| 更多标准异常 | 未实现 | 尚未覆盖指令、Load、Store 访问故障，断点及其他特权级环境调用等完整特权规范事件 |
| `mtval` 等附加 Trap 信息 | 未实现 | 当前只保存 `mepc` 与 `mcause`，没有保存故障地址或非法指令内容 |
| `mtvec` 向量模式与特权级切换 | 未实现 | 当前按直接入口使用 `mtvec`，没有 vectored 模式和 M/S/U 多特权级委托 |
| 更强的异常/中断验证 | 可继续扩展 | 可增加多个事件同周期的优先级、连续中断、嵌套中断及处理中断期间再次请求等测试 |

这些未完成项不妨碍当前课程范围内的五级流水线 CPU 完成基础异常/中断闭环；如果继续向完整 RISC-V 特权架构、真实 FPGA 外设或高性能处理器扩展，则需要逐项补充。

# 2026/10/12：D-Cache 基础结构与带握手的后端存储器

## 今日修改顺序（总体总结）

```text
确定第一版 Cache 范围与固定几何参数
    → 新建 DCache，定义 CPU 侧和后端侧请求/响应接口
    → 拆分当前 CPU 地址与已锁存请求地址
    → 声明 valid、tag、data 三类 Cache 阵列
    → 新建 DCacheAddress_tb，验证地址拆分和数组结构
    → 新建 CacheBackingMemory，建立 ready/valid 请求—完成协议
    → 用 IDLE、WAIT、RESP 状态机模拟三周期后端访问
    → 修正存储深度、延迟边界和锁存请求使用问题
    → 新建 CacheBackingMemory_tb，验证读写、延迟、锁存和 reset
```

今天开始在现有五级流水线 CPU 之外独立实现 Cache 子系统。第一版范围固定为直接映射、阻塞式、一次只处理一个请求，D-Cache 采用写穿透、写命中更新和写不命中不分配。今天尚未把 D-Cache 接入 `PIPELINED_CPU`，也没有修改原有 `DataMemory`，目的是先把地址组织方式和可变延迟后端协议分别验证清楚，避免以后把 Cache 错误和流水线暂停错误混在一起。

## 1. DCache：建立接口、固定结构和地址拆分

新增 `rtl/Cache/DCache.v`。当前文件已经完成接口、固定参数、Cache 阵列、两组地址拆分和请求保存寄存器的声明；hit、miss、refill、Store 和输出驱动尚未实现。

### 1.1 CPU 侧输入与输出

| 方向 | 信号 | 位宽 | 作用 |
| --- | --- | ---: | --- |
| 输入 | `clk` | 1 | D-Cache 时序逻辑使用的时钟；后续在时钟沿锁存请求、更新状态和写 Cache 阵列 |
| 输入 | `reset` | 1 | 后续复位状态机并清除全部 valid bit，不要求清空 tag 和 data |
| 输入 | `cpu_req_valid` | 1 | CPU MEM 阶段正在提供一个真实的 Load 或 Store 请求 |
| 输入 | `cpu_req_addr` | 64 | Load/Store 的字节地址，第一版只接受 8 字节对齐地址 |
| 输入 | `cpu_req_write` | 1 | `0` 表示 Load，`1` 表示 Store |
| 输入 | `cpu_req_wdata` | 64 | Store 准备写入的数据 |
| 输出 | `cpu_req_ready` | 1 | D-Cache 当前能够接受一个新请求；只有与 `cpu_req_valid` 同时为 1 时请求才被接收 |
| 输出 | `cpu_resp_valid` | 1 | 本次请求已经完成；Load 数据有效或 Store 后端写入已经确认 |
| 输出 | `cpu_resp_rdata` | 64 | Load 返回给 CPU 的 64 位数据，只有 `cpu_resp_valid=1` 时才有意义 |

CPU 请求侧以后采用：

```text
cpu_req_valid && cpu_req_ready → 请求被 D-Cache 接受
cpu_resp_valid                 → 原请求真正完成，流水线可以继续
```

`cpu_req_ready` 只说明 Cache 接受了请求，不说明访存已经结束；miss 或 write-through Store 仍需等待 `cpu_resp_valid`。

### 1.2 后端存储器侧输入与输出

| 方向 | 信号 | 位宽 | 作用 |
| --- | --- | ---: | --- |
| 输入 | `mem_req_ready` | 1 | 后端存储器能够接受 D-Cache 当前提供的请求 |
| 输入 | `mem_resp_valid` | 1 | 后端读数据已经返回，或后端写操作已经完成 |
| 输入 | `mem_resp_rdata` | 64 | 后端一次返回的 64 位读数据 |
| 输出 | `mem_req_valid` | 1 | D-Cache 正在向后端提供一个有效请求 |
| 输出 | `mem_req_write` | 1 | `0` 表示读取一个 64 位 word，`1` 表示写入一个 64 位 word |
| 输出 | `mem_req_addr` | 64 | 送往后端的字节地址，必须按 8 字节对齐 |
| 输出 | `mem_req_wdata` | 64 | 写穿透 Store 送往后端的数据 |

后端请求以后同样只在 `mem_req_valid && mem_req_ready` 时被接受。一次 32B Cache Line 填充不会要求后端一次返回 256 位，而是由 D-Cache 依次发出四次 64 位读请求。

### 1.3 固定 Cache 参数和阵列

第一版 D-Cache 使用以下固定参数：

| 参数 | 数值 | 含义 |
| --- | ---: | --- |
| `ADDR_WIDTH` | 64 | CPU 和后端使用 64 位字节地址 |
| `BACKEND_DATA_WIDTH` | 64 | 后端每次传输一个 64 位 word |
| `CACHE_LINES` | 8 | 直接映射 Cache 共有 8 个 Line 槽位 |
| `LINE_BYTES` | 32 | 每个 Cache Line 包含 32 Byte |
| `BACKEND_WORD_BYTES` | 8 | 一个 64 位 word 包含 8 Byte |
| `WORDS_PER_LINE` | 4 | 每行包含 4 个 64 位 word |
| `BYTE_OFFSET_BITS` | 3 | 选择 64 位 word 内的字节 |
| `WORD_OFFSET_BITS` | 2 | 选择 Cache Line 内的 4 个 word |
| `BLOCK_OFFSET_BITS` | 5 | 32B 行内偏移总位数 |
| `INDEX_BITS` | 3 | 选择 8 个 Cache Line |
| `TAG_WIDTH` | 56 | 地址高 56 位用于 tag 比较 |
| `CACHE_CAPACITY_BYTES` | 256 | `8 × 32B` 的总数据容量 |

阵列结构为：

| 阵列 | 结构 | 作用 |
| --- | --- | --- |
| `valid_array` | 8 个 valid bit | 表明对应槽位是否保存有效 Cache Line；复位只需清除此阵列 |
| `tag_array[0:7]` | 每项 56 位 | 保存每个槽位当前对应的高位地址 tag |
| `data_array[0:7][0:3]` | 8 行、每行 4 个 64 位 word | 保存实际 Cache Line 数据 |

今天曾发现并修正阵列维度问题：tag 必须是 8 个 56 位元素，data 必须是 `8 × 4` 个 64 位元素，而不是普通的 8 位向量或 4 个 8 位元素。

### 1.4 地址拆分逻辑

32B Cache Line 需要 5 位行内偏移，8 个直接映射槽位需要 3 位 index，因此地址拆分为：

```text
63                        8 7       5 4       3 2       0
+--------------------------+---------+---------+---------+
|           Tag            |  Index  | WordOff | ByteOff |
+--------------------------+---------+---------+---------+
         56 bit               3 bit     2 bit     3 bit
```

当前 CPU 请求地址产生：

| 信号 | 地址位段或计算 | 作用 |
| --- | --- | --- |
| `cpu_addr_tag` | `cpu_req_addr[63:8]` | 与 `tag_array[cpu_addr_index]` 比较 |
| `cpu_addr_index` | `cpu_req_addr[7:5]` | 选择 8 个直接映射槽位之一 |
| `cpu_addr_word_offset` | `cpu_req_addr[4:3]` | 选择一行中的 4 个 64 位 word 之一 |
| `cpu_addr_byte_offset` | `cpu_req_addr[2:0]` | 检查 64 位 Load/Store 是否按 8 字节对齐 |
| `cpu_addr_aligned` | byte offset 是否为 0 | 表示当前请求满足第一版 D-Cache 对齐要求 |
| `cpu_line_base` | 请求地址低 5 位清零 | 得到后端整行填充的起始地址 |

D-Cache 还声明了 `req_addr_reg`、`req_write_reg`、`req_wdata_reg`，用于以后在请求真正被接受时保存完整事务。由 `req_addr_reg` 再组合产生 `req_tag`、`req_index`、`req_word_offset`、`req_byte_offset`、`req_addr_aligned` 和 `req_line_base`。这样进入 miss 或 Store 多周期处理后，Cache 使用已经锁存的请求，不继续依赖可能变化的 CPU 输入。

当前地址与锁存地址保留两套拆分的原因是：IDLE 状态以后可以直接用当前 CPU 地址进行组合 hit 判断，而 miss/refill 阶段必须使用锁存地址维持事务身份。

例如：

- `0x38` 的 line base 为 `0x20`、word offset 为 3、index 为 1、tag 为 0；
- `0x138` 的 line base 为 `0x120`、word offset 为 3、index 仍为 1、tag 为 1；
- 两者拥有相同 index 和不同 tag，因此会在直接映射 Cache 中发生替换。

## 2. DCacheAddress_tb：验证地址组织和数组边界

新增 `tb/DCacheAddress_tb.v`。该测试平台没有模块端口，直接驱动 D-Cache 的 CPU 地址输入，并在当前尚未实现请求锁存时临时检查内部地址拆分信号。

测试内容包括：

| 测试内容 | 验证目标 |
| --- | --- |
| `0x00`、`0x08`、`0x18` | 同一 Cache Line 内的不同 word offset |
| `0x20`、`0x38` | index 从 0 变为 1，并正确保持同一 line base |
| `0xF8`、`0x100` | index 从 7 回绕到 0，同时 tag 增加 |
| `0x38`、`0x138` | 相同 index、相同 word offset、不同 tag |
| 高位非零地址 | 验证 56 位 tag 没有截断 |
| `0x39` | 验证 byte offset 和未对齐判断 |
| 数组首尾元素 | 验证 valid 为 8 位、tag 有 8 项、data 的边界为 `[0:7][0:3]` 且每项 64 位 |
| 锁存地址拆分 | 验证 `req_addr_reg` 派生字段与当前地址采用相同规则 |

测试结果为：

```text
PASS: DCache address decomposition and array geometry passed 13 cases.
```

该 TB 当前会直接给内部 `req_addr_reg` 和数组赋值，只用于第一阶段的结构测试。以后实现 D-Cache 请求握手和状态机后，应改为只通过模块公开接口驱动事务。

## 3. CacheBackingMemory：建立可变完成时间的后端接口

新增 `rtl/memory/CacheBackingMemory.v`。该模块不替换原 `DataMemory`，而是作为 D-Cache 独立测试使用的后端存储器模型。它一次只接受一个 64 位读或写请求，并在请求接受三个周期后产生完成响应。

### 3.1 输入与输出

| 方向 | 信号 | 位宽 | 作用 |
| --- | --- | ---: | --- |
| 输入 | `clk` | 1 | 锁存请求、更新延迟计数和提交存储器操作 |
| 输入 | `reset` | 1 | 同步取消未完成事务并把控制状态恢复为 IDLE，不清除 memory 内容 |
| 输入 | `req_valid` | 1 | 上游 Cache 正在提供一个后端请求 |
| 输入 | `req_write` | 1 | `0` 表示读，`1` 表示写 |
| 输入 | `req_addr` | 64 | 8 字节对齐的后端字节地址 |
| 输入 | `req_wdata` | 64 | 写请求的数据 |
| 输出 | `req_ready` | 1 | 后端处于 IDLE，可以接受请求 |
| 输出 | `resp_valid` | 1 | 读数据有效或写操作已经完成，只在 RESP 状态保持一个周期 |
| 输出 | `resp_rdata` | 64 | 读请求的返回数据；写响应和非法请求响应置为 0 |

请求接受条件是：

```text
req_fire = req_valid && req_ready
```

只有 `req_fire` 成立的时钟沿才锁存 `req_addr`、`req_write` 和 `req_wdata`。之后即使上游修改输入，后端仍然使用 `pending_addr`、`pending_write` 和 `pending_wdata` 完成原请求。

### 3.2 存储阵列和地址范围

后端包含 256 个 64 位 word：

```text
memory[0:255]，总容量 256 × 8B = 2048B
```

合法地址范围为 `0x000～0x7FF`，word 下标由锁存地址的 `[10:3]` 产生。地址低 3 位必须为 0。未对齐或越界请求仍会在规定延迟后产生响应，但读数据为 0、写操作不修改 memory，从而避免高地址静默别名到低地址。

最初曾把数组写成 `[0:256]`，这会产生 257 个元素；今天已修正为 `[0:255]`。

### 3.3 IDLE、WAIT、RESP 状态机

状态输出关系为：

| 状态 | `req_ready` | `resp_valid` | 作用 |
| --- | ---: | ---: | --- |
| IDLE | 1 | 0 | 接受一个新请求并锁存请求内容 |
| WAIT | 0 | 0 | 拒绝新请求，递减延迟计数器 |
| RESP | 0 | 1 | 对上游报告读返回有效或写操作完成 |

整体运行顺序为：

```text
IDLE 中 req_valid && req_ready
    → 锁存地址、读写类型和写数据，delay_count 置 3
    → 进入 WAIT，等待期间 req_ready 保持 0
    → delay_count 大于 1 时每拍减 1
    → delay_count 等于 1 时执行读或写并进入 RESP
    → RESP 维持一个周期，resp_valid=1
    → 下一时钟沿回到 IDLE
```

三周期时间关系为：

| 时钟沿 | 行为 |
| --- | --- |
| E0 | 请求被接受，计数器装入 3 |
| E1 | 计数器从 3 减到 2 |
| E2 | 计数器从 2 减到 1 |
| E3 | 执行访问、进入 RESP，响应有效 |
| E4 | 返回 IDLE，可以接收下一请求 |

实现过程中曾使用“计数器大于等于 1 时递减、等于 0 时完成”，这会让响应出现在 E4，实际延迟为四周期。今天已改为计数等于 1 时完成，符合三周期定义。

读请求在 E3 使用 `pending_addr` 对应的 word 更新 `resp_rdata`。写请求在 E3 使用 `pending_write` 和 `pending_wdata` 只修改一次 memory，并把 `resp_rdata` 置 0。此前写类型判断曾误用实时输入 `req_write`，如果上游在忙期间改变该信号，原 Store 可能被误当作 Load；今天已改为使用锁存的 `pending_write`。

reset 只复位状态、pending 请求、延迟计数和响应数据，不清除 memory。如果 reset 在 WAIT 中到来，未完成事务被取消，尚未提交的 Store 不得修改 memory，也不会在 reset 释放后继续产生延迟响应。

## 4. CacheBackingMemory_tb：验证请求—完成协议

新增 `tb/CacheBackingMemory_tb.v`，对后端存储器运行独立自检查。测试平台通过模块公开接口发起事务，并直接初始化和观察后端 memory 以检查实际副作用。

测试覆盖如下：

| 测试内容 | 验证目标 |
| --- | --- |
| reset 后接口状态 | 后端处于 IDLE，`req_ready=1`、`resp_valid=0` |
| reset 保留 memory | 控制复位不会清除主存内容 |
| 精确三周期读响应 | E0 接受请求，E1/E2 无响应，E3 返回数据 |
| 请求字段锁存 | 忙期间改变实时地址、读写类型和写数据不影响原请求 |
| 忙期间第二个请求 | WAIT 中 `req_ready=0`，未握手请求不能产生读写副作用 |
| Store 提交时刻 | WAIT 期间 memory 不变，只在响应周期写入一次 |
| 写后读 | 后续 Load 能读到已经完成的 Store 数据 |
| 未对齐请求 | 产生零响应但不修改 memory |
| 越界请求 | 不允许高地址别名到 `memory[0]` |
| WAIT 中 reset | 取消 pending Store，不修改 memory，也不产生迟到响应 |
| RESP 单周期 | 响应后一拍回到 IDLE，不重复产生完成信号 |

测试结果为：

```text
PASS: CacheBackingMemory protocol passed 35 checks.
```

本机使用的 Icarus Verilog 12.0 开发版在默认合并编译单元模式下处理动态 memory 时会在 VVP 代码生成阶段异常退出。使用 `-u` 分离编译单元后能够正常生成并运行：

```text
iverilog -u -g2012 -s CacheBackingMemory_tb \
  -o tb/CacheBackingMemory_tb.out \
  rtl/memory/CacheBackingMemory.v \
  tb/CacheBackingMemory_tb.v

vvp tb/CacheBackingMemory_tb.out
```

诊断期间产生的临时最小测试和 `.out` 仿真产物已经清理，工程中只保留正式 RTL 与正式 TB。

## 5. 今日结束时的完成状态与下一步

| 模块或功能 | 当前状态 |
| --- | --- |
| D-Cache CPU/后端接口 | 已定义，输出尚未驱动 |
| D-Cache 固定参数和三类阵列 | 已完成并通过结构测试 |
| 当前地址与锁存地址拆分 | 已完成并通过 13 项测试 |
| D-Cache 请求锁存寄存器 | 已声明，尚未在握手时钟沿赋值 |
| D-Cache valid 复位 | 尚未实现 |
| D-Cache hit/miss 判断 | 尚未实现 |
| D-Cache Load miss/refill | 尚未实现 |
| D-Cache Store 写穿透和 no-write-allocate | 尚未实现 |
| CacheBackingMemory 请求锁存和三周期状态机 | 已完成 |
| CacheBackingMemory 读写、非法地址和 reset 行为 | 已通过 35 项测试 |
| D-Cache 与后端连接 | 尚未进行 |
| D-Cache 与 CPU MEM 阶段连接 | 尚未进行 |

下一步先完成 D-Cache 的只读路径：复位清除 valid、IDLE 中组合判断 Load hit、Load miss 时锁存请求、依次向后端读取四个 64 位 word、整行到齐后写 tag 并置 valid、最后根据原 word offset 返回数据。等 Load hit/miss/refill 独立测试通过后，再加入写穿透 Store 路径，最后才处理流水线暂停和 Trap 的组合优先级。

# 2026/10/13：D-Cache Load 命中接口与 Load miss 请求保存框架

## 今日修改顺序（总体逻辑链）

```text
复用昨日完成的地址拆分、valid/tag 比较和命中数据选择
    → 将内部 Load hit 结果接到 CPU 侧 ready/response 正式接口
    → 新建 DCacheHitInterface_tb，验证命中请求能够在同周期完成
    → 区分“Cache 可以接收请求”和“CPU 确实发出了请求”
    → 用 valid && ready 定义一次真实的请求接收事件 cpu_req_fire
    → 定义 IDLE、REFILL_REQ、REFILL_WAIT、RESP 四个阻塞式状态
    → 将 cpu_req_ready 从“只有 hit 才有效”扩展为“IDLE 中可接收对齐 Load”
    → Load miss 被接收时锁存地址、读写类型和写数据
    → 进入 REFILL_REQ 后关闭 ready，建立一次只能处理一个请求的约束
    → 用 STATE_IDLE 限制组合命中响应，防止忙碌期间误用实时 CPU 输入
    → 复位状态机和请求寄存器，为后续后端读请求与整行填充做好准备
```

今天完成的内容把 D-Cache 从“只能在内部判断某地址是否命中”推进到了“能够通过正式接口完成 Load hit，并能在 Load miss 时取得一次事务的所有权”。整个只读访问路径现在形成了下面这条尚未闭环的链路：

```text
CPU 提供 Load 请求
    → IDLE 状态检查地址对齐、valid 和 tag
        → Hit：同周期接受请求、返回所选 word，继续保持 IDLE
        → Miss：接受请求、锁存事务、进入 REFILL_REQ、停止接收新请求
              → 后端读请求、四个 word 填充和最终响应尚待后续实现
```

这一步服务于整个 Cache 设计中的“事务边界”。未来后端存储器可能需要多个周期才能返回数据，CPU 输入在这段时间内也可能变化，因此 Cache 必须先明确请求在哪个周期被接受，再把该请求保存下来，后续状态只能围绕这份锁存内容运行。

## 1. 将内部 Load hit 判断接到 CPU 正式接口

### 1.1 这一步为整体设计服务的目的

昨日完成的 `cpu_line_hit`、`cpu_load_hit` 和 `cpu_hit_rdata` 只属于 D-Cache 内部判断结果。CPU 不能直接依赖这些内部信号，它需要通过模块端口知道请求是否被接受、访问是否完成以及 Load 返回了什么数据。

今天首先打通了最短的成功路径：

```text
CPU 当前地址拆分
    → index 选择 Cache Line
    → valid && tag 相等得到 line hit
    → word offset 选择 64 位数据
    → CPU 正式响应接口在同一组合周期返回结果
```

这条路径以后仍然是 D-Cache 的快速命中路径。后续加入 miss 状态机时，只是在其旁边增加慢速填充路径，不需要改变地址拆分和命中数据选择的基本原理。

### 1.2 本步使用的输入与输出

| 方向 | 信号 | 作用 |
| --- | --- | --- |
| 输入 | `reset` | 复位期间屏蔽所有 CPU 侧接收和响应活动 |
| 输入 | `cpu_req_valid` | 表示 CPU 当前确实提供了一个访存请求 |
| 输入 | `cpu_req_addr` | 提供 tag、index、word offset 和对齐判断所需的地址 |
| 输入 | `cpu_req_write` | 区分 Load 与 Store；本阶段只允许 Load 走该路径 |
| 内部 | `cpu_line_hit` | 表示选中的 Cache Line 有效且 tag 相等 |
| 内部 | `cpu_load_hit` | 表示当前存在有效、对齐的 Load 请求并且 line hit |
| 内部 | `cpu_hit_rdata` | 根据当前 word offset 从命中 Cache Line 中选出的 64 位数据 |
| 输出 | `cpu_req_ready` | 表示当前 Cache 是否有能力接受该请求 |
| 输出 | `cpu_resp_valid` | 表示当前请求已经完成，返回结果可以被 CPU 使用 |
| 输出 | `cpu_resp_rdata` | `cpu_resp_valid=1` 时返回命中的 64 位数据，否则输出 0 |

在最初的“只支持 hit”阶段，接口行为为：

```text
对齐 Load hit：ready=1，resp_valid=1，resp_rdata=命中数据
Load miss：    ready=0，resp_valid=0
Store：        ready=0，resp_valid=0
未对齐 Load： ready=0，resp_valid=0
reset：        ready=0，resp_valid=0
```

这里的 `resp_valid` 表示完成，而不是仅仅表示 Cache 看到了请求。Load hit 没有额外等待，所以请求接受与请求完成可以发生在同一个周期。

## 2. DCacheHitInterface_tb：验证同周期 Load hit 接口

### 2.1 这一步为整体设计服务的目的

地址拆分 TB 只能证明地址被正确分段，Lookup TB 只能证明内部 hit 判断和 word 选择正确。本次新增的 `tb/DCacheHitInterface_tb.v` 继续向模块边界推进一层，验证 CPU 实际可见的三个输出是否与内部命中结果一致。

这使验证链形成：

```text
地址位段正确
    → valid/tag 命中判断正确
    → word 数据选择正确
    → CPU 侧 ready/response 接口正确
```

### 2.2 测试内容与阶段性结果

测试覆盖：

| 场景 | 当时验证的行为 |
| --- | --- |
| 对齐 Load hit | `ready=1`、`resp_valid=1`，返回正确 word |
| `cpu_req_valid=0` | 可以显示接收能力，但不得产生响应 |
| Load miss | 在当时的 hit-only 阶段不接受，也不产生响应 |
| Store hit | 暂不接受 Store，不产生响应 |
| 未对齐 Load | 不接受请求，不产生响应 |
| reset | 立即屏蔽 ready、response 和返回数据 |

阶段性测试结果为：

```text
PASS: DCache CPU-side Load-hit interface passed 6 checks.
```

该结果证明了“只支持命中”的接口版本。今天后半段加入 miss 请求锁存能力后，IDLE 状态下的 Load miss 已经应当被接受，因此该 TB 中 Load miss 的旧期望需要下一次改为 `ready=1、resp_valid=0`，并补充上升沿后的状态和锁存内容检查。上述 6 项通过结果不能替代新状态机版本的完整测试。

## 3. 建立 ready、valid、fire 和 response 的事务语义

### 3.1 这一步为整体设计服务的目的

固定单周期 DataMemory 中，请求和完成几乎发生在同一时刻，容易把“模块接收了请求”和“模块完成了请求”当成一件事。Cache miss 引入可变延迟后，两者必须拆开：

```text
cpu_req_valid && cpu_req_ready → Cache 在本周期接受请求
cpu_resp_valid                 → 被接受的请求已经真正完成
```

这套关系将来也是流水线暂停逻辑的依据。CPU 不能把 `cpu_req_ready` 当成访存完成信号；miss 被接受以后，MEM 阶段仍需等待 `cpu_resp_valid` 才能让 Load 进入 WB。

### 3.2 内部握手信号

今天增加了：

| 信号 | 定义或含义 | 服务的整体逻辑 |
| --- | --- | --- |
| `cpu_req_fire` | `cpu_req_valid && cpu_req_ready` | 标记一个 CPU 请求真正被 D-Cache 接受的时钟周期 |
| `cpu_load_miss_fire` | `cpu_req_fire && !cpu_line_hit` | 标记一个被正式接受的 Load miss，用来触发锁存和状态转换 |

必须使用 `fire` 触发状态转换，不能只使用 `ready && !hit`。`ready` 只表示 Cache 有能力接收；当 `cpu_req_valid=0` 时，CPU 没有提供真实请求，即使当前地址碰巧 miss，也不能锁存地址或进入 refill 状态。

例如：

```text
cpu_req_valid = 0
cpu_req_ready = 1
cpu_line_hit  = 0
```

此时 `cpu_req_fire=0`，所以 `cpu_load_miss_fire` 必须为 0，状态继续保持 IDLE。

## 4. 扩展 cpu_req_ready：允许 IDLE 接受 Load miss

### 4.1 这一步为整体设计服务的目的

命中接口阶段只有 hit 能被接受，因为 Cache 当时没有地方保存 miss。请求锁存寄存器和状态机建立后，Cache 已经具备取得 miss 事务所有权的条件，因此 `cpu_req_ready` 不再依赖 `cpu_line_hit`。

当前 ready 条件为：

```text
非 reset
&& 请求不是 Store
&& 地址按 8 字节对齐
&& state == STATE_IDLE
```

因此当前接口语义变为：

| 场景 | `cpu_req_ready` | `cpu_resp_valid` | 含义 |
| --- | ---: | ---: | --- |
| IDLE 中对齐 Load hit | 1 | 1 | 同周期接受并完成 |
| IDLE 中对齐 Load miss | 1 | 0 | 本周期接受，但需要后续多个周期处理 |
| REFILL 状态 | 0 | 0 | 已有未完成请求，不接受第二个请求 |
| Store | 0 | 0 | Store 路径尚未实现 |
| 未对齐 Load | 0 | 0 | 交由 CPU 的地址未对齐异常逻辑处理 |
| reset | 0 | 0 | 不接收请求，也不产生响应 |

这一修改正式建立了阻塞式 Cache 的入口：空闲时可以接收一个 hit 或 miss；一旦 miss 被接受，Cache 变为忙碌，直到原事务完成前都不接收第二个请求。

## 5. 四状态阻塞式 Load refill 框架

### 5.1 这一步为整体设计服务的目的

后端存储器使用独立的 ready/valid 协议，而且一次只能返回一个 64 位 word；一条 32B Cache Line 需要四次后端读取。因此 D-Cache 必须记住当前处于“准备发请求”“等待返回”还是“向 CPU 完成响应”的哪一阶段。

今天定义了四个状态：

| 状态 | 在完整设计中的作用 | 今日实现程度 |
| --- | --- | --- |
| `STATE_IDLE` | 检查新的 CPU 请求；hit 同周期返回，miss 锁存后离开 | 已实现 |
| `STATE_REFILL_REQ` | 向后端提供当前 refill word 的读请求，等待 `mem_req_ready` | 只定义并能进入，后端输出尚未驱动 |
| `STATE_REFILL_WAIT` | 后端已接受一次读请求，等待 `mem_resp_valid` 和 64 位数据 | 已定义，尚未进入 |
| `STATE_RESP` | 四个 word 全部填充后，按原 word offset 向 CPU返回数据 | 已定义，尚未进入 |

今日实际状态转换为：

```text
reset → STATE_IDLE

STATE_IDLE：
    Load hit       → 保持 STATE_IDLE
    Load miss fire → 锁存请求，进入 STATE_REFILL_REQ

STATE_REFILL_REQ：
    暂时保持 STATE_REFILL_REQ，等待下一次实现后端请求逻辑

非法或尚未实现的状态：
    default → STATE_IDLE
```

当前 miss 后停在 `STATE_REFILL_REQ` 是阶段性设计结果，不代表 refill 已经完成。这样可以先独立验证“请求是否只接收一次、是否正确保存、忙碌期间是否拒绝新请求”，再增加后端的四次读事务。

## 6. 锁存原始 miss 请求并切断对实时 CPU 输入的依赖

### 6.1 这一步为整体设计服务的目的

Load miss 可能持续多个周期。请求接受以后，CPU 端的 `cpu_req_addr`、`cpu_req_write` 和 `cpu_req_wdata` 不应继续决定正在处理的事务，否则 CPU 一旦改变输入，Cache 就可能填充错误地址或返回错误 word。

因此在 `cpu_load_miss_fire` 成立的上升沿锁存：

| 源输入 | 锁存寄存器 | 后续用途 |
| --- | --- | --- |
| `cpu_req_addr` | `req_addr_reg` | 保存原始 Load 地址，决定 refill 行地址、替换 index、tag 和最终返回 word |
| `cpu_req_write` | `req_write_reg` | 保存事务类型；当前锁存值为 Load，后续扩展 Store 时复用 |
| `cpu_req_wdata` | `req_wdata_reg` | 保存 Store 数据；当前 Load 路径暂时不用，为后续写穿透路径预留 |

锁存地址继续拆分为：

| 信号 | 后续服务对象 |
| --- | --- |
| `req_tag` | refill 完成时写入 `tag_array[req_index]` |
| `req_index` | 选择需要被填充或替换的 Cache Line |
| `req_word_offset` | refill 完成后选择原始 Load 真正需要的 word |
| `req_line_base` | 生成四个后端地址：基地址、基地址+8、+16、+24 |

状态进入 `STATE_REFILL_REQ` 后，`cpu_req_ready=0`，因此 CPU 即使继续保持 valid 或提供新地址，也不会产生第二次 `cpu_req_fire`，锁存寄存器不会被覆盖。这一机制实现了第一版阻塞式 Cache 的“一次只能处理一个未完成访问”。

复位时同时将状态和三个请求寄存器清零，使仿真波形确定，并保证 reset 取消尚未继续执行的 miss 控制流程。

## 7. 用状态限制组合命中响应

### 7.1 这一步为整体设计服务的目的

`cpu_line_hit` 和 `cpu_hit_rdata` 始终由实时 `cpu_req_addr` 组合产生。进入 refill 状态以后，这些信号仍可能随着 CPU 输入变化。若 `cpu_resp_valid` 只依赖实时 `cpu_load_hit`，忙碌期间出现另一个命中地址时就可能错误产生第二个响应。

今天在 `cpu_resp_valid` 中增加 `state == STATE_IDLE` 条件：

```text
只有非 reset、IDLE 状态且当前 Load hit 时，组合命中响应才有效
```

这样两套地址路径的职责明确分开：

```text
STATE_IDLE：使用 cpu_req_addr 进行快速组合查找
REFILL/RESP：使用 req_addr_reg 及其派生字段维持原事务身份
```

这项限制为以后实现正确的 refill 返回和流水线暂停提供了基础，保证一个未完成事务存在时不会被新的实时 CPU 输入干扰。

## 8. 今日验证结果与当前验证边界

### 8.1 已完成的验证

| 验证项 | 结果 |
| --- | --- |
| 原地址拆分和数组结构测试 | 此前通过 13 项检查 |
| 原 valid/tag/Load-hit Lookup 测试 | 此前通过 12 项检查 |
| 今日初始 hit-only CPU 接口测试 | 通过 6 项检查 |
| 当前 RTL 语法编译 | 通过，没有隐式连线、端口或位宽警告 |

`cpu_req_fire` 和 `cpu_load_miss_fire` 均已显式声明，组合赋值、状态转换条件和声明名称保持一致。这样可以避免 Verilog 自动创建隐式 wire，并使以后启用 ``default_nettype none`` 时仍能正确编译。

状态机版本尚未进行新的专项动态测试。下一次需要更新 `DCacheHitInterface_tb.v` 中 Load miss 的 ready 期望，并增加以下检查：

1. `cpu_req_valid=0` 时，即使地址 miss 也不得进入 `STATE_REFILL_REQ`；
2. Load miss 只在 `cpu_req_valid && cpu_req_ready` 的上升沿锁存；
3. 锁存后改变实时 CPU 地址，不得改变 `req_addr_reg` 及其派生字段；
4. `STATE_REFILL_REQ` 中 `cpu_req_ready=0`、`cpu_resp_valid=0`；
5. 忙碌期间第二个请求不得覆盖原请求；
6. reset 能取消当前 miss 控制状态并返回 `STATE_IDLE`。

## 9. 今日结束时的完成状态与后续衔接

| 模块或功能 | 当前状态 | 它在整体链路中的位置 |
| --- | --- | --- |
| 地址拆分与 Cache 阵列结构 | 已完成并测试 | 建立 Cache 的数据组织基础 |
| valid/tag 命中判断 | 已完成并测试 | 决定当前地址是否可走快速命中路径 |
| Load 命中 word 选择 | 已完成并测试 | 从 32B Cache Line 中取出 CPU 需要的 64 位数据 |
| CPU 侧 Load-hit 正式接口 | 已完成阶段性测试 | 让 CPU 能通过 ready/response 接收命中结果 |
| `cpu_req_fire` 请求接受事件 | 已实现 | 将“可以接收”和“确实接收”分开 |
| Load miss 请求锁存 | 主体逻辑与信号声明已完成，待专项测试 | 保存多周期事务身份 |
| 阻塞状态机入口 | 可由 IDLE 进入 REFILL_REQ | 建立一次只有一个未完成访问的控制约束 |
| 后端读请求 | 尚未实现 | 从主存依次取得 Cache Line 的四个 word |
| refill word 计数 | 尚未实现 | 记录当前正在读取一行中的第几个 word |
| data/tag/valid 填充 | 尚未实现 | 把四次后端返回组成新的有效 Cache Line |
| miss 最终响应 | 尚未实现 | 根据原始 word offset 向 CPU 完成 Load |
| Store 写穿透路径 | 尚未实现 | 完成写命中更新和写不命中不分配策略 |
| D-Cache 接入 CPU MEM 阶段 | 尚未进行 | 用请求/完成关系控制整条流水线暂停和恢复 |

下一次应先完成一个很小的闭环：更新并运行 CPU 接口/请求锁存专项 TB。确认 miss 只接收一次、锁存内容稳定、忙碌期间拒绝第二个请求后，再开始驱动 `mem_req_valid`、`mem_req_addr` 和 `mem_req_write`，实现 `STATE_REFILL_REQ → STATE_REFILL_WAIT` 的第一笔后端读握手。

# 2026/10/14：D-Cache Load miss 整行填充、提交与响应闭环

## 今日修改顺序（从请求锁存到完整 Load miss 闭环）

```text
更新 CPU 接口/请求锁存专项测试，验证昨天建立的 miss 事务边界
    → 在 REFILL_REQ 中驱动第一笔后端读请求
    → 用 mem_req_valid && mem_req_ready 确认后端真正接受请求
    → 进入 REFILL_WAIT，等待后端返回64位数据
    → 定义 mem_resp_fire，只在正确状态消费后端响应
    → 将第一份返回数据写入锁存 index 的 word 0
    → 增加两位 refill_word_index，生成 +0/+8/+16/+24 四个地址
    → 在 REFILL_REQ 与 REFILL_WAIT 之间循环，依次填充四个 word
    → 最后一个 word 到达后进入 STATE_RESP
    → 合并 valid_array 的复位与置位，消除多时序块驱动风险
    → 在 STATE_RESP 返回原始 Load 需要的 word，并提交 tag/valid
    → 返回 IDLE，使第二次相同访问直接命中
    → 验证同 index、不同 tag 的直接映射替换
    → 运行六组 D-Cache 回归，共通过74项检查
```

今天把此前分散完成的地址拆分、命中判断、CPU 请求锁存和后端存储器协议连接成了第一条完整的 D-Cache Load 通路。当前 Load 行为已经形成闭环：

```text
CPU发出对齐Load
    → IDLE中检查valid和tag
        → Hit：同周期返回所选64位word
        → Miss：锁存原始请求并阻塞新请求
              → 从Line基地址开始发出四笔后端读请求
              → 每笔请求等待对应响应后写入data_array
              → 四个word全部到齐后进入STATE_RESP
              → 返回原始Load所需word
              → 写入新tag、valid置1并回到IDLE
              → 后续相同地址直接Hit
```

这一闭环使 D-Cache 第一次真正具备了“请求接受时间与完成时间不同”的模块行为，为以后接入 CPU MEM 阶段、冻结流水线并等待 `cpu_resp_valid` 打下了基础。

## 1. 更新请求锁存测试：确认 miss 事务边界

### 1.1 这一步为整体设计服务的目的

昨天已经写出 `cpu_req_fire`、`cpu_load_miss_fire`、请求寄存器和 `IDLE → REFILL_REQ` 转换，但尚未进行完整动态验证。今天先更新 `DCacheHitInterface_tb.v`，确认 Cache 能够可靠取得一次 miss 事务的所有权，避免后续后端访问建立在错误的请求锁存基础上。

这一阶段补齐的整体链路是：

```text
CPU提供请求
    → valid && ready成立
    → Cache只接收一次
    → 锁存地址、读写类型和写数据
    → 进入忙碌状态
    → CPU实时输入不再影响当前事务
```

### 1.2 涉及的输入、输出和内部状态

| 类型 | 信号 | 本阶段作用 |
| --- | --- | --- |
| CPU输入 | `cpu_req_valid` | 表示 CPU 当前确实提供有效请求 |
| CPU输入 | `cpu_req_addr` | 在请求握手时锁存为 `req_addr_reg` |
| CPU输入 | `cpu_req_write` | 当前 Load 路径要求为0，仍锁存供未来 Store 复用 |
| CPU输入 | `cpu_req_wdata` | 当前 Load 不使用，仍随请求保存 |
| Cache输出 | `cpu_req_ready` | IDLE 中允许对齐 Load 被接受 |
| 内部事件 | `cpu_req_fire` | `cpu_req_valid && cpu_req_ready`，表示请求真正被接受 |
| 内部事件 | `cpu_load_miss_fire` | 被接受的请求没有命中，用于触发锁存和状态转换 |
| 请求寄存器 | `req_addr_reg/req_write_reg/req_wdata_reg` | 保存整个多周期事务的身份和内容 |

测试重点包括：

- `cpu_req_valid=0` 时，即使当前地址 miss 也不能进入 refill；
- Load miss 只在 `cpu_req_fire` 成立的上升沿锁存；
- 进入 `STATE_REFILL_REQ` 后 `cpu_req_ready=0`；
- CPU 改变实时地址不会覆盖锁存请求；
- 忙碌期间第二个请求不能被接受；
- reset 能取消未完成事务并恢复 IDLE。

测试结果：

```text
PASS: DCache CPU interface and Load-miss capture passed 15 checks.
```

这证明了阻塞式 Cache 的第一条控制约束：一次只拥有一个未完成请求。

## 2. STATE_REFILL_REQ：发出并保持第一笔后端读请求

### 2.1 这一步为整体设计服务的目的

请求被锁存后，D-Cache 必须把 CPU 的一次 Cache Line miss 转换为后端能够处理的64位读事务。今天首先实现 `STATE_REFILL_REQ` 的请求输出和握手，使 Cache 能够在后端暂时忙碌时稳定保持请求，并且只在后端真正接受后进入等待状态。

这一阶段连接了两个此前独立完成的模块：

```text
DCache中锁存的Load miss
    → DCache后端请求接口
    → CacheBackingMemory ready/valid接口
```

### 2.2 后端请求接口

| 方向 | 信号 | 当前 Load refill 中的含义 |
| --- | --- | --- |
| D-Cache输出 | `mem_req_valid` | `STATE_REFILL_REQ`中持续为1，表示请求有效 |
| 后端输入 | `mem_req_ready` | 后端能够在当前时钟沿接受请求 |
| D-Cache输出 | `mem_req_write` | 固定为0，表示后端读 |
| D-Cache输出 | `mem_req_addr` | 第一阶段为锁存请求对应的 `req_line_base` |
| D-Cache输出 | `mem_req_wdata` | 读请求不使用，固定为0 |
| 内部事件 | `mem_req_fire` | `mem_req_valid && mem_req_ready`，表示请求真正交给后端 |

状态逻辑为：

```text
STATE_REFILL_REQ：
    mem_req_fire=0 → 保持STATE_REFILL_REQ，请求和地址保持稳定
    mem_req_fire=1 → 进入STATE_REFILL_WAIT，停止重复发送该请求
```

`mem_req_valid`不能依赖 `mem_req_ready`。如果后端不 ready，valid 和地址必须持续保持；这在电路上相当于状态译码器持续开启输出，而请求地址来自稳定的 `req_addr_reg`。

后端地址使用 `req_line_base`，而不是实时的 `cpu_line_base`。`req_line_base={req_addr_reg[63:5],5'b0}` 将32字节 Cache Line 内的低5位偏移清零，例如原始地址 `0x138` 对应 Line 基地址 `0x120`。

新增 `DCacheBackendRequest_tb.v`，验证 ready 拉低期间请求保持、CPU 地址变化不影响后端地址、握手后只接收一次以及 reset 取消事务。结果为：

```text
PASS: DCache first backend refill request passed 13 checks.
```

## 3. STATE_REFILL_WAIT：消费第一份后端响应

### 3.1 这一步为整体设计服务的目的

后端接受请求只表示存储访问已经开始，数据尚未返回。D-Cache 必须在独立的等待阶段识别后端完成事件，并将返回数据写入原 miss 对应的 Cache Line。该步骤建立了“后端请求”和“后端完成”之间的多周期关系。

完整关系为：

```text
mem_req_fire成立
    → 请求已经被后端接受
    → D-Cache进入REFILL_WAIT
    → 等待mem_resp_valid
    → 在正确状态消费mem_resp_rdata
```

### 3.2 响应消费事件与数组写入

定义：

```text
mem_resp_fire = !reset
                && state == STATE_REFILL_WAIT
                && mem_resp_valid
```

当前响应接口没有 `mem_resp_ready`，因为设计约定 D-Cache 进入等待状态后一定能接收后端响应。`state == STATE_REFILL_WAIT`相当于内部响应接收使能；它与 `mem_resp_valid`共同形成数组写使能。

第一份数据写端口为：

| 写端口部分 | 来源 |
| --- | --- |
| 写使能 | `mem_resp_fire` |
| Cache Line编号 | `req_index` |
| Line内word编号 | 初始阶段固定为0 |
| 写数据 | `mem_resp_rdata` |

必须使用锁存地址产生的 `req_index`。CPU 在等待期间可能改变 `cpu_req_addr`，而后端返回仍属于之前已接受的 miss。

新增 `DCacheBackendResponse_tb.v`，验证 IDLE 和 REFILL_REQ 中的伪响应被忽略、`mem_resp_valid=0` 时数组不变、返回数据写入锁存 index 的 word 0，以及 tag/valid 不会在第一份数据到达时提前提交。结果为：

```text
PASS: DCache first backend response capture passed 7 checks.
```

## 4. refill_word_index：把单次读扩展为四字整行填充

### 4.1 这一步为整体设计服务的目的

一条 Cache Line 为32字节，而后端每次只传输8字节，因此一个 Load miss 必须拆成四次相互独立的后端请求—响应事务。今天增加两位 `refill_word_index`，使 `STATE_REFILL_REQ`和 `STATE_REFILL_WAIT`能够循环四次，并把四份数据放入正确的行内位置。

该计数器补齐了下面的控制循环：

```text
当前word编号
    → 生成后端字节地址
    → 发出请求并等待响应
    → 写入当前word
    → 若不是word 3则编号加1并继续
    → word 3完成后结束整行搬运
```

### 4.2 计数器、地址和写入位置

| `refill_word_index` | 字节偏移 | 后端地址 | data_array写入位置 |
| ---: | ---: | --- | --- |
| 0 | 0 | `req_line_base + 0` | `[req_index][0]` |
| 1 | 8 | `req_line_base + 8` | `[req_index][1]` |
| 2 | 16 | `req_line_base + 16` | `[req_index][2]` |
| 3 | 24 | `req_line_base + 24` | `[req_index][3]` |

`refill_word_index`在 reset 和新 Load miss 被接受时清零。64位字节偏移由：

```text
{59'b0, refill_word_index, 3'b0}
```

产生。低3位补零等价于乘以8，高位补零避免直接对两位计数器移位时发生结果位宽截断。

响应状态逻辑为：

```text
mem_resp_fire && refill_word_index != 3：
    data_array[req_index][refill_word_index] ← mem_resp_rdata
    refill_word_index ← refill_word_index + 1
    state ← STATE_REFILL_REQ

mem_resp_fire && refill_word_index == 3：
    data_array[req_index][3] ← mem_resp_rdata
    state ← STATE_RESP

没有响应：
    保持STATE_REFILL_WAIT和当前word编号
```

计数器必须在响应被消费后递增，不能在请求握手时递增。它在等待期间还承担“未来返回数据属于哪个 word”的身份标记；若请求一被接受就递增，word 0的返回数据会被错误写入 word 1。

数组写入和计数器递增使用非阻塞赋值。同一上升沿中数组下标使用旧计数值，计数器在时钟沿结束后才更新，因此当前返回数据会写入正确 word。

最后一个 word 单独进入 `STATE_RESP`，避免两位计数器从3回绕到0并错误发出第五笔请求。

## 5. STATE_RESP：提交元数据并向 CPU 完成原始 Load

### 5.1 这一步为整体设计服务的目的

四个数据 word 到齐后，Cache Line 还不能仅凭 `data_array`被正常命中。直接映射查找还需要正确的 tag 和 valid。同时，最初发出 Load 的 CPU 必须收到一次明确完成响应。因此 `STATE_RESP`承担两个职责：

```text
对CPU：返回原始Load需要的word并产生一个周期resp_valid
对Cache阵列：提交新tag和valid，使整行正式可见
```

这一步完成后，Load miss 才从“数据已经搬入内部”变成“体系结构访问已经完成”。

### 5.2 CPU响应的两个数据来源

| 路径 | 有效条件 | 数据选择 |
| --- | --- | --- |
| Load hit快速路径 | `STATE_IDLE && cpu_load_hit` | `data_array[cpu_addr_index][cpu_addr_word_offset]` |
| Load miss完成路径 | `STATE_RESP` | `data_array[req_index][req_word_offset]` |

`cpu_resp_valid`扩展为：

```text
!reset && (
    IDLE中的Load hit
    || STATE_RESP中的miss完成
)
```

`STATE_RESP`响应不能依赖当前 `cpu_req_valid`。原请求在更早的 `cpu_req_fire`周期已经被 Cache 接受，后续响应属于 Cache 内部保存的事务；即使 CPU 实时输入改变，完成信号和数据仍必须产生。

`cpu_resp_rdata`使用组合多路选择器：无响应时为0，`STATE_RESP`时优先选择锁存请求对应的数据，否则选择当前 hit 数据。`cpu_resp_rdata`因此改为组合过程驱动的 `reg`输出。

### 5.3 tag/valid提交与单一驱动

原先 `valid_array`由独立时序块负责复位。若再从状态机中设置某一 valid bit，同一个寄存器会被两个 `always`块驱动。因此今天删除独立 valid 复位块，把两种写操作统一到状态机：

```text
reset：
    valid_array全部清零

STATE_RESP结束的上升沿：
    tag_array[req_index]   ← req_tag
    valid_array[req_index] ← 1
    state                  ← STATE_IDLE
```

其他状态不赋值时，valid 和 tag 自然保持。data 和 tag 不需要在 reset 时清零，因为 `valid=0`已经阻止旧内容被正常命中。

### 5.4 最后一个 word 与响应时序

最后一个响应到来的上升沿同时执行：

```text
data_array[req_index][3] ← mem_resp_rdata
state ← STATE_RESP
```

非阻塞赋值在时钟沿结束后共同更新。进入 `STATE_RESP`后，word 3已经是新数据，所以原请求即使需要 word 3，也能通过组合读取直接获得正确结果，不需要额外旁路。

`STATE_RESP`保持一个完整周期。该周期中 CPU 观察到 `cpu_resp_valid=1`和正确数据；周期结束的上升沿，CPU采样响应，D-Cache同时提交 tag/valid并回到 IDLE。当前接口没有 `cpu_resp_ready`，因此约定 CPU 在等待状态中始终能够接收这个单周期响应。

## 6. 直接映射替换与完整 Load 闭环测试

### 6.1 这一步为整体设计服务的目的

第一次 miss 能返回数据还不足以证明 Cache 行为完整。还需要确认填充后的第二次访问真正走 hit 快速路径，以及两个拥有相同 index、不同 tag 的地址会占用同一个槽位并发生替换。

更新 `DCacheRefillLoop_tb.v`，并直接连接真实的三周期 `CacheBackingMemory`，验证以下完整流程：

```text
第一次访问0x138：
    tag=1，index=1，word offset=3
    → miss
    → 后端地址0x120、0x128、0x130、0x138
    → 返回word 3
    → tag=1、valid=1

第二次访问同一Cache Line：
    → hit
    → 不再产生后端请求

访问0x38：
    tag=0，index=1，word offset=3
    → 与0x138具有相同index、不同tag
    → miss并读取0x20、0x28、0x30、0x38
    → 用tag=0的新行替换原tag=1

替换后：
    0x138不再命中
    0x38可以直接命中
```

完整闭环测试结果：

```text
PASS: DCache Load miss refill, response, hit, and replacement passed 14 checks.
```

该测试还确认：

- 一个 miss 严格产生四笔后端请求；
- 后端地址按8字节递增且不会产生第五笔请求；
- 四份数据按顺序进入同一 Cache Line；
- `req_word_offset`在整个事务期间保持原始 Load 的选择；
- `STATE_RESP`返回正确 word；
- valid 不会在整行完成前提前提交；
- hit 不会再次访问后端；
- 替换只由相同 index、不同 tag 触发。

## 7. 今日完整回归结果

今天更新了此前阶段性 TB 中已经过时的“永远停在 REFILL_WAIT/STATE_RESP”预期，并运行六组 D-Cache 回归：

```text
PASS: DCache address decomposition and array geometry passed 13 cases.
PASS: DCache reset and Load-hit lookup passed 12 checks.
PASS: DCache CPU interface and Load-miss capture passed 15 checks.
PASS: DCache first backend refill request passed 13 checks.
PASS: DCache first backend response capture passed 7 checks.
PASS: DCache Load miss refill, response, hit, and replacement passed 14 checks.
```

合计通过74项检查。

编译仅有两类提示：`DCache.v`和 `CacheBackingMemory.v`没有声明 `timescale`；Icarus 在 `cpu_resp_rdata`组合逻辑读取二维 `data_array`时提示将全部32个 word 加入敏感列表。两者均不影响当前功能仿真。

当前 `refill_resp_rdata`已经声明并连接到锁存地址对应的数据，但 `cpu_resp_rdata`组合逻辑仍直接写出了相同数组索引表达式。两者功能相同；后续可以让组合逻辑引用 `refill_resp_rdata`，或删除该冗余 wire，作为代码整理项。

## 8. 今日结束时的完成状态与整体位置

| 模块或功能 | 当前状态 | 在整体设计中的作用 |
| --- | --- | --- |
| 地址拆分与 Cache 阵列 | 已完成并测试 | 定义直接映射 Cache 的 tag/index/word 组织 |
| Load hit 查找与CPU响应 | 已完成并测试 | 提供无额外等待的快速命中路径 |
| CPU请求握手与miss锁存 | 已完成并测试 | 建立可变延迟事务的接受边界 |
| 阻塞控制 | 已完成并测试 | miss期间关闭 ready，保证一次只有一个未完成访问 |
| 后端读请求握手 | 已完成并测试 | 将一次 Cache miss 拆为后端可接受的请求 |
| 后端响应消费 | 已完成并测试 | 只在等待状态接收并写入返回数据 |
| 四字Cache Line refill | 已完成并测试 | 依次读取和保存32字节整行数据 |
| tag/valid原子提交 | 已完成并测试 | 整行完成后才使新Cache Line对查找可见 |
| Load miss最终响应 | 已完成并测试 | 根据原始word offset向CPU完成访问 |
| 直接映射替换 | 已完成并测试 | 相同index、不同tag时用新行替换旧行 |
| Store写穿透路径 | 尚未实现 | 后续完成写命中更新与写不命中不分配 |
| D-Cache接入CPU MEM阶段 | 尚未进行 | 后续使用请求/完成信号冻结和恢复流水线 |
| I-Cache | 尚未开始 | D-Cache稳定并接入CPU后再实现取指缓存 |

至此，第一版 D-Cache 的 Load-only 核心逻辑已经闭环：

```text
地址组织
  → 命中判断
  → 请求接受与锁存
  → 后端四字填充
  → 元数据提交
  → CPU完成响应
  → 后续命中与直接映射替换
```

下一阶段应实现约定的 Store 策略：写穿透、写命中更新、写不命中不分配。Store 无论命中还是不命中都需要等待后端写完成；命中时同时更新 Cache 中对应 word，不命中时只写后端、不填充 Cache Line。Store 路径独立测试通过后，再把完整 D-Cache 接入 CPU 的 MEM 阶段并实现流水线冻结。

# 2026/10/15：D-Cache Store 写穿透、命中更新与不命中不分配闭环

## 今日修改顺序（从 Load-only Cache 到完整 Load/Store D-Cache）

```text
扩展状态编码，为 Store 增加请求、等待和响应三个状态
    → 放开 CPU 侧 ready，使 IDLE 能够接收对齐 Store
    → 定义 cpu_store_fire，只在 Store 真正握手时取得请求
    → 锁存 Store 地址、写数据和接收时的 Cache 命中结果
    → 修正 cpu_load_miss_fire，防止 Store miss 误入 Load refill
    → 在 STATE_STORE_REQ 中向后端持续提供写请求
    → 后端接受请求后进入 STATE_STORE_WAIT，避免同一 Store 重复发送
    → 等待后端用 mem_resp_valid 确认写操作完成
    → Store hit 时更新 Cache 中对应 word
    → Store miss 时保持 valid、tag 和 data_array 不变
    → 进入 STATE_STORE_RESP，向 CPU 产生一个周期的完成响应
    → 返回 STATE_IDLE，重新允许下一次访问
    → 完成写穿透、写命中更新、写不命中不分配的完整 Store 闭环
```

昨天已经完成 Load hit、Load miss、整行 refill、直接映射替换和 CPU Load 响应。今天在不改变 Load 路径基本结构的前提下加入 Store，使第一版独立 D-Cache 从只读版本扩展为能够处理对齐64位 Load/Store 的完整阻塞式 Cache。

当前 Store 路径形成了下面的整体关系：

```text
CPU发出对齐Store
    → D-Cache在IDLE中接受并锁存请求
    → 同时记录目标Cache Line是否命中
    → 无论hit还是miss都向后端发送一次写请求
    → 等待后端确认写操作完成
        → hit：更新Cache中对应word
        → miss：Cache保持不变
    → 向CPU报告Store完成
    → 返回IDLE
```

这一闭环补齐了第一版 D-Cache 的写路径，并保持了设计范围：直接映射、阻塞式、一次只有一个未完成访问、Write Through、Write Hit Update、No Write Allocate。

## 1. 扩展状态机并建立 Store 请求入口

### 1.1 这一步为整体设计服务的目的

原状态机只有 Load 使用的 `IDLE/REFILL_REQ/REFILL_WAIT/RESP` 四个状态。Store 虽然不需要整行 refill，但写穿透要求等待后端完成，因此同样是一个执行时间不固定的多周期事务，不能在 IDLE 中直接视为完成。

为 Store 增加三个状态：

| 状态 | 编码 | 作用 |
| --- | ---: | --- |
| `STATE_STORE_REQ` | `3'd4` | 向后端提供 Store 写请求，等待请求握手 |
| `STATE_STORE_WAIT` | `3'd5` | 后端已经接受写请求，等待写完成响应 |
| `STATE_STORE_RESP` | `3'd6` | 向 CPU 报告 Store 已完成 |

状态寄存器由两位扩展为三位。Load 原有四个状态保持原编码和原职责，使新增 Store 路径与已经验证的 Load 路径并列存在。

### 1.2 CPU 侧 Store 接受条件

此前 `cpu_req_ready`隐含拒绝 Store。今天将其扩展为：

```text
cpu_req_ready = !reset
                && cpu_addr_aligned
                && state == STATE_IDLE
```

它现在表示：只要 D-Cache 空闲且地址满足当前64位对齐要求，就可以接受 Load 或 Store。请求是否真实发生仍由：

```text
cpu_req_fire = cpu_req_valid && cpu_req_ready
```

决定。

Store 接受事件定义为：

```text
cpu_store_fire = cpu_req_fire && cpu_req_write
```

只有该事件成立的上升沿才会取得 Store 事务，不能仅凭 `cpu_req_write=1`进入 Store 状态。

### 1.3 锁存 Store 事务

Store 被接受时保存：

| 寄存器 | 锁存内容 | 后续用途 |
| --- | --- | --- |
| `req_addr_reg` | `cpu_req_addr` | 生成后端写地址以及 Cache index/word offset |
| `req_write_reg` | `cpu_req_write` | 保存请求类型 |
| `req_wdata_reg` | `cpu_req_wdata` | 后端写数据和命中 Cache 更新数据 |
| `store_hit_reg` | `cpu_line_hit` | 写完成后决定是否更新 Cache 副本 |

状态同时从 `STATE_IDLE`进入 `STATE_STORE_REQ`。之后 CPU 即使改变实时地址和写数据，也不会改变正在处理的 Store。

`store_hit_reg`在 reset 时清零，在新的 Store 被接受时更新。它保存的是请求接受瞬间的命中结果，而不是之后根据实时 CPU 地址重新计算的结果。

### 1.4 防止 Store miss 进入 Load refill

放开 `cpu_req_ready`以后，Store 也能够产生 `cpu_req_fire`。因此 Load miss 事件必须显式排除写请求：

```text
cpu_load_miss_fire = cpu_req_fire
                     && !cpu_req_write
                     && !cpu_line_hit
```

如果缺少 `!cpu_req_write`，一次 Store miss 会同时满足“请求已接受”和“Cache未命中”，从而错误进入 `STATE_REFILL_REQ`并执行 Load refill。

最终 IDLE 分流关系为：

```text
cpu_store_fire成立
    → 锁存Store请求和命中结果
    → STATE_STORE_REQ

否则cpu_load_miss_fire成立
    → 锁存Load miss请求
    → STATE_REFILL_REQ

否则
    → 保持STATE_IDLE
    → Load hit由组合快速路径同周期完成
```

## 2. 明确 Store 命中的含义与写策略分流

### 2.1 这一步为整体设计服务的目的

Store 路径复用了原有的行命中判断：

```text
cpu_line_hit = valid_array[cpu_addr_index]
               && tag_array[cpu_addr_index] == cpu_addr_tag
```

这里的命中表示目标内存块当前有一份有效副本位于 D-Cache 中，不表示后端存储器中是否“存在”这个地址。`index`负责选择唯一候选槽位，`valid`和 `tag`共同确认该槽位是否正是目标 Cache Line。

后端存储器是体系中保存数据的主体；Cache hit/miss只描述是否有缓存副本。由于采用 Write Through，Store 无论 hit 还是 miss 都必须写后端。

### 2.2 三种写策略在当前设计中的组合

| 策略 | 当前实现含义 |
| --- | --- |
| Write Through | 每次 Store 都要写后端，并等待后端完成 |
| Write Hit Update | Store hit 时，后端完成后更新 Cache 中对应 word |
| No Write Allocate | Store miss 时不读取整行、不写新 tag、不置 valid |

因此 hit/miss 不决定是否写后端，只决定后端完成后是否更新 Cache：

| Store情况 | 写后端 | 更新Cache目标word | 修改tag/valid | 整行refill |
| --- | ---: | ---: | ---: | ---: |
| Store hit | 是 | 是 | 否 | 否 |
| Store miss | 是 | 否 | 否 | 否 |

如果 Store miss 的 index 当前保存另一个 tag 的有效 Cache Line，No Write Allocate 要求这条旧 Cache Line 完整保留，不能清除 valid，也不能覆盖其数据。

## 3. STATE_STORE_REQ：向后端发出并保持写请求

### 3.1 这一步为整体设计服务的目的

Store 请求已经被 D-Cache 接受，但写穿透要求把数据真正交给后端。`STATE_STORE_REQ`负责将锁存请求转换为后端 ready/valid 写事务，并在后端暂时忙碌时保持所有载荷稳定。

后端请求接口从原来的 Load-only 输出扩展为：

| 信号 | `STATE_REFILL_REQ` | `STATE_STORE_REQ` |
| --- | --- | --- |
| `mem_req_valid` | 1 | 1 |
| `mem_req_write` | 0 | 1 |
| `mem_req_addr` | `req_line_base + refill_word_byte_offset` | `req_addr_reg` |
| `mem_req_wdata` | 0 | `req_wdata_reg` |

`mem_req_valid`现在在 Load refill 请求状态或 Store 请求状态有效：

```text
mem_req_valid = !reset
                && (state == STATE_REFILL_REQ
                    || state == STATE_STORE_REQ)
```

`mem_req_write`只在有效 Store 请求期间为1；`mem_req_wdata`只在写请求期间输出锁存数据，无请求或读请求时输出0。

### 3.2 Store 地址为什么使用原始请求地址

Load miss 需要搬运整条 Cache Line，因此从 `req_line_base`开始读取 `+0/+8/+16/+24`四个 word。Store 只写 CPU 指定的一个64位 word，因此必须直接使用 `req_addr_reg`。

例如：

```text
Store地址 = 0x128
所属Line基地址 = 0x120
```

后端写地址必须是 `0x128`。若错误使用 Line 基地址，就会写入该行第0个 word，而不是 CPU 指定的 word。

### 3.3 ready/valid握手与单次发送

请求接受事件继续复用：

```text
mem_req_fire = mem_req_valid && mem_req_ready
```

状态逻辑为：

```text
STATE_STORE_REQ：
    mem_req_fire=0
        → 保持STATE_STORE_REQ
        → valid、write、addr、wdata保持稳定

    mem_req_fire=1
        → 后端已经接受写请求
        → 进入STATE_STORE_WAIT
        → 下一周期mem_req_valid变为0
```

进入 `STATE_STORE_WAIT`后停止发送请求，保证同一条 Store 只被后端接受一次。

## 4. STATE_STORE_WAIT：等待写完成并按命中结果更新 Cache

### 4.1 这一步为整体设计服务的目的

`mem_req_fire`只表示后端已经接收写请求，不代表写操作已经完成。D-Cache 必须继续保持忙碌，直到后端用 `mem_resp_valid`确认本次写事务结束。

为 Store 定义独立完成事件：

```text
store_mem_resp_fire = !reset
                      && state == STATE_STORE_WAIT
                      && mem_resp_valid
```

它和 Load 的 `mem_resp_fire`分开：Load 响应携带 refill 数据并写入当前 word；Store 响应只表示写操作完成，不使用 `mem_resp_rdata`。

### 4.2 等待状态逻辑

```text
store_mem_resp_fire=0：
    保持STATE_STORE_WAIT
    不修改Cache
    不响应CPU

store_mem_resp_fire=1：
    若store_hit_reg=1，更新目标Cache word
    若store_hit_reg=0，Cache阵列保持不变
    进入STATE_STORE_RESP
```

Store hit 的写端口为：

| 写端口部分 | 来源 |
| --- | --- |
| 写使能 | `store_mem_resp_fire && store_hit_reg` |
| Cache Line编号 | `req_index` |
| Line内word编号 | `req_word_offset` |
| 写数据 | `req_wdata_reg` |

对应的时序写入为：

```text
data_array[req_index][req_word_offset] ← req_wdata_reg
```

这里只更新一个64位 word。其余三个 word、当前 tag 和 valid 都保持不变，因为 Store hit 已经说明目标 Cache Line 的元数据正确。

### 4.3 Store miss为什么完全不修改Cache

`store_hit_reg=0`时不执行任何 Cache 数组赋值：

```text
valid_array保持
tag_array保持
data_array保持
```

这既不会把 Store 地址分配进 Cache，也不会破坏相同 index 下可能存在的其他有效 Cache Line。以后如果 CPU Load 该 Store 地址，由于本次 Store miss 没有分配，它仍会发生 Load miss，再从已经被写新的后端存储器中取回整行数据。

### 4.4 为什么等后端完成后才更新命中Cache

Cache 更新以后端完成事件作为提交点：

```text
后端尚未完成
    → Cache仍保存旧值
    → Store仍未完成

后端确认完成
    → 命中时更新Cache副本
    → 进入完成响应状态
```

这样后端和 Cache 的新值在同一次 Store 事务完成时统一可见。当前 Cache 是阻塞式，等待期间不会接受另一个访问，因此推迟到完成点更新不会让其他请求看到中间状态。

## 5. STATE_STORE_RESP：向 CPU 完成 Store 并恢复空闲

### 5.1 这一步为整体设计服务的目的

后端 `mem_resp_valid`只对 D-Cache 可见，CPU 仍需要通过正式 Cache 接口知道 Store 已完成。因此在内部写完成和条件更新之后，使用独立 `STATE_STORE_RESP`产生稳定的 CPU 完成周期。

`cpu_resp_valid`扩展为三种来源：

```text
1. IDLE中的Load hit
2. STATE_RESP中的Load miss完成
3. STATE_STORE_RESP中的Store完成
```

Store 响应期间：

| 信号 | 数值 | 含义 |
| --- | ---: | --- |
| `cpu_resp_valid` | 1 | Store 已经完成 |
| `cpu_resp_rdata` | 0 | Store 没有需要返回的读取数据 |
| `cpu_req_ready` | 0 | 当前周期只完成旧请求，不接收新请求 |

`cpu_resp_rdata`增加 `STATE_STORE_RESP`专用分支并固定返回0，避免它落入 Load hit 数据选择路径而输出与 Store 无关的 Cache 数据。

`STATE_STORE_RESP`保持一个完整周期，随后在上升沿执行：

```text
state ← STATE_IDLE
```

返回 IDLE 后 `cpu_resp_valid`撤销、`cpu_req_ready`重新有效，D-Cache 可以接受下一项访问。请求寄存器不需要在完成时清零，下一次多周期请求被接受时会覆盖它们，状态本身已经说明当前没有未完成事务。

## 6. 完整 Store hit 与 Store miss 运行逻辑

### 6.1 Store hit

```text
CPU发出Store
    → IDLE中valid和tag匹配
    → cpu_store_fire成立
    → 锁存地址、数据，store_hit_reg置1
    → STATE_STORE_REQ输出后端写请求
    → mem_req_fire后进入STATE_STORE_WAIT
    → 等待后端mem_resp_valid
    → 更新data_array[req_index][req_word_offset]
    → tag和valid保持不变
    → 进入STATE_STORE_RESP
    → cpu_resp_valid=1、cpu_resp_rdata=0
    → 返回STATE_IDLE
```

完成后，后端目标地址和 Cache 目标 word 都保存新值。

### 6.2 Store miss

```text
CPU发出Store
    → IDLE中valid无效或tag不匹配
    → cpu_store_fire成立
    → 锁存地址、数据，store_hit_reg置0
    → STATE_STORE_REQ仍然输出后端写请求
    → mem_req_fire后进入STATE_STORE_WAIT
    → 等待后端mem_resp_valid
    → 不修改valid、tag或data_array
    → 进入STATE_STORE_RESP
    → cpu_resp_valid=1、cpu_resp_rdata=0
    → 返回STATE_IDLE
```

完成后只有后端目标地址变为新值，Cache 中原有内容完整保留。后续 Load 同一地址时仍然 miss，并从后端取回包含新值的 Cache Line。

## 7. Load 与 Store 共享接口后的最终状态机

当前 D-Cache 共使用七个状态：

| 状态 | 访问类型 | 核心职责 |
| --- | --- | --- |
| `STATE_IDLE` | Load/Store | 接受新请求；Load hit可同周期完成 |
| `STATE_REFILL_REQ` | Load miss | 提供一笔后端读请求 |
| `STATE_REFILL_WAIT` | Load miss | 等待并保存一个返回word |
| `STATE_RESP` | Load miss | 返回原Load数据并提交tag/valid |
| `STATE_STORE_REQ` | Store | 提供一次后端写请求 |
| `STATE_STORE_WAIT` | Store | 等待写完成并按原命中结果更新Cache |
| `STATE_STORE_RESP` | Store | 向CPU报告Store完成 |

整体分流关系为：

```text
                           Load hit
                      ┌────────────────┐
                      │ 同周期返回数据 │
                      ▼                │
                   STATE_IDLE ─────────┘
                      │
          ┌───────────┴───────────┐
          │ Load miss             │ Store
          ▼                       ▼
 STATE_REFILL_REQ          STATE_STORE_REQ
          │                       │
          ▼                       ▼
 STATE_REFILL_WAIT         STATE_STORE_WAIT
          │                       │
          │ 前3个word循环          │ hit时更新一个word
          │ 第4个word结束          │ miss时Cache不变
          ▼                       ▼
     STATE_RESP            STATE_STORE_RESP
          │                       │
          └───────────┬───────────┘
                      ▼
                  STATE_IDLE
```

`cpu_req_ready`只在 IDLE 有效，因此 Load miss 或 Store 多周期处理期间都不会接受第二个请求。这继续维持第一版阻塞式 Cache“一次只有一个未完成访问”的约束。

## 8. 测试与当前完成状态

今天针对 Store 请求锁存、后端写请求保持、单次握手、写完成消费、Store hit 更新、Store miss 不分配、CPU 完成响应以及连接真实 `CacheBackingMemory`后的完整写穿透流程进行了专项测试，并重新运行已有 D-Cache 回归。所有测试均通过，最终九组 D-Cache 测试合计通过107项检查。

测试文件只用于验证上述状态与接口行为，未改变 RTL 的设计结构。

## 9. 今日结束时的完成状态与后续衔接

| 模块或功能 | 当前状态 | 在整体设计中的作用 |
| --- | --- | --- |
| 地址拆分与直接映射阵列 | 已完成 | 提供tag/index/word组织基础 |
| Load hit快速路径 | 已完成 | 命中时同周期返回64位数据 |
| Load miss四字refill | 已完成 | 从后端取回并安装完整32B Cache Line |
| Load直接映射替换 | 已完成 | 相同index、不同tag时覆盖旧行 |
| Store请求接受与锁存 | 已完成 | 保存多周期写事务及原始命中结果 |
| Store写穿透 | 已完成 | hit和miss都把新值写入后端 |
| Store写命中更新 | 已完成 | 后端完成后更新命中Cache word |
| Store写不命中不分配 | 已完成 | miss只写后端，Cache保持原状 |
| Store CPU完成响应 | 已完成 | 用独立响应周期结束写事务 |
| 阻塞式单请求控制 | 已完成 | 忙碌期间关闭ready，禁止第二项访问 |
| D-Cache接入CPU MEM阶段 | 尚未进行 | 后续根据请求完成关系暂停和恢复流水线 |
| I-Cache | 尚未开始 | D-Cache接入并稳定后再处理取指缓存 |

至此，第一版独立 D-Cache 的 Load/Store 核心逻辑已经闭环：

```text
地址组织与命中判断
    → CPU请求接受与事务锁存
    → Load命中快速返回
    → Load miss整行填充、提交与替换
    → Store写穿透
    → Store hit更新或Store miss保持Cache
    → CPU完成响应
    → 返回IDLE接收下一项访问
```

下一阶段不再继续扩展 D-Cache 内部策略，而是准备把它接到五级流水线 CPU 的 MEM 阶段。首先需要明确 `valid_mem/MemRead_mem/MemWrite_mem/aluresult_mem/Store数据`如何组成 Cache 请求，以及 `cpu_resp_valid`未到来时哪些流水线寄存器和 PC 必须冻结。之后还要单独处理 Store 在等待期间不能重复提交、Load 完成前不能进入 WB，以及 Cache stall 与 Trap/flush 同时出现时的控制优先级。

# 2026/10/17：为 D-Cache 接入 MEM 阶段建立流水线保持能力与握手接线

## 今日修改顺序（从独立 D-Cache 到 CPU 顶层结构接入）

```text
分析可变延迟D-Cache对现有五级流水线的影响
    → 确认PC和IF/ID已有写使能，而ID/EX和EX/MEM缺少保持能力
    → 为ID_EX增加ID_EX_write输入和保持分支
    → 为EX_MEM增加EX_MEM_write输入和保持分支
    → 保证reset/flush优先于流水线保持
    → 在顶层连接两个新写使能，并暂时固定为1保持原CPU行为
    → 在MEM阶段区分合法Load、合法Store、气泡和Trap指令
    → 生成D-Cache CPU侧请求valid、地址、读写类型和Store数据
    → 声明D-Cache返回CPU的ready、response和Load数据
    → 声明D-Cache与后端存储器之间的请求/响应连线
    → 在PIPELINED_CPU中实例化DCache和CacheBackingMemory
    → 保留原DataMemory，暂不让D-Cache接管CPU读写和流水线暂停
```

今天开始把已经独立闭环的 D-Cache 接入五级流水线 CPU。当前阶段没有立即替换 `DataMemory`，而是先解决两个前置问题：流水线能否在 Cache 等待期间保持关键状态，以及 MEM 阶段能否正确生成一项无异常、可提交的 D-Cache 请求。

这一步将独立模块推进到了下面的位置：

```text
CPU的MEM阶段
    → 识别有效Load/Store并屏蔽Trap副作用
    → 生成D-Cache请求载荷
    → 连接D-Cache CPU侧ready/response接口
    → D-Cache连接CacheBackingMemory
```

但当前还没有根据 `dcache_cpu_resp_valid`冻结和恢复流水线，所以这只是结构接入阶段，D-Cache尚未成为 CPU 的正式数据存储路径。

## 1. 为 ID/EX 和 EX/MEM 增加写使能

### 1.1 这一步为整体设计服务的目的

原 `DataMemory`能够组合返回读取结果，CPU默认 MEM 阶段每个周期都能完成。D-Cache miss 或 Write Through Store 可能等待多个周期，如果流水线寄存器仍持续更新，发生访存的指令会被后续指令覆盖。

例如 Load A 在 MEM 中发生 miss：

```text
EX/MEM当前保存Load A的地址、目的寄存器和控制信号
    → D-Cache尚未返回数据
    → 若EX/MEM继续更新，下一条指令B覆盖Load A
    → 数据返回时已无法确定它属于哪条Load
```

因此未来 `cache_stall=1`时至少需要保持：

```text
PC
IF/ID
ID/EX
EX/MEM
```

PC已经有 `PCwrite`，IF/ID已经有 `IF_IDwrite`。今天为缺少保持能力的 `ID_EX`和 `EX_MEM`分别增加写使能。

### 1.2 ID_EX_write

`ID_EX`新增输入：

```text
ID_EX_write=1 → 锁存ID阶段的新输入
ID_EX_write=0 → 所有ID/EX输出保持原值
```

保持内容包括：

- PC、指令和两个源操作数；
- 立即数；
- ALU、Load/Store、分支和跳转控制；
- 寄存器写回控制；
- CSR数据与控制；
- 异常、ECALL、MRET信息；
- 分支预测信息和 `valid_out`。

保持分支对所有输出寄存器执行自赋值，使其风格与现有 `IF_ID`一致。

### 1.3 EX_MEM_write

`EX_MEM`新增输入：

```text
EX_MEM_write=1 → 锁存EX阶段的新结果
EX_MEM_write=0 → 保持当前MEM指令及全部控制状态
```

保持内容包括：

- `ALUresult_out`，即访存地址；
- `writedata_out`，即 Store 数据；
- `MemRead_out/MemWrite_out`；
- `MemtoReg_out/Regwrite_out`；
- 指令、PC、分支和跳转信息；
- CSR、异常、预测和 `valid_out`。

这保证以后 D-Cache 等待期间，MEM 阶段看到的始终是同一条访存指令。

### 1.4 reset、flush、hold和正常更新的优先级

两个流水线寄存器都使用：

```text
reset或flush成立
    → 清零，形成无效指令

否则write=0
    → 保持全部输出

否则write=1
    → 锁存新输入
```

即：

```text
reset/flush > hold > normal update
```

flush必须高于保持。未来 Cache stall 与 Trap、分支纠错或跳转冲刷同时出现时，控制冲刷仍然能够清除错误路径指令，不会被暂停阻止。

顶层新增 `ID_EX_write_final`和 `EX_MEM_write_final`并连接相应实例。当前暂时固定为 `1'b1`，所以新增能力不会改变原 CPU 行为；以后建立 `cache_stall`后再由暂停条件控制它们。

## 2. MEM 阶段合法访存资格判断

### 2.1 这一步为整体设计服务的目的

D-Cache不能仅根据 `MemRead_mem`或 `MemWrite_mem`决定是否访问。请求还必须属于一条有效流水线指令，并且当前指令没有进入 Trap。

需要排除：

- `valid_mem=0`的流水线气泡；
- 非Load/Store指令；
- Load或Store地址未对齐；
- 非法指令、ECALL等同步异常；
- 当前 MEM 指令因外部中断而不得提交的情况。

现有 Store 副作用资格信号为：

```text
MemWrite_valid_mem = valid_mem
                     && MemWrite_mem
                     && !trap_enter
```

今天增加对称的 Load 资格信号：

```text
MemRead_valid_mem = valid_mem
                    && MemRead_mem
                    && !trap_enter
```

这样 Trap 发生时既不会写原 `DataMemory`，也不会向 D-Cache发出 Load/Store 请求。

### 2.2 MEM 到 D-Cache 的请求载荷

根据两个资格信号生成：

| D-Cache CPU侧信号 | CPU中的来源 | 含义 |
| --- | --- | --- |
| `dcache_cpu_req_valid` | `MemRead_valid_mem || MemWrite_valid_mem` | 当前存在一项合法数据访问 |
| `dcache_cpu_req_addr` | `aluresult_mem` | EX阶段计算并锁存到MEM的字节地址 |
| `dcache_cpu_req_write` | `MemWrite_valid_mem` | 0表示Load，1表示合法Store |
| `dcache_cpu_req_wdata` | `storedata_mem` | 经前递并锁存到EX/MEM的Store数据 |

CPU顶层不拆分 tag、index 和 offset，也不生成 Line Base。这些都属于 D-Cache 内部职责；CPU只提供原始字节地址和访问类型。

Store写数据继续沿用原前递通路：

```text
forwardB_result
    → EX_MEM.writedata_in
    → storedata_mem
    → dcache_cpu_req_wdata
```

所以接入 D-Cache 不会破坏已有的 Store-data forwarding。

## 3. CPU 与 D-Cache 的请求—完成关系

### 3.1 这一步为整体设计服务的目的

当前接线正式区分了请求接受和请求完成两个时间点。

CPU请求被 D-Cache 接受的事件为：

```text
dcache_cpu_req_fire = dcache_cpu_req_valid
                      && dcache_cpu_req_ready
```

其中：

- `dcache_cpu_req_valid`由 CPU MEM 阶段产生；
- `dcache_cpu_req_ready`由 D-Cache 返回；
- 两者同时为1，D-Cache才取得该事务。

请求完成由：

```text
dcache_cpu_resp_valid
```

表示。Load完成时 `dcache_cpu_resp_rdata`携带读取结果；Store完成时返回数据为0，只使用完成信号。

### 3.2 为什么valid不能依赖ready

CPU的 `dcache_cpu_req_valid`只由 MEM 中的有效访存决定，不能写成 `valid && ready`。若 D-Cache暂时不 ready，发送方必须保持 valid、地址、类型和数据，直到请求真正被接受。

未来由 `cache_stall`冻结 EX/MEM 后，`valid_mem/aluresult_mem/MemRead_mem/MemWrite_mem/storedata_mem`会保持稳定，从而自然保持整组 D-Cache 请求载荷。

## 4. 在 CPU 顶层实例化 DCache 和 CacheBackingMemory

### 4.1 DCache CPU侧接口

顶层新增并连接：

| 方向 | 信号 |
| --- | --- |
| CPU到D-Cache | `dcache_cpu_req_valid` |
| CPU到D-Cache | `dcache_cpu_req_addr` |
| CPU到D-Cache | `dcache_cpu_req_write` |
| CPU到D-Cache | `dcache_cpu_req_wdata` |
| D-Cache到CPU | `dcache_cpu_req_ready` |
| D-Cache到CPU | `dcache_cpu_resp_valid` |
| D-Cache到CPU | `dcache_cpu_resp_rdata` |

这组接口负责 CPU MEM 阶段的一项体系结构访存事务。

### 4.2 DCache后端接口

D-Cache另一侧连接 `CacheBackingMemory`：

| D-Cache信号 | 后端存储器端口 | 作用 |
| --- | --- | --- |
| `dcache_mem_req_valid` | `req_valid` | D-Cache提供有效后端请求 |
| `dcache_mem_req_write` | `req_write` | 区分后端读写 |
| `dcache_mem_req_addr` | `req_addr` | 64位字节地址 |
| `dcache_mem_req_wdata` | `req_wdata` | Store写数据 |
| `dcache_mem_req_ready` | `req_ready` | 后端能否接受请求 |
| `dcache_mem_resp_valid` | `resp_valid` | 后端读返回或写完成 |
| `dcache_mem_resp_rdata` | `resp_rdata` | Load refill返回的64位数据 |

由此形成两层握手：

```text
CPU MEM阶段
    ↔ DCache CPU侧请求/完成接口
        ↔ CacheBackingMemory后端ready/valid接口
```

D-Cache内部已经负责把一次 Load miss拆成四次后端读取，或把一次 Store转换为后端写请求。CPU顶层不需要参与 refill word计数和 Cache Line填充。

## 5. 当前仍保留 DataMemory 的原因

今天没有删除原 `DataMemory`，也没有让 `mem_readdata_mem`改用 `dcache_cpu_resp_rdata`。原因是 Cache stall 尚未建立。

若此时直接让 D-Cache接管 CPU 数据通路：

```text
Load miss被D-Cache接受
    → D-Cache需要多个周期
    → 流水线仍继续推进
    → EX/MEM中的Load控制和目标寄存器被覆盖
    → 返回数据无法对应原Load
```

所以当前结构是：

```text
原DataMemory
    → 仍负责CPU当前可见的实际读写行为

DCache + CacheBackingMemory
    → 已完成顶层端口接线
    → 尚未接管mem_readdata_mem和流水线时序
```

这是一个用于分阶段集成的中间版本，不代表 Cache 已经能够正确参与整机执行。

## 6. 今日测试结论

新增写使能和 D-Cache 结构接线后，`PIPELINED_CPU`整机层次编译通过。现有基础流水线、前递、冒险、分支预测、CSR、Trap、异常、中断和 MRET 回归均通过，说明两个新写使能固定为1以及旁路式 D-Cache接线没有改变原 CPU 的既有行为。

## 7. 今日结束时的完成状态与后续衔接

| 模块或功能 | 当前状态 | 在整体设计中的作用 |
| --- | --- | --- |
| PC写使能 | 原有能力 | 未来Cache stall时冻结取指地址 |
| IF/ID写使能 | 原有能力 | 未来保持前端指令和PC |
| ID/EX写使能 | 今日完成 | 未来保持EX阶段指令和全部控制 |
| EX/MEM写使能 | 今日完成 | 未来保持正在等待Cache的MEM指令 |
| reset/flush高于hold | 今日完成 | 保证冲刷不会被暂停阻止 |
| MEM合法Load资格判断 | 今日完成 | 无效指令或Trap不发Load请求 |
| MEM合法Store资格判断 | 已有并复用 | Trap时屏蔽Store副作用 |
| D-Cache请求载荷生成 | 今日完成 | 将MEM地址、类型和数据送往Cache |
| CPU—D-Cache结构接线 | 今日完成 | 建立request/ready/response接口 |
| D-Cache—后端结构接线 | 今日完成 | 连接可变延迟后端存储器 |
| Cache stall | 尚未实现 | 根据访存未完成状态冻结流水线 |
| D-Cache读取结果进入MEM/WB | 尚未实现 | 用Cache数据替换原DataMemory读取值 |
| 原DataMemory移除 | 尚未进行 | Cache正式接管后再处理 |
| MEM/WB等待期间行为 | 尚未处理 | 防止Load未完成时提前写回 |

今天完成的是 CPU—D-Cache 握手的请求生成和物理接线部分：

```text
MEM合法访存
    → 请求valid和载荷
    → D-Cache ready接受
    → D-Cache访问后端
    → D-Cache产生完成response
```

下一阶段需要把这组握手真正转化成流水线时间控制。核心关系应当是：

```text
MEM中存在合法Load/Store
并且dcache_cpu_resp_valid=0
    → cache_stall=1
    → 冻结PC、IF/ID、ID/EX、EX/MEM

dcache_cpu_resp_valid=1
    → cache_stall=0
    → Load返回数据进入MEM/WB
    → 当前访存离开MEM
    → 流水线继续推进
```

实现时还必须单独处理 MEM/WB 在等待期间不能让未完成 Load 提前写回，以及 Cache stall 与 Trap/branch flush 同时出现时的优先级。

# 2026/10/18：完成 D-Cache 流水线集成、数据通路接管与整体收尾

## 今日修改顺序（从结构接线到正式接管 CPU 访存）

```text
根据D-Cache请求是否完成生成cache_stall
    → 将cache_stall合并到PC和前四级流水线寄存器控制
    → 处理Cache stall、数据冒险与控制冲刷的优先级
    → 在miss等待期间屏蔽MEM/WB写回和无效前递
    → 使用D-Cache返回值接管Load数据通路
    → 记录已经接受但尚未完成的D-Cache请求
    → miss期间延迟外部中断，避免旧响应被错误使用
    → 从五级流水线CPU中移除旧DataMemory通路
    → 由DCache和CacheBackingMemory独立承担全部数据访存
    → 完成整机回归，确认基础D-Cache整体实现完成
```

昨天已经完成 CPU、D-Cache 和后端存储器的接口接线，但 D-Cache 尚未真正控制流水线时间，也没有为 CPU 提供最终 Load 数据。今天完成的是这部分集成的核心：把 `cpu_req_valid/ready` 和 `cpu_resp_valid` 转换为流水线暂停、恢复和提交行为，使 CPU 能够正确使用一个执行时间不固定的存储模块。

## 1. 根据请求完成状态生成 Cache stall

### 1.1 这一步为整体设计服务的目的

D-Cache 的 `cpu_req_ready`只表示能否接受请求，并不表示请求已经完成。Load miss首次被接受时可能同时满足 `valid=1`、`ready=1`，但返回数据仍需等待多个周期。因此 CPU 是否继续前进必须由完成响应决定。

最终暂停条件为：

```text
cache_stall = dcache_cpu_req_valid
              && !dcache_cpu_resp_valid
```

它描述的是：MEM阶段存在一项合法Load或Store，但D-Cache尚未完成它。

| 当前情况 | 请求有效 | 完成响应 | `cache_stall` |
| --- | ---: | ---: | ---: |
| 非访存指令 | 0 | 0 | 0 |
| Load hit | 1 | 1 | 0 |
| Load miss等待 | 1 | 0 | 1 |
| Store等待后端完成 | 1 | 0 | 1 |
| miss或Store完成 | 1 | 1 | 0 |

这一信号把 D-Cache 的可变延迟转换成了 CPU 顶层能够使用的统一等待条件。

## 2. 使用 Cache stall 冻结前四级流水线

### 2.1 这一步完善了哪部分整体逻辑

miss期间必须保留当前MEM访存指令，同时保留其后所有年轻指令。否则 EX/MEM 中的地址、访问类型和Store数据会被下一条指令覆盖，D-Cache返回时便无法找到原请求。

今天将 `cache_stall`合并到以下控制中：

| 被控制状态 | Cache stall时行为 | 目的 |
| --- | --- | --- |
| PC | 保持 | 取指地址不继续前进 |
| IF/ID | 保持 | 保存当前ID指令和预测信息 |
| ID/EX | 保持 | 保存当前EX指令和全部控制信号 |
| EX/MEM | 保持 | 保存正在等待D-Cache的MEM指令、地址和数据 |

最终写使能关系为：

```text
IF_ID_write_final = IF_ID_write_hazard && !cache_stall
ID_EX_write_final = !cache_stall
EX_MEM_write_final = !cache_stall
```

PC还必须允许控制重定向，因此采用：

```text
PCwrite_final = control_flush_mem
                || (PCwrite_hazard && !cache_stall)
```

### 2.2 数据冒险、保持与冲刷的优先级

普通Load-use冒险的处理方式是保持PC和IF/ID，并清空ID/EX插入气泡。但Cache stall要求ID/EX保持，不能在等待期间因为另一个数据冒险而丢失其中的年轻指令。因此最终ID/EX冲刷关系为：

```text
ID_EX_flush_final = control_flush_mem
                    || (ID_EX_flush_hazard && !cache_stall)
```

由此形成三类控制的明确关系：

```text
控制冲刷
    → 最高优先级，清除错误路径并重定向PC

Cache stall
    → 没有控制冲刷时保持PC、IF/ID、ID/EX、EX/MEM

普通Load-use冒险
    → 没有Cache stall时按原方式插入气泡
```

ID/EX和EX/MEM内部仍保持 `reset/flush > hold > normal update` 的寄存器更新优先级。

## 3. 控制 MEM/WB 提交，避免未完成访问产生副作用

### 3.1 这一步为整体设计服务的目的

前四级冻结后，MEM/WB仍会在每个周期更新。如果直接把 `Regwrite_valid_mem`送入MEM/WB，Load miss尚未返回时就可能携带无效数据进入WB。因此需要区分：

```text
指令具有写寄存器资格
```

和：

```text
指令已经完成，可以正式提交写回
```

最终增加：

```text
Regwrite_commit_mem = Regwrite_valid_mem
                      && !cache_stall
```

并将它同时用于：

- MEM/WB的 `Regwrite_in`；
- Forwarding Unit的MEM级写回资格。

### 3.2 为什么MEM/WB不与前四级一起冻结

Cache miss刚开始时，MEM/WB中可能保存着一条更老的正常指令。这条指令应该正常写回和退出。若冻结MEM/WB，它会停留在WB并重复产生副作用。

因此采用的策略是：

```text
前四级保持
MEM/WB继续流动
但等待周期送入Regwrite=0的无副作用气泡
```

响应到来时，`cache_stall`撤销，当前Load携带有效写回控制和正确数据进入MEM/WB，随后只写回一次。

## 4. D-Cache 正式接管 Load 数据通路

### 4.1 Load完成资格

Load返回值只有在当前MEM指令确实是合法Load，并且D-Cache已经产生响应时才有效：

```text
load_complete_mem = MemRead_valid_mem
                    && dcache_cpu_resp_valid
```

### 4.2 CPU可见的MEM读数据

最终MEM阶段读数据改为：

```text
mem_readdata_mem = load_complete_mem
                    ? dcache_cpu_resp_rdata
                    : 0
```

由于 MEM/WB 和MEM级前递原本都使用 `mem_readdata_mem`，修改数据源后形成：

```text
DCache.cpu_resp_rdata
    → mem_readdata_mem
        ├─→ MEM/WB
        └─→ MEM阶段前递选择
```

结合 `Regwrite_commit_mem`，等待期间返回值被视为无效，完成周期才允许进入写回和前递通路。

## 5. 记录 D-Cache 未完成请求并延迟外部中断

### 5.1 这一步完善了哪部分整体逻辑

若D-Cache已经接受miss或Store请求，外部中断却立即产生 `trap_enter`并冲刷流水线，后端中的旧请求仍会继续执行。其返回结果可能在中断处理程序的新访存到来时被错误识别为新请求的响应。

因此增加：

```text
dcache_request_inflight
```

它记录D-Cache是否已经接受了一个跨周期请求。

更新规则为：

```text
reset
    → 清零

dcache_cpu_resp_valid
    → 清零，请求已经完成

dcache_cpu_req_fire
    → 置一，请求已经被D-Cache正式接受

其他情况
    → 保持
```

响应清零的优先级高于请求置位，因此Load hit同时发生request fire和response时不会留下错误的未完成标志。

### 5.2 外部中断的安全接收条件

送入Trap控制单元的外部中断改为：

```text
external_interrupt_pending_effective
    = external_interrupt_pending
      && !dcache_request_inflight
```

最终行为为：

| 情况 | 处理方式 |
| --- | --- |
| 同步异常，如Load/Store未对齐 | 立即Trap，访存请求不会进入D-Cache |
| 外部中断先到，请求尚未接受 | 立即进入中断 |
| D-Cache接受请求后外部中断到来 | 暂时延迟中断，先完成原访问 |
| 原访问完成 | 当前访存正常提交，随后处理仍然pending的中断 |

这里使用时序寄存器记录请求，而没有直接用 `cache_stall`屏蔽中断，从而避免 `trap_enter → req_valid → cache_stall → trap_enter` 的组合逻辑环。

## 6. 移除五级流水线CPU中的旧 DataMemory 通路

### 6.1 这一步为整体设计服务的目的

D-Cache完成暂停、提交和数据返回后，旧 `DataMemory`不再需要承担CPU可见的读取。继续保留两份实际数据存储会造成初始化、检查和Store结果的双重状态，后续也难以判断哪一份才是体系结构上的真实内存。

今天从 `PIPELINED_CPU`的有效硬件结构中移除了旧 `DataMemory`实例，同时取消了只为过渡阶段服务的：

- `legacy_mem_readdata`；
- `MemWrite_commit_mem`；
- Store对旧DataMemory的镜像写入。

`DataMemory.v`文件本身继续保留，因为旧的单周期CPU仍可能使用它。

删除后，五级流水线CPU的数据存储层次变为：

```text
CPU MEM阶段
    ↔ DCache
        ↔ CacheBackingMemory
```

### 6.2 Store为什么不会重复写后端

流水线暂停期间 `dcache_cpu_req_valid`会持续为1，但D-Cache只在：

```text
dcache_cpu_req_fire = dcache_cpu_req_valid
                      && dcache_cpu_req_ready
```

成立时接受请求。接受Store后，D-Cache离开IDLE并拉低CPU侧ready，因此同一条Store不会再次被接收。D-Cache状态机只向后端提交一次写请求，等待完成后再恢复流水线。

## 7. D-Cache 从请求到完成的整体逻辑闭环

### 7.1 Load hit

```text
MEM产生合法Load请求
    → DCache在IDLE比较valid和tag
    → hit并选择对应64位数据
    → 当周期产生cpu_resp_valid和返回数据
    → cache_stall保持为0
    → Load进入MEM/WB
    → 下一周期写回寄存器
```

### 7.2 Load miss

```text
MEM产生合法Load请求
    → DCache接受请求并锁存地址
    → cache_stall=1
    → PC、IF/ID、ID/EX、EX/MEM保持
    → MEM/WB只接收无副作用气泡
    → DCache向后端依次读取4个64位数据
    → 填充完整的32字节Cache Line
    → 写入tag并置valid
    → 返回原Load对应的64位数据
    → cache_stall撤销
    → Load只进入MEM/WB一次
```

### 7.3 Store hit

```text
MEM产生合法Store请求
    → DCache锁存地址、数据和原命中状态
    → cache_stall=1
    → 向CacheBackingMemory写穿透
    → 后端确认完成
    → 更新命中的Cache Line字
    → 返回Store完成响应
    → 流水线恢复
```

### 7.4 Store miss

```text
MEM产生合法Store请求
    → 当前index/tag不命中
    → 不分配、不回填Cache Line
    → 直接向CacheBackingMemory写穿透
    → 后端确认完成
    → 返回Store完成响应
    → 流水线恢复
```

这最终实现了最初确定的教学版本：

```text
直接映射
+ 阻塞式
+ 一次一个未完成请求
+ Write Through
+ Write Hit Update
+ No Write Allocate
```

## 8. 今日测试结论

D-Cache单元功能、CPU—D-Cache集成、Cache miss流水线保持、Load/Store提交、外部中断延迟，以及基础流水线、前递、冒险、分支预测、CSR和Trap整机回归均已通过。

## 9. 今日结束时的完成状态

| 模块或功能 | 当前状态 |
| --- | --- |
| D-Cache地址拆分与直接映射阵列 | 完成 |
| Load hit | 完成 |
| Load miss整行回填 | 完成 |
| 相同index不同tag替换 | 完成 |
| Store写穿透 | 完成 |
| Store hit更新 | 完成 |
| Store miss不分配 | 完成 |
| CPU—D-Cache握手 | 完成 |
| D-Cache—后端握手 | 完成 |
| Cache miss冻结流水线 | 完成 |
| MEM/WB等待期间副作用屏蔽 | 完成 |
| D-Cache返回数据接管Load | 完成 |
| miss期间外部中断延迟 | 完成 |
| 旧DataMemory退出五级流水线数据通路 | 完成 |
| 五级流水线整机回归 | 通过 |

至此，当前规划范围内的基础 D-Cache 已经形成完整闭环。下一阶段开始独立实现只读、直接映射、阻塞式 I-Cache，完成后再将取指通路从组合式 `IR`迁移到具有miss等待能力的I-Cache。

## 10. 启动 I-Cache 独立实现：建立阵列、地址查询与 CPU 侧请求入口

### 10.1 今日 I-Cache 修改顺序

```text
确定I-Cache的CPU侧和后端接口
    → 复用D-Cache的8行、每行32字节几何结构
    → 建立valid、tag和64位数据阵列
    → 将64位取指地址拆分为tag、index和行内偏移
    → 从一个64位后端数据中选择32位指令
    → 建立CPU侧ready/valid命中响应
    → 定义四状态阻塞式回填框架
    → 在miss被正式接受时锁存原取指地址
    → 进入REFILL_REQ，等待下一阶段实现后端读取
```

今天开始独立实现 `ICache.v`，暂时不连接 CPU。这样可以先验证只读Cache自身的查询和握手逻辑，避免将取指暂停、分支重定向和Trap冲刷问题同时引入。

### 10.2 I-Cache 接口框架

CPU侧接口包括：

| 信号 | 方向 | 作用 |
| --- | --- | --- |
| `cpu_req_valid` | CPU到I-Cache | 当前存在有效取指请求 |
| `cpu_req_addr[63:0]` | CPU到I-Cache | 当前取指PC字节地址 |
| `cpu_req_ready` | I-Cache到CPU | I-Cache能否接受该请求 |
| `cpu_resp_valid` | I-Cache到CPU | 该次取指已经完成 |
| `cpu_resp_instr[31:0]` | I-Cache到CPU | 返回的32位指令 |

后端接口包括：

| 信号 | 方向 | 作用 |
| --- | --- | --- |
| `mem_req_valid` | I-Cache到后端 | 发出64位读取请求 |
| `mem_req_addr[63:0]` | I-Cache到后端 | 后端读取字节地址 |
| `mem_req_ready` | 后端到I-Cache | 后端能够接受请求 |
| `mem_resp_valid` | 后端到I-Cache | 读取结果已经返回 |
| `mem_resp_rdata[63:0]` | 后端到I-Cache | 返回的64位数据 |

I-Cache只读，因此CPU侧没有Store输入，后端也不需要由I-Cache输出写使能和写数据。今天将原先误写的响应输入名称修正为 `mem_resp_valid`，使接口含义与请求—响应协议一致。

### 10.3 I-Cache 几何结构与地址拆分

第一版I-Cache采用与D-Cache相同的基础几何结构：

```text
直接映射
8条Cache Line
每条32字节
每条包含4个64位后端数据
总容量256字节
```

64位取指地址拆分为：

| 地址位 | 字段 | 作用 |
| --- | --- | --- |
| `[63:8]` | tag | 判断当前index中保存的是哪个内存块 |
| `[7:5]` | index | 选择8条Cache Line中的一条 |
| `[4:3]` | 64位word offset | 选择一条Cache Line中的4个64位数据之一 |
| `[2]` | half select | 选择64位数据的低32位或高32位指令 |
| `[1:0]` | byte offset | 检查指令地址是否按4字节对齐 |

对应关系为：

```text
PC[2] = 0
    → 选择selected_word64[31:0]

PC[2] = 1
    → 选择selected_word64[63:32]
```

同时生成：

```text
cpu_line_base = 将CPU请求地址低5位清零
```

用于后续从32字节Cache Line起始地址依次读取4个64位数据。地址低2位的byte offset已经修正为2位宽度，与32位指令对齐要求一致。

### 10.4 Cache阵列与复位行为

建立了三类阵列：

```text
valid_array[8]
tag_array[8]
data_array[8][4]
```

其中：

- `valid_array[index]`表示该Cache Line是否包含有效内容；
- `tag_array[index]`保存该行对应的地址tag；
- `data_array[index][word_offset]`保存一个64位后端读取结果。

复位时只清空全部valid位：

```text
reset
    → valid_array全部置0
    → state返回STATE_IDLE
```

tag和data阵列不要求在复位时清零，因为valid为0时这些内容不会参与有效命中。

### 10.5 命中判断与32位指令选择

基础Line命中条件为：

```text
cpu_line_hit = valid_array[cpu_addr_index]
                && tag_array[cpu_addr_index] == cpu_addr_tag
```

完整指令命中条件还要求：

```text
cpu_req_valid=1
地址按4字节对齐
Cache Line命中
```

命中后先根据 `[4:3]`选择一个64位数据：

```text
selected_word64 = data_array[index][word_offset]
```

再根据地址位 `[2]`得到CPU所需的32位指令。这个两级选择把64位后端读取粒度转换成了RISC-V当前实现使用的32位固定长度指令。

### 10.6 CPU侧命中握手

I-Cache仅在以下条件下能够接受新请求：

```text
没有复位
&& state == STATE_IDLE
&& 请求地址按4字节对齐
```

正式请求接受事件定义为：

```text
cpu_req_fire = cpu_req_valid && cpu_req_ready
```

命中时：

```text
state == STATE_IDLE
&& cpu_instr_hit
    → cpu_resp_valid=1
    → cpu_resp_instr输出命中的32位指令
```

因此I-Cache hit可以在请求被接受的同一周期完成，不需要进入额外状态，也不需要锁存地址。

`cpu_req_ready`没有依赖hit。这样miss请求同样能够被I-Cache正式接受，随后才能启动回填。

### 10.7 miss请求锁存与状态机入口

I-Cache定义了四个状态：

| 状态 | 作用 |
| --- | --- |
| `STATE_IDLE` | 接受CPU请求并查询valid/tag |
| `STATE_REFILL_REQ` | 准备向后端发送一次64位读取请求 |
| `STATE_REFILL_WAIT` | 请求已被接受，等待后端返回数据 |
| `STATE_RESP` | 整条Cache Line填充完成，向CPU完成原取指请求 |

miss被正式接受的事件为：

```text
cpu_instr_miss_fire = cpu_req_fire && !cpu_line_hit
```

发生miss时：

```text
锁存cpu_req_addr到req_addr_reg
    → refill_word_index清零
    → state进入STATE_REFILL_REQ
```

之后所有回填地址、阵列写入位置和最终指令选择都将使用锁存后的 `req_addr_reg`，而不是继续依赖CPU实时提供的PC。

锁存地址也建立了对应的：

```text
req_tag
req_index
req_word_offset
req_half_select
req_line_base
```

这组字段服务于后续多周期回填；`cpu_addr_*`则只服务于IDLE阶段的实时命中查询。

### 10.8 当前完成状态与下一阶段

| I-Cache部分 | 当前状态 |
| --- | --- |
| CPU侧接口定义 | 完成 |
| 后端只读接口定义 | 完成 |
| Cache参数和阵列 | 完成 |
| 地址拆分 | 完成 |
| valid/tag命中判断 | 完成 |
| 64位数据中选择32位指令 | 完成 |
| CPU侧hit握手 | 完成 |
| 四状态FSM定义 | 完成 |
| miss请求地址锁存 | 完成 |
| `refill_word_index`建立 | 完成 |
| miss后端读取请求 | 尚未实现 |
| `REFILL_REQ/WAIT/RESP`状态转换 | 尚未实现 |
| Cache Line数据写入和tag提交 | 尚未实现 |
| miss完成后的32位指令响应 | 尚未实现 |
| I-Cache后端存储器 | 尚未实现 |
| 与CPU IF阶段连接 | 尚未进行 |

当前代码已经完成语法检查。下一阶段将使用 `req_line_base`和 `refill_word_index`生成4个后端读取地址，建立 `mem_req_valid/ready` 与 `mem_resp_valid` 的握手，并依次填充完整Cache Line。

# 2026/10/19：完成独立 I-Cache 的后端回填、miss 响应与单元闭环

## 今日修改顺序（从 miss 入口到完整取指响应）

```text
使用锁存地址生成32字节Cache Line首地址
    → 使用refill_word_index生成+0、+8、+16、+24四个后端读地址
    → 在REFILL_REQ中保持mem_req_valid，直到后端正式接收请求
    → 请求被接收后进入REFILL_WAIT，等待对应64位数据返回
    → 将返回数据写入目标Cache Line的对应word
    → 前三个word返回后递增计数并继续发起下一次读取
    → 第四个word返回后进入STATE_RESP
    → 使用锁存的原取指地址选择目标32位指令并响应CPU
    → 写入新tag、置位valid并返回IDLE
    → 完成独立I-Cache测试，确认hit、miss、回填和替换闭环
```

昨天完成了 I-Cache 的接口、阵列、地址拆分、命中查询以及 miss 请求地址锁存。今天继续完成多周期部分，使 I-Cache 能够把一次取指 miss 转换为四次后端读取，在完整 Cache Line 返回后完成原取指请求。至此，I-Cache 已经从只能判断 hit/miss 的查询结构，发展为能够独立处理变延迟后端访问的阻塞式 Cache。

## 1. 生成整行回填所需的四个后端读取地址

### 1.1 这一步为整体设计服务的目的

I-Cache 的 Cache Line 为32字节，而后端一次返回64位，即8字节。因此一次 miss 不能通过一次后端读取完成，必须从目标 Cache Line 的起始地址连续读取四个64位数据。

请求被接受时已经将原PC保存到 `req_addr_reg`，由它得到：

```text
req_line_base = {req_addr_reg[63:5], 5'b0}
```

这会清除地址低5位，使地址对齐到32字节Cache Line首地址。随后使用2位 `refill_word_index`记录当前正在处理该行中的第几个64位数据：

```text
refill_word_byte_offset = refill_word_index × 8
mem_req_addr = req_line_base + refill_word_byte_offset
```

因此四次请求地址依次为：

| `refill_word_index` | 后端读取地址 | 对应Cache Line位置 |
| ---: | --- | --- |
| 0 | `req_line_base + 0` | `data_array[req_index][0]` |
| 1 | `req_line_base + 8` | `data_array[req_index][1]` |
| 2 | `req_line_base + 16` | `data_array[req_index][2]` |
| 3 | `req_line_base + 24` | `data_array[req_index][3]` |

`refill_word_index`在一次新 miss 被接受时清零，只在当前64位数据已经返回后递增。这样请求地址和阵列写入位置始终表示同一个word。

### 1.2 后端请求接口及作用

| 信号 | 方向 | 本阶段的作用 |
| --- | --- | --- |
| `mem_req_valid` | I-Cache到后端 | 表示当前有一个64位读取请求等待接收 |
| `mem_req_addr[63:0]` | I-Cache到后端 | 给出当前回填word的字节地址 |
| `mem_req_ready` | 后端到I-Cache | 表示后端本周期能够接收请求 |
| `mem_req_fire` | I-Cache内部事件 | `valid && ready`，表示当前读取请求只被正式接收一次 |

`mem_req_valid`只在 `STATE_REFILL_REQ`中有效。如果后端暂时没有准备好，状态、锁存地址和 `refill_word_index`都保持不变，因此 `mem_req_valid`和 `mem_req_addr`能够稳定保持，直到握手发生。

## 2. 区分“后端接收请求”和“后端返回数据”

### 2.1 这一步完善了哪部分整体逻辑

后端的 `mem_req_ready`只表示读取请求已经被接收，并不表示数据已经返回。真实存储器可以在接受请求后等待多个周期，因此 I-Cache 必须把请求握手和响应握手分成两个阶段：

```text
STATE_REFILL_REQ
    → 等待mem_req_valid && mem_req_ready
    → 后端正式接收当前word读取请求

STATE_REFILL_WAIT
    → 等待mem_resp_valid
    → 当前word数据真正返回
```

响应消费事件定义为：

```text
mem_resp_fire = !reset
                && state == STATE_REFILL_WAIT
                && mem_resp_valid
```

把状态条件包含在事件中，可以保证 I-Cache 只在确实等待返回数据时使用 `mem_resp_rdata`，不会把其他状态中出现的响应信号误当成当前回填数据。

### 2.2 返回数据如何写入Cache Line

后端响应接口为：

| 信号 | 方向 | 作用 |
| --- | --- | --- |
| `mem_resp_valid` | 后端到I-Cache | 表示当前64位读取结果有效 |
| `mem_resp_rdata[63:0]` | 后端到I-Cache | 当前返回的64位数据 |

发生 `mem_resp_fire`时执行：

```text
data_array[req_index][refill_word_index] ← mem_resp_rdata
```

其中 `req_index`来自 miss 时锁存的原取指地址，`refill_word_index`指出当前返回的是一行中的哪个word。CPU即使在请求被接受后改变实时PC，也不会改变回填目标。

前三个word返回时：

```text
写入当前word
    → refill_word_index加1
    → 返回STATE_REFILL_REQ
    → 发出下一次后端读取
```

第四个word返回时：

```text
写入data_array[req_index][3]
    → 不再继续发出读取
    → 进入STATE_RESP
```

由此形成四次严格串行的“请求—等待—返回”过程，符合当前阻塞式、一次一个未完成后端访问的教学范围。

## 3. 完成四状态 I-Cache 状态机

### 3.1 各状态在完整流程中的职责

| 状态 | 输入或判断 | 主要动作 | 下一状态 |
| --- | --- | --- | --- |
| `STATE_IDLE` | CPU请求、地址valid/tag命中结果 | hit直接响应；miss锁存地址并清零回填计数 | hit保持IDLE；miss进入REFILL_REQ |
| `STATE_REFILL_REQ` | `mem_req_ready` | 保持后端读取请求，等待请求握手 | 握手后进入REFILL_WAIT |
| `STATE_REFILL_WAIT` | `mem_resp_valid` | 保存返回的64位数据 | 前三个word回到REFILL_REQ；最后一个进入RESP |
| `STATE_RESP` | 已经完成的整条Cache Line | 返回原取指指令，提交tag和valid | 返回IDLE |

完整 miss 状态路径为：

```text
IDLE
    → REFILL_REQ → REFILL_WAIT
    → REFILL_REQ → REFILL_WAIT
    → REFILL_REQ → REFILL_WAIT
    → REFILL_REQ → REFILL_WAIT
    → RESP
    → IDLE
```

请求状态和等待状态交替出现，是因为每个64位数据都有自己独立的一次请求握手和一次响应等待。`cpu_req_ready`只在IDLE有效，因此整个回填期间不会再接受第二个取指请求，维持阻塞式Cache的一次一个请求约束。

状态机增加了非法状态的默认恢复路径，使异常状态能够回到 `STATE_IDLE`。

## 4. 使用锁存请求完成 miss 后的CPU响应

### 4.1 这一步为请求—完成关系服务的目的

当以下条件成立时：

```text
cpu_req_fire = cpu_req_valid && cpu_req_ready
```

I-Cache已经正式接受CPU请求。此后CPU有权撤销 `cpu_req_valid`或改变 `cpu_req_addr`，因此 miss 完成时不能继续使用实时CPU地址选择指令，必须使用此前保存的 `req_addr_reg`。

锁存地址拆分得到：

| 字段 | 作用 |
| --- | --- |
| `req_index` | 选择刚刚完成回填的Cache Line |
| `req_word_offset` | 从该行选择一个64位word |
| `req_half_select` | 从64位word选择高32位或低32位指令 |
| `req_tag` | 在回填完成时写入目标tag |

因此 `STATE_RESP`中的返回路径为：

```text
data_array[req_index][req_word_offset]
    → 根据req_half_select选择[31:0]或[63:32]
    → cpu_resp_instr
```

这与IDLE命中路径形成两套地址来源明确的数据选择：

```text
IDLE hit
    → 使用当前cpu_req_addr拆分字段

miss完成响应
    → 使用锁存req_addr_reg拆分字段
```

### 4.2 CPU响应信号

`cpu_resp_valid`现在覆盖两种完成情况：

```text
没有复位
&& (
       IDLE中的实时hit
       || STATE_RESP中的miss完成
   )
```

复位条件作用于整个响应表达式，确保复位期间两种路径都不会对CPU产生有效响应。

在 `STATE_RESP`结束的时钟沿：

```text
tag_array[req_index] ← req_tag
valid_array[req_index] ← 1
state ← STATE_IDLE
```

至此，原 miss 请求获得一次正式完成响应，同时新 Cache Line 成为后续取指可以命中的有效副本。

### 4.3 本阶段修正的锁存理解问题

`req_index`、`req_word_offset`和 `req_half_select`都是从 `req_addr_reg`组合拆分得到的 `wire`。只需在 miss 接受时锁存完整的：

```text
req_addr_reg ← cpu_req_addr
```

之后这些字段便会自动反映锁存地址对应的值，不需要、也不能在时序块中再次对这些 `wire`赋值。这样既避免重复保存同一信息，也保证所有字段始终来自同一个完整地址。

## 5. I-Cache当前已经形成的完整运行逻辑

### 5.1 取指命中

```text
CPU给出有效且4字节对齐的PC
    → I-Cache在IDLE读取index对应的valid和tag
    → tag命中
    → 使用word offset选择64位数据
    → 使用half select选择32位指令
    → 当周期产生cpu_resp_valid和cpu_resp_instr
    → 不访问后端，状态保持IDLE
```

### 5.2 取指未命中

```text
CPU给出有效且4字节对齐的PC
    → I-Cache在IDLE发现valid/tag不命中
    → 正式接受请求并锁存PC
    → 对齐到32字节Cache Line首地址
    → 向后端依次读取+0、+8、+16、+24
    → 四个64位数据写入同一Cache Line
    → 使用锁存PC选择原请求对应的32位指令
    → STATE_RESP向CPU报告完成
    → 写入tag并置valid
    → 返回IDLE
```

### 5.3 相同index、不同tag替换

```text
新地址选择已经有效的同一个index
    → tag不同，因此产生miss
    → 完整读取新地址对应的32字节Cache Line
    → 覆盖该index中的四个data word
    → 更新tag并保持valid=1
```

当前I-Cache为只读Cache，因此替换时没有dirty bit，也不需要写回旧行。

## 6. 今日测试结论

已完成独立 I-Cache 测试，复位、未对齐请求屏蔽、首次 miss、四次64位回填、后端地址顺序、请求地址锁存、命中、高低32位指令选择、相同index不同tag替换以及替换后旧tag再次miss均通过，共通过12项检查。

## 7. 今日结束时的完成状态

| I-Cache部分 | 当前状态 |
| --- | --- |
| CPU侧ready/valid接口 | 完成 |
| 地址拆分与直接映射阵列 | 完成 |
| 32位指令高低半字选择 | 完成 |
| IDLE命中响应 | 完成 |
| miss请求地址锁存 | 完成 |
| 后端读取请求握手 | 完成 |
| 四个64位word串行回填 | 完成 |
| Cache Line数据、tag和valid提交 | 完成 |
| miss完成响应 | 完成 |
| 相同index不同tag替换 | 完成 |
| 复用CacheBackingMemory进行独立验证 | 通过 |
| I-Cache独立功能闭环 | 完成 |
| I-Cache接入CPU IF阶段 | 尚未进行 |
| I-Cache miss期间冻结PC和前端 | 尚未进行 |
| 分支重定向或Trap期间旧取指响应处理 | 尚未进行 |
| I-Cache与D-Cache共享后端时的端口或仲裁方案 | 尚未确定 |

至此，独立 I-Cache 已经能够正确处理立即命中和多周期 miss，并能够在CPU请求信号改变后继续依靠锁存地址完成原访问。下一阶段将开始规划 I-Cache 与 CPU IF 阶段的连接，把当前组合式指令读取替换为具有请求、等待和完成关系的取指通路；同时需要明确 I-Cache 与 D-Cache 的后端连接方式，以及取指miss、分支重定向和Trap冲刷之间的优先级。

# 2026/10/20：完成 I-Cache 与五级流水线 CPU 的顶层集成

## 今日修改顺序（从独立 I-Cache 到完整取指通路）

```text
在顶层建立CPU与I-Cache之间的请求和响应信号
    → 使用current_pc_if作为取指请求地址
    → 例化I-Cache并连接独立的指令CacheBackingMemory
    → 使用icache_request_inflight记录尚未完成的miss
    → 使用icache_pending_pc保存未完成请求所属的原始PC
    → 区分当周期hit响应和多周期miss完成响应
    → 只把与当前PC匹配的有效响应送入IF阶段
    → I-Cache没有可用响应时保持PC，并向IF/ID送入无效气泡
    → I-Cache响应可用时锁存指令并允许PC产生下一次取指地址
    → 让分支、跳转、Trap和mret重定向优先于I-Cache等待
    → 屏蔽重定向周期的旧响应，并丢弃重定向后的迟到响应
    → 将原IR模块退出顶层取指数据通路
    → 在测试文件中向指令后端存储器装入程序
    → 完成CPU—I-Cache顶层专项测试
```

昨天已经完成了独立 I-Cache 的 hit、miss、整行回填和替换功能。今天的工作是把它接入五级流水线，使 IF 阶段不再默认“每个周期都能立即获得指令”，而是根据 I-Cache 的请求接受和响应完成信号决定何时产生有效指令、何时保持 PC，以及控制流重定向后是否能够采用返回结果。至此，CPU 的取指端也开始支持执行时间不固定的模块。

## 1. 建立 CPU 与 I-Cache 的顶层请求通路

### 1.1 这一步为整体设计服务的目的

原取指通路直接根据 PC 组合读出指令，不存在请求是否被接受、结果是否已经返回的概念。接入 I-Cache 后，当前 PC 只能表示 CPU 希望访问的地址，只有通过握手，I-Cache 才真正接收了这次取指请求。

CPU 到 I-Cache 的连接为：

| 信号 | 来源 | 去向 | 作用 |
| --- | --- | --- | --- |
| `icache_cpu_req_valid` | CPU顶层 | I-Cache | 表示当前存在取指请求；复位和控制冲刷周期无效 |
| `icache_cpu_req_addr` | `current_pc_if` | I-Cache | 当前准备取指的PC字节地址 |
| `icache_cpu_req_ready` | I-Cache | CPU顶层 | 表示I-Cache当前能够接收请求 |
| `icache_cpu_req_fire` | 顶层内部 | 顶层请求跟踪逻辑 | `valid && ready`，表示请求被正式接收 |

请求入口的当前关系为：

```text
icache_cpu_req_valid = !reset && !control_flush_mem
icache_cpu_req_addr  = current_pc_if
icache_cpu_req_fire  = icache_cpu_req_valid && icache_cpu_req_ready
```

`control_flush_mem`有效的周期不再发送当前PC请求，是因为该周期的 `next_pc`将被异常入口、返回地址或控制转移目标替换，继续接受旧PC请求没有意义。

## 2. 建立响应通路，并区分 hit 与尚未完成的 miss

### 2.1 I-Cache 返回给顶层的信号

| 信号 | 来源 | 去向 | 作用 |
| --- | --- | --- | --- |
| `icache_cpu_resp_valid` | I-Cache | 顶层响应判断 | 表示本周期存在一条完成的取指响应 |
| `icache_cpu_resp_instr[31:0]` | I-Cache | IF阶段 | 返回的32位指令 |
| `icache_resp_usable` | 顶层内部 | PC与IF/ID控制 | 表示该响应不仅有效，而且属于当前仍然需要的PC |

I-Cache hit 可以在请求所在周期直接响应；miss 则需要经过多次后端读取后再响应。顶层增加了：

```text
icache_request_inflight
icache_pending_pc
```

其中：

- `icache_request_inflight`表示已经接受了一次不能当周期完成的取指请求；
- `icache_pending_pc`保存这次未完成请求所属的原始PC；
- 请求握手且当周期没有响应时，置位inflight并锁存当前PC；
- I-Cache产生完成响应时，清除inflight。

`icache_pending_pc`与 I-Cache 内部的 `req_addr_reg`职责不同：

| 保存位置 | 保存内容 | 服务对象 |
| --- | --- | --- |
| I-Cache内部 `req_addr_reg` | miss时的原始取指地址 | 回填地址生成、Cache阵列写入及原请求指令选择 |
| CPU顶层 `icache_pending_pc` | CPU发出该miss时对应的PC | 判断迟到响应是否仍属于当前取指方向 |

不能使用 `icache_mem_req_addr`代替 `icache_pending_pc`，因为前者在回填过程中依次变化为Cache Line的 `+0、+8、+16、+24`四个后端读取地址，并不始终代表原始取指PC。

### 2.2 两类可采用响应

当周期命中响应要求当前没有未完成miss：

```text
icache_hit_resp_usable =
    icache_cpu_resp_valid && !icache_request_inflight
```

miss完成响应除要求响应有效外，还要求锁存PC仍然等于当前PC：

```text
icache_miss_resp_usable =
    icache_cpu_resp_valid
    && icache_request_inflight
    && icache_pending_pc == current_pc_if
```

最终只有在没有发生控制冲刷，并且以上任一路径成立时，响应才可进入流水线：

```text
icache_resp_usable =
    !control_flush_mem
    && (icache_hit_resp_usable || icache_miss_resp_usable)
```

由此把“I-Cache返回了一条指令”和“CPU当前仍然需要这条指令”分成了两个不同概念。

## 3. 用 I-Cache 完成信号控制 IF 阶段

### 3.1 指令与valid的来源

顶层取指结果现在直接来自 I-Cache：

```text
instruction_if = icache_resp_usable ? icache_cpu_resp_instr : 0
valid_if       = icache_resp_usable
```

只有可采用响应出现时，IF/ID才会得到一条有效指令。等待期间即使 `instruction_if`为0，也不会被解释为真实指令，因为同时传入的 `valid_if`为0。

原来的 IR 实例已经退出顶层取指数据通路，避免同一个 IF 指令同时存在两套来源。`IR.v`是否保留为历史模块不影响当前CPU，顶层已经不再依靠它完成取指。

### 3.2 miss期间PC和流水线如何运行

PC写使能现在为：

```text
PCwrite_final =
    control_flush_mem
    || (PCwrite_hazard && !dcache_stall && icache_resp_usable)
```

普通顺序取指只有在以下条件同时成立时才允许 PC 前进：

```text
数据冒险单元允许PC写入
&& D-Cache没有冻结整个流水线
&& I-Cache已经返回当前PC所需的指令
```

I-Cache miss等待期间，`icache_resp_usable=0`，因此 PC 保持原值。IF/ID没有因为 I-Cache miss而长期保存上一条有效指令，而是接收 `valid_if=0`的气泡，使已经取得的旧指令可以继续向后级排空，同时避免同一条IF指令被重复执行。I-Cache完成后，返回指令在一个时钟沿进入IF/ID，PC也在同一个时钟沿更新到下一取指地址。

这形成了如下关系：

```text
没有取指响应
    → PC保持
    → IF/ID得到无效气泡
    → 流水线中已有指令继续向后排空

当前取指响应可用
    → IF/ID锁存返回指令并置valid
    → PC前进到顺序地址或预测地址
```

## 4. 连接 I-Cache 的独立后端存储器

### 4.1 本阶段采用的后端结构

顶层例化了第二个 `CacheBackingMemory`，专门作为 I-Cache 的只读后端：

```text
I-Cache
    → icache_mem_req_valid / icache_mem_req_addr
    → u_icache_backing_memory
    → icache_mem_resp_valid / icache_mem_resp_rdata
    → I-Cache
```

I-Cache后端实例的写使能固定为0，写数据固定为0。D-Cache继续连接自己的 `u_dcache_backing_memory`。当前两个Cache各自拥有一个后端模型，因此不需要增加总线仲裁器，可以先集中验证取指和访存的变延迟控制。未来如果把二者连接到统一内存端口，再单独增加仲裁逻辑。

### 4.2 程序如何装入

`CacheBackingMemory`是通用存储器模型，不在模块内部固定某个测试程序，CPU顶层也不负责写入程序。测试时由testbench直接初始化：

```text
dut.u_icache_backing_memory.memory[地址下标]
```

一个64位后端word保存两条32位指令：低32位对应较低的4字节地址，高32位对应下一条指令地址。PC只负责给出读取地址，不是被写入存储器的数据。

## 5. 处理分支、跳转、异常和中断期间的旧取指响应

### 5.1 控制重定向具有更高优先级

`control_flush_mem`覆盖：

```text
JAL
JALR
分支预测错误
trap_enter
mret
```

它在 `PCwrite_final`中拥有独立的最高优先路径，因此即使 I-Cache 正在 miss，没有产生 `icache_resp_usable`，PC仍能立即改写为跳转目标、`mtvec`或 `mepc`。

控制冲刷周期同时执行：

```text
不接受当前旧PC的新取指请求
    → 不采用本周期出现的I-Cache响应
    → 冲刷流水线中的错误路径指令
    → PC写入重定向目标
```

### 5.2 已经发出的旧请求如何处理

当前 I-Cache 和后端没有取消接口，因此重定向发生前已经接受的miss仍会完成整行回填。回填Cache Line本身不会修改寄存器或内存，属于没有架构副作用的微结构动作，可以允许它完成。

旧请求返回时，如果PC已经改为新目标：

```text
icache_pending_pc != current_pc_if
    → icache_miss_resp_usable = 0
    → valid_if = 0
    → 旧指令不会进入有效流水线
```

旧miss完成、I-Cache重新回到IDLE后，CPU再为当前重定向PC发起新请求。当前阻塞式设计因此保证功能正确，但中断或跳转目标可能需要等待旧回填结束后才能开始取指，这是本教学版本允许的性能代价。

### 5.3 I-Cache与D-Cache在异常/中断处理上的区别

D-Cache请求可能包含Store写内存或Load写回等架构副作用，因此顶层需要用 `~trap_enter`屏蔽异常指令的访存与提交，并在 `dcache_request_inflight`期间暂缓外部中断，避免丢失已经发出的真实访存。

I-Cache只读取指令，没有架构副作用，所以不需要用 `icache_request_inflight`屏蔽外部中断。它需要保证的是：重定向能够优先改变PC，错误路径响应不能进入流水线。当前的 `control_flush_mem`、`icache_pending_pc`和 `icache_resp_usable`已经共同完成这项工作。

## 6. 集成后的完整取指流程

### 6.1 取指命中

```text
current_pc_if形成取指请求
    → I-Cache在IDLE接受请求
    → valid和tag命中
    → 当周期返回32位指令
    → 顶层判定hit响应可用
    → instruction_if得到返回指令，valid_if=1
    → 时钟沿将指令锁存到IF/ID
    → PC更新到下一取指地址
```

### 6.2 取指miss

```text
current_pc_if形成取指请求
    → I-Cache接受请求但当周期没有响应
    → 顶层置位icache_request_inflight并锁存icache_pending_pc
    → PC保持，IF/ID接收无效气泡
    → I-Cache完成四次后端读取和整行回填
    → 返回原PC对应的32位指令
    → pending PC仍等于current_pc_if，因此响应可用
    → IF/ID锁存该指令，PC恢复前进
```

### 6.3 miss期间发生重定向

```text
旧PC的I-Cache miss尚未完成
    → MEM阶段产生跳转、预测修正、Trap或mret
    → control_flush_mem置1
    → PC立即写入重定向目标，流水线被冲刷
    → 旧miss继续完成，但返回PC与当前PC不一致
    → 顶层丢弃旧响应
    → I-Cache空闲后重新请求重定向目标
```

## 7. 今日测试结论

新增并运行了 `PIPELINED_CPU_ICache_tb.v`顶层专项测试，仿真在78个周期内通过。测试确认了首次冷miss、同一Cache Line连续hit、每条Cache Line四次后端读取、等待期间PC保持、无响应时IF/ID气泡、JAL重定向、错误路径冲刷、旧miss迟到响应丢弃、跳转目标重新取指，以及有效指令只提交一次。测试程序共产生3次Cache Line填充和12次64位后端读取，结果与预期一致。

## 8. 今日结束时的完成状态

| I-Cache部分 | 当前状态 |
| --- | --- |
| I-Cache独立hit、miss与整行回填 | 完成 |
| CPU到I-Cache请求通路 | 完成 |
| I-Cache到CPU响应通路 | 完成 |
| `icache_request_inflight`请求跟踪 | 完成 |
| `icache_pending_pc`原取指PC锁存 | 完成 |
| hit响应与miss完成响应区分 | 完成 |
| 只采用与当前PC匹配的响应 | 完成 |
| I-Cache miss期间PC保持 | 完成 |
| 无取指响应时向IF/ID注入无效气泡 | 完成 |
| I-Cache响应接管 `instruction_if/valid_if` | 完成 |
| 原IR退出顶层取指数据通路 | 完成 |
| I-Cache独立后端存储器连接 | 完成 |
| 测试文件向指令后端装入程序 | 完成 |
| 分支、跳转、Trap和mret重定向优先级 | 完成 |
| 旧路径迟到响应丢弃 | 完成 |
| CPU—I-Cache顶层专项测试 | 通过 |
| I-Cache接入CPU IF阶段 | 完成 |
| 当前规划范围内的阻塞式I-Cache闭环 | 完成 |
| I-Cache与D-Cache统一后端及仲裁 | 后续可选扩展 |

至此，当前规划范围内的基础 I-Cache 已经完成从独立模块到五级流水线顶层的完整闭环。CPU的取指端已经具有请求、等待和完成关系；取指命中时正常推进，取指miss时保持PC并排空旧指令，控制流重定向时能够优先改变PC并拒绝旧路径返回结果。D-Cache负责MEM阶段的变延迟数据访问，I-Cache负责IF阶段的变延迟指令访问，两条通路目前分别连接独立后端，为后续学习统一存储层次、总线仲裁以及更复杂的非阻塞取指结构保留了清晰的扩展边界。

# 2026/11/09：支持 Clang 递归 Fibonacci，并修复 D-Cache 停顿期间的流水线数据冒险

## 本阶段 CPU RTL 修改范围

本阶段使用 Clang 将递归 Fibonacci 编译为 RV64I 程序。与此前的 `return 42` 和普通整数加法相比，该程序新增使用了 `BLT` 和 `ADDIW`，并通过递归函数连续执行栈指针更新、`SD/LD`、函数调用和返回。

本次只记录 CPU RTL 的修改，不记录 testbench 代码。修改涉及：

```text
rtl/control/Control.v
rtl/control/ALUControl.v
rtl/datapath/Immgen.v
rtl/datapath/Register.v
rtl/memory/MEM_WB.v
rtl/PIPELINED_CPU.v
```

## 1. 增加 BLT 指令的主控制译码

### 1.1 修改前

分支 opcode `1100011`只接受 `BEQ` 和 `BNE`：

```verilog
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
```

### 1.2 修改后

将 `funct3=100`纳入合法分支编码：

```verilog
7'b1100011: begin // BEQ/BNE/BLT
    case (instruction[14:12])
        3'b000, 3'b001, 3'b100: begin
            Branch             = 1'b1;
            ALUOp              = 2'b01;
            UseRs1             = 1'b1;
            UseRs2             = 1'b1;
            IllegalInstruction = 1'b0;
        end
        default: begin end
    endcase
end
```

`BLT`仍属于 B-type 指令，因此立即数生成和分支目标地址计算继续复用原有 B-type 通路。

## 2. 根据 funct3 区分相等比较和有符号小于比较

### 2.1 修改前

所有分支都统一选择减法：

```verilog
case(ALUOp)
    2'b00: ALUControl = 4'b0010;
    2'b01: ALUControl = 4'b0110;
```

该逻辑可以通过结果是否为零判断 `BEQ/BNE`，但不能判断两个有符号数的大小关系。

### 2.2 修改后

在分支类 `ALUOp=01`内部继续检查 `funct3`：

```verilog
2'b01: begin
    case(instruction[14:12])
        3'b000, 3'b001: ALUControl = 4'b0110; // BEQ/BNE: subtract
        3'b100:         ALUControl = 4'b0100; // BLT: signed less-than
        default:        ALUControl = 4'b1111;
    endcase
end
```

现有 ALU 的 `4'b0100`执行：

```verilog
ALUResult = ($signed(A) < $signed(B)) ? 64'd1 : 64'd0;
```

因此 `BLT`成立时 ALU 结果为1、`Zero=0`；不成立时结果为0、`Zero=1`。

## 3. 在 MEM 阶段增加 BLT 的实际跳转判断

### 3.1 修改前

顶层只组合 `BEQ` 和 `BNE`的结果：

```verilog
wire beq_taken_mem =
    Branch_mem &&
    (instruction_mem[14:12] == 3'b000) &&
    zero_mem;

wire bne_taken_mem =
    Branch_mem &&
    (instruction_mem[14:12] == 3'b001) &&
    !zero_mem;

wire branch_taken_mem = beq_taken_mem || bne_taken_mem;
```

### 3.2 修改后

加入 `BLT`分支条件：

```verilog
wire blt_taken_mem =
    Branch_mem &&
    (instruction_mem[14:12] == 3'b100) &&
    !zero_mem;

wire branch_taken_mem =
    beq_taken_mem || bne_taken_mem || blt_taken_mem;
```

这里的 `!zero_mem`不是直接比较两个源寄存器是否不相等，而是检查上一节有符号小于比较的结果是否为1。

## 4. 增加 ADDIW 的主控制译码

### 4.1 修改前

主控制器没有 `0011011`（OP-IMM-32）分支，因此 Clang 生成的 `ADDIW`会保持默认非法指令状态：

```verilog
IllegalInstruction = 1'b1;
```

### 4.2 修改后

只接受当前需要的 `funct3=000`，其他 OP-IMM-32 编码仍保持非法：

```verilog
7'b0011011: begin // ADDIW
    if (instruction[14:12] == 3'b000) begin
        ALUOp = 2'b10;
        Regwrite = 1'b1;
        ALUSrc = 1'b1;
        UseRs1 = 1'b1;
        IllegalInstruction = 1'b0;
    end
end
```

信号含义为：读取 `rs1`、选择立即数作为 ALU 的 B 输入、计算结果写入 `rd`。

## 5. 增加 ADDIW 的立即数生成

### 5.1 修改前

I-type 立即数生成只覆盖普通 OP-IMM：

```verilog
7'b0010011:
    instruction64 = {{52{instruction[31]}}, instruction[31:20]};
```

### 5.2 修改后

为 OP-IMM-32 增加相同的12位符号扩展：

```verilog
7'b0010011:
    instruction64 = {{52{instruction[31]}}, instruction[31:20]};

7'b0011011:
    instruction64 = {{52{instruction[31]}}, instruction[31:20]};
```

这样 `addiw a0,s1,-2`中的 `-2`会被扩展为64位补码，再送入 ALU。

## 6. ADDIW 复用已有的32位加法与符号扩展通路

### 6.1 修改前

`ALUControl`没有处理 opcode `0011011`：

```verilog
2'b10: begin
    case(instruction[6:0])
        // 原有 opcode 分支
    endcase
end
```

### 6.2 修改后

将 `ADDIW`映射到已有的 `4'b1000`控制码：

```verilog
7'b0011011: begin
    case(instruction[14:12])
        3'b000: ALUControl = 4'b1000; // ADDIW
        default: ALUControl = 4'b1111;
    endcase
end
```

`4'b1000`原本已经由 `ADDW`使用，其 ALU 数据通路为：

```verilog
wire [31:0] addw_result = A[31:0] + B[31:0];

4'b1000:
    ALUResult = {{32{addw_result[31]}}, addw_result};
```

`ADDW`和 `ADDIW`的区别在第二操作数来自寄存器还是立即数；两者最终都执行低32位加法并将 bit31 符号扩展到64位，所以可以安全复用同一 ALU 操作。

## 7. Fibonacci 暴露出的 D-Cache 停顿转发问题

递归函数的序言包含：

```asm
addi sp, sp, -32
sd   ra, 24(sp)
sd   s0, 16(sp)
sd   s1, 8(sp)
```

问题发生过程为：

```text
ADDI更新sp
    → 第一条SD进入MEM并等待D-Cache
    → 后续SD被保持在ID/EX
    → MEM/WB仍继续更新，原sp结果的转发来源消失
    → 被保持的SD恢复执行时使用进入ID/EX时保存的旧sp
    → s0被写入上一层栈槽，而不是当前栈槽
```

因此实际问题不是数值 `2`在传输中变成了 `0`，而是 `2`被写到了错误地址，随后 `LD`从正确地址读到了原来的 `0`。

## 8. D-Cache stall 时同步保持 MEM/WB

### 8.1 修改前

原顶层只保持 PC、IF/ID、ID/EX 和 EX/MEM：

```verilog
wire IF_ID_write_final = IF_ID_write_hazard && ~dcache_stall;
wire ID_EX_write_final = ~dcache_stall;
wire EX_MEM_write_final = ~dcache_stall;
```

`MEM_WB`模块则在每一个非复位时钟沿无条件更新：

```verilog
always @(posedge clk) begin
    if(reset) begin
        // 清零
    end
    else begin
        readdata_out      <= readdata_in;
        ALUresult_out     <= ALUresult_in;
        MemtoReg_out      <= MemtoReg_in;
        instruction64_out <= instruction64_in;
        instruction_out   <= instruction_in;
        pc_plus4_out      <= pc_plus4_in;
        Regwrite_out      <= Regwrite_in;
        CSR_rdata_out     <= CSR_rdata_in;
        CSRtoReg_out      <= CSRtoReg_in;
    end
end
```

### 8.2 修改后

顶层生成 MEM/WB 写使能：

```verilog
wire MEM_WB_write_final = ~dcache_stall;
```

并连接到流水寄存器：

```verilog
MEM_WB u_mem_wb(
    // 其他端口
    .MEM_WB_write(MEM_WB_write_final)
);
```

`MEM_WB`加入写使能输入，并在禁止写入时保持原值：

```verilog
input MEM_WB_write;

always @(posedge clk) begin
    if(reset) begin
        // 清零
    end
    else if(MEM_WB_write) begin
        readdata_out      <= readdata_in;
        ALUresult_out     <= ALUresult_in;
        MemtoReg_out      <= MemtoReg_in;
        instruction64_out <= instruction64_in;
        instruction_out   <= instruction_in;
        pc_plus4_out      <= pc_plus4_in;
        Regwrite_out      <= Regwrite_in;
        CSR_rdata_out     <= CSR_rdata_in;
        CSRtoReg_out      <= CSRtoReg_in;
    end
    else begin
        readdata_out      <= readdata_out;
        ALUresult_out     <= ALUresult_out;
        MemtoReg_out      <= MemtoReg_out;
        instruction64_out <= instruction64_out;
        instruction_out   <= instruction_out;
        pc_plus4_out      <= pc_plus4_out;
        Regwrite_out      <= Regwrite_out;
        CSR_rdata_out     <= CSR_rdata_out;
        CSRtoReg_out      <= CSRtoReg_out;
    end
end
```

这一修改修正了此前“MEM/WB不需要随 D-Cache stall 保持”的认识。MEM/WB中的数据确实不能被简单丢弃，因为被阻塞在 EX 级的指令仍可能需要它完成转发。

## 9. 分离“可用于转发”和“真正提交一次”

### 9.1 修改前

同一个 `Regwrite_wb`同时用于寄存器堆写回和 WB 到 EX 的转发：

```verilog
wire Regwrite_wb;

Register u_register(
    // 其他端口
    .Regwrite(Regwrite_wb)
);

ForwardingUnit u_forwardingunit(
    // 其他端口
    .Regwrite_wb(Regwrite_wb)
);

MEM_WB u_mem_wb(
    // 其他端口
    .Regwrite_out(Regwrite_wb)
);
```

如果仅仅保持 MEM/WB，`Regwrite_wb`也会在整个停顿期间持续为1，使同一条指令被重复视为写回。

### 9.2 修改后

增加一个保持给转发单元使用的资格信号，以及一个记录本条 WB 是否已经在停顿期间提交的状态：

```verilog
wire Regwrite_wb;
wire Regwrite_forward_wb;
reg  wb_stall_commit_done;
```

MEM/WB输出和转发单元使用保持后的资格：

```verilog
.Regwrite_out(Regwrite_forward_wb)

.Regwrite_wb(Regwrite_forward_wb)
```

寄存器堆仍使用代表真实架构提交的 `Regwrite_wb`。提交状态控制为：

```verilog
always @(posedge clk) begin
    if(reset)
        wb_stall_commit_done <= 1'b0;
    else if(dcache_stall)
        wb_stall_commit_done <= 1'b1;
    else
        wb_stall_commit_done <= 1'b0;
end

assign Regwrite_wb =
    Regwrite_forward_wb && ~wb_stall_commit_done;
```

最终形成两种不同语义：

```text
Regwrite_forward_wb：MEM/WB中保留的数据是否仍能作为EX转发源
Regwrite_wb：本周期是否真正向寄存器堆提交一次写回
```

这样，较老的 WB 指令可以在 D-Cache 停顿开始时正常提交一次，同时其值继续保留，供被阻塞的后续指令在恢复执行时转发使用。

## 10. 增加寄存器堆同周期写回旁路

### 10.1 修改前

寄存器堆组合读端口只读取数组：

```verilog
if (Readregister1 == 5'd0)
    Readdata1 = 64'b0;
else
    Readdata1 = registers[Readregister1];

if (Readregister2 == 5'd0)
    Readdata2 = 64'b0;
else
    Readdata2 = registers[Readregister2];
```

当 WB 在某个上升沿写寄存器，而 ID 在同一个上升沿把该寄存器的读值送入 ID/EX 时，非阻塞赋值的更新时序可能使 ID/EX 捕获旧值。

### 10.2 修改后

如果当前写回寄存器与读寄存器相同，组合读端口直接返回 `Writedata`：

```verilog
if (Readregister1 == 5'd0)
    Readdata1 = 64'b0;
else if (Regwrite && (Writeregister != 5'd0) &&
         (Writeregister == Readregister1))
    Readdata1 = Writedata;
else
    Readdata1 = registers[Readregister1];

if (Readregister2 == 5'd0)
    Readdata2 = 64'b0;
else if (Regwrite && (Writeregister != 5'd0) &&
         (Writeregister == Readregister2))
    Readdata2 = Writedata;
else
    Readdata2 = registers[Readregister2];
```

`x0`仍保持最高优先级，任何对 `x0`的写入都不会被旁路成非零值。

## 11. 修改后的整体数据关系

```text
D-Cache产生stall
    → PC、IF/ID、ID/EX、EX/MEM和MEM/WB共同保持
    → 较老的WB指令只提交一次
    → MEM/WB结果继续作为EX级转发源
    → stall结束时，被保持的指令使用正确的新sp或其他操作数

WB与ID同周期访问同一寄存器
    → 寄存器堆读端口直接选择Writedata
    → ID/EX不会锁存旧寄存器值
```

## 12. 本阶段最终状态

| CPU RTL项目 | 当前状态 |
| --- | --- |
| `BLT`主控制译码 | 完成 |
| `BLT`有符号比较 | 完成 |
| `BLT`的 MEM 阶段跳转判定 | 完成 |
| `ADDIW`主控制译码 | 完成 |
| `ADDIW`立即数生成 | 完成 |
| `ADDIW`低32位加法与64位符号扩展 | 完成 |
| D-Cache stall期间保持MEM/WB转发源 | 完成 |
| WB写回只提交一次 | 完成 |
| 寄存器堆WB到ID同周期旁路 | 完成 |
| Clang递归 `fib(10)`返回55 | 完成 |
| 全部Verilog回归 | 27项全部通过 |

至此，CPU不仅能够识别递归 Fibonacci 新引入的 `BLT`和 `ADDIW`，还能够在多周期 D-Cache 访问造成全局停顿时保留必要的转发信息，并正确处理 WB 与 ID 同周期访问同一寄存器的情况。该问题说明：对于带变延迟存储系统的五级流水线，仅保持前四级并不足以保证数据相关正确，必须同时考虑被保持消费者所依赖的转发生产者是否仍然存在，以及保持期间架构写回是否会重复发生。

# 2026/11/09：为数组求和程序增加 BGE、SLLI 和 LW 支持

## 本阶段背景

在递归 Fibonacci 跑通后，开始使用 Clang 编译数组求和程序。链接后的真实 RISC-V 反汇编中，循环主体为：

```asm
bge   zero, a1, loop_exit
slli  a1, a1, 2
add   a1, a0, a1
lw    a3, 0(a0)
addi  a0, a0, 4
addw  a2, a3, a2
bne   a0, a1, loop
```

其中 `ADD、ADDI、ADDW、BNE`已经支持，本阶段新增：

```text
BGE   有符号大于等于分支
SLLI  逻辑左移立即数
LW    读取32位有符号整数并扩展到64位
```

## 1. 增加 BGE 有符号分支

### 1.1 指令识别

`BGE`属于 B-type，其编码条件为：

```text
opcode = 1100011
funct3 = 101
```

B-type 的 `instruction[31:25]`属于分支立即数，不是 `funct7`，因此不能将其作为固定功能字段参与译码。

`Control.v`把原分支集合：

```verilog
3'b000, 3'b001, 3'b100
```

扩展为：

```verilog
3'b000, 3'b001, 3'b100, 3'b101
```

`BGE`与 `BLT`使用相同的主控制信号：

```verilog
Branch             = 1'b1;
ALUOp              = 2'b01;
UseRs1             = 1'b1;
UseRs2             = 1'b1;
IllegalInstruction = 1'b0;
```

### 1.2 ALUControl 与 ALU

`ALUControl.v`为 `BGE`分配新的控制码：

```verilog
3'b101: ALUControl = 4'b1001;
```

`ALU.v`增加有符号大于等于判断：

```verilog
4'b1001:
    ALUResult = ($signed(A) >= $signed(B)) ? 64'd1 : 64'd0;
```

这里必须使用 `>=`，不能使用 `>`，因为两个操作数相等时 `BGE`也必须跳转。

### 1.3 顶层分支判断

`PIPELINED_CPU.v`原来只组合 `BEQ、BNE、BLT`的实际跳转结果，本阶段加入：

```verilog
wire bge_taken_mem =
    Branch_mem &&
    (instruction_mem[14:12] == 3'b101) &&
    !zero_mem;
```

并将其合并到最终分支结果：

```verilog
wire branch_taken_mem =
    beq_taken_mem || bne_taken_mem ||
    blt_taken_mem || bge_taken_mem;
```

由于 ALU 在 `A >= B`时返回1，因此 `Zero=0`，顶层使用 `!zero_mem`表示 BGE 成立。

## 2. 增加 SLLI 逻辑左移立即数

### 2.1 RV64 SLLI 编码

RV64 的 SLLI 使用：

```text
instruction[31:26] = funct6 = 000000
instruction[25:20] = shamt[5:0]
instruction[14:12] = funct3 = 001
instruction[6:0]   = opcode = 0010011
```

RV64允许0～63的移位量，所以这里是6位 `shamt`，不能按照 RV32 只处理5位。

### 2.2 主控制译码

`Control.v`在 OP-IMM 中增加：

```verilog
3'b001: begin // SLLI
    if (instruction[31:26] == 6'b000000) begin
        ALUOp = 2'b10;
        Regwrite = 1'b1;
        ALUSrc = 1'b1;
        UseRs1 = 1'b1;
        IllegalInstruction = 1'b0;
    end
end
```

检查 `funct6`可以避免把保留或非法编码误认为 SLLI。

### 2.3 复用现有移位通路

`ALUControl.v`将合法 SLLI 映射到原 SLL 使用的控制码：

```verilog
3'b001: begin
    if (instruction[31:26] == 6'b000000)
        ALUControl = 4'b0101;
end
```

ALU原有逻辑为：

```verilog
4'b0101: ALUResult = A << B[5:0];
```

`Immgen.v`已经对 opcode `0010011`生成12位 I-type 立即数，其低6位正好是 `shamt`；`ALUSrc=1`又会选择立即数作为 B 输入。因此 SLLI 不需要修改 ALU、Immgen 或顶层数据通路。

数组程序中的：

```asm
slli a1, a1, 2
```

完成 `length × 4`，用于把 `int`数组长度转换为字节长度。

## 3. 增加 LW 主控制译码

`LW`和 `LD`使用相同 opcode：

```text
opcode = 0000011
LW funct3 = 010
LD funct3 = 011
```

`Control.v`将原来只接受 LD 的判断改成：

```verilog
7'b0000011: begin // LW/LD
    case (instruction[14:12])
        3'b010, 3'b011: begin
            MemRead            = 1'b1;
            MemtoReg           = 2'b01;
            ALUOp              = 2'b00;
            ALUSrc             = 1'b1;
            Regwrite           = 1'b1;
            UseRs1             = 1'b1;
            IllegalInstruction = 1'b0;
        end
        default: begin end
    endcase
end
```

LW继续复用 I-type 立即数和 `rs1 + immediate`地址计算，因此不需要修改 ALUControl、ALU或Immgen。

## 4. D-Cache允许4字节对齐的读请求

### 4.1 修改原因

原 D-Cache 只支持 LD/SD，要求所有请求地址满足：

```verilog
cpu_req_addr[2:0] == 3'b000
```

但 LW 合法地址只要求4字节对齐，例如 `0x48、0x4c、0x50`。其中 `0x4c`的 bit2 为1，如果继续要求8字节对齐就无法读取一个64位后端 word 的高32位。

### 4.2 修改后的对齐入口

`DCache.v`现在区分读写请求：

```verilog
wire cpu_addr_aligned = cpu_req_write ?
                        (cpu_addr_byte_offset == 3'b000) :
                        (cpu_req_addr[1:0] == 2'b00);
```

当前含义为：

```text
Store：仍只支持SD，要求8字节对齐
Load：可能是LD或LW，D-Cache入口允许4字节对齐
```

D-Cache仍然返回包含目标地址的完整64位后端 word，不在 Cache 内部决定这是 LW 还是 LD。具体访存类型由 CPU MEM 阶段根据随流水线传下来的指令判断。

## 5. 顶层选择 LW 的高低32位并进行符号扩展

### 5.1 选择目标32位

`PIPELINED_CPU.v`在 D-Cache 返回数据之后增加：

```verilog
wire [31:0] lw_data_mem = aluresult_mem[2] ?
                          dcache_cpu_resp_rdata[63:32] :
                          dcache_cpu_resp_rdata[31:0];
```

选择规则为：

```text
address[2] = 0：读取64位word的低32位
address[2] = 1：读取64位word的高32位
```

### 5.2 LW符号扩展与LD直通

继续根据 MEM 阶段指令的 `funct3`选择最终 Load 数据：

```verilog
wire [63:0] load_data_mem =
    (instruction_mem[14:12] == 3'b010) ?
    {{32{lw_data_mem[31]}}, lw_data_mem} :
    dcache_cpu_resp_rdata;
```

并替换原来直接使用64位 D-Cache 数据的连接：

```verilog
assign mem_readdata_mem =
    load_complete_mem ? load_data_mem : 64'b0;
```

因此：

```text
LW：选择32位后将bit31符号扩展到64位
LD：完整64位数据直接进入MEM/WB
```

本次没有新增 `MemSize`流水控制信号，因为 `instruction_mem[14:12]`本来就与访存指令一起到达 MEM 阶段，足以区分 LW 和 LD。

## 6. 顶层按访存宽度判断 Load 地址错位

原顶层统一要求所有 Load 地址8字节对齐：

```verilog
aluresult_mem[2:0] == 3'b000
```

修改后根据 `funct3`分别判断：

```verilog
always @(*) begin
    load_misaligned_mem = 1'b0;
    if(MemRead_mem == 1'b1 && valid_mem == 1'b1) begin
        case(instruction_mem[14:12])
            3'b010:
                load_misaligned_mem =
                    (aluresult_mem[1:0] != 2'b00); // LW
            3'b011:
                load_misaligned_mem =
                    (aluresult_mem[2:0] != 3'b000); // LD
            default:
                load_misaligned_mem = 1'b1;
        endcase
    end
end
```

最终对齐规则为：

```text
LW地址0x04：合法
LW地址0x02：Load address misaligned
LD地址0x08：合法
LD地址0x04：Load address misaligned
```

错误对齐的 Load 在 MEM 阶段产生 Trap，并通过现有 `~trap_enter`条件阻止 D-Cache 请求和寄存器写回。

## 7. 顶层修改汇总

本阶段对 `PIPELINED_CPU.v`的直接修改包括：

```text
1. 增加bge_taken_mem并合并到branch_taken_mem
2. 增加lw_data_mem，根据地址bit2选择高/低32位
3. 增加load_data_mem，在LW符号扩展和LD直通之间选择
4. 让mem_readdata_mem使用处理后的load_data_mem
5. 让load_misaligned_mem根据LW/LD宽度分别判断
```

SLLI没有修改顶层，因为现有立即数选择和 ALU 左移通路已经完整。

## 8. 测试结果

本阶段测试只记录结果，不在日志中粘贴 testbench 代码。

| 验证内容 | 结果 |
| --- | --- |
| BGE大于时跳转 | 通过 |
| BGE相等时跳转 | 通过 |
| BGE有符号负数比较 | 通过 |
| SLLI普通移位 | 通过 |
| RV64 SLLI六位移位量 | 通过 |
| SLLI非法funct6拒绝 | 通过 |
| LW读取低32位 | 通过 |
| LW读取高32位 | 通过 |
| LW正数扩展 | 通过 |
| LW负数符号扩展 | 通过 |
| LW四字节对齐访问 | 通过 |
| LW错位地址异常 | 通过 |
| 原有LD/SD和D-Cache流程 | 回归通过 |
| Fibonacci、ADDW、ADDIW、BLT等旧功能 | 回归通过 |
| 完整Verilog回归 | 29项全部通过 |

## 9. 今日结束时的状态

数组求和程序已经完成从 C 到 RISC-V ELF 的编译和链接，CPU现已支持该 ELF 反汇编中出现的 `BGE、SLLI、LW`。下一阶段需要把 ELF 的 `.text`和`.data`分别转换并装入指令后端与数据后端，再运行完整数组求和程序，检查 `main`是否返回31。

与此前只包含代码的 Fibonacci 程序不同，数组求和首次真正依赖 ELF 的 `.data`节，因此后续不能只把一个 HEX 文件装入 I-Cache；必须保证位于地址 `0x48`的数组初值被正确放入 D-Cache 后端对应地址。

# 2026/11/10：跑通数组求和并建立 TB 级性能基准

## 1. 数组求和完整运行

从现有 `program.elf` 生成 104 字节的 `program.bin` 和 13 个 64 位字的 `program.hex`，在整机 TB 中将平坦映像同时装入 I-Cache 与 D-Cache 后端，程序完成 8 次 `LW` 后返回 `31`。

**需要理解：** 分离的指令与数据后端必须分别获得 ELF 中对应地址的内容，只有指令正确并不代表带 `.data` 的 C 程序能够运行。

## 2. 定义性能事件

在 TB 中统一定义周期、提交指令、I/D Cache miss、I-Cache等待、D-Cache stall、Load-use stall、分支执行、Taken 分支和预测错误，其中提交事件使用“有效 MEM 指令被 MEM/WB 接受且未触发 Trap”的条件。

**需要理解：** 性能计数的核心是找到只出现一次的事件脉冲或需要逐周期累加的状态，尤其要避免同一条指令在 stall 期间被重复统计。

## 3. 为四个 C 程序加入统一计数器

`minimal`、`int_add`、`fibonacci` 和 `array_sum` 的整机 TB 已采用相同测量窗口，单指令功能 TB 不加入 CPI 统计。

**需要理解：** 只有使用相同的开始、结束、Cache初始状态和事件定义，不同程序或优化前后的性能数据才具有可比性。

## 4. 原始性能基准

| 程序 | 周期数 | 提交指令数 | CPI | I-Cache miss | D-Cache Load miss | D-Cache stall周期 | 分支预测错误 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `minimal` | 33 | 3 | 11.000 | 1 | 0 / 0 | 0 | 0 / 0 |
| `int_add` | 91 | 13 | 7.000 | 2 | 1 / 1 | 27 | 0 / 0 |
| `fibonacci` | 5159 | 1949 | 2.647 | 4 | 10 / 265 | 1800 | 87 / 177 |
| `array_sum` | 167 | 44 | 3.795 | 3 | 2 / 8 | 42 | 2 / 9 |

完整明细保存在 `docs/benchmarks/CPU性能基准.md`，完整 Verilog 回归共 30 项，全部通过。

**需要理解：** CPI、总周期、miss次数和stall周期描述不同问题，例如 Fibonacci 的CPI不高但递归栈写入仍造成大量D-Cache等待。

## 5. 下一阶段

当前结果作为 LLVM Pass 之前的原始基线，下一步实现一个简单 LLVM IR Pass，并在相同条件下重新生成 ELF、HEX 和性能结果进行对比。

**需要理解：** 编译优化是否有效不能只看汇编是否变短，而应使用同一套基准量化它对动态指令数、周期数和存储系统行为的影响。

# 2026/11/11：建立 LLVM Pass 开发链路并完成首次 IR 修改

## 1. 生成并认识 LLVM IR

使用 Clang 将 `software/array_sum/main.c` 转换为 `main.ll`，确认完整编译流程为 `C → LLVM IR → LLVM Pass → RISC-V 汇编`，并初步认识 `define、load、add、icmp、br、getelementptr、phi` 等 IR 结构。

**需要理解：** LLVM IR 是 Clang 前端与目标后端之间的中间表示，Pass 的输入是 IR，而不是直接处理 C 语法或 Verilog CPU。

## 2. 准备项目内 LLVM Pass 开发环境

在 `.tools/llvm-23.1.5` 中安装项目专用的完整 LLVM 工具链，补齐 `opt`、LLVM 头文件、链接库和 CMake 配置；增加 `scripts/llvm/use_project_llvm.ps1`，用于在当前 PowerShell 会话中启用项目 LLVM。

**需要理解：** 原有 Clang 主要用于编译 C 程序，完整 LLVM 开发包则用于编译并运行自己实现的 Pass。

## 3. 实现 IR 静态统计 Pass

在 `compiler/llvm_passes/ir_stats` 中增加 `IRStatsPass.cpp、CMakeLists.txt、IRStatsPass.def`，编译生成 `IRStatsPass.dll`；Pass 按“函数 → 基本块 → 指令”遍历 IR，统计基本块、指令、Load、Store 和 Branch 数量。

对数组求和 IR 的统计结果为：`sum_array` 包含 4 个基本块、14 条 IR 指令、1 条 Load 和 3 条 Branch，`main` 包含 2 条 IR 指令。

**需要理解：** 当前统计是静态 IR 数量，不等于 CPU 上的动态执行次数、RISC-V 指令数或运行周期数。

## 4. 完成第一个修改型 Pass

新增 `software/pass_add_zero/main.c`，在其 IR 中保留 `%add = add nsw i32 %0, 0`；随后手动实现并注册 `RemoveAddZeroPass`，识别整数加零运算，用非零操作数替换原结果的全部使用者，再删除旧的 `add` 指令。

优化后生成 `software/pass_add_zero/optimized.ll`，`add_zero` 函数从 5 条 IR 指令减少到 4 条，并通过 LLVM verifier 检查。

**需要理解：** 修改型 Pass 的基本动作是“识别目标指令 → 替换使用关系 → 删除旧指令 → 正确报告分析是否仍然有效”。

## 5. 对比优化前后的后端结果

分别从原始 IR 和优化 IR 生成 `original.s` 与 `optimized.s`，两份 RISC-V 汇编完全相同，因为 LLVM 后端即使没有运行自定义 Pass，也会自动消除加零运算。

**需要理解：** IR 发生变化不一定会改变最终机器指令；后续优化实验必须选择后端不会自动完成的变换，并继续使用已有 TB 性能基准验证实际收益。

本阶段只增加 LLVM 工具、Pass 源码和软件实验文件，没有修改 CPU RTL 或现有 testbench。

## 6. 使用 LLVM 内置 Pass 进行循环展开

从数组求和 C 程序重新生成不带 `optnone` 的 O0 IR，经 `mem2reg、simplifycfg、loop-simplify、lcssa` 整理后，分别使用 `loop-unroll` 生成二路和四路展开版本；四路展开的循环体中由 1 条 `load volatile` 变为 4 条，证明循环体已被复制。

**需要理解：** 二路和四路展开分别让一组循环处理 2 个和 4 个元素，用代码体积换取更少的循环控制开销，同时仍需保留必要的边界检查。

## 7. O0 后端实验与寄存器压力

使用 `llc -O0` 生成汇编并构建 ELF/HEX，新增 `CLANG_ARRAY_SUM_UNROLL_COMPARE_tb.v`，以两个独立 CPU 实例在相同初始状态下比较未展开和四路展开程序。

| O0版本 | 周期数 | 提交指令数 | CPI | I-Cache miss | I-Cache等待 | D-Cache stall |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 未展开 | 873 | 216 | 4.042 | 7 | 147 | 474 |
| 四路展开 | 1352 | 186 | 7.269 | 27 | 567 | 675 |

四路展开虽然使动态指令减少 13.9%，但代码段由 216 字节增长到 420 字节，超过 256 字节直接映射 I-Cache；同时 `llc -O0` 产生 128 字节栈帧及大量 spill/reload，最终周期增加 54.9%。

**需要理解：** 展开会提高寄存器压力和代码容量压力，动态指令更少不代表执行周期必然更少；`-O0` 的寄存器分配结果也不适合作为最终优化结论。

## 8. 使用 O2 消除额外 spill

分别以 `llc -O2` 重新生成未展开、二路展开和四路展开汇编，额外 spill 基本消失，三个版本都只保留 ABI 所需的 `ra/s0` 保存恢复，栈帧统一缩小到 16 字节。

新增 `software/array_sum_unroll/common/link.ld`，将 `.data` 按 32 字节 D-Cache Line 对齐，避免不同代码长度改变数组跨行情况；对比 TB 通过编译宏选择 O0、二路 O2 或四路 O2 映像。

**需要理解：** 公平比较编译优化时，不仅要保持硬件和输入相同，还要控制后端优化等级及数据对齐，避免把链接布局造成的 Cache miss误认为 Pass 效果。

## 9. 二路与四路展开的最终 O2 结果

| O2版本 | `.text`大小 | 周期数 | 提交指令数 | CPI | I-Cache miss | I-Cache等待 | D-Cache stall |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 未展开 | 128 B | 240 | 66 | 3.636 | 5 | 105 | 66 |
| 二路展开 | 148 B | 222 | 63 | 3.524 | 5 | 105 | 66 |
| 四路展开 | 180 B | 241 | 61 | 3.951 | 6 | 126 | 66 |

二路展开在不增加 Cache miss 的情况下使周期减少 7.5%、动态指令减少 4.5%，为当前 CPU 的最佳方案；四路展开虽然使动态指令减少 7.6%，但多访问一条 I-Cache Line并增加一次 miss，最终比未展开多 1 个周期。

所有版本均通过整机 TB：完成 8 次 `LW`、`main` 返回 31、未进入 Trap，并将栈指针恢复到 `0x800`。O0、二路 O2 和四路 O2 三种 TB 模式均已回归通过。

**需要理解：** 最优展开因子取决于循环控制收益、寄存器压力、代码体积和 Cache 结构之间的平衡；对当前 256 字节直接映射 I-Cache，二路展开优于四路展开。

本阶段新增循环展开 IR、O2 汇编/ELF/HEX、Cache Line 对齐链接脚本和参数化性能对比 TB，没有修改 CPU RTL。

# 2026/11/13：自动二路展开 Pass 与实验目录整理

在现有插件中增加 `CPUUnrollHintPass`，针对规范化后的 `sum_array` 循环写入 `llvm.loop.unroll.count = 2`，再调用 LLVM 内置 `loop-unroll` 完成安全展开。自定义 Pass 生成的 O2 汇编和 BIN 与手工二路展开版本完全一致。

整机 TB 结果为未展开 240 周期、66 条提交指令，自定义 Pass 二路展开 222 周期、63 条提交指令，周期减少 7.5%，且 I/D Cache 指标没有恶化；原有 `ir-stats` 和 `remove-add-zero` 均回归通过。

`software/array_sum_unroll` 已按实验方案整理为 `common、baseline、unroll4、unroll2_manual、unroll2_cpu_pass`，每个方案目录保存自身从 IR 到 HEX 的完整产物，并增加目录 README。

优化实验数据单独记录在 `docs/benchmarks/LLVM循环优化性能对比.md`，避免与编译条件不同的原始性能基准混用。本阶段没有修改 CPU RTL。

# 2026/11/14：定义 SUM2W 并完成基础 RTL 支持

## 1. 指令目标与正式语义

`SUM2W` 用一次64位 `LD` 得到两个打包的32位 `int`，再将它们和现有32位累加值相加：

```text
sum32 = (rs1[31:0] + rs2[31:0] + rs2[63:32]) mod 2^32
rd = sign_extend(sum32[31:0])
```

该语义与连续两次 `ADDW` 等价：溢出时只保留低32位，最终按照 bit31 符号扩展到64位，不触发算术异常。

## 2. R-type 指令组成

| 字段 | 位段 | SUM2W编码 | 作用 |
| --- | --- | --- | --- |
| `funct7` | `[31:25]` | `0000000` | 标识当前自定义运算 |
| `rs2` | `[24:20]` | 寄存器编号 | 保存两个打包的32位数组元素 |
| `rs1` | `[19:15]` | 寄存器编号 | 当前32位累加结果 |
| `funct3` | `[14:12]` | `000` | 标识当前自定义运算 |
| `rd` | `[11:7]` | 寄存器编号 | 接收符号扩展后的结果 |
| `opcode` | `[6:0]` | `0001011`（`0x0B`） | RISC-V `custom-0`空间 |

完整字段排列为：

```text
31       25 24    20 19    15 14  12 11     7 6       0
+----------+--------+--------+------+---------+---------+
| 0000000  |  rs2   |  rs1   | 000  |   rd    | 0001011 |
+----------+--------+--------+------+---------+---------+
```

配套编码常量为：

```text
MATCH_SUM2W = 0x0000000B
MASK_SUM2W  = 0xFE00707F
ALUControl  = 4'b1010
```

例如 `sum2w a0, a0, a1` 的机器码为 `0x00B5050B`。

## 3. `Control.v` 主控制译码

### 修改前

主控制器没有 `custom-0` 分支，`opcode=0001011` 会进入默认路径并保持 `IllegalInstruction=1`：

```verilog
default: begin end
```

### 修改后

```verilog
7'b0001011: begin // custom-0: SUM2W
    if ({instruction[31:25], instruction[14:12]} ==
        10'b0000000_000) begin
        ALUOp = 2'b10;
        Regwrite = 1'b1;
        UseRs1 = 1'b1;
        UseRs2 = 1'b1;
        IllegalInstruction = 1'b0;
    end
end
```

`SUM2W` 被定义为普通双源 ALU 写回指令：不读写存储器、不使用立即数、不进行跳转；只有 `opcode、funct3、funct7` 全部匹配时才合法，其他 `custom-0` 编码仍触发非法指令。

## 4. `ALUControl.v` 运算选择

### 修改前

`ALUOp=2'b10` 的 R-type 译码中没有 `custom-0`，因此会保持默认控制码 `1111`。

### 修改后

```verilog
7'b0001011:begin // custom-0: SUM2W
    case({instruction[31:25],instruction[14:12]})
        10'b0000000_000: ALUControl = 4'b1010;
        default: ALUControl = 4'b1111;
    endcase
end
```

内部控制码 `1010` 原先未被使用，因此不会改变现有 `ADDW、BGE` 等操作。

## 5. `ALU.v` 运算逻辑

### 修改前

ALU 只包含现有 `ADDW` 的32位结果：

```verilog
wire [31:0] addw_result = A[31:0] + B[31:0];
```

原 `case` 中没有 `ALUControl=1010` 对应分支。

### 修改后

新增32位模加中间结果：

```verilog
wire [31:0] sum2w_result =
    A[31:0] + B[31:0] + B[63:32];
```

新增符号扩展输出：

```verilog
4'b1010: ALUResult = {{32{sum2w_result[31]}},sum2w_result};
```

其中 `A` 对应 `rs1`，`B` 对应包含两个32位元素的 `rs2`；中间结果线宽固定为32位，因此高位进位会自然丢弃。

## 6. 单元测试与回归结果

新增 `tb/SUM2W_DECODE_ALU_tb.v`，当前只验证主控制、ALUControl和ALU，不经过流水线顶层。

| 测试内容 | 结果 |
| --- | --- |
| `0x00B5050B` 精确译码 | 通过 |
| 正数 `10 + 20 + 12 = 42` | 通过 |
| 正负数混合 | 通过 |
| 32位溢出截断 | 通过 |
| 结果符号扩展 | 通过 |
| Zero 标志 | 通过 |
| 非法 `funct3` 拒绝 | 通过 |
| 非法 `funct7` 拒绝 | 通过 |
| 原有 `ADDW` 回归 | 通过 |
| 原有 `ADDIW、BLT、BGE` 回归 | 通过 |
| 原有 `SLLI` 回归 | 通过 |

## 7. 当前阶段边界

本阶段只修改了 `Control.v、ALUControl.v、ALU.v` 并增加独立单元 TB，尚未修改或验证流水线顶层、前递、冒险、Trap、整机汇编程序和 LLVM 自动生成自定义指令的部分。

# 2026/11/15：完成 SUM2W 整机验证与 LLVM Pass 自动转换

## 1. SUM2W 五级流水线集成测试

新增 `tb/SUM2W_PIPELINE_tb.v`，直接向取指端送入由真实机器码组成的小程序：

```text
addi x1,  x0, 10
addi x2,  x0, 12
slli x2,  x2, 32
addi x2,  x2, 20
sum2w x10, x1, x2    # 机器码 0x0020850B
addi x11, x10, 1
jal x0, 0
```

`SUM2W` 在第29个统计周期向 `x10` 写回42，紧随其后的相关 `ADDI` 在第30个统计周期向 `x11` 写回43；测试同时覆盖了 `rs2` 输入前递、SUM2W结果前递、ALU结果流水传递和通用写回通路。由于现有R-type数据通路可以直接复用，本阶段没有修改 `PIPELINED_CPU.v`。

**需要理解：** 新指令只有在真实机器码经过取指、译码、前递、执行和写回后仍得到正确结果，才算完成了处理器整机集成，而不只是 ALU 单元功能正确。

## 2. 使用人工 IR 验证 SUM2W 的正确性与收益

以 `unroll2_cpu_pass/cpu_unrolled2.ll` 为基准，在 `sum2w_manual/sum2w.ll` 中先人工建立原型：将成对路径中的两次 `volatile i32` 读取和两次32位累加改为一次对齐到8字节的 `volatile i64` 读取，并使用 LLVM inline asm 插入：

```text
.insn r 0x0b, 0, 0, $0, $1, $2
```

尾部路径仍使用普通 `i32 load + add`，因此元素数量为奇数时仍能正确处理。最终 ELF 中出现机器码 `0x00E6060B`；官方反汇编器显示 `<unknown>`，只是因为尚未在 LLVM RISC-V 后端注册 SUM2W 助记符，不影响 CPU 按编码执行。

第一次使用 `align 4` 时，LLVM 为避免潜在非对齐访问把64位读取拆成两次读取、移位和 OR；改为经过证明的 `align 8` 后才生成单条 `LD`。同时将循环累加器保持为 `i64`，只在返回时截断为 `i32`，消除了每轮额外的符号扩展指令。

**需要理解：** 自定义运算本身正确还不够，内存对齐、尾部处理和 IR 类型设计都会影响最终机器指令质量。

## 3. 新增 SUM2WCombinePass

在 `compiler/llvm_passes/ir_stats/IRStatsPass.cpp` 中新增 `SUM2WCombinePass`，并注册流水线名称 `cpu-sum2w-combine`。Pass 分成三个核心步骤：

1. `hasExpectedUnrolledShape`：只接受签名正确、包含两次 `volatile i32` 读取且读取值参与32位加法的 `sum_array`；
2. `guaranteeEightByteBaseAlignment`：检查直接调用方传入全局数组，并把数组对齐提升到8字节；
3. `rebuildWithSUM2W`：使用 `IRBuilder` 重新创建循环头、成对处理、单元素尾部和退出基本块，在成对路径生成 `i64 load + SUM2W`。

Pass 对不符合结构的 IR 输出：

```text
[SUM2WCombine] function=sum_array transformed=0 reason=shape-mismatch
```

并保持原函数不变；对二路展开输入则输出：

```text
[SUM2WCombine] function=sum_array transformed=1 pair_load=i64 custom_opcode=0x0b
```

重建循环时还保留了索引加法的 `nuw/nsw` 信息，使 LLVM 能把每轮的移位加法地址计算优化成单条指针递增；补充这些属性后，自动 Pass 版本和人工 IR 版本生成的 BIN 文件 SHA-256 完全一致。

**需要理解：** 修改型 Pass 的核心不是直接拼接文本，而是先验证 IR 模式，再用 LLVM API 创建基本块、PHI、Load、Branch 和 Call；无法证明转换安全时必须跳过。

## 4. 自动构建链路

新增 `scripts/llvm/build_sum2w_pass.ps1`，将以下步骤封装成一次命令：

```text
重新编译 IRStatsPass.dll
→ cpu_unrolled2.ll
→ cpu-sum2w-combine + verifier
→ cpu_sum2w.ll
→ llc -O2
→ 汇编和链接
→ ELF / BIN / HEX / MAP / 反汇编
```

运行方式为：

```powershell
.\scripts\llvm\build_sum2w_pass.ps1
```

自动产物保存在 `software/array_sum_unroll/sum2w_cpu_pass`，最终循环核心为：

```asm
ld      a4, 0(a0)
addi    a0, a0, 8
.insn   r 11, 0, 0, a2, a2, a4
```

**需要理解：** 当前完整软件链路是“二路展开 Pass → SUM2WCombinePass → LLVM 后端 → ELF/HEX”，不再需要人工编辑生成的 `.ll` 文件。

## 5. 自动 Pass 整机性能结果

在 `CLANG_ARRAY_SUM_UNROLL_COMPARE_tb.v` 中新增 `ARRAY_SUM_SUM2W_PASS` 模式，同时加载普通二路展开 HEX 和自动 SUM2W Pass HEX。两个程序都正确返回31、未进入 Trap，性能结果如下：

| 指标 | 普通二路展开 | 自动 SUM2W Pass | 变化 |
| --- | ---: | ---: | ---: |
| `.text` 大小 | 148 B | 152 B | +4 B |
| 总周期 | 222 | 217 | -2.3% |
| 提交指令 | 63 | 55 | -12.7% |
| CPI | 3.524 | 3.945 | 上升 |
| 数组读取 | 8次 `LW` | 4次 `LD` | -50% |
| I-Cache miss | 5 | 5 | 不变 |
| I-Cache等待周期 | 105 | 105 | 不变 |
| D-Cache stall周期 | 66 | 66 | 不变 |

提交指令减少8条，但固定的 I-Cache 和 D-Cache 等待没有变化，因此总周期只减少5个，CPI反而上升；评价优化效果应以总周期和正确性为主，不能只看 CPI 或静态指令数量。

回归结果：原有 `CPUUnrollHintPass` 二路展开测试仍为240周期降至222周期；`SUM2W_PIPELINE_tb` 仍得到 `x10=42、x11=43`；形状不匹配测试能够安全跳过转换。

**需要理解：** 本实验已经完成“LLVM Pass自动转换 → 自定义机器码 → RTL执行 → 性能量化”的软硬件端到端闭环；当前 SUM2W Pass 仍是面向 `sum_array` 的保守专用版本，后续可以再推广为更通用的循环模式识别。

# 2026/11/17：非投机全局相关预测器与竞赛预测器的实现和量化

## 1. 本阶段目标与实施顺序

本阶段目标是在原有16项、每项2位饱和计数器的普通 BHT 基础上，依次建立：

~~~text
模式0：普通 BHT
模式1：2位 GHR + Global PHT
模式2：普通 BHT / Global PHT 竞赛预测器
~~~

为了避免同时改变指令集、程序和预测器而导致实验变量混杂，先不补全 RV64I，也不实现投机 GHR，而是按照以下顺序实施：

1. 创建只依赖当前 CPU 指令子集的定向分支预测 Benchmark；
2. 固定普通 BHT 的周期和错判基线；
3. 在 BranchPredictionUnit.v 内实现非投机全局预测器与竞赛选择器；
4. 使用独立 TB 验证预测器内部功能；
5. 修改顶层和三级流水线寄存器，传递预测时元数据；
6. 使用完全相同的 ELF/HEX 比较三种预测模式；
7. 回归数组、Trap 和 D-Cache 整机测试。

本阶段的 GHR 只在有效条件分支到达 MEM、得到真实结果后更新：

~~~verilog
ghr <= {ghr[0], branch_taken_mem};
~~~

IF 阶段不会把预测结果提前移入 GHR，因此没有投机历史，也不需要错误预测恢复。

## 2. 创建分支预测定向 Benchmark

新增目录：

~~~text
software/branch_predictor_benchmark/
~~~

主要文件如下：

| 文件 | 作用 |
| --- | --- |
| main.c | 构造相关分支和 BHT 友好分支 |
| build.ps1 | 使用 Clang 构建 RV64I ELF/BIN/HEX/反汇编 |
| run.ps1 | 参数化编译并运行整机 TB |
| README.md | 记录构建、运行方法和实验目的 |
| program.disasm.txt | 最终机器码反汇编 |

同时新增：

~~~text
tb/CLANG_BRANCH_PREDICTOR_BENCH_tb.v
~~~

Benchmark 包含两个主要阶段。

### 2.1 相关分支阶段

分支 A 和分支 B 使用相同条件，该条件随循环迭代变化：

~~~text
A结果：T N T N T N ...
B结果：T N T N T N ...
~~~

单独观察 A 或 B 时，普通2位 BHT 很难预测交替结果；预测 B 时，如果 GHR 已经包含本轮 A 的结果，全局相关预测器就能学习：

~~~text
A=T → B=T
A=N → B=N
~~~

最终机器码中两条分支位于：

~~~text
分支A：PC 0x84
分支B：PC 0xA8
~~~

二者之间插入6条真实 RV64I NOP，使第一版“到 MEM 才更新 GHR”的非投机设计也有机会在预测 B 前得到 A 的真实结果。

### 2.2 BHT 友好阶段

另一个目标分支以8次为一个连续段改变方向：

~~~text
N N N N N N N N
T T T T T T T T
N N N N N N N N
...
~~~

普通 BHT 只需在每次方向切换时重新适应，能够获得较好准确率。在该分支前安排不相关分支改变短 GHR，使 Global PHT 把同一静态分支分散到多个历史上下文，从而构造出：

~~~text
相关分支：Global更好
长连续段分支：普通BHT更好
~~~

这为竞赛选择器提供了两个方向明确的胜场，而不是只证明全局预测器优于普通 BHT。

## 3. 第一次编译发现 C 分支被优化消除

第一版 C 源码使用两个普通 if，但 O2 反汇编显示 Clang 将分支 A 转换为：

~~~text
SLTU + ADD
~~~

机器码中只剩分支 B。源码中存在两个 if 并不代表最终机器码中一定存在两条条件分支，因此后续改用最小 RV64I 内联片段固定被测分支：

~~~asm
addi value, value, base
beq  condition, x0, 1f
addi value, value, extra
1:
~~~

该片段只有一条条件分支，不包含额外无条件跳转，能够防止编译器将控制流重新变成无分支运算。

**需要理解：** 分支预测实验必须以最终反汇编为准，不能只根据 C 源码判断动态分支结构。

## 4. 第一次整机运行暴露 RV64I 子集缺项

程序明确使用：

~~~text
-march=rv64i
-mabi=lp64
~~~

但第一次整机仿真没有到达 halt。检查反汇编和当前译码/ALU 后确认，编译器生成了合法 RV64I 指令：

~~~text
SRLI
SLTU
SLTIU
~~~

这些指令尚不在当前 CPU 已实现的 RV64I 子集中。为保持本阶段只研究分支预测，没有立即修改 CPU RTL，而是：

1. 将数据序列生成改为 ADD、SLLI、XOR 组合；
2. 避免右移和无符号比较；
3. 在 build.ps1 中增加反汇编检查。

构建脚本会拒绝：

~~~text
RV64M：MUL、DIV、REM及其变体
当前未支持：SRLI、SRAI、SLTU、SLTIU
当前未支持的分支：BLTU、BGEU
~~~

最终程序镜像为：

~~~text
BIN大小：408 B
HEX行数：51个64位word
~~~

没有出现 RV64M 或上述当前未实现的 RV64I 指令。

## 5. 去除用于保留分支的内存噪声

中间版本使用 volatile 内存条件强制编译器保留分支，第一次跑通时得到：

| 指标 | 中间版本 |
| --- | ---: |
| 周期 | 54,797 |
| 提交指令 | 33,576 |
| 条件分支 | 4,096 |
| 错误预测 | 1,478 |
| D-Cache stall周期 | 12,792 |

虽然能够运行，但大量 volatile load/store 让 D-Cache 停顿淹没分支预测收益。随后将条件保留在寄存器中，并继续使用最小内联 RV64I 分支保证控制流不被优化。

最终版本只有：

~~~text
D-Cache load miss：2
D-Cache stall周期：72
~~~

因此三种预测器之间的周期差异主要来自分支错误预测，而不是内存访问。

## 6. 固定普通 BHT 基线

最终 Benchmark 在原普通 BHT 上的结果为：

| 指标 | 普通BHT基线 |
| --- | ---: |
| 总周期 | 32,637 |
| 提交指令 | 27,814 |
| CPI | 1.173 |
| 条件分支 | 4,096 |
| Taken分支 | 3,006 |
| 错误预测 | 1,479 |
| 预测准确率 | 63.89% |
| I-Cache miss | 16 |
| D-Cache load miss | 2 |
| I-Cache等待周期 | 335 |
| D-Cache stall周期 | 72 |

关键静态分支结果为：

| 分支 | 错误/执行 |
| --- | ---: |
| 相关分支A | 512/512 |
| 相关分支B | 512/512 |
| 干扰分支0 | 1/512 |
| 干扰分支1 | 257/512 |
| 长连续段目标分支 | 128/512 |

TB 会检查五条关键分支都必须执行512次，防止编译器删除或合并分支。

在接入 RTL 前，按体系结构分支顺序建立的软件参考模型得到：

~~~text
普通BHT错判：       1479
2位GHR全局错判：     593
竞赛预测器错判：     462
~~~

其中普通 BHT 的参考值与 RTL 实测完全一致，证明分支序列符合预期；Global 和 Tournament 数字当时只作为结构可行性参考，最终仍以整机 RTL 为准。

## 7. 扩展 BranchPredictionUnit

修改：

~~~text
rtl/control/BranchPredictionUnit.v
~~~

模块增加参数：

~~~verilog
parameter PREDICTOR_MODE = 0
~~~

模式定义为：

~~~text
0：原普通BHT
1：非投机全局相关预测器
2：普通BHT/全局预测器竞赛
~~~

新增预测状态：

~~~verilog
reg [1:0] bht          [0:15];
reg [1:0] global_pht   [0:63];
reg [1:0] choice_table [0:15];
reg [1:0] ghr;
~~~

空间组成为：

~~~text
普通BHT：       16 × 2 bit =  32 bit
Global PHT：    64 × 2 bit = 128 bit
Choice Table：  16 × 2 bit =  32 bit
GHR：                         2 bit
总预测状态：                194 bit
~~~

IF 阶段并行读取：

~~~verilog
bht_index_if    = pc_if[5:2];
global_index_if = {ghr, pc_if[5:2]};

bimodal_prediction_if = bht[bht_index_if][1];
global_prediction_if  = global_pht[global_index_if][1];
~~~

选择器状态定义：

~~~text
00：强选择普通BHT
01：弱选择普通BHT
10：弱选择Global
11：强选择Global
~~~

Choice Table 只在两个候选预测器意见不一致时更新：

~~~verilog
if (bimodal_prediction_mem != global_prediction_mem) begin
    choice_table[bht_index_mem] <= update_counter(
        choice_table[bht_index_mem],
        global_prediction_mem == branch_taken_mem
    );
end
~~~

两个方向预测器都会按真实结果训练；Global PHT 使用从 IF 随指令保存下来的 global_index_mem，不会在 MEM 用已经变化的 GHR 重新计算索引。

默认 PREDICTOR_MODE=0，因此尚未接顶层时原 CPU 仍保持普通 BHT 行为。

## 8. 新增预测器独立功能 TB

新增：

~~~text
tb/BranchPredictionTournamentUnit_tb.v
~~~

TB 同时实例化普通 BHT、Global 和 Tournament 三个模式，验证：

1. 复位后方向计数器为弱不跳转；
2. Choice Table 初始弱选择普通 BHT；
3. 非分支指令不会产生 taken 重定向；
4. 非投机 GHR 按真实结果完成 00 → 01 → 10；
5. Global PHT 使用预测时索引更新；
6. Choice Table 能向 Global 移动，也能移回 BHT；
7. 相关分支 B 能被全局历史学习。

测试结果：

~~~text
Predictor unit results on correlated branch B:
  BHT misses        = 20 / 20
  Global misses     = 1 / 20
  Tournament misses = 2 / 20
PASS
~~~

Tournament 比纯 Global 多错一次来自 Choice Table 的预热过程，符合预期。

Icarus Verilog 对包含多组动态数组的设计需要使用 -u，否则合并编译单元模式可能无输出退出。

## 9. 修改三级流水线寄存器

修改：

~~~text
rtl/memory/IF_ID.v
rtl/memory/ID_EX.v
rtl/memory/EX_MEM.v
~~~

在原有 predicted_taken 和 bht_index 基础上新增：

~~~text
global_index          6 bit
bimodal_prediction    1 bit
global_prediction     1 bit
~~~

完整预测元数据为：

~~~text
bht_index             4 bit
global_index          6 bit
bimodal_prediction    1 bit
global_prediction     1 bit
final_prediction      1 bit
~~~

每一级都实现三种行为：

~~~text
reset或flush：所有预测元数据清零
stall：保持当前值
正常推进：锁存上一级输入
~~~

其中 global_index 必须从 IF 一直传到 MEM，因为更新时需要访问该分支预测时真正读取的 Global PHT 表项。

## 10. 顶层参数和数据通路接入

修改：

~~~text
rtl/PIPELINED_CPU.v
~~~

顶层增加：

~~~verilog
parameter BRANCH_PREDICTOR_MODE = 0
~~~

并向预测器传递：

~~~verilog
BranchPredictionUnit #(
    .PREDICTOR_MODE(BRANCH_PREDICTOR_MODE)
) u_branchpredictionunit (...);
~~~

顶层新增 IF、ID、EX、MEM 四级的 global_index、bimodal_prediction 和 global_prediction 信号。

训练有效信号收紧为：

~~~verilog
wire branch_resolve_valid_mem =
    valid_mem && Branch_mem && ~trap_enter;
~~~

该信号统一用于预测器训练和错误预测判断：

~~~verilog
wire branch_mispredict_mem =
    branch_resolve_valid_mem &&
    (predicted_taken_mem != branch_taken_mem);
~~~

因此流水线气泡、被冲刷指令和发生 Trap 的指令不会更新 BHT、Global PHT、Choice Table 或 GHR。

## 11. 参数化整机测试方法

CLANG_BRANCH_PREDICTOR_BENCH_tb.v 增加：

~~~verilog
parameter PREDICTOR_MODE = 0;
~~~

并传给 CPU 顶层。运行脚本支持：

~~~powershell
& software/branch_predictor_benchmark/run.ps1 -PredictorMode 0
& software/branch_predictor_benchmark/run.ps1 -PredictorMode 1
& software/branch_predictor_benchmark/run.ps1 -PredictorMode 2
~~~

三个模式加载完全相同的 program.hex，Cache、程序、编译选项和提交指令数均不变。

## 12. 三种预测器整机结果

| 指标 | 普通BHT | 非投机Global | Tournament |
| --- | ---: | ---: | ---: |
| 总周期 | 32,637 | 29,982 | 29,586 |
| 提交指令 | 27,814 | 27,814 | 27,814 |
| CPI | 1.173 | 1.078 | 1.064 |
| 条件分支 | 4,096 | 4,096 | 4,096 |
| Taken分支 | 3,006 | 3,006 | 3,006 |
| 错误预测 | 1,479 | 594 | 462 |
| 预测准确率 | 63.89% | 85.50% | 88.72% |
| I-Cache miss | 16 | 16 | 16 |
| D-Cache load miss | 2 | 2 | 2 |
| I-Cache等待周期 | 335 | 335 | 335 |
| D-Cache stall周期 | 72 | 72 | 72 |

相对普通 BHT：

~~~text
非投机Global：
  周期减少 8.13%
  加速比约 1.089×

Tournament：
  周期减少 9.35%
  加速比约 1.103×
  错误预测减少 68.76%
~~~

Tournament 相对纯 Global：

~~~text
错误预测减少：132次，即22.22%
周期减少：396，即1.32%
加速比约：1.013×
~~~

## 13. 分支分类结果

| 分支 | 普通BHT错判 | Global错判 | Tournament错判 |
| --- | ---: | ---: | ---: |
| 相关分支A | 512/512 | 2/512 | 3/512 |
| 相关分支B | 512/512 | 2/512 | 3/512 |
| 干扰分支0 | 1/512 | 4/512 | 1/512 |
| 干扰分支1 | 257/512 | 257/512 | 257/512 |
| 长连续段目标分支 | 128/512 | 255/512 | 128/512 |

这些数据说明：

1. Global PHT 能利用跨分支历史，将两条相关分支从全部错判降至各2次；
2. 同一个长连续段分支被不同 GHR 分散后，Global 错判从128次上升到255次；
3. Tournament 对相关分支选择 Global，对长连续段和强偏向分支选择普通 BHT；
4. 干扰分支1对三者都接近不可预测，因此仍为257次错判；
5. Tournament 的相关分支比 Global 多1次错判，来自选择器初始弱选择 BHT 的预热。

这证明竞赛预测器的收益不是“全局预测器整体更强”，而是能够针对不同静态分支选择更适合的预测机制。

## 14. 回归测试

除三模式 Benchmark 和预测器独立 TB 外，还运行以下整机回归。

### 14.1 原普通 BHT 兼容性

模式0结果与修改前完全一致：

~~~text
周期：32637
提交指令：27814
错误预测：1479
准确率：63.89%
~~~

说明新增端口、参数和表状态没有改变默认普通 BHT 行为。

### 14.2 数组求和

~~~text
CLANG_ARRAY_SUM_tb：PASS
周期：167
提交指令：44
返回值：31
分支错误：2/9
~~~

### 14.3 Trap整机测试

~~~text
PIPELINED_CPU_TRAP_tb：PASS
~~~

覆盖非法指令、访存错位、JAL/JALR目标错位、分支目标错位、外部中断和 MRET。尤其验证了发生 Trap 的分支不会破坏控制流。

### 14.4 D-Cache整机测试

~~~text
PIPELINED_CPU_DCache_tb：PASS
cycles=60
stall_cycles=27
stall_episodes=2
~~~

说明增加的预测元数据在 Cache stall 下能够随流水线正确保持，没有破坏原 D-Cache 停顿行为。

## 15. 本阶段结论与边界

本阶段已经形成完整闭环：

~~~text
可控C Benchmark
→ RV64I子集编译与反汇编检查
→ 普通BHT基线
→ 非投机Global Predictor
→ Tournament Chooser
→ 流水线元数据传递
→ 三模式整机周期和准确率比较
~~~

最终 Tournament 在相同程序、相同提交指令数和相同 Cache 指标下，将周期从32,637降低到29,586，周期减少9.35%，执行速度提升约10.3%。

当前阶段仍有以下边界：

1. GHR 在 MEM 才按真实结果更新，尚未投机更新；
2. 相邻且距离很近的相关分支可能在预测时看不到前一分支结果；
3. 尚未实现 GHR checkpoint、错误预测恢复（GHR所需的内部状态恢复没有实现，但是预测错误后流水线的冲刷和重定向复用了本来的逻辑）和其他重定向恢复；
4. RV64I仍未补全，Benchmark通过反汇编检查主动避开当前未支持指令；
5. 当前结果来自定向微基准，后续补全 RV64I 后还应使用 Embench/CoreMark 类通用负载验证。

下一阶段可以在“补全 RV64I”和“研究投机 GHR 原理与恢复机制”之间选择；在理解投机历史之前，当前非投机版本可作为稳定、可量化的基线。

---

# 2026年11月19日：面向 CoreMark 的 RV64IM 指令补全

## 1. 本阶段目标

本阶段不再使用为现有指令集定制的微基准，而是引入 EEMBC 官方
CoreMark，根据编译器实际生成的机器指令反向确定 CPU 需要补全的
指令。

官方源码固定为：

~~~text
repository: https://github.com/eembc/coremark
commit:     1f483d5b8316753a742cbf5590caf5bd0a4e4777
target:     riscv64-unknown-elf
march:      rv64im
mabi:       lp64
optimize:   -O2
~~~

首先只编译 CoreMark 的五个核心对象文件，不加入启动代码和链接脚本。
对象文件尺寸如下：

| 对象文件 | text/Byte | data/Byte | bss/Byte |
| --- | ---: | ---: | ---: |
| core_list_join.o | 2,926 | 0 | 0 |
| core_main.o | 3,336 | 24 | 2,000 |
| core_matrix.o | 2,496 | 0 | 0 |
| core_state.o | 2,032 | 0 | 0 |
| core_util.o | 918 | 0 | 0 |
| 合计 | 11,708 | 24 | 2,000 |

这说明当前约 2 KiB 的指令主存和数据主存均不足以容纳 CoreMark。
指令主存至少还要容纳约 11.7 KiB 核心代码、裸机启动和移植代码；
数据主存除 2,000 Byte 静态工作区外还要保留栈空间。

## 2. 反汇编结果

使用以下方式关闭伪指令别名并统计真实机器指令：

~~~powershell
llvm-objdump -d --no-show-raw-insn -M no-aliases
~~~

对象文件共出现 43 种指令。与修改前 RTL 对照后，确认有 20 种
CoreMark 必需指令尚未实现：

~~~text
BLTU BGEU
SLTU SLTIU
SRLI SRAI
SLLIW SRLIW SRAIW
MUL MULHU MULW DIVUW
LBU LH LHU LWU
SB SH SW
~~~

实现过程中同时补充了 LB、SLLW、SRLW 和 SRAW，使相关译码和数据
通路保持完整。

## 3. 新增算术、比较、分支和乘除指令

原 ALUControl 只有 4 bit，除非法值和自定义 SUM2W 外已没有足够编码
空间，因此扩展为 5 bit。原有操作编码保持数值不变，避免破坏已有
测试。

| 指令 | 关键编码 | 执行逻辑 | RV64 写回或跳转规则 |
| --- | --- | --- | --- |
| SLTU | OP，funct3=011 | 无符号比较 A 小于 B | 真写 1，否则写 0 |
| SLTIU | OP-IMM，funct3=011 | A 与符号扩展后的立即数做无符号比较 | 真写 1，否则写 0 |
| BLTU | BRANCH，funct3=110 | 复用无符号 A 小于 B 比较 | 比较结果非零时跳转 |
| BGEU | BRANCH，funct3=111 | 无符号比较 A 大于等于 B | 比较结果非零时跳转 |
| SRLI | OP-IMM，funct3=101，funct6=000000 | A 逻辑右移 shamt[5:0] | 64 bit 逻辑右移 |
| SRAI | OP-IMM，funct3=101，funct6=010000 | signed A 算术右移 shamt[5:0] | 64 bit 算术右移 |
| SLLIW | OP-IMM-32，funct3=001 | A[31:0] 左移 shamt[4:0] | 32 bit 结果符号扩展到 64 bit |
| SRLIW | OP-IMM-32，funct3=101，funct7=0000000 | A[31:0] 逻辑右移 | 32 bit 结果符号扩展到 64 bit |
| SRAIW | OP-IMM-32，funct3=101，funct7=0100000 | signed A[31:0] 算术右移 | 32 bit 结果符号扩展到 64 bit |
| SLLW | OP-32，funct3=001 | A[31:0] 左移 B[4:0] | 32 bit 结果符号扩展到 64 bit |
| SRLW | OP-32，funct3=101，funct7=0000000 | A[31:0] 逻辑右移 B[4:0] | 32 bit 结果符号扩展到 64 bit |
| SRAW | OP-32，funct3=101，funct7=0100000 | signed A[31:0] 算术右移 B[4:0] | 32 bit 结果符号扩展到 64 bit |
| MUL | OP，funct7=0000001，funct3=000 | 计算 128 bit 乘积 | 写回低 64 bit |
| MULHU | OP，funct7=0000001，funct3=011 | 两个 64 bit 无符号数相乘 | 写回 128 bit 乘积的高 64 bit |
| MULW | OP-32，funct7=0000001，funct3=000 | 低 32 bit 相乘 | 低 32 bit 乘积符号扩展到 64 bit |
| DIVUW | OP-32，funct7=0000001，funct3=101 | A[31:0] 除以 B[31:0]，无符号 | 商符号扩展；除数为 0 时结果为全 1 |

无符号分支在 MEM 级加入：

~~~verilog
bltu_taken = Branch && funct3 == 3'b110 && !zero;
bgeu_taken = Branch && funct3 == 3'b111 && !zero;
~~~

它们继续复用已有的分支重定向、错误预测冲刷和预测器训练路径。

当前乘法和除法均为组合逻辑。该实现便于首先验证 ISA 功能，但
DIVUW 会显著拉长 EX 级关键路径。后续若进行 FPGA 综合和频率优化，
应将除法器改为多周期迭代单元，并为流水线增加 busy/stall 握手。

## 4. 新增子字加载指令

D-Cache 仍以 64 bit 后端字为传输单位。CPU 根据有效地址低 3 bit，
先将返回字右移 byte_offset 乘 8，再按照 funct3 截取和扩展。

| 指令 | funct3 | 截取宽度 | 写回扩展 | 对齐要求 |
| --- | --- | ---: | --- | --- |
| LB | 000 | 8 bit | 符号扩展到 64 bit | 无 |
| LH | 001 | 16 bit | 符号扩展到 64 bit | addr[0]=0 |
| LW | 010 | 32 bit | 符号扩展到 64 bit | addr[1:0]=0 |
| LD | 011 | 64 bit | 原值写回 | addr[2:0]=0 |
| LBU | 100 | 8 bit | 零扩展到 64 bit | 无 |
| LHU | 101 | 16 bit | 零扩展到 64 bit | addr[0]=0 |
| LWU | 110 | 32 bit | 零扩展到 64 bit | addr[1:0]=0 |

加载地址对齐检查仍在 CPU MEM 级完成。错误对齐的加载在向 D-Cache
发请求前进入 trap，因此不会产生寄存器写回或缓存副作用。

## 5. 新增子字存储与 byte strobe

原 D-Cache 和 CacheBackingMemory 只能覆盖整个 64 bit 字，直接增加
SB/SH/SW 会错误破坏同一字中的其他字节。因此新增 8 bit 写掩码：

~~~text
CPU → DCache:             cpu_req_wstrb[7:0]
DCache → BackingMemory:   mem_req_wstrb[7:0]
BackingMemory:            req_wstrb[7:0]
~~~

| 指令 | funct3 | 基础写掩码 | 对齐要求 | 数据处理 |
| --- | --- | --- | --- | --- |
| SB | 000 | 0000_0001 | 无 | 低 8 bit 左移到目标 byte lane |
| SH | 001 | 0000_0011 | addr[0]=0 | 低 16 bit 左移到目标 halfword lane |
| SW | 010 | 0000_1111 | addr[1:0]=0 | 低 32 bit 左移到目标 word lane |
| SD | 011 | 1111_1111 | addr[2:0]=0 | 完整 64 bit 写入 |

基础掩码再左移 addr[2:0]，形成最终 byte strobe。D-Cache 命中时按照
掩码合并 cache word，后端主存也只更新掩码为 1 的字节，因此命中和
未命中 store 都不会破坏其他 byte lane。写后端地址统一向下对齐到
8 Byte 边界。

D-Cache 本身改为接受任意 byte address；具体指令是否合法对齐由 CPU
根据访问宽度判断。这一职责划分允许 LB/LBU/SB 正常访问任意字节。

## 6. 修改文件汇总

| 文件 | 修改内容 |
| --- | --- |
| rtl/control/Control.v | 新增指令合法性、源寄存器使用和控制信号译码 |
| rtl/control/ALUControl.v | ALU 控制扩展为 5 bit，并增加比较、移位和 M 操作编码 |
| rtl/datapath/ALU.v | 实现无符号比较、算术右移、word 移位和乘除法 |
| rtl/PIPELINED_CPU.v | 新增无符号分支判断、加载截取扩展、store 写数据/掩码和按宽度对齐检查 |
| rtl/Cache/DCache.v | 接入 byte strobe，支持子字地址和命中行部分更新 |
| rtl/memory/CacheBackingMemory.v | 按 req_wstrb 逐字节更新 64 bit memory word |
| rtl/legacy/single_cycle/CPU.v | 同步 ALUControl 端口宽度 |

## 7. 新增和扩展的测试

| Testbench | 覆盖内容 |
| --- | --- |
| CoreMarkALUInstructions_tb.v | 新增指令的 Control、ALUControl 和 ALU 单元语义 |
| CoreMarkALUPipeline_tb.v | BLTU/BGEU 冲刷恢复、M 指令及移位指令的五级流水线执行 |
| CoreMarkSubwordMemory_tb.v | LB/LBU/LH/LHU/LWU、SB/SH/SW 和 byte lane 保持 |
| PIPELINED_CPU_TRAP_tb.v | 增加错误对齐 LH、SH 的精确异常和副作用抑制 |
| DCache 原有测试 | 更新为 byte-addressed cache 接口契约，并验证原 64 bit 行为未退化 |

最终完整回归结果：

~~~text
TOTAL_PASS=37
TOTAL_FAIL=0
~~~

同时通过：

~~~text
git diff --check
残留 4 bit ALUControl 检查：0
~~~

## 8. 当前结论与边界

本轮已经覆盖当前 rv64im -O2 CoreMark 对象反汇编中出现的全部
43 种指令。这里的结论是“当前 CoreMark 所需 RV64IM 子集已实现”，
不能表述为“完整 RV64IM 已实现”。

尚未实现的 M 扩展指令仍包括：

~~~text
MULH MULHSU
DIV DIVU DIVW
REM REMU REMW REMUW
~~~

此外，当前还没有完成：

1. CoreMark 裸机启动代码、平台计时和结果签名；
2. 最终链接脚本和 ELF；
3. 对最终 ELF 再次反汇编；
4. 在 RTL 仿真中验证 CoreMark CRC 并测量周期、CPI 和分支预测收益。

## 9. CoreMark 最小实用主存扩容

根据当前对象文件的 11,708 Byte text 和 2,000 Byte bss，顶层采用以下
容量：

| 主存 | 64 bit 字数 | 容量 | 合法字节地址 |
| --- | ---: | ---: | --- |
| I-Cache backing memory | 2,048 | 16 KiB | 0x0000–0x3fff |
| D-Cache backing memory | 1,024 | 8 KiB | 0x4000–0x5fff |

CacheBackingMemory 新增 MEM_WORDS 参数，默认值仍为 256，即原来的
2 KiB。顶层 PIPELINED_CPU 通过 ICACHE_BACKING_WORDS 和
DCACHE_BACKING_WORDS 分别覆盖两个实例，因此独立缓存测试仍可使用
原默认容量。

地址索引宽度改为：

~~~verilog
WORD_INDEX_BITS = $clog2(MEM_WORDS)
word_index = pending_addr[WORD_INDEX_BITS+2:3]
~~~

合法地址通过 pending_addr 小于 MEM_WORDS 乘 8 判断，不再硬编码
地址位 63:11 必须为零。

新增 CacheBackingMemoryCapacity_tb，覆盖：

1. 16 KiB 主存最后一个合法 64 bit 字 0x3ff8 的读写；
2. 最后一个字的 byte strobe 部分写；
3. 首个越界地址 0x4000 不得破坏合法数据；
4. 越界读取返回 0；
5. 参数化容量常数检查。

扩容后的完整回归结果：

~~~text
TOTAL_PASS=38
TOTAL_FAIL=0
~~~

16 KiB 指令主存为当前 CoreMark 对象代码预留约 4 KiB 启动和移植代码
空间；8 KiB 数据主存在 2 KiB 静态数据之外预留约 6 KiB 栈及运行时
空间。最终是否足够仍应以裸机 ELF 链接后的 section size 和链接器
溢出检查为准。

### 9.1 为什么不能只把 256 改成一个更大的常数

修改前，CacheBackingMemory 中有三处容量相关的硬编码：

~~~verilog
reg [63:0] memory [0:255];
wire [7:0] word_index = pending_addr[10:3];
wire address_legal =
    (pending_addr[63:11] == 53'b0) &&
    (pending_addr[2:0] == 3'b000);
~~~

其中：

1. memory 数组限定为 256 个 64 bit 字，即 2 KiB；
2. 地址 10:3 正好形成 8 bit 索引，只能选择 256 个字；
3. 地址 63:11 必须为零，将合法地址限制在 0x000–0x7ff。

如果只把数组改为 memory[0:2047]，索引和合法地址检查仍然保持 2 KiB，
新增的数组空间不会被正常访问。另一方面，CoreMark 的指令和数据容量
需求不同，如果把两个主存实例都固定成同一个更大数组，会浪费仿真和
综合资源。因此本次选择参数化模块，而不是继续增加硬编码。

### 9.2 容量选择过程

当前已编译但尚未链接的五个 CoreMark 核心对象文件具有：

~~~text
text = 11,708 Byte
data = 24 Byte
bss  = 2,000 Byte
~~~

容量选择按以下过程完成：

1. 指令侧首先选择大于 11,708 Byte 的二次幂容量；
2. 8 KiB 明显不够，16 KiB 能额外提供约 4.6 KiB；
3. 额外空间用于启动代码、平台移植代码、结果签名和链接填充；
4. 数据侧至少需要容纳 2,000 Byte 静态工作区；
5. 再为栈、全局变量和少量运行时状态预留空间，选择 8 KiB；
6. 由于指令和数据主存是分离的，二者可使用不同参数。

这里的“最小”是当前编译结果下的最小实用配置，而不是最终严格下界。
真正的下界只能在生成最终 ELF 后，根据各 section 的装载地址和
链接器 MEMORY 区域检查得到。

### 9.3 CacheBackingMemory 参数化

模块头增加：

~~~verilog
module CacheBackingMemory #(
    parameter integer MEM_WORDS = 256
) (...);
~~~

保留 256 作为默认值的原因是：

1. 不改变独立 CacheBackingMemory 测试的原始规模；
2. 旧 testbench 未传参数时仍保持原行为；
3. 只有 CPU 顶层需要为 CoreMark 扩容；
4. 可以继续用小数组快速运行缓存单元测试。

数组与容量常数改为：

~~~verilog
localparam integer WORD_INDEX_BITS = $clog2(MEM_WORDS);
localparam [63:0] MEMORY_BYTES = MEM_WORDS * 8;
reg [63:0] memory [0:MEM_WORDS-1];
~~~

MEM_WORDS 表示 64 bit 字的数量，而不是字节数量。因此：

~~~text
MEMORY_BYTES = MEM_WORDS × 8
~~~

例如：

~~~text
2048 words × 8 Byte = 16384 Byte = 16 KiB
1024 words × 8 Byte =  8192 Byte =  8 KiB
~~~

### 9.4 参数化地址索引

64 bit 后端主存要求 8 Byte 对齐，因此地址低 3 bit 是 byte offset，
不参与 word 索引。

~~~verilog
wire [WORD_INDEX_BITS-1:0] word_index =
    pending_addr[WORD_INDEX_BITS+2:3];
~~~

以 16 KiB 配置为例：

~~~text
MEM_WORDS        = 2048
WORD_INDEX_BITS  = clog2(2048) = 11
word_index       = pending_addr[13:3]
~~~

地址 0x3ff8 的计算过程为：

~~~text
0x3ff8 / 8 = 0x7ff = 2047
~~~

它正好选择 memory[2047]，即数组最后一个元素。下一个地址 0x4000
对应索引 2048，必须判定为越界。

地址合法性改为：

~~~verilog
wire address_legal =
    (pending_addr < MEMORY_BYTES) &&
    (pending_addr[2:0] == 3'b000);
~~~

这个判断同时完成：

1. 容量边界检查；
2. 64 bit 后端字对齐检查。

即使 MEM_WORDS 将来不是二次幂，clog2 产生的索引位可能覆盖更多
编码，pending_addr 小于 MEMORY_BYTES 的比较仍会阻止访问数组外部。

### 9.5 顶层为 I/D 主存分别传参

PIPELINED_CPU 增加：

~~~verilog
parameter integer ICACHE_BACKING_WORDS = 2048,
parameter integer DCACHE_BACKING_WORDS = 1024
~~~

实例化时分别覆盖：

~~~verilog
CacheBackingMemory #(
    .MEM_WORDS(DCACHE_BACKING_WORDS)
) u_dcache_backing_memory (...);

CacheBackingMemory #(
    .MEM_WORDS(ICACHE_BACKING_WORDS)
) u_icache_backing_memory (...);
~~~

这样既能为程序代码提供更大空间，也不会把数据主存无条件扩展到相同
大小。以后若最终 ELF 超出容量，只需调整顶层参数，不需要再次修改
地址译码 RTL。

### 9.6 Backing memory 与 Cache 容量的区别

本次扩展的是 I-Cache 和 D-Cache 后方的主存容量，不是 Cache 容量。

~~~text
Backing memory：
  保存完整程序和数据，容量从 2 KiB 扩展到 16/8 KiB。

I-Cache / D-Cache：
  仍然只保存少量最近访问的 cache line，几何结构没有扩大。
~~~

因此扩容不会直接降低 cache miss rate，只是使 miss refill 能够访问
更大的合法地址范围。CoreMark 的工作集若超过 cache 容量，仍会产生
正常的替换和 miss，这正是后续性能测量需要保留的行为。

### 9.7 边界测试过程

新增 CacheBackingMemoryCapacity_tb，并使用 MEM_WORDS=2048 实例化
主存。测试顺序如下：

1. 向最后一个合法地址 0x3ff8 写入完整 64 bit 数据；
2. 从 0x3ff8 读回并比较；
3. 使用 req_wstrb=0x03 只修改最后一个字的低两个字节；
4. 再次读回，确认高六个字节保持不变；
5. 向第一个非法地址 0x4000 写入全 1；
6. 检查 memory[2047] 未被越界写破坏；
7. 读取 0x4000，确认非法读取返回 0；
8. 检查 MEMORY_BYTES 等于 16,384。

定向测试结果：

~~~text
PASS: 16 KiB backing-memory upper boundary and range check.
~~~

随后重新编译并运行全部 testbench。扩容前为 37 项，增加容量边界测试
后为：

~~~text
TOTAL_PASS=38
TOTAL_FAIL=0
~~~

这说明参数化没有破坏原有流水线、Cache、trap、CSR、分支预测和
CoreMark 指令测试。

### 9.8 后续加载 CoreMark 时的注意事项

现有多数 testbench 只初始化 memory[0] 到 memory[255]，因为旧程序
都位于前 2 KiB。这不会影响已有回归，但加载 CoreMark 时必须按照
ELF 或转换后的 hex 文件实际长度初始化更高地址。

后续应由构建脚本完成：

1. 将 ELF 中的可执行 section 转换为 64 bit 小端指令主存镜像；
2. 将 data、rodata 等 section 放入数据主存约定地址；
3. 初始化栈指针到 8 KiB 数据主存顶部附近；
4. 检查所有 section 与栈均未越过 0x2000；
5. 检查所有代码均未越过 0x4000；
6. 若链接器报告溢出，再通过顶层参数扩大容量，而不是修改模块逻辑。

下一步完成 CoreMark 裸机启动、链接脚本和实际运行。

## 10. 统一地址空间与 CoreMark 裸机启动（2026-11-22）

本阶段按“先修正地址模型并完成回归，再编写启动代码”的顺序执行。

### 10.1 为什么 I/D backing memory 不能都从地址 0 开始

CPU 内部虽然采用分离的 I-Cache 和 D-Cache，但编译器、ELF 和 C 指针使用的是
同一个地址空间。如果指令主存和数据主存都声明为从 0 开始，则链接器无法同时把
`.text` 和 `.data` 放在地址 0；程序中的数据指针也无法表达“访问 D-memory 的地址 0，
而不是 I-memory 的地址 0”。

本次确定的地址布局为：

| 区域 | 地址范围 | 容量 | 用途 |
|---|---:|---:|---|
| IMEM | `0x0000–0x3fff` | 16 KiB | `.text` |
| DMEM 静态区 | `0x4000–0x57ff` | 6 KiB | mailbox、`.rodata`、`.data`、`.bss` |
| DMEM 栈 | `0x5800–0x5fff` | 2 KiB | 向下增长的运行栈，初始 `sp=0x6000` |

特别注意：`.rodata` 放在 DMEM，而不是和 `.text` 一起放入 IMEM。当前是 Harvard
存储结构，C 代码执行普通 `load` 时只能经过 D-Cache；若字符串和常量位于 IMEM，
数据读取无法到达它们。

### 10.2 Backing memory 基址参数化

`CacheBackingMemory` 新增 64 bit 参数 `BASE_ADDR`。请求地址先转换为局部地址：

~~~verilog
local_addr = pending_addr - BASE_ADDR;
word_index = local_addr[WORD_INDEX_BITS+2:3];
~~~

合法请求同时满足：

~~~verilog
pending_addr >= BASE_ADDR
local_addr < MEMORY_BYTES
local_addr[2:0] == 0
~~~

顶层新增 `ICACHE_BACKING_BASE_ADDR` 和 `DCACHE_BACKING_BASE_ADDR`，默认值分别为
`0x0000` 与 `0x4000`。Cache 内部仍保留完整统一地址用于 tag；只有访问最终 backing
array 时才减去基址。

为了让旧的定制程序保持原地址布局，原有顶层 testbench 显式把
`DCACHE_BACKING_BASE_ADDR` 覆盖为 0。生产默认配置以及新的 CoreMark 测试使用
`0x4000`。

新增验证：

1. `CacheBackingMemoryBaseAddress_tb`：检查非零基址的首地址、末地址、下越界、
   上越界与非对齐访问；
2. `CoreMarkMemoryMap_tb`：在完整流水线中用 `LUI` 形成 `0x4000`，执行
   `LD → ADDI → SD → LD`，验证 CPU、D-Cache 与 backing memory 的地址传递。

地址映射完成后的阶段回归结果：

~~~text
TOTAL_PASS=40
TOTAL_FAIL=0
~~~

### 10.3 CoreMark 启动、链接与平台层

新增 `software/coremark`，包含：

| 文件 | 作用 |
|---|---|
| `start.S` | 设置 `sp=0x6000`、清零 `.bss`、调用 `main`、保存返回值并进入 halt loop |
| `link.ld` | 分离 IMEM/DMEM，检查 16 KiB 代码上限和 2 KiB 栈预留 |
| `core_portme.h/.c` | 定义 RV64 类型、静态内存模式、计时占位接口和结果 mailbox |
| `build.ps1` | 用 LLVM 编译/链接、检查指令集与容量、生成 I/D 两个 64 bit HEX 镜像 |
| `run.ps1` | 重新构建镜像、编译 testbench 并运行 RTL smoke test |

`_start` 在调用 C 代码前按 8 Byte 步长清零 `__bss_start` 到 `__bss_end`。链接器把
CoreMark 使用的只读常量和可写全局变量合并进 `.dmem` 输出段，再分别从 ELF 提取
`.text` 与 `.dmem`，生成：

~~~text
coremark-imem.hex  -> 2048 个 64 bit word
coremark-dmem.hex  -> 1024 个 64 bit word
~~~

镜像补零到 backing array 的完整深度，因此 `$readmemh` 不会产生文件长度不足警告。

### 10.4 真实链接暴露并补齐 SUBW

第一次链接后的反汇编检查发现平台计时差值生成了标准 RV64I 指令 `SUBW`，而原 CPU
只实现了 `ADDW`。因此没有通过改写 C 代码规避，而是补齐：

| 位置 | 修改 |
|---|---|
| `Control.v` | 接受 `funct7=0100000, funct3=000, opcode=0111011` |
| `ALUControl.v` | 将 `SUBW` 映射为控制码 `0x15` |
| `ALU.v` | 计算低 32 bit 的 `A-B`，再将 bit 31 符号扩展至 64 bit |
| 测试 | 增加正结果、负结果及完整流水线相关性验证 |

原 `ADDW_tb` 曾把 `SUBW` 当作非法反例；实现后将它改为功能验证，并使用仍未实现的
`XORW` 作为非法 OP-32 编码，避免测试目标失效。

### 10.5 最终 ELF 尺寸与实际运行结果

LLVM 最终链接结果：

~~~text
.text       10868 Byte  @ 0x0000
.dmem        2028 Byte  @ 0x4000
.bss         2024 Byte  @ 0x47f0
stack top              = 0x6000
~~~

链接器断言确认 `.text` 未超过 16 KiB，静态数据结束地址未进入 `0x5800–0x5fff`
的 2 KiB 栈保留区。构建脚本还解析完整反汇编并拒绝当前 CPU 未实现的指令。

`CoreMarkSmoke_tb` 加载上游 CoreMark 的 I/D 镜像，运行到 `coremark_halt`，并通过
位于 `0x4000` 的 mailbox 判断上游 CRC 验证结果。实测：

~~~text
PASS: CoreMark upstream CRC validation completed.
cycles             = 1,137,169
valid instructions observed at MEM = 319,615
ee_printf calls    = 15
mailbox status     = 2 (PASS)
main return value  = 0
~~~

这是 `ITERATIONS=1` 的功能与 CRC smoke test。当前平台计时器每次调用固定前进 10 tick，
只用于让 CoreMark 完成验证路径；它不是硬件周期计数器，所以不能用这里的时间或
Iterations/Sec 对外报告 CoreMark 分数。上述 `cycles` 是 testbench 观察到的 RTL
仿真周期，可用于调试，但在实现真实 `mcycle`、确定时钟频率和按官方规则增加迭代数
之前，不应作为正式 benchmark 成绩。

加入 CoreMark smoke test 后的最终完整回归：

~~~text
TOTAL_PASS=41
TOTAL_FAIL=0
~~~
