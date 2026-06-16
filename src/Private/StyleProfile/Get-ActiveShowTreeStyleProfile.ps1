# src/Private/StyleProfile/Get-ActiveShowTreeStyleProfile.ps1

<#
.SYNOPSIS
    Returns the currently active style profile.

.DESCRIPTION
    The Get-ActiveShowTreeStyleProfile cmdlet retrieves the style profile currently being used by the module.
    If no profile is set in the session state, it returns the default profile.
#>
function Get-ActiveShowTreeStyleProfile {
    [CmdletBinding()]
    param()

    if ($null -eq $script:ShowTreeState -or $null -eq $script:ShowTreeState.StyleProfile) {
        return Get-ShowTreeStyleProfile
    }

    return $script:ShowTreeState.StyleProfile
}
