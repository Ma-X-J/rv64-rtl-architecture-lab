# Bare-metal software and compiler experiments

This directory contains source inputs, startup code, linker scripts, port
layers, and build commands.  Generated objects and executable images are kept
out of the source tree and written to:

```text
build/software/<program>/
```

Stable HEX images required by RTL regression are committed separately below
`tb/fixtures/programs/`.  Rebuilding software does not make the regression
depend on a local compiler installation.

| Directory | Purpose |
|---|---|
| `minimal/`, `int_add/`, `fibonacci/`, `array_sum/` | Small Clang-generated bare-metal programs |
| `branch_predictor_benchmark/` | Controlled BHT/global/tournament comparison |
| `coremark/` | Upstream CoreMark bare-metal port and functional validation |
| `array_sum_unroll/` | Baseline, manual unroll, LLVM unroll, and SUM2W experiments |
| `pass_add_zero/` | Small LLVM transformation experiment |

To refresh committed regression images after intentionally rebuilding their
sources:

```powershell
& .\scripts\update_test_fixtures.ps1
```

Do not commit `.o`, `.elf`, `.bin`, `.map`, generated assembly, or generated
disassembly files from `build/software/`.
