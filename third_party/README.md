# Third-party source code

Third-party components in this directory keep their upstream licenses and are
not covered by this repository's MIT license unless the upstream license says
otherwise.

## CoreMark

- Component: EEMBC CoreMark
- Upstream: <https://github.com/eembc/coremark>
- Vendored commit: `1f483d5b8316753a742cbf5590caf5bd0a4e4777`
- Imported: 2026-11-23
- License: Apache License 2.0; see
  [`coremark/LICENSE.md`](coremark/LICENSE.md)

`coremark/` is a vendored source snapshot, not a nested Git repository or a
Git submodule.  This keeps a normal clone of the CPU repository self-contained
for rebuilding the bare-metal CoreMark image.

The CPU-specific startup code, linker script, port layer, and build commands
live in [`../software/coremark`](../software/coremark).  Upstream CoreMark
source files should remain unmodified; target-specific changes belong in that
port directory.

### Updating the vendored snapshot

1. Clone or fetch CoreMark in a separate temporary directory.
2. Record the new full upstream commit hash.
3. Copy the upstream working tree into `third_party/coremark`, excluding its
   `.git` directory.
4. Preserve the upstream `LICENSE.md` and update the commit recorded above.
5. Rebuild and run the functional validation:

   ```powershell
   & .\software\coremark\run.ps1
   python .\scripts\run_regression.py
   ```

6. Review the vendored-source diff separately from local port changes.
