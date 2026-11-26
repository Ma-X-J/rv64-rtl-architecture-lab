# Branch Predictor Benchmark

This RV64I-only microbenchmark is intended to compare three configurations on
the same CPU:

1. the existing 16-entry bimodal BHT;
2. a 2-bit-GHR correlated predictor;
3. a tournament predictor choosing between the two.

`correlated_phase` contains a pair of pseudo-random but mutually correlated
branches. `bimodal_phase` contains a run-biased target branch preceded by two
unrelated branches that make a short global history noisy. Together they give
the tournament selector distinct branches on which each component predictor
can win.

Build from the repository root:

```powershell
& software\branch_predictor_benchmark\build.ps1
```

Generated files are written to
`build/software/branch_predictor_benchmark/`; the build also refreshes the
committed regression fixture in `tb/fixtures/programs/branch_predictor/`.

Run one CPU predictor mode:

```powershell
& software\branch_predictor_benchmark\run.ps1 -PredictorMode 0 # BHT
& software\branch_predictor_benchmark\run.ps1 -PredictorMode 1 # Global
& software\branch_predictor_benchmark\run.ps1 -PredictorMode 2 # Tournament
```

The dedicated runner uses Icarus Verilog's `-u` option because the default
merged-compilation-unit mode crashes on this project's dynamic memory arrays.

The build targets `rv64i/lp64` and rejects RV64M arithmetic instructions and
the currently unsupported unsigned conditional branches `BLTU/BGEU` if they
appear in the final disassembly.
