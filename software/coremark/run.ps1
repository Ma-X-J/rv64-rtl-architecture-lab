$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$buildDir = Join-Path $projectRoot 'build\software\coremark'
$simulation = Join-Path $buildDir 'CoreMarkSmoke_tb.vvp'

& (Join-Path $PSScriptRoot 'build.ps1')

New-Item -ItemType Directory -Force $buildDir | Out-Null

# The regression test consumes committed fixtures rather than ignored build
# output.  Refresh the two CoreMark fixtures so this command always simulates
# the image it just built.
$fixtureDir = Join-Path $projectRoot 'tb\fixtures\programs\coremark'
New-Item -ItemType Directory -Force $fixtureDir | Out-Null
Copy-Item -LiteralPath (Join-Path $buildDir 'coremark-imem.hex') `
    -Destination (Join-Path $fixtureDir 'imem.hex') -Force
Copy-Item -LiteralPath (Join-Path $buildDir 'coremark-dmem.hex') `
    -Destination (Join-Path $fixtureDir 'dmem.hex') -Force

$rtlSources = @(
    (Join-Path $projectRoot 'rtl\PIPELINED_CPU.v')
) + @(
    Get-ChildItem (Join-Path $projectRoot 'rtl\control') -File -Filter '*.v' |
        Sort-Object FullName | ForEach-Object FullName
) + @(
    Get-ChildItem (Join-Path $projectRoot 'rtl\datapath') -File -Filter '*.v' |
        Sort-Object FullName | ForEach-Object FullName
) + @(
    Get-ChildItem (Join-Path $projectRoot 'rtl\Cache') -File -Filter '*.v' |
        Sort-Object FullName | ForEach-Object FullName
) + @(
    Get-ChildItem (Join-Path $projectRoot 'rtl\memory') -File -Filter '*.v' |
        Sort-Object FullName | ForEach-Object FullName
)

& iverilog -g2012 -s CoreMarkSmoke_tb -o $simulation `
    @rtlSources (Join-Path $projectRoot 'tb\programs\coremark\CoreMarkSmoke_tb.v')
if ($LASTEXITCODE -ne 0) {
    throw "iverilog failed with exit code $LASTEXITCODE"
}

Push-Location $projectRoot
try {
    & vvp $simulation
    if ($LASTEXITCODE -ne 0) {
        throw "CoreMark simulation failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
