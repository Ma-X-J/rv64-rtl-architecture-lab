$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$outputDir = Join-Path $projectRoot `
    'build\software\branch_predictor_benchmark'
$llvmBin = 'C:\Program Files\LLVM\bin'
$linkerScript = Join-Path $projectRoot 'software\array_sum\link.ld'

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Executable"
    }
}

$clang = Join-Path $llvmBin 'clang.exe'
$linker = Join-Path $llvmBin 'ld.lld.exe'
$objcopy = Join-Path $llvmBin 'llvm-objcopy.exe'
$objdump = Join-Path $llvmBin 'llvm-objdump.exe'

New-Item -ItemType Directory -Force $outputDir | Out-Null

$targetFlags = @(
    '--target=riscv64-unknown-elf',
    '-march=rv64i',
    '-mabi=lp64'
)

$cCompileFlags = $targetFlags + @(
    '-ffreestanding',
    '-fno-builtin',
    '-fno-stack-protector'
)

Invoke-Native $clang ($cCompileFlags + @(
    '-O2',
    '-c', (Join-Path $PSScriptRoot 'main.c'),
    '-o', (Join-Path $outputDir 'main.o')
))

Invoke-Native $clang ($targetFlags + @(
    '-c', (Join-Path $projectRoot 'software\array_sum\start.s'),
    '-o', (Join-Path $outputDir 'start.o')
))

Invoke-Native $linker @(
    '-m', 'elf64lriscv',
    '-T', $linkerScript,
    "-Map=$(Join-Path $outputDir 'program.map')",
    (Join-Path $outputDir 'start.o'),
    (Join-Path $outputDir 'main.o'),
    '-o', (Join-Path $outputDir 'program.elf')
)

Invoke-Native $objcopy @(
    '-O', 'binary',
    (Join-Path $outputDir 'program.elf'),
    (Join-Path $outputDir 'program.bin')
)

$disassembly = & $objdump -d -M no-aliases `
    (Join-Path $outputDir 'program.elf')
if ($LASTEXITCODE -ne 0) {
    throw 'llvm-objdump failed.'
}
[IO.File]::WriteAllLines(
    (Join-Path $outputDir 'program.disasm.txt'),
    [string[]]$disassembly
)

$binaryPath = Join-Path $outputDir 'program.bin'
$bytes = [IO.File]::ReadAllBytes($binaryPath)
$hexLines = for ($offset = 0; $offset -lt $bytes.Length; $offset += 8) {
    $word = [byte[]]::new(8)
    $count = [Math]::Min(8, $bytes.Length - $offset)
    [Array]::Copy($bytes, $offset, $word, 0, $count)
    [BitConverter]::ToUInt64($word, 0).ToString('x16')
}
[IO.File]::WriteAllLines(
    (Join-Path $outputDir 'program.hex'),
    [string[]]$hexLines
)

# Fail the build if an RV64M arithmetic instruction appears in the output.
$rv64mInstruction = $disassembly | Select-String -Pattern `
    '\s(mul|mulh|mulhsu|mulhu|mulw|div|divu|divw|divuw|rem|remu|remw|remuw)\s'
if ($null -ne $rv64mInstruction) {
    throw "RV64M instruction found in disassembly: $rv64mInstruction"
}

# The CPU currently resolves BEQ/BNE/BLT/BGE.  Reject unsigned branches so
# the benchmark cannot silently depend on unimplemented BLTU/BGEU behavior.
$unsupportedBranch = $disassembly | Select-String -Pattern '\s(bltu|bgeu)\s'
if ($null -ne $unsupportedBranch) {
    throw "Unsupported unsigned branch found: $unsupportedBranch"
}

# These are legal RV64I operations, but they are outside the subset currently
# implemented by this CPU's ALU/decode path.
$unsupportedSubsetInstruction = $disassembly | Select-String -Pattern `
    '\s(srli|srai|sltu|sltiu)\s'
if ($null -ne $unsupportedSubsetInstruction) {
    throw "Instruction outside the implemented CPU subset found: $unsupportedSubsetInstruction"
}

if ($bytes.Length -gt 2048) {
    throw "Program image is $($bytes.Length) bytes; CPU backing memory is 2048 bytes."
}

$fixtureDir = Join-Path $projectRoot `
    'tb\fixtures\programs\branch_predictor'
New-Item -ItemType Directory -Force $fixtureDir | Out-Null
Copy-Item -LiteralPath (Join-Path $outputDir 'program.hex') `
    -Destination (Join-Path $fixtureDir 'program.hex') -Force

Write-Host 'Branch predictor benchmark build completed.'
Write-Host "  ELF:         $(Join-Path $outputDir 'program.elf')"
Write-Host "  HEX:         $(Join-Path $outputDir 'program.hex')"
Write-Host "  Disassembly: $(Join-Path $outputDir 'program.disasm.txt')"
Write-Host "  BIN bytes:   $($bytes.Length)"
Write-Host "  HEX lines:   $($hexLines.Count)"
