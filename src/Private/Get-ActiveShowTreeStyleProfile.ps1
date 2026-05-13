# src\Private\Get-ActiveShowTreeStyleProfile.ps1

function Get-ActiveShowTreeStyleProfile {
    [CmdletBinding()]
    param()

    if (-not $script:ShowTreeState.StyleProfile) {
        $script:ShowTreeState.StyleProfile = Get-ShowTreeStyleProfile
    }

    return $script:ShowTreeState.StyleProfile
}
