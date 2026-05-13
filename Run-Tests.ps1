# Run-Tests.ps1

$moduleRoot   = Split-Path -Parent $PSCommandPath
$moduleSrcRoot = Join-Path $moduleRoot 'src'
$manifest   = Join-Path $moduleRoot 'ShowTree.psd1'

if (-not (Test-Path $manifest)) {
    # fallback for running inside ShowTree\Tests\
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
    $manifest   = Join-Path $moduleRoot 'ShowTree.psd1'
}

$testsRoot    = Join-Path $moduleSrcRoot 'Tests'
$pesterConfig = Join-Path $testsRoot 'Pester.psd1'

$config = Import-PowerShellDataFile $pesterConfig
$config.Run.Path = $testsRoot

Invoke-Pester -Configuration $config
