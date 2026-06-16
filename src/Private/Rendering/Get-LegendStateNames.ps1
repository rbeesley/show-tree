<#
.SYNOPSIS
    Returns a list of state names to display in the legend.

.DESCRIPTION
    The Get-LegendStateNames cmdlet filters the states defined in a style profile based on the 
    specified platform (Windows, Unix, or Current) to show only relevant states in the legend output.
#>
function Get-LegendStateNames {
    param(
        $StyleProfile,

        [ValidateSet('Current', 'Windows', 'Unix')]
        [string]$Platform = 'Current',

        [switch]$All
    )

    if (-not $StyleProfile.States) {
        return @()
    }

    if ($All) {
        return @($StyleProfile.States.Keys)
    }

    $resolvedPlatform = if ($Platform -eq 'Current') {
        $IsWindows ? 'Windows' : 'Unix'
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
