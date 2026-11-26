$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$coremarkRoot = Join-Path $projectRoot 'third_party\coremark'
$outputDir = Join-Path $projectRoot 'build\software\coremark'
$llvmBin = 'C:\Program Files\LLVM\bin'

New-Item -ItemType Directory -Force $outputDir | Out-Null

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

function Convert-BinaryToHex64 {
    param(
        [Parameter(Mandatory = $true)][string]$BinaryPath,
        [Parameter(Mandatory = $true)][string]$HexPath,
        [Parameter(Mandatory = $true)][int]$WordCount
    )

    $bytes = [IO.File]::ReadAllBytes($BinaryPath)
    $lines = for ($offset = 0; $offset -lt $bytes.Length; $offset += 8) {
        $word = [byte[]]::new(8)
        $count = [Math]::Min(8, $bytes.Length - $offset)
        [Array]::Copy($bytes, $offset, $word, 0, $count)
        [BitConverter]::ToUInt64($word, 0).ToString('x16')
    }
    if ($lines.Count -gt $WordCount) {
        throw "$BinaryPath needs $($lines.Count) words; capacity is $WordCount."
    }
    $paddedLines = @($lines)
    while ($paddedLines.Count -lt $WordCount) {
        $paddedLines += '0000000000000000'
    }
    [IO.File]::WriteAllLines($HexPath, [string[]]$paddedLines)
    return $paddedLines.Count
}

$clang = Join-Path $llvmBin 'clang.exe'
$linker = Join-Path $llvmBin 'ld.lld.exe'
$objcopy = Join-Path $llvmBin 'llvm-objcopy.exe'
$objdump = Join-Path $llvmBin 'llvm-objdump.exe'
$sizeTool = Join-Path $llvmBin 'llvm-size.exe'

$targetFlags = @(
    '--target=riscv64-unknown-elf',
    '-march=rv64im',
    '-mabi=lp64',
    '-mcmodel=medany',
    '-mno-relax'
)

$compileFlags = $targetFlags + @(
    '-O2',
    '-ffreestanding',
    '-fno-builtin',
    '-fno-stack-protector',
    '-fno-pic',
    '-fno-common',
    '-fno-unwind-tables',
    '-fno-asynchronous-unwind-tables',
    '-msmall-data-limit=0',
    "-I$(Join-Path $PSScriptRoot '')",
    "-I$coremarkRoot",
    '-DPERFORMANCE_RUN=1',
    '-DITERATIONS=1',
    '-DTOTAL_DATA_SIZE=2000'
)

$sourceFiles = @(
    (Join-Path $coremarkRoot 'core_list_join.c'),
    (Join-Path $coremarkRoot 'core_main.c'),
    (Join-Path $coremarkRoot 'core_matrix.c'),
    (Join-Path $coremarkRoot 'core_state.c'),
    (Join-Path $coremarkRoot 'core_util.c'),
    (Join-Path $PSScriptRoot 'core_portme.c')
)

$objects = @()
foreach ($source in $sourceFiles) {
    $name = [IO.Path]::GetFileNameWithoutExtension($source)
    $object = Join-Path $outputDir "$name.o"
    Invoke-Native $clang ($compileFlags + @('-c', $source, '-o', $object))
    $objects += $object
}

$startObject = Join-Path $outputDir 'start.o'
Invoke-Native $clang ($targetFlags + @(
    '-c', (Join-Path $PSScriptRoot 'start.S'),
    '-o', $startObject
))

$elf = Join-Path $outputDir 'coremark.elf'
$map = Join-Path $outputDir 'coremark.map'
Invoke-Native $linker (@(
    '-m', 'elf64lriscv',
    '--no-relax',
    '-T', (Join-Path $PSScriptRoot 'link.ld'),
    "-Map=$map",
    $startObject
) + $objects + @('-o', $elf))

$imemBin = Join-Path $outputDir 'coremark-imem.bin'
$dmemBin = Join-Path $outputDir 'coremark-dmem.bin'
Invoke-Native $objcopy @('-O', 'binary', '--only-section=.text', $elf, $imemBin)
Invoke-Native $objcopy @('-O', 'binary', '--only-section=.dmem', $elf, $dmemBin)

$imemLength = (Get-Item $imemBin).Length
$dmemLength = (Get-Item $dmemBin).Length
if ($imemLength -gt 16KB) {
    throw "Instruction image is $imemLength bytes; IMEM capacity is 16384."
}
if ($dmemLength -gt 6KB) {
    throw "Initialized data is $dmemLength bytes; it overlaps the reserved stack."
}

$imemLines = Convert-BinaryToHex64 $imemBin `
    (Join-Path $outputDir 'coremark-imem.hex') 2048
$dmemLines = Convert-BinaryToHex64 $dmemBin `
    (Join-Path $outputDir 'coremark-dmem.hex') 1024

$disassembly = & $objdump -d --no-show-raw-insn -M no-aliases $elf
if ($LASTEXITCODE -ne 0) {
    throw 'llvm-objdump disassembly failed.'
}
[IO.File]::WriteAllLines(
    (Join-Path $outputDir 'coremark.disasm.txt'),
    [string[]]$disassembly
)

$sections = & $objdump -h $elf
if ($LASTEXITCODE -ne 0) {
    throw 'llvm-objdump section listing failed.'
}
[IO.File]::WriteAllLines(
    (Join-Path $outputDir 'coremark.sections.txt'),
    [string[]]$sections
)

$allowedInstructions = @(
    'add','addi','addiw','addw','and','andi','auipc',
    'beq','bge','bgeu','blt','bltu','bne',
    'divuw','jal','jalr','lb','lbu','ld','lh','lhu','lui','lw','lwu',
    'mul','mulhu','mulw','or','ori','sb','sd','sh',
    'sll','slli','slliw','sllw','slt','sltiu','sltu',
    'sra','srai','sraiw','sraw','srl','srli','srliw','srlw',
    'sub','subw','sw','xor','xori'
)
$mnemonics = $disassembly | ForEach-Object {
    if ($_ -match '^\s*[0-9a-f]+:\s+([a-z0-9_.]+)') {
        $Matches[1]
    }
}
$unsupported = $mnemonics | Sort-Object -Unique |
    Where-Object { $_ -notin $allowedInstructions }
if ($unsupported) {
    throw "Linked ELF contains unsupported instructions: $($unsupported -join ', ')"
}

$sizeOutput = & $sizeTool $elf
if ($LASTEXITCODE -ne 0) {
    throw 'llvm-size failed.'
}

Write-Host 'CoreMark RV64IM functional image built successfully.'
Write-Host "  ELF:        $elf"
Write-Host "  IMEM:       $imemLength bytes, $imemLines x 64-bit words"
Write-Host "  DMEM init:  $dmemLength bytes, $dmemLines x 64-bit words"
Write-Host '  Address map: .text @ 0x0000, .dmem/.bss @ 0x4000, stack top @ 0x6000'
Write-Host '  Timing: functional placeholder only; do not report a CoreMark score.'
$sizeOutput | ForEach-Object { Write-Host "  $_" }
