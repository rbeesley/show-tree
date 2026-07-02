# build.ps1

[CmdletBinding()]
param(
    [string[]] $Task = @('Test'),
    [string[]] $Test,
    [string[]] $Tag,
    [switch] $Bootstrap
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$requirementsPath = Join-Path $PSScriptRoot 'build\requirements.psd1'
$requirements = Import-PowerShellDataFile $requirementsPath

try {
    foreach ($module in $requirements.Modules) {
        $installed = Get-Module -ListAvailable -Name $module.ModuleName |
                Where-Object Version -eq $module.RequiredVersion |
                Select-Object -First 1

        if ($Bootstrap -and -not $installed) {
            Write-Host "Installing module $($module.ModuleName) version $($module.RequiredVersion)..."
            Install-Module -Name $module.ModuleName `
                -RequiredVersion $module.RequiredVersion `
                -Scope CurrentUser `
                -Force `
                -AllowClobber
        }

        Import-Module $module.ModuleName -RequiredVersion $module.RequiredVersion -Force
    }
}
catch {
    Write-Error "Failed to bootstrap or import requirements: $($_.Exception.Message)"
    Write-Host "Try running: .\build.ps1 -Bootstrap" -ForegroundColor Yellow
    exit 1
}

$invokeBuildParams = @{
    File = (Join-Path $PSScriptRoot 'build\tasks.build.ps1')
    Task = $Task
}

if ($PSBoundParameters.ContainsKey('Test')) {
    $invokeBuildParams.Test = $Test
}

if ($PSBoundParameters.ContainsKey('Tag')) {
    $invokeBuildParams.Tag = $Tag
}

Invoke-Build @invokeBuildParams
