# RV64 RTL Architecture Lab

[中文说明](README.zh-CN.md) · [RTL regression](https://github.com/Ma-X-J/rv64-rtl-architecture-lab/actions/workflows/rtl-regression.yml)

A 64-bit, single-issue, in-order RISC-V CPU implemented in Verilog for RTL and computer-architecture experiments.

![Branch misprediction recovery waveform](docs/architecture/branch-recovery-waveform.png)

## What is implemented

- Five-stage IF/ID/EX/MEM/WB pipeline with forwarding, load-use stalls, flush, and misprediction recovery.
- An RV64I subset extended with the RV64M operations needed by the current CoreMark image, plus the custom `SUM2W` instruction.
- Configurable 16-entry bimodal BHT, 2-bit global-history correlated predictor, and tournament predictor.
- Machine-mode CSR, trap/interrupt handling, `ECALL`, and `MRET`.
- Separate blocking direct-mapped I-Cache and D-Cache with multi-cycle backing-memory handshakes.
- Bare-metal Clang/LLVM builds, an upstream CoreMark functional port, and custom LLVM-pass experiments.
- 42 self-checking Icarus Verilog testbenches, including unit, pipeline, cache, software, and CoreMark tests.

This is an educational core rather than a complete RV64IM implementation. See [Current scope](#current-scope) before reusing it as a general RISC-V target.

## Measured results

All results below were reproduced on the current RTL with cold caches.

### Branch predictor benchmark

The same 4,096-branch RV64I workload is run in all three modes.

| Predictor | Cycles | CPI | Mispredictions | Accuracy |
|---|---:|---:|---:|---:|
| 16-entry bimodal BHT | 32,637 | 1.173 | 1,479 | 63.89% |
| 2-bit-GHR correlated | 29,982 | 1.078 | 594 | 85.50% |
| Tournament | **29,586** | **1.064** | **462** | **88.72%** |

The tournament predictor reduces cycles by 9.35% and mispredictions by 68.76% relative to the bimodal BHT on this controlled workload.

### LLVM loop experiment

| Version (`-O2`) | Cycles | Retired instructions | I-Cache misses |
|---|---:|---:|---:|
| Baseline | 240 | 66 | 5 |
| Manual 2-way unroll | 222 | 63 | 5 |
| Custom LLVM-pass 2-way unroll | **222** | **63** | **5** |
| 4-way unroll | 241 | 61 | 6 |

The selected 2-way unroll reduces cycles by 7.5%. The 4-way version executes fewer instructions but adds an I-Cache miss and is slower, showing why instruction count alone is not a sufficient metric.

### Verification status

| Check | Result |
|---|---|
| Complete RTL regression | **42 / 42 passed** |
| Upstream CoreMark functional run | **CRC validation passed** |
| CoreMark RTL simulation | 1,137,169 cycles; 319,615 instructions observed at MEM |
| SUM2W LLVM transformation | `transformed=1`; generated custom encoding verified |

CoreMark currently uses a fixed functional timer. Its CRC result validates compilation and execution, but it is **not an official CoreMark score**.

## Reproduce

### Requirements

- Python 3
- Icarus Verilog (`iverilog` and `vvp`)
- GTKWave when reproducing the README waveform
- PowerShell, Clang/LLVM 23, and CMake only when rebuilding software or LLVM passes

Run the committed-fixture RTL regression:

```powershell
python .\scripts\run_regression.py
```

Reproduce the branch-misprediction recovery waveform shown at the top of this
README:

```powershell
& .\scripts\generate_readme_waveform.ps1
```

The script compiles and self-checks the short demonstration program, writes
`build/readme-waveform/branch-recovery.vcd`, and opens GTKWave with the
committed signal order, colors, markers, and time range. To generate only the
VCD without opening GTKWave, add `-NoGui`.

Rebuild and run the CoreMark functional image:

```powershell
& .\software\coremark\run.ps1
```

Rebuild the predictor benchmark and compare all modes:

```powershell
& .\software\branch_predictor_benchmark\build.ps1
& .\software\branch_predictor_benchmark\run.ps1 -PredictorMode 0
& .\software\branch_predictor_benchmark\run.ps1 -PredictorMode 1
& .\software\branch_predictor_benchmark\run.ps1 -PredictorMode 2
```

Build the SUM2W LLVM pass and generated program:

```powershell
$env:LLVM_BIN = 'C:\path\to\complete-llvm\bin' # optional if opt.exe is on PATH
& .\scripts\llvm\build_sum2w_pass.ps1
python .\scripts\run_regression.py SUM2W_DECODE_ALU_tb SUM2W_PIPELINE_tb
```

Generated outputs are written under ignored `build/` directories. Regression HEX fixtures are committed under `tb/fixtures/`, so the standard regression does not require LLVM.

## Repository layout

| Path | Contents |
|---|---|
| `rtl/` | Current pipelined RTL and retained legacy single-cycle RTL |
| `tb/` | Unit, integration, program, and legacy testbenches plus fixtures |
| `software/` | Bare-metal sources, linker scripts, and build commands |
| `compiler/` | Custom LLVM pass source |
| `scripts/` | Regression, fixture, diagram, LLVM, and Vivado helpers |
| `docs/` | Architecture figures, benchmark records, and development log |
| `third_party/` | Vendored upstream CoreMark source and license |

## Current scope

- The implemented ISA is the subset exercised by the included programs and tests, not full RV64IM compliance.
- `DIVUW` is currently combinational; this project has not been synthesized or timed as a performance-ready divider.
- Privileged support is a machine-mode teaching subset, not a complete privileged architecture.
- Performance numbers are RTL-simulation results for controlled workloads and are not silicon measurements.

More detail is available in the [benchmark notes](docs/benchmarks/CPU性能基准.md), [LLVM comparison](docs/benchmarks/LLVM循环优化性能对比.md), and [development log](docs/development/五周期流水线CPU代码编写日志.md).

## License

Project code is released under the [MIT License](LICENSE). Vendored CoreMark retains its upstream Apache-2.0 license; see [third-party notices](third_party/README.md).
