$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

$fixtureMap = @(
    @('build/software/minimal/program.hex',
      'tb/fixtures/programs/minimal/program.hex'),
    @('build/software/int_add/program.hex',
      'tb/fixtures/programs/int_add/program.hex'),
    @('build/software/fibonacci/program.hex',
      'tb/fixtures/programs/fibonacci/program.hex'),
    @('build/software/array_sum/program.hex',
      'tb/fixtures/programs/array_sum/program.hex'),
    @('build/software/branch_predictor_benchmark/program.hex',
      'tb/fixtures/programs/branch_predictor/program.hex'),
    @('build/software/array_sum_unroll/baseline/prepared.hex',
      'tb/fixtures/programs/array_sum_unroll/baseline/prepared.hex'),
    @('build/software/array_sum_unroll/baseline/prepared_o2.hex',
      'tb/fixtures/programs/array_sum_unroll/baseline/prepared_o2.hex'),
    @('build/software/array_sum_unroll/sum2w/pass/cpu_sum2w_o2.hex',
      'tb/fixtures/programs/array_sum_unroll/sum2w/pass_o2.hex'),
    @('build/software/array_sum_unroll/sum2w/manual/sum2w_o2.hex',
      'tb/fixtures/programs/array_sum_unroll/sum2w/manual_o2.hex'),
    @('build/software/array_sum_unroll/llvm_unroll/cpu_unrolled2_o2.hex',
      'tb/fixtures/programs/array_sum_unroll/llvm_unroll/cpu_unrolled2_o2.hex'),
    @('build/software/array_sum_unroll/manual_unroll/unroll2/unrolled2_o2.hex',
      'tb/fixtures/programs/array_sum_unroll/manual_unroll/unrolled2_o2.hex'),
    @('build/software/array_sum_unroll/manual_unroll/unroll4/unrolled.hex',
      'tb/fixtures/programs/array_sum_unroll/manual_unroll/unrolled4.hex'),
    @('build/software/array_sum_unroll/manual_unroll/unroll4/unrolled_o2.hex',
      'tb/fixtures/programs/array_sum_unroll/manual_unroll/unrolled4_o2.hex'),
    @('build/software/coremark/coremark-imem.hex',
      'tb/fixtures/programs/coremark/imem.hex'),
    @('build/software/coremark/coremark-dmem.hex',
      'tb/fixtures/programs/coremark/dmem.hex')
)

foreach ($entry in $fixtureMap) {
    $source = Join-Path $projectRoot $entry[0]
    $destination = Join-Path $projectRoot $entry[1]

    if (-not (Test-Path -LiteralPath $source)) {
        throw "Fixture source does not exist: $($entry[0])"
    }

    New-Item -ItemType Directory -Force `
        -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
    Write-Host "Updated $($entry[1])"
}

Write-Host "Updated $($fixtureMap.Count) regression fixtures."
