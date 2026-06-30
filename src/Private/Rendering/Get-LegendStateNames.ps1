# /src/Private/Rendering/Get-LegendStateNames.ps1

<#
.SYNOPSIS
    Returns a list of state names for legend rendering.

.DESCRIPTION
    Get-LegendStateNames provides the ordered list of states (like Hidden, ReadOnly, 
    Symlink) that should be displayed when rendering the color legend.
#>
function Get-LegendStateNames {
    param(
        $StyleProfile,

        [ValidateSet('Current', 'Windows', 'Unix')]
        [string]$Platform = 'Current',

        [switch]$All
    )

    if (-not $PSBoundParameters.ContainsKey('Debug') -and $PSCmdlet)
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose') -and $PSCmdlet)
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    if (-not $StyleProfile.States) {
        return @()
    }

    if ($All) {
        return @($StyleProfile.States.Keys)
    }

    $localIsWindows = $IsWindows ? $IsWindows : $true
    $resolvedPlatform = if ($Platform -eq 'Current') {
        $localIsWindows ? 'Windows' : 'Unix'
    }
    else {
        $Platform
    }

    $commonStates = @(
        'Hidden',
        'ReadOnly',
        'Symlink',
        'BrokenLink'
    )

    $windowsStates = @(
        'System',
        'Temporary',
        'SparseFile',
        'ReparsePoint',
        'Compressed',
        'Offline',
        'NotContentIndexed',
        'Encrypted',
        'IntegrityStream',
        'NoScrubData'
    )

    $unixStates = @(
        'Executable',
        'SetUid',
        'SetGid',
        'Sticky'
    )

    $stateNames = switch ($resolvedPlatform) {
        'Windows' { $commonStates + $windowsStates }
        'Unix'    { $commonStates + $unixStates }
    }

    foreach ($stateName in $stateNames) {
        if ($StyleProfile.States.ContainsKey($stateName)) {
            $stateName
        }
    }
}
