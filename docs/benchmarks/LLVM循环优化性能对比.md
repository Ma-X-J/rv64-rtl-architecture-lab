# LLVM 循环优化性能对比

## 实验目标

比较数组求和循环在未展开、二路展开和四路展开时，于当前五级流水线 RV64 CPU 上的实际性能，并验证自定义 `CPUUnrollHintPass` 能否自动复现最佳展开策略。

## 统一实验条件

- 输入均来自同一份规范化 `prepared.ll`；
- RISC-V 后端统一使用 `llc -O2`；
- `.data` 统一按 32 字节 D-Cache Line 对齐；
- CPU、Cache 初始状态、数组内容和 TB 统计窗口完全相同；
- 每个程序必须完成 8 次 `LW`、返回 31、无 Trap，并恢复栈指针；
- 对比 TB 为
  `tb/programs/clang/CLANG_ARRAY_SUM_UNROLL_COMPARE_tb.v`。

这些数据只用于本组受控循环展开实验，不与 `docs/benchmarks/CPU性能基准.md` 中由另一套 Clang 编译流程生成的原始 `array_sum` 数据直接混算。

## O2 最终结果

| 版本 | `.text`大小 | 周期数 | 提交指令数 | CPI | I-Cache miss | I-Cache等待 | D-Cache stall |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 未展开 | 128 B | 240 | 66 | 3.636 | 5 | 105 | 66 |
| 手工二路展开 | 148 B | 222 | 63 | 3.524 | 5 | 105 | 66 |
| 自定义 Pass 二路展开 | 148 B | 222 | 63 | 3.524 | 5 | 105 | 66 |
| 四路展开 | 180 B | 241 | 61 | 3.951 | 6 | 126 | 66 |

## 结论

- 二路展开使周期减少 7.5%、动态指令减少 4.5%，且没有增加 Cache miss；
- 四路展开虽然使动态指令减少 7.6%，但增加一次 I-Cache miss，最终比未展开多 1 个周期；
- 自定义 `CPUUnrollHintPass` 生成的 O2 汇编和 BIN 与手工二路展开版本逐字节一致；
- 当前 256 字节直接映射 I-Cache 下，二路展开是三种方案中的最佳折中。

## 自定义 Pass 链路

```text
baseline/prepared.ll
→ CPUUnrollHintPass 写入 llvm.loop.unroll.count = 2
→ llvm_unroll/cpu_hinted.ll
→ LLVM loop-unroll 完成安全展开
→ llvm_unroll/cpu_unrolled2.ll
→ O2汇编 / ELF / HEX
→ Verilog CPU testbench
```

自定义 Pass 当前只处理已经规范化、带有 `!llvm.loop` 标记的 `sum_array`，尚不是通用循环优化器。

## O0 诊断实验

| O0版本 | 周期数 | 提交指令数 | CPI | I-Cache miss | I-Cache等待 | D-Cache stall |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 未展开 | 873 | 216 | 4.042 | 7 | 147 | 474 |
| 四路展开 | 1352 | 186 | 7.269 | 27 | 567 | 675 |

O0 四路展开因代码超过 I-Cache 容量且产生大量寄存器 spill/reload，虽然动态指令减少，周期仍增加 54.9%。该结果用于说明寄存器压力和代码容量影响，不作为最终优化方案。
