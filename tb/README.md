# RTL testbench organization

The regression runner discovers every `*_tb.v` recursively, so testbenches are
grouped by verification level without changing their module names.

| Directory | Scope |
|---|---|
| `unit/isa/` | Instruction decode and ALU behavior |
| `unit/control/` | Predictor, CSR, and trap-control modules |
| `unit/cache/` | I-Cache, D-Cache, and backing-memory behavior |
| `integration/` | Full pipeline, cache, CSR, trap, and memory interactions |
| `programs/clang/` | Small bare-metal programs compiled with Clang/LLVM |
| `programs/branch_predictor/` | Controlled predictor comparison benchmark |
| `programs/coremark/` | Upstream CoreMark functional smoke test |
| `fixtures/` | Committed HEX inputs required by program-level tests |
| `legacy/` | Earlier single-cycle CPU regression |

Run the complete suite from the repository root:

```powershell
python .\scripts\run_regression.py
```

Run selected tests by module/file stem; their directory is not required:

```powershell
python .\scripts\run_regression.py CoreMarkSmoke_tb CSRFile_tb
```

Program tests must load images only from `tb/fixtures/`, never directly from
ignored build output.  See [`fixtures/README.md`](fixtures/README.md) for the
fixture refresh workflow.
