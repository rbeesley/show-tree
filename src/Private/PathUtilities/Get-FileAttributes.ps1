# src/Private/PathUtilities/Get-FileAttributes.ps1

<#
.SYNOPSIS
    Enumerates all set file attributes on an item.

.DESCRIPTION
    The Get-FileAttributes cmdlet expands a FileAttributes bitmask into a collection of individual flags,
    which is used by Get-ItemStyle to apply attribute-based styling overlays.
#>
function Get-FileAttributes {
    param([IO.FileAttributes]$Attributes)

    if (-not $PSBoundParameters.ContainsKey('Debug'))
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose'))
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    foreach ($flag in [System.Enum]::GetValues([IO.FileAttributes])) {
        if ($Attributes -band $flag) {
            $flag
        }
    }
}