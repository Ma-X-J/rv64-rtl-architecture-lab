param(
    [ValidateSet(0, 1, 2)]
    [int]$PredictorMode = 0
)

$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$buildDir = Join-Path $projectRoot `
    'build\software\branch_predictor_benchmark'
$testbench = Join-Path $projectRoot `
    'tb\programs\branch_predictor\CLANG_BRANCH_PREDICTOR_BENCH_tb.v'
$simulation = Join-Path $buildDir `
    "CLANG_BRANCH_PREDICTOR_BENCH_tb_mode${PredictorMode}.vvp"

New-Item -ItemType Directory -Force $buildDir | Out-Null

$rtlSources = Get-ChildItem `
    -LiteralPath (Join-Path $projectRoot 'rtl') `
    -Recurse `
    -Filter '*.v' |
    Sort-Object FullName |
    ForEach-Object { $_.FullName }

# -u separates compilation units.  This avoids the Icarus Verilog crash that
# this project documents for designs containing dynamic memory arrays.
& iverilog `
    -u `
    -g2012 `
    -s CLANG_BRANCH_PREDICTOR_BENCH_tb `
    "-PCLANG_BRANCH_PREDICTOR_BENCH_tb.PREDICTOR_MODE=${PredictorMode}" `
    -o $simulation `
    @rtlSources `
    $testbench
if ($LASTEXITCODE -ne 0) {
    throw "iverilog failed with exit code $LASTEXITCODE"
}

Push-Location $projectRoot
try {
    & vvp $simulation
    if ($LASTEXITCODE -ne 0) {
        throw "vvp failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
