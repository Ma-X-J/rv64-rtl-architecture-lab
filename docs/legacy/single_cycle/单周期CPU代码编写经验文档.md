# 单周期 CPU 代码编写经验记录（2026/9/20）

这份记录按本次实际推进的顺序整理，止于 [`CPU.v`](rtl/CPU.v) 全部连线完成并通过编译。这里实现的是一个教学用的 **RV64 指令子集单周期 CPU**：PC 和数据通路为 64 位，指令为 32 位，支持 `add/sub/and/or`、`ld/sd` 和 `beq`。图上的 IF、ID、EX、MEM、WB 是一条指令在一个周期内经过的功能部分；此时还没有流水级寄存器。

## 一、模块是按什么顺序写出来的

| 顺序 | 文件 | 当时要解决的事 | 遇到的主要问题与收获 |
| --- | --- | --- | --- |
| 1 | [`ALU.v`](rtl/datapath/ALU.v) | 给两个 64 位操作数和 4 位控制码，产生运算结果及 `Zero` | 把图中的 ALU 黑盒变成“输入、选择、输出”的组合逻辑；四种运算可用 `case` 表达。 |
| 2 | [`ALUControl.v`](rtl/control/ALUControl.v) | 将 `ALUOp` 和指令功能位翻译为 ALU 的 4 位控制码 | 搞清楚 `ALUOp` 不是直接送进 ALU 的最终操作码；当前只按图使用 `instruction[30]` 与 `instruction[14:12]`。 |
| 3 | [`Control.v`](rtl/control/Control.v) | 用 opcode 生成 `Regwrite`、`MemWrite`、`MemRead` 等主控制信号 | 先查清四类指令的 opcode，再把控制表逐行写成 `case`；所有输出先给安全默认值。 |
| 4 | [`Register.v`](rtl/datapath/Register.v) | 实现 32 个 64 位通用寄存器、双读口和单写口 | 学习 Verilog 数组；分清写寄存器编号与写入的数据；组合读、上升沿写；`x0` 始终读零且禁止写。 |
| 5 | [`Immgen.v`](rtl/datapath/Immgen.v) | 从 32 位指令拆出 I/S/B 型立即数，扩展为 64 位 | 立即数不是“把整个指令补到 64 位”，而是先按格式拼位，再复制符号位。 |
| 6 | [`PC.v`](rtl/datapath/PC.v) | 保存当前 64 位 PC | PC 是字节地址，不是指令本身；复位与更新发生在时钟上升沿，`NextPC` 由顶层决定。 |
| 7 | [`IR.v`](rtl/memory/IR.v) | 用 PC 从 256×32 位指令 ROM 取一条指令 | 32 位指令占 4 字节，因此 `PC[9:2]` 是 ROM 下标；不是每种指令建一个 ROM。 |
| 8 | [`DataMemory.v`](rtl/memory/DataMemory.v) | 实现 64×64 位数据存储器 | `sd` 只有写入效果，不需要为写操作单独设置输出；字节地址与 64 位数组下标要换算。 |
| 9 | [`CPU.v`](rtl/CPU.v) | 把以上模块接成完整数据通路 | 先接能形成闭环的主线，再逐步补 ALU 输入、存储器、写回和分支选择；端口拼写和位宽必须逐一核对。 |

## 二、每个模块里真正学到的东西

### 1. ALU：先确定功能，再写 Verilog

ALU 本身只需要知道 `A`、`B`、`ALUControl`，不需要知道 opcode、`ALUOp` 或整条指令。当前控制码为 `0000→AND`、`0001→OR`、`0010→ADD`、`0110→SUB`。它用 `always @(*)` 和 `case` 形成组合逻辑，`Zero` 由结果是否为零得到。执行 `beq` 时，前级会让 ALU 做减法，所以两数相等恰好对应 `Zero=1`。

这一段的思维转变是：**先为黑盒列出输入、输出和真值关系，再决定用 `assign` 还是 `always @(*)` 描述。** `output reg` 在这里表示该输出由过程块赋值，并不意味着 ALU 内部增加了时钟寄存器。

### 2. ALUControl：两层控制不能混成一层

主控制器根据 opcode 输出两位 `ALUOp`：访存用 `00`，`beq` 用 `01`，R 型用 `10`。`ALUControl` 再结合指令功能位，把它翻译成 ALU 真正接收的四位码。因此“ALU 只看四位控制码”与“顶层需要传递 `ALUOp`、指令功能位”是同时成立的。

当前 R 型译码特意遵照所用数据通路图，仅检查 `{instruction[30], instruction[14:12]}`；未支持的组合输出 `1111`。它足以区分本次的四种 R 型运算，但**没有检查完整 `funct7`，也不是完整的非法指令识别**。这是当时明确保留的实现范围。

### 3. Control：把控制表逐行翻译成译码逻辑

这一步卡在“不知道 opcode 从哪里来”。先确定本次四类 opcode，再做控制表：

| 指令类 | opcode | 数据通路中的关键动作 |
| --- | --- | --- |
| R 型 | `0110011` | 两个寄存器送 ALU，结果写回寄存器。 |
| `ld` | `0000011` | 基址加立即数，读数据存储器，读数写回。 |
| `sd` | `0100011` | 基址加立即数，把第二读口的数据写入存储器。 |
| `beq` | `1100011` | 两寄存器相减比较，相等时选择分支目标 PC。 |

组合译码先给所有控制输出默认值，然后在命中的 opcode 分支里覆盖所需信号。这样不会因为某条路径漏赋值而无意留下旧值；未知 opcode 默认也不会写寄存器或内存。这里仅按 opcode 分大类，具体 R 型操作由 `ALUControl` 再译码。

### 4. Register：数组、端口和时序的关系

`reg [63:0] registers[0:31]` 表示 **32 个元素，每个元素 64 位**。`Readregister1/2` 和 `Writeregister` 是 5 位编号；`Readdata1/2` 与 `Writedata` 才是 64 位数据。“write register”是目的寄存器的编号，“write data”是要存进去的值。

两个读口放在 `always @(*)` 中，地址或数组内容变化时重新给出读数；写口放在 `always @(posedge clk)` 中，仅在 `Regwrite && (Writeregister != 5'd0)` 时更新。判断编号不为零是为了保护 RISC-V 的 `x0`。这一步还遇到过程块赋值对象该声明为 `reg` 还是 `wire` 的问题：Verilog 中由 `always` 块赋值的输出要声明为 `reg`，连续赋值通常连接 `wire`。

### 5. Immgen：先还原立即数，再符号扩展

`ld` 的 I 型立即数来自 `instruction[31:20]`；`sd` 的 S 型立即数来自 `{instruction[31:25], instruction[11:7]}`。它们各为 12 位，所以在当前 64 位通路中，高位复制 52 个 `instruction[31]`。正数高位补零，负数高位补一。

`beq` 的位被拆散存放，当前模块拼出 `{instruction[31], instruction[7], instruction[30:25], instruction[11:8]}`，扩展后得到**尚未左移的偏移值**。图中的 Shift left 1 留给 `CPU.v` 完成。例如 `beq` 的字节偏移为 `+8` 时，这根线先表示 `4`，顶层左移一位后才变成 `8`。不要在 Immgen 和顶层各左移一次。

### 6. PC 与 IR：字节地址怎样找到 32 位指令

当前 PC 是 64 位**字节地址**，ROM 的每项是 32 位（4 字节）指令。顺序执行时 PC 加 4；例如十进制 `PC=8` 对应第三条指令，下标为 `8/4=2`，在硬件中就是 `CurrentPC[9:2]`。`CurrentPC[1:0]` 必须为 `00` 才是本实现接受的对齐地址；高位检查把取指限制在这 256 项 ROM 的地址范围内。

ROM 中的各项是“程序的第几条指令”，并不是“某种指令专属的位置”。当前前四项依次放 `add`、`ld`、`sd`、`beq`；其他项预置为 `add x0,x0,x0`，相当于对可见寄存器状态无影响的占位指令。取出的 32 位 `instruction` 才交给后面的译码模块识别类型。

### 7. DataMemory：区分地址、写入值、读出值

以 `sd x5, 8(x2)` 为例：寄存器堆的 `Readdata1` 是 `x2` 的基址，`Readdata2` 是 `x5` 的内容；立即数 8 与基址经 ALU 相加形成字节地址；`Readdata2` 同时直达存储器的 `Writedata`。在上升沿且 `MemWrite=1` 时，数据写入内存。写入不需要额外的输出端口，之后读取内存即可观察其结果。

当前存储器每项 8 字节，因此使用 `Address[8:3]` 作 64 项数组的下标：字节地址 8 对应下标 1，字节地址 16 对应下标 2。`MemRead=1` 时组合读，`MemWrite=1` 时上升沿写。现有代码默认地址已按 8 字节对齐且在使用范围内；它没有检查被忽略的高地址位和低三位。读逻辑只列出 `MemRead=0/1`，这覆盖了实际二值控制，但仿真出现 `X/Z` 时没有 `default` 赋值。这些是当前教学模型的边界，不能误认为已经处理了所有访存错误。

## 三、CPU.v 是怎样从上到下接起来的

顶层的难点不在再写一个复杂算法，而是**把每个模块的输入来源、输出去向和位宽逐一对应起来**。实际采用了下面的渐进顺序，而不是一次写完所有线。

1. **先声明接口与中间线。** 顶层只有 `clk`、`reset` 两个输入；列出 `current_pc/next_pc`（64 位）、`instruction`（32 位）、`instruction64`（64 位）、两个寄存器读数、ALU 结果、存储器读数，以及各一位或两位控制信号。先把线命名，后面实例化时才有明确的连接对象。
2. **先接 PC、IR、Control，形成取指与主译码链。** 开始时暂用 `next_pc = current_pc + 4`，使 PC 可以顺序前进。`current_pc` 送 IR，IR 的 `instruction[6:0]` 送 Control。这样最先能检查的不是执行结果，而是 PC、指令和控制信号是否沿预想方向流动。
3. **接 ALUControl。** 把 Control 的 `ALUOp` 和整条 `instruction` 送入它，得到四位 `ALUControl`。这一层解决“当前指令要让 ALU 做什么”，与主控制器的“这是什么指令类”分开。
4. **接 Immgen。** 整条 32 位指令进入 Immgen，输出 64 位 `instruction64`，供访存地址计算和后来的分支地址计算使用。
5. **接 Register。** `instruction[19:15]`、`[24:20]`、`[11:7]` 分别是 `rs1`、`rs2`、`rd` 的编号。初接线时尚无写回数据，曾把 `Writedata` 暂接 0、`Regwrite` 暂接 0；这只是为了先完成读路径，**不能当成最终连线**。
6. **接 ALU 和它的 B 输入 MUX。** `A` 取 `readdata1`；`B` 根据 `ALUSrc` 在 `instruction64` 和 `readdata2` 之间选。R 型、`beq` 用寄存器操作数；`ld/sd` 用立即数。ALU 的 `aluresult` 与 `zero` 分别留给后续访存/写回和分支判断。
7. **接 DataMemory。** `Address=aluresult`、`Writedata=readdata2`，读写使能接 Control 的 `MemRead/MemWrite`，读数接新声明的 64 位 `mem_readdata`。这里第一次漏接了 `MemWrite`，编译器提示输入悬空；`sd` 不可能靠一个未驱动的写使能可靠工作。
8. **闭合写回路径。** 用 `MemtoReg ? mem_readdata : aluresult` 选出寄存器写入值，再把它和真正的 `Regwrite` 接回 Register，替换第 5 步的临时常量连接。这样 R 型从 ALU 写回，`ld` 从存储器写回。
9. **最后闭合分支 PC 路径。** 由 `instruction64 << 1` 得到 `branch_offset`，计算 `branch_pc = current_pc + branch_offset` 与 `pc_plus4 = current_pc + 4`；`Branch & zero` 决定 `next_pc` 取哪一个。Shift left 1、两个加法器和 MUX 都可以在顶层用连续赋值描述，不必为每个图形单独建立 `.v` 模块。

按最终数据流读 `CPU.v`，可以沿着 `PC → IR → Control/ALUControl/Immgen → Register → ALU → DataMemory → 写回` 追一条指令；遇到 `beq` 时再沿 `Zero → 分支选择 → NextPC` 回到 PC。

### 顶层接线时实际踩过的坑

| 当时的写法或现象 | 原因 | 最后确认的规则 |
| --- | --- | --- |
| `.B(ALUSrc ? (instruction64:readdata2))` 编译失败 | 三目运算符的 `?`、`:` 被错误地放进一组括号 | 使用 `ALUSrc ? instruction64 : readdata2`。 |
| `.ALUResult(aluresult)` 后直接写 `.Zero(zero)` | 端口连接之间漏逗号 | 命名端口连接除最后一项外都要以逗号分隔。 |
| DataMemory 实例漏接 `MemWrite` | 只接了地址、写入数据和读口 | 端口声明要逐项核对；编译器的悬空输入警告必须追查。 |
| 写成 `Memwrite`、`branch` | Verilog 标识符区分大小写；这两个拼写不是 `MemWrite`、`Branch` | 大小写必须与声明一致，否则可能产生未驱动的隐式线网。 |
| `branch_offset = instruction << 1`，且行末漏分号 | 错把整条 32 位指令当偏移；语法也未结束 | 分支偏移来自 Immgen 的 64 位 `instruction64`，写成 `instruction64 << 1;`。 |
| 初期寄存器写使能接常量 0 | 只是分阶段接线的临时措施 | 写回 MUX 完成后必须恢复为 Control 的 `Regwrite`。 |

最终顶层能通过编译，只有寄存器堆和数据存储器数组在 `always @(*)` 中被读取时的敏感列表提示。**编译通过说明语法与实例端口能建立起来，不等于所有指令行为已经经过仿真验证。**

## 四、这次形成的手写方法

面对一个数据通路黑盒，先用一句话写出它“接收什么、什么时候生效、产生什么”，再决定代码形式：纯计算和选择用组合逻辑；PC、寄存器写口、存储器写口用时钟上升沿更新。数组下标要先从**字节地址**换算到每项的字节数；端口连接要逐个核对方向、位宽和大小写。

接顶层时保留一个能编译的中间状态，每次只补一段数据流，并分清临时常量与最终连接。最后回头检查两个闭环：一是结果能否写回目的寄存器，二是分支能否把正确的 `NextPC` 送回 PC。这比盯着一整张图一次性翻译成 Verilog 更容易定位问题。
