# build.ps1

[CmdletBinding()]
param(
    [string[]] $Task = @('Test'),
    [switch] $Bootstrap
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$requirementsPath = Join-Path $PSScriptRoot 'build\requirements.psd1'
$requirements = Import-PowerShellDataFile $requirementsPath

foreach ($module in $requirements.Modules) {
    $installed = Get-Module -ListAvailable -Name $module.ModuleName |
        Where-Object Version -eq $module.RequiredVersion |
        Select-Object -First 1

    if (-not $installed) {
        Install-Module -Name $module.ModuleName `
            -RequiredVersion $module.RequiredVersion `
            -Scope CurrentUser `
            -Force
    }

    Import-Module $module.ModuleName -RequiredVersion $module.RequiredVersion -Force
}

Invoke-Build -File (Join-Path $PSScriptRoot 'build\tasks.build.ps1') -Task $Task
