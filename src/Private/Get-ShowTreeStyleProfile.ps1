# src\Private\Get-ShowTreeStyleProfile.ps1

function Get-ShowTreeStyleProfile {
    [CmdletBinding()]
    param(
        [string] $Path
    )

    $defaultProfile = Import-PowerShellDataFile -LiteralPath $script:DefaultStyleProfilePath

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Join-Path $HOME '.showtree\StyleProfile.psd1'
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        return $defaultProfile
    }

    $userProfile = Import-PowerShellDataFile -LiteralPath $Path
    return Merge-ShowTreeHashtable -Base $defaultProfile -Override $userProfile
}