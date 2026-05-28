# src/Private/StyleProfile/Get-ActiveShowTreeStyleProfile.ps1

function Get-ActiveShowTreeStyleProfile {
    [CmdletBinding()]
    param()

    if ($null -eq $script:ShowTreeState -or $null -eq $script:ShowTreeState.StyleProfile) {
        return Get-ShowTreeStyleProfile
    }

    return $script:ShowTreeState.StyleProfile
}
