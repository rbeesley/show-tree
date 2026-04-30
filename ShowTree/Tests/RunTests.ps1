# RunTests.ps1

$RepoRoot   = Split-Path -Parent $PSCommandPath
$ModuleRoot = Join-Path $RepoRoot 'ShowTree'
$TestsRoot  = Join-Path $ModuleRoot 'Tests'
$Manifest   = Join-Path $ModuleRoot 'ShowTree.psd1'

if (-not (Test-Path $Manifest)) {
    # fallback for running inside ShowTree\Tests\
    $ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
    $Manifest   = Join-Path $ModuleRoot 'ShowTree.psd1'
    $TestsRoot  = Join-Path $ModuleRoot 'Tests'
}

$config = @{
    Run = @{
        Path = $TestsRoot
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    BeforeDiscovery = {
        Import-Module $using:Manifest -Force
    }
}

Invoke-Pester -Configuration $config