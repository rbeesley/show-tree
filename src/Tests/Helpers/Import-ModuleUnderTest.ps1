# src\Tests\Helpers\Import-ModuleUnderTest.ps1

[CmdletBinding()]
param(
    [string] $StartPath = $PSScriptRoot,
    [string] $ManifestPath,
    [string] $ModuleName,
    [string] $SourceRootName,
    [string] $SourceRootPath,
    [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5')]
    [string] $Algorithm = 'SHA256',
    [string[]] $Include,
    [string[]] $Exclude,
    [switch] $PassThru,
    [switch] $ForceReload
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$helpersPath = Split-Path -Parent $PSCommandPath

$moduleInfoParams = @{
    StartPath = $StartPath
}

if ($PSBoundParameters.ContainsKey('ManifestPath') -and -not [string]::IsNullOrWhiteSpace($ManifestPath)) {
    $moduleInfoParams.ManifestPath = $ManifestPath
}

if ($PSBoundParameters.ContainsKey('ModuleName') -and -not [string]::IsNullOrWhiteSpace($ModuleName)) {
    $moduleInfoParams.ModuleName = $ModuleName
}

if ($PSBoundParameters.ContainsKey('SourceRootName') -and -not [string]::IsNullOrWhiteSpace($SourceRootName)) {
    $moduleInfoParams.SourceRootName = $SourceRootName
}

if ($PSBoundParameters.ContainsKey('SourceRootPath') -and -not [string]::IsNullOrWhiteSpace($SourceRootPath)) {
    $moduleInfoParams.SourceRootPath = $SourceRootPath
}

$moduleInfo = . (Join-Path $helpersPath 'Get-ModuleUnderTestInfo.ps1') @moduleInfoParams

$fingerprintParams = @{
    ModuleInfo = $moduleInfo
    Algorithm  = $Algorithm
}

if ($PSBoundParameters.ContainsKey('Include')) {
    $fingerprintParams.Include = $Include
}

if ($PSBoundParameters.ContainsKey('Exclude')) {
    $fingerprintParams.Exclude = $Exclude
}

$fingerprintInfo = . (Join-Path $helpersPath 'Get-ModuleSourceFingerprint.ps1') @fingerprintParams

$loadedModules = Get-Module -Name $moduleInfo.ModuleName -All -ErrorAction SilentlyContinue

$matchingModule = $loadedModules |
    Where-Object {
        $_.Name -eq $moduleInfo.ModuleName -and
        $_.Path -eq $moduleInfo.RootModulePath
    } |
    Select-Object -First 1

$needsReload = [bool]$ForceReload

if (-not $needsReload) {
    if (-not $matchingModule) {
        $needsReload = $true
    }
    else {
        $existingFingerprint = $matchingModule.PrivateData['ModuleSourceFingerprint']
        $existingRootModule  = $matchingModule.PrivateData['ModuleRootModulePath']

        if (-not $existingFingerprint -or
            $existingFingerprint -ne $fingerprintInfo.Fingerprint -or
            $existingRootModule -ne $moduleInfo.RootModulePath) {
            $needsReload = $true
        }
    }
}

if ($needsReload) {
    if ($loadedModules) {
        $loadedModules | Remove-Module -Force -ErrorAction SilentlyContinue
    }

    Import-Module -Name $moduleInfo.ManifestPath -Force -ErrorAction Stop

    $matchingModule = Get-Module -Name $moduleInfo.ModuleName -All -ErrorAction Stop |
        Where-Object {
            $_.Name -eq $moduleInfo.ModuleName -and
            $_.Path -eq $moduleInfo.RootModulePath
        } |
        Select-Object -First 1

    if (-not $matchingModule) {
        throw "Module '$($moduleInfo.ModuleName)' was imported, but no loaded module matched root module path '$($moduleInfo.RootModulePath)'."
    }

    $matchingModule.PrivateData['ModuleManifestPath']      = $moduleInfo.ManifestPath
    $matchingModule.PrivateData['ModuleRootModulePath']    = $moduleInfo.RootModulePath
    $matchingModule.PrivateData['ModuleSourceRootPath']    = $moduleInfo.SourceRootPath
    $matchingModule.PrivateData['ModuleSourceRootName']    = $moduleInfo.SourceRootName
    $matchingModule.PrivateData['ModuleSourceFingerprint'] = $fingerprintInfo.Fingerprint
    $matchingModule.PrivateData['ModuleHashAlgorithm']     = $fingerprintInfo.Algorithm

    Write-Host "Imported $($moduleInfo.ModuleName) from '$($matchingModule.Path)'" -ForegroundColor Cyan
}

if ($PassThru) {
    $matchingModule
}
