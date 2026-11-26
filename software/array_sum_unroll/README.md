# Array Sum 循环与指令扩展实验

本目录只保存实验源码、LLVM IR 和公共链接文件。汇编、目标文件、ELF、
反汇编、HEX 等生成物统一写入：

```text
build/software/array_sum_unroll/
```

RTL 回归使用的稳定 HEX 副本位于：

```text
tb/fixtures/programs/array_sum_unroll/
```

## 四类对比实现

| 目录 | 实现 | 说明 |
|---|---|---|
| `baseline/` | 原始循环 | 保存原始及规范化后的基准 IR |
| `manual_unroll/` | 人工循环展开 | 保存手工二路、四路展开 IR |
| `llvm_unroll/` | LLVM Pass 展开 | 保存 Pass 提示及自动二路展开结果 |
| `sum2w/` | 自定义指令 | 保存人工 SUM2W IR 与自定义 Pass 输出 IR |
| `common/` | 公共文件 | 链接脚本等各方案共享输入 |

主要变换链路为：

```text
baseline/prepared.ll
    -> CPUUnrollHintPass
    -> llvm_unroll/cpu_hinted.ll
    -> LLVM loop-unroll
    -> llvm_unroll/cpu_unrolled2.ll
```

自定义 SUM2W Pass 以 `llvm_unroll/cpu_unrolled2.ll` 为输入，构建命令为：

```powershell
& .\scripts\llvm\build_sum2w_pass.ps1
```

该命令把所有生成物写入 `build/software/array_sum_unroll/sum2w/pass/`，
并刷新 `tb/fixtures/programs/array_sum_unroll/sum2w/pass_o2.hex`。

若其他方案的镜像也被重新生成，可统一刷新全部回归夹具：

```powershell
& .\scripts\update_test_fixtures.ps1
```
