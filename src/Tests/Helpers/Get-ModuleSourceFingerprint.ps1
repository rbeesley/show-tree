# src\Tests\Helpers\Get-ModuleSourceFingerprint.ps1

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [psobject] $ModuleInfo,
    [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5')]
    [string] $Algorithm = 'SHA256',
    [string[]] $Include,
    [string[]] $Exclude
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$allPaths = @(
    $ModuleInfo.ManifestPath
    $ModuleInfo.RootModulePath
)

if ($ModuleInfo.SourceRootPath) {
    $allPaths += Get-ChildItem -LiteralPath $ModuleInfo.SourceRootPath -Recurse -File |
        Sort-Object FullName |
        Select-Object -ExpandProperty FullName
}

$fileEntries = foreach ($path in $allPaths | Select-Object -Unique) {
    $resolved = (Resolve-Path -LiteralPath $path).ProviderPath
    # Fallback for Windows PowerShell where [IO.Path]::GetRelativePath is missing
    $relative = if ([Type]::GetType('System.IO.Path') | Get-Member -Static -Name GetRelativePath) {
        [IO.Path]::GetRelativePath($ModuleInfo.ModuleBase, $resolved)
    }
    else {
        $base = $ModuleInfo.ModuleBase.TrimEnd('\') + '\'
        if ($resolved.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
            $resolved.Substring($base.Length)
        }
        else {
            $resolved
        }
    }
    $relative = $relative.Replace('\', '/')

    [pscustomobject]@{
        FullPath  = $resolved
        Relative  = $relative
    }
}

$includedExact = @()
$includedGlob  = @()
$excludedExact = @()
$excludedGlob  = @()

foreach ($entry in $fileEntries) {
    $name = $entry.Relative

    if ($Include) {
        if ($Include -contains $name) {
            $includedExact += $entry
        }
        elseif ($Include | Where-Object { $name -like $_ }) {
            $includedGlob += $entry
        }
    }

    if ($Exclude) {
        if ($Exclude -contains $name) {
            $excludedExact += $entry
        }
        elseif ($Exclude | Where-Object { $name -like $_ }) {
            $excludedGlob += $entry
        }
    }
}

$finalEntries = foreach ($entry in $fileEntries) {
    $isIncludedExact = $includedExact -contains $entry
    $isIncludedGlob  = $includedGlob  -contains $entry
    $isExcludedExact = $excludedExact -contains $entry
    $isExcludedGlob  = $excludedGlob  -contains $entry

    if ($isIncludedExact) { $entry; continue }
    if ($isExcludedExact) { continue }
    if ($isIncludedGlob)  { $entry; continue }
    if ($isExcludedGlob)  { continue }

    # if ($Include) {
    #     continue
    # }

    $entry
}

$entries = foreach ($entry in $finalEntries) {
    $fileHash = (Get-FileHash -LiteralPath $entry.FullPath -Algorithm $Algorithm).Hash
    '{0}|{1}' -f $entry.Relative, $fileHash
}

$combinedText = [string]::Join("`n", $entries)
$bytes        = [Text.Encoding]::UTF8.GetBytes($combinedText)
$stream       = [IO.MemoryStream]::new($bytes)

try {
    [pscustomobject]@{
        ModuleName      = $ModuleInfo.ModuleName
        ManifestPath    = $ModuleInfo.ManifestPath
        RootModulePath  = $ModuleInfo.RootModulePath
        SourceRootPath  = $ModuleInfo.SourceRootPath
        Algorithm       = $Algorithm
        Fingerprint     = (Get-FileHash -InputStream $stream -Algorithm $Algorithm).Hash
        Files           = $entries.Count
        Entries         = $entries
        Included        = $finalEntries.Relative
    }
}
finally {
    $stream.Dispose()
}