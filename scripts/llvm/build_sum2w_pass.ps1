$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$projectLLVM = Join-Path $projectRoot '.tools\llvm-23.1.5\bin'
if ($env:LLVM_BIN) {
    $llvmBin = [IO.Path]::GetFullPath($env:LLVM_BIN)
} elseif (Test-Path -LiteralPath (Join-Path $projectLLVM 'opt.exe')) {
    $llvmBin = $projectLLVM
} else {
    $optCommand = Get-Command opt.exe -ErrorAction SilentlyContinue
    if ($null -eq $optCommand) {
        throw 'A complete LLVM installation was not found. Set LLVM_BIN to its bin directory.'
    }
    $llvmBin = Split-Path -Parent $optCommand.Source
}

$clangCommand = Get-Command clang.exe -ErrorAction SilentlyContinue
$clang = if (Test-Path -LiteralPath (Join-Path $llvmBin 'clang.exe')) {
    Join-Path $llvmBin 'clang.exe'
} elseif ($null -ne $clangCommand) {
    $clangCommand.Source
} else {
    throw 'clang.exe was not found.'
}

$llvmRoot = Split-Path -Parent $llvmBin
$llvmConfig = Join-Path $llvmRoot 'lib\cmake\llvm\LLVMConfig.cmake'
$llvmCMakeDir = Split-Path -Parent $llvmConfig
$buildDir = Join-Path $projectRoot 'build\llvm_passes\ir_stats'
$plugin = Join-Path $buildDir 'Release\IRStatsPass.dll'
$inputIR = Join-Path $projectRoot `
    'software\array_sum_unroll\llvm_unroll\cpu_unrolled2.ll'
$outputDir = Join-Path $projectRoot `
    'build\software\array_sum_unroll\sum2w\pass'
$linkerScript = Join-Path $projectRoot `
    'software\array_sum_unroll\common\link.ld'
$startObject = Join-Path $projectRoot `
    'build\software\array_sum_unroll\common\start.o'
$startSource = Join-Path $projectRoot 'software\array_sum\start.s'

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

New-Item -ItemType Directory -Force $outputDir | Out-Null
New-Item -ItemType Directory -Force `
    (Split-Path -Parent $startObject) | Out-Null

foreach ($tool in @('opt.exe', 'llc.exe', 'ld.lld.exe', 'llvm-objcopy.exe', 'llvm-objdump.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $llvmBin $tool))) {
        throw "Required LLVM tool was not found: $(Join-Path $llvmBin $tool)"
    }
}
if (-not (Test-Path -LiteralPath $llvmConfig)) {
    throw "LLVM CMake package was not found: $llvmConfig"
}

Invoke-Native $clang @(
    '--target=riscv64-unknown-elf',
    '-march=rv64i',
    '-mabi=lp64',
    '-c', $startSource,
    '-o', $startObject
)

$configureArguments = @(
    '-S', (Join-Path $projectRoot 'compiler\llvm_passes\ir_stats'),
    '-B', $buildDir,
    "-DLLVM_DIR=$llvmCMakeDir"
)

$diaCandidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2022\BuildTools\DIA SDK'),
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2022\Community\DIA SDK')
)
$diaSdk = $diaCandidates | Where-Object {
    Test-Path -LiteralPath (Join-Path $_ 'include\dia2.h')
} | Select-Object -First 1
if ($diaSdk) {
    $configureArguments += "-DMSVC_DIA_SDK_DIR=$diaSdk"
}

Invoke-Native 'cmake' $configureArguments

Invoke-Native 'cmake' @(
    '--build', $buildDir,
    '--config', 'Release'
)

Invoke-Native (Join-Path $llvmBin 'opt.exe') @(
    '-load-pass-plugin', $plugin,
    '-passes=cpu-sum2w-combine,verify',
    '-S', $inputIR,
    '-o', (Join-Path $outputDir 'cpu_sum2w.ll')
)

Invoke-Native (Join-Path $llvmBin 'llc.exe') @(
    '-O2',
    '-mtriple=riscv64-unknown-elf',
    '-mattr=+i',
    (Join-Path $outputDir 'cpu_sum2w.ll'),
    '-o', (Join-Path $outputDir 'cpu_sum2w_o2.s')
)

Invoke-Native $clang @(
    '--target=riscv64-unknown-elf',
    '-march=rv64i',
    '-mabi=lp64',
    '-c', (Join-Path $outputDir 'cpu_sum2w_o2.s'),
    '-o', (Join-Path $outputDir 'cpu_sum2w_o2.o')
)

Invoke-Native (Join-Path $llvmBin 'ld.lld.exe') @(
    '-m', 'elf64lriscv',
    '-T', $linkerScript,
    "-Map=$(Join-Path $outputDir 'cpu_sum2w_o2.map')",
    $startObject,
    (Join-Path $outputDir 'cpu_sum2w_o2.o'),
    '-o', (Join-Path $outputDir 'cpu_sum2w_o2.elf')
)

Invoke-Native (Join-Path $llvmBin 'llvm-objcopy.exe') @(
    '-O', 'binary',
    (Join-Path $outputDir 'cpu_sum2w_o2.elf'),
    (Join-Path $outputDir 'cpu_sum2w_o2.bin')
)

$disassembly = & (Join-Path $llvmBin 'llvm-objdump.exe') `
    -d -M no-aliases (Join-Path $outputDir 'cpu_sum2w_o2.elf')
if ($LASTEXITCODE -ne 0) {
    throw 'llvm-objdump failed.'
}
[IO.File]::WriteAllLines(
    (Join-Path $outputDir 'cpu_sum2w_o2.disasm.txt'),
    [string[]]$disassembly
)

$binaryPath = Join-Path $outputDir 'cpu_sum2w_o2.bin'
$bytes = [IO.File]::ReadAllBytes($binaryPath)
$hexLines = for ($offset = 0; $offset -lt $bytes.Length; $offset += 8) {
    $word = [byte[]]::new(8)
    $count = [Math]::Min(8, $bytes.Length - $offset)
    [Array]::Copy($bytes, $offset, $word, 0, $count)
    [BitConverter]::ToUInt64($word, 0).ToString('x16')
}
[IO.File]::WriteAllLines(
    (Join-Path $outputDir 'cpu_sum2w_o2.hex'),
    [string[]]$hexLines
)

$sum2wEncoding = Select-String `
    -Path (Join-Path $outputDir 'cpu_sum2w_o2.disasm.txt') `
    -Pattern '00e6060b'
if ($null -eq $sum2wEncoding) {
    throw 'Expected SUM2W encoding 0x00e6060b was not found.'
}

$fixtureDir = Join-Path $projectRoot `
    'tb\fixtures\programs\array_sum_unroll\sum2w'
New-Item -ItemType Directory -Force $fixtureDir | Out-Null
Copy-Item -LiteralPath (Join-Path $outputDir 'cpu_sum2w_o2.hex') `
    -Destination (Join-Path $fixtureDir 'pass_o2.hex') -Force

Write-Host 'SUM2W Pass build completed.'
Write-Host "  IR:  $(Join-Path $outputDir 'cpu_sum2w.ll')"
Write-Host "  ELF: $(Join-Path $outputDir 'cpu_sum2w_o2.elf')"
Write-Host "  HEX: $(Join-Path $outputDir 'cpu_sum2w_o2.hex')"
Write-Host "  BIN bytes: $($bytes.Length), HEX lines: $($hexLines.Count)"
