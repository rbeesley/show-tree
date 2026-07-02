# src/Private/PathUtilities/Get-FileAttributes.ps1

<#
.SYNOPSIS
    Enumerates all set file attributes on an item.

.DESCRIPTION
    The Get-FileAttributes cmdlet expands a FileAttributes bitmask into a collection of individual flags,
    which is used by Get-ItemStyle to apply attribute-based styling overlays.

.PARAMETER Attributes
    The System.IO.FileAttributes bitmask to expand.
#>
function Get-FileAttributes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [IO.FileAttributes]$Attributes
    )

    if (-not $PSBoundParameters.ContainsKey('Debug') -and $PSCmdlet)
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose') -and $PSCmdlet)
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    foreach ($flag in [System.Enum]::GetValues([IO.FileAttributes])) {
        if ($Attributes -band $flag) {
            $flag
        }
    }
}