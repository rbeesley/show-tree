# src/Public/Show-TreeLegend.ps1

<#
.SYNOPSIS
    Displays a color legend for base types and state overlays.

.DESCRIPTION
    The Show-TreeLegend cmdlet displays a visual guide to the colors used by Show-Tree.
    It shows how base types (File, Directory) and various states (Hidden, ReadOnly, System, etc.)
    are rendered in the current style profile.

    By default, only states relevant to the current platform are shown.
    Use -Platform to preview another platform's states, or -All to show every
    state defined by the active style profile.

.PARAMETER StyleProfile
    A specific style profile to use for the legend. Defaults to the active profile.

.PARAMETER Culture
    The culture to use for loading a style profile and displaying localized strings.

.PARAMETER Platform
    The platform states to display ('Current', 'Windows', 'Unix').

.PARAMETER All
    If set, displays all states defined in the style profile, regardless of the platform.

.EXAMPLE
    Show-TreeLegend
    Displays the legend for the current style profile and platform.

.EXAMPLE
    Show-TreeLegend -Platform Unix
    Displays the legend as it would appear on a Unix platform.

.LINK
    Show-Tree
    Get-ItemStyle
#>
function Show-TreeLegend {
    param(
        $StyleProfile = $null,

        [string]$Culture,

        [ValidateSet('Current', 'Windows', 'Unix')]
        [string]$Platform = 'Current',

        [switch]$All
    )

    if ($Culture) {
        $StyleProfile = Get-ShowTreeStyleProfile -Culture $Culture
    }
    elseif (-not $StyleProfile) {
        $StyleProfile = Get-ActiveShowTreeStyleProfile
    }

    $reset = $StyleProfile.Reset

    $ui = $StyleProfile.UIStrings.Legend
    Write-Output ""
    Write-Output $ui.Header
    Write-Output $ui.HeaderUnderline
    Write-Output ""

    #
    # Helper to render a sample line
    #
    function Show-Sample {
        param(
            [string]$Name,
            $Item,
            $Indent = "",
            $StyleProfile
        )

        $style = Get-ItemStyle -Item $Item -Colorize:$true -StyleProfile $StyleProfile
        $ansi  = $style.Ansi
        $reset = $StyleProfile.Reset
        Write-Output ("{0,-22} {1}{2}{3}" -f ($Indent + $Name), $ansi, $Name, $reset)
    }

    $stateNames = Get-LegendStateNames `
        -StyleProfile $StyleProfile `
        -Platform $Platform `
        -All:$All

    #
    # Base types
    #
    Write-Output $ui.Types

    Show-Sample "File"      (New-TreeItem -FullPath 'file' -IsContainer $false -Kind 'File' -Native @{ FileAttributes = [IO.FileAttributes]::Archive }) " " $StyleProfile
    Write-Output $ui.States
    foreach ($state in $stateNames) {
        $item = New-TreeItem -FullPath 'file' -IsContainer $false -Kind 'File' -States @($state)
        Show-Sample $state $item "   " $StyleProfile
    }
    Write-Output ""

    Show-Sample "Directory" (New-TreeItem -FullPath 'dir' -IsContainer $true -Kind 'Directory' -Native @{ FileAttributes = [IO.FileAttributes]::Directory }) " " $StyleProfile
    Write-Output $ui.States
    foreach ($state in $stateNames) {
        $item = New-TreeItem -FullPath 'dir' -IsContainer $true -Kind 'Directory' -States @($state)
        Show-Sample $state $item "   " $StyleProfile
    }
    Write-Output ""
}
