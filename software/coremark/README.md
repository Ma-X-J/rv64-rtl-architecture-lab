# CoreMark RV64IM functional port

This directory boots the upstream CoreMark sources from
`third_party/coremark` on the five-stage CPU.

## Memory map

- `0x0000–0x3fff`: 16 KiB instruction backing memory (`.text`)
- `0x4000–0x57ff`: initialized data, read-only constants, and `.bss`
- `0x5800–0x5fff`: 2 KiB reserved stack, with `sp = 0x6000`

Read-only C constants are deliberately linked into data memory. The CPU has
separate instruction and data backing arrays, so a normal load cannot fetch a
constant from the instruction array.

## Build

From the repository root:

```powershell
& .\software\coremark\build.ps1
```

The build produces separate 64-bit little-endian preload files:

- `build/software/coremark/coremark-imem.hex`
- `build/software/coremark/coremark-dmem.hex`

It also writes the ELF, link map, section table, and disassembly. The script
rejects an image that exceeds the configured memories or contains an
instruction outside the CPU's current implemented subset.

To rebuild and run the one-iteration RTL smoke test:

```powershell
& .\software\coremark\run.ps1
```

## Result mailbox

The first six 64-bit words of data memory form a simulation mailbox:

| Address | Meaning |
|---|---|
| `0x4000` | magic value `0x434f52454d41524b` (`COREMARK`) |
| `0x4008` | status: 0 boot, 1 running, 2 CRC pass, 3 fail, 4 no result |
| `0x4010` | functional timer value |
| `0x4018` | number of `ee_printf` calls |
| `0x4020` | reserved |
| `0x4028` | return value from `main` |

This is initially a one-iteration functional/CRC run. Its timer advances by a
fixed amount at each timing call so that CoreMark completes its validation
path. It is not a hardware cycle counter, and the resulting time or score must
not be reported as a valid CoreMark performance result. Simulation cycle count
is measured separately by the testbench.
