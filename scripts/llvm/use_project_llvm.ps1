$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

if ($env:LLVM_BIN) {
    $llvmBin = [IO.Path]::GetFullPath($env:LLVM_BIN)
} else {
    $projectLLVM = Join-Path $projectRoot '.tools\llvm-23.1.5\bin'
    if (Test-Path -LiteralPath (Join-Path $projectLLVM 'opt.exe')) {
        $llvmBin = $projectLLVM
    } else {
        $optCommand = Get-Command opt.exe -ErrorAction SilentlyContinue
        if ($null -eq $optCommand) {
            throw 'A complete LLVM installation was not found. Set LLVM_BIN to its bin directory.'
        }
        $llvmBin = Split-Path -Parent $optCommand.Source
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $llvmBin 'opt.exe'))) {
    throw "A complete LLVM installation was not found at: $llvmBin"
}

$env:Path = "$llvmBin;$env:Path"
Write-Host "LLVM is active in this PowerShell session: $llvmBin"
opt --version
