# src/Public/Set-ShowTreeStyleProfile.ps1

<#
.SYNOPSIS
    Sets the active style profile for Show-Tree.

.DESCRIPTION
    The Set-ShowTreeStyleProfile cmdlet sets the active style profile used for colorizing and formatting tree output.
    You can set the profile by path, provide a hashtable of overrides, or reset to the default profile.

.PARAMETER Path
    The path to a .psd1 or .json file containing the style profile.

.PARAMETER Culture
    The culture to use when loading the style profile.

.PARAMETER InputObject
    A hashtable containing style overrides to apply to the active profile.

.PARAMETER Reset
    Resets the active style profile to the default for the current system and culture.

.EXAMPLE
    Set-ShowTreeStyleProfile -Path .\MyStyles.psd1
    Sets the active style profile from a file.

.EXAMPLE
    Set-ShowTreeStyleProfile -InputObject @{ Base = @{ File = '31' } }
    Overrides the base file color to red in the active profile.

.LINK
    Get-ActiveShowTreeStyleProfile
    Get-ShowTreeStyleProfile
#>
function Set-ShowTreeStyleProfile {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(ParameterSetName = 'Path')]
        [string] $Path,

        [Parameter(ParameterSetName = 'Path')]
        [string] $Culture,

        [Parameter(ParameterSetName = 'InputObject')]
        [System.Collections.IDictionary] $InputObject,

        [Parameter(ParameterSetName = 'Reset', Mandatory)]
        [switch] $Reset
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Reset' {
            $script:ShowTreeState.StyleProfile = Get-ShowTreeStyleProfile
            return
        }

        'Path' {
            $script:ShowTreeState.StyleProfile = Get-ShowTreeStyleProfile -Path $Path -Culture $Culture
            return
        }

        'InputObject' {
            $baseProfile = Get-ActiveShowTreeStyleProfile
            $script:ShowTreeState.StyleProfile = Merge-ShowTreeHashtable -Base $baseProfile -Override $InputObject
            return
        }
    }
}
