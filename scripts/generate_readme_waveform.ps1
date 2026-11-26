param(
    [switch]$NoGui
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildDir = Join-Path $projectRoot 'build\readme-waveform'
$vvpOutput = Join-Path $buildDir 'BranchRecoveryWaveformDemo.vvp'
$vcdOutput = Join-Path $buildDir 'branch-recovery.vcd'
$testbench = Join-Path $projectRoot 'tb\demos\BranchRecoveryWaveformDemo.v'
$layoutScript = Join-Path $projectRoot `
    'scripts\gtkwave\readme_branch_recovery.tcl'

$iverilog = (Get-Command iverilog.exe -ErrorAction Stop).Source
$vvp = (Get-Command vvp.exe -ErrorAction Stop).Source
$gtkwaveCommand = Get-Command gtkwave.exe -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force $buildDir | Out-Null
$rtlSources = Get-ChildItem (Join-Path $projectRoot 'rtl') `
    -Recurse -File -Filter '*.v' | Sort-Object FullName |
    Select-Object -ExpandProperty FullName

& $iverilog -g2012 -s BranchRecoveryWaveformDemo `
    -o $vvpOutput @rtlSources $testbench
if ($LASTEXITCODE -ne 0) {
    throw 'Icarus Verilog compilation failed.'
}

Push-Location $projectRoot
try {
    & $vvp $vvpOutput
    if ($LASTEXITCODE -ne 0) {
        throw 'Waveform simulation failed.'
    }
} finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $vcdOutput)) {
    throw "Expected VCD was not generated: $vcdOutput"
}

Write-Host 'README branch-recovery waveform generated.'
Write-Host "  VCD: $vcdOutput"

if (-not $NoGui) {
    if ($null -eq $gtkwaveCommand) {
        throw 'gtkwave.exe was not found on PATH. Use -NoGui to generate only the VCD.'
    }
    Write-Host 'Opening the curated GTKWave view...'
    Start-Process -FilePath $gtkwaveCommand.Source -WindowStyle Maximized `
        -ArgumentList @(
        '--script',
        $layoutScript,
        $vcdOutput
    )
}
