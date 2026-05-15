# build/Test-WindowsPowerShellDist.ps1

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $DistManifestPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw "This smoke test must be run under Windows PowerShell."
}

if (-not (Test-Path -LiteralPath $DistManifestPath)) {
    throw "Dist manifest not found: $DistManifestPath"
}

Write-Host "Smoke: Importing module"
Import-Module -Name $DistManifestPath -Force -ErrorAction Stop

Write-Host "Smoke: Checking exported commands"
$requiredCommands = @(
    'Show-Tree'
    'Show-TreeLegend'
    'Set-ShowTreeStyleProfile'
)

foreach ($commandName in $requiredCommands) {
    $command = Get-Command -Name $commandName -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Expected command was not exported: $commandName"
    }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('ShowTreeSmoke_' + [guid]::NewGuid().ToString('N'))

try {
    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path $tempRoot 'DirectoryA') -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path $tempRoot 'DirectoryB') -ItemType Directory -Force | Out-Null
    Set-Content -Path (Join-Path $tempRoot 'file.txt') -Value 'smoke' -Encoding UTF8

    Write-Host "Smoke: Running Normal mode"
    $normalOutput = Show-Tree -Path $tempRoot -NoFiles -Mono | Out-String
    if ($normalOutput -notmatch 'DirectoryA') {
        throw "Normal mode smoke test did not include DirectoryA."
    }

    Write-Host "Smoke: Running List mode"
    $listOutput = Show-Tree -Path $tempRoot -Mode List -NoFiles -Mono | Out-String
    if ($listOutput -notmatch 'DirectoryB') {
        throw "List mode smoke test did not include DirectoryB."
    }

    Write-Host "Smoke: Running Tree mode"
    $treeOutput = Show-Tree -Path $tempRoot -Mode Tree | Out-String
    if ($treeOutput -notmatch 'Folder PATH listing for volume') {
        throw "Tree mode smoke test did not include the expected tree.com-compatible header."
    }

    Write-Host "Smoke: Running Legend check"
    $legendOutput = Show-TreeLegend | Out-String
    if ([string]::IsNullOrWhiteSpace($legendOutput)) {
        throw "Legend smoke test returned no output."
    }

    Write-Host "Windows PowerShell dist smoke test passed." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }

    Remove-Module ShowTree -Force -ErrorAction SilentlyContinue
}
