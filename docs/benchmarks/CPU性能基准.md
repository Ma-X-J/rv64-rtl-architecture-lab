# CPU 性能基准

## 原始基准：LLVM Pass 前

记录日期：2026/11/10。

本表用于后续比较“原始程序”和“经过 LLVM Pass 的程序”，测量对象为当前 RTL、当前 ELF 和 Icarus Verilog 仿真结果。

### 统一测量口径

- 每项测试均从解除 `reset` 开始，到程序第一次进入 testbench 规定的 `halt` 为止。
- I-Cache、D-Cache 均从无效状态开始，因此结果包含冷启动 miss。
- `halt` 自环不计入提交指令数。
- 指令在有效 MEM 阶段被 MEM/WB 接受且未触发 Trap 时记为提交一次。
- Cache miss 统计新请求被 Cache 接受并确认未命中的次数；stall 统计等待状态持续的周期数。

### 基准结果

| 程序 | 周期数 | 提交指令数 | CPI | I-Cache miss | I-Cache等待周期 | D-Cache Load miss | D-Cache stall周期 | Taken分支 | 分支预测错误 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `minimal` | 33 | 3 | 11.000 | 1 | 21 | 0 / 0 | 0 | 0 / 0 | 0 / 0 |
| `int_add` | 91 | 13 | 7.000 | 2 | 42 | 1 / 1 | 27 | 0 / 0 | 0 / 0 |
| `fibonacci` | 5159 | 1949 | 2.647 | 4 | 84 | 10 / 265（3.8%） | 1800 | 89 / 177 | 87 / 177 |
| `array_sum` | 167 | 44 | 3.795 | 3 | 63 | 2 / 8（25.0%） | 42 | 7 / 9 | 2 / 9 |

### 结果说明

- `minimal` 指令数量极少，固定的 I-Cache 冷启动 miss 无法被摊薄，因此 CPI 最高。
- `int_add` 的 D-Cache stall 同时包含栈 Store 写穿透和后续 Load miss 的等待时间。
- `fibonacci` 的大量递归栈 Store 使 D-Cache stall 达到 1800 周期，因此不能只根据 Load miss 数量判断访存开销。
- `array_sum` 的数组从 `0x48` 开始并跨越两个 32 字节 Cache line，因此 8 次 `LW` 产生 2 次冷 miss。

后续 LLVM Pass 实验必须保持相同的输入、Cache 初始状态、编译选项和统计窗口，再比较提交指令数、总周期、CPI、Cache miss 与分支预测结果。

循环展开及自定义 LLVM Pass 的受控优化结果单独记录在 [LLVM循环优化性能对比.md](LLVM循环优化性能对比.md)，不与本页使用不同编译流程得到的原始基准直接混算。
