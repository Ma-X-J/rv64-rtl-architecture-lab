# Regression fixtures

This directory contains the prebuilt 64-bit hexadecimal memory images used by
the RTL program-level testbenches.  They are committed test inputs, not general
software build outputs.

Keeping these files below `tb/fixtures` makes the Icarus regression independent
of a locally installed LLVM toolchain.  A clean checkout can therefore run
`python scripts/run_regression.py` without first rebuilding every bare-metal
program.

The corresponding C/assembly sources and build scripts remain below
`software/`; generated files are written below `build/software/`.  After
intentionally rebuilding those programs, refresh these copies with:

```powershell
& .\scripts\update_test_fixtures.ps1
```

CoreMark must be built first because its source images are generated below
`build/software/coremark/`:

```powershell
& .\software\coremark\build.ps1
& .\scripts\update_test_fixtures.ps1
```

Do not edit the HEX files by hand.  Review fixture changes together with the
source/compiler change that generated them.
