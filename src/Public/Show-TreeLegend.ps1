# src/Public/Show-TreeLegend.ps1

<#
.SYNOPSIS
    Displays a color legend for base types and state overlays.

.DESCRIPTION
    Useful for understanding how Show-Tree applies color to files,
    directories, symlinks, junctions, and state combinations.

    By default, only states relevant to the current platform are shown.
    Use -Platform to preview another platform's states, or -All to show every
    state defined by the active style profile.
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
