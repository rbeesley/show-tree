# src/Private/StyleProfile/Get-ActiveShowTreeStyleProfile.ps1

<#
.SYNOPSIS
    Retrieves the currently active style profile object.

.DESCRIPTION
    Get-ActiveShowTreeStyleProfile looks up the style profile currently set in the 
    module's state. If no profile is set, it initializes and returns the default profile.
#>
function Get-ActiveShowTreeStyleProfile {
    [CmdletBinding()]
    param()

    if (-not $PSBoundParameters.ContainsKey('Debug') -and $PSCmdlet)
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose') -and $PSCmdlet)
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    if ($null -eq $script:ShowTreeState -or $null -eq $script:ShowTreeState.StyleProfile) {
        return Get-ShowTreeStyleProfile
    }

    return $script:ShowTreeState.StyleProfile
}
