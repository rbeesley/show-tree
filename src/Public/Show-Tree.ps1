# src/Public/Show-Tree.ps1

<#
.SYNOPSIS
    Displays a directory tree in Normal, Tree.com-compatible, or Listing mode.

.DESCRIPTION
    The Show-Tree cmdlet displays a directory tree for the specified path. It supports three distinct modes:
    - Normal: A clean, modern tree view.
    - Tree: A legacy-compatible view mimicking the classic tree.com output.
    - List: A flat listing of items with tree-aware metadata.

    The output is fully colorized based on file attributes and types, and supports custom style profiles.

.PARAMETER Mode
    Specifies the output mode. Valid values are 'Normal', 'Tree', and 'List'. Default is 'Normal'.

.PARAMETER Path
    The path to the directory to display. Default is the current directory ('.').

.PARAMETER Include
    Includes only items that match the specified glob patterns.

.PARAMETER Exclude
    Excludes items that match the specified glob patterns.

.PARAMETER Color
    Forces colorization in Tree mode.

.PARAMETER Mono
    Disables colorization in Normal or List modes.

.PARAMETER Files
    Shows files in Tree mode.

.PARAMETER NoFiles
    Hides files in Normal or List modes.

.PARAMETER ShowHidden
    Shows hidden items in Tree mode.

.PARAMETER HideHidden
    Hides hidden items in Normal or List modes.

.PARAMETER ShowSystem
    Shows system items in Tree mode.

.PARAMETER HideSystem
    Hides system items in Normal or List modes.

.PARAMETER ShowTargets
    Shows symbolic link and junction targets in List mode.

.PARAMETER NoTargets
    Hides symbolic link and junction targets in Normal or Tree modes.

.PARAMETER Gap
    Adds gap lines between items in Tree mode for better readability.

.PARAMETER NoGap
    Removes gap lines in Normal or Tree modes.

.PARAMETER MaxDepth
    The maximum depth to traverse.

.PARAMETER Recurse
    Recursively traverses all subdirectories.

.PARAMETER Ascii
    Uses ASCII characters for tree connectors instead of Unicode/Box-drawing characters.

.PARAMETER Legend
    Displays the color legend for the current style profile.

.PARAMETER LegendAll
    Displays the full color legend for all supported platforms.

.PARAMETER Platform
    Specifies the platform to use for the legend ('Current', 'Windows', 'Unix').

.PARAMETER Culture
    Overrides the current culture for localization and style selection.

.EXAMPLE
    Show-Tree
    Displays the current directory in Normal mode.

.EXAMPLE
    Show-Tree -Mode Tree -Files
    Displays the current directory in Tree mode, including files.

.EXAMPLE
    Show-Tree C:\Windows -MaxDepth 2
    Displays the C:\Windows directory up to 2 levels deep.

.LINK
    Get-TreeItem
    Format-Tree
#>
function Show-Tree {
    [CmdletBinding()]
    param(
        #
        # MODE SELECTION
        #
        [ValidateSet('Normal', 'Tree', 'List')]
        [string]$Mode = 'Normal',

        # Backward-compatible aliases
        [Alias('Tree')]
        [switch]$AsTree,

        [Alias('List','Listing')]
        [switch]$AsListing,


        #
        # PATH
        #
        [Parameter(Position = 0)]
        [string]$Path = '.',


        #
        # GLOB FILTERING
        #
        [string[]]$Include,
        [string[]]$Exclude,

        #
        # MODE-SPECIFIC SWITCHES
        #

        # Colorization
        [switch]$Color,      # Tree
        [Alias('NoColor')]
        [switch]$Mono,       # Normal/Listing

        # Files
        [Alias('ShowFiles')]
        [switch]$Files,      # Tree
        [switch]$NoFiles,    # Normal/Listing

        # Hidden
        [switch]$ShowHidden, # Tree
        [switch]$HideHidden, # Normal/Listing

        # System
        [switch]$ShowSystem, # Tree
        [switch]$HideSystem, # Normal/Listing

        # Reparse targets
        [switch]$ShowTargets, # Listing
        [switch]$NoTargets,   # Normal/Tree

        # Gap lines
        [switch]$Gap,         # Tree
        [switch]$NoGap,       # Normal/Tree

        # Depth
        [Alias('Depth')]
        [int]$MaxDepth,
        [switch]$Recurse,

        # ASCII connectors
        [switch]$Ascii,

        # Show the color legend
        [switch]$Legend,

        # Shortcut for Show-TreeLegend -All
        [switch]$LegendAll,

        # Platform to show in legend mode
        [ValidateSet('Current', 'Windows', 'Unix')]
        [string]$Platform = 'Current',

        # BCP-47 culture override
        [string]$Culture
    )

    #
    # Resolve Mode (explicit or implied)
    #
    if ($AsTree)    { $Mode = 'Tree' }
    if ($AsListing) { $Mode = 'List' }

    $resolvedStyleProfile = Get-ActiveShowTreeStyleProfile
    if ($Culture) {
        $resolvedStyleProfile = Get-ShowTreeStyleProfile -Culture $Culture
    }
    elseif ($null -eq $resolvedStyleProfile) {
        $resolvedStyleProfile = Get-ShowTreeStyleProfile
    }
    $uiErrors = $resolvedStyleProfile.UIStrings.Errors

    #
    # Legend mode validation/rendering
    #
    $isLegendMode = $Legend -or $LegendAll

    if ($PSBoundParameters.ContainsKey('Platform') -and -not $isLegendMode) {
        throw $uiErrors.PlatformRequiresLegend
    }

    if ($isLegendMode) {
        Show-TreeLegend `
            -StyleProfile $resolvedStyleProfile `
            -Platform $Platform `
            -All:$LegendAll
        return
    }

    if ($Mode -eq 'Tree' -and $PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
        throw $uiErrors.WindowsOnly
    }

    #
    # Validate paired switches
    #
    if ($Color -and $Mono) { throw $uiErrors.ColorMonoConflict }
    if ($Files -and $NoFiles) { throw $uiErrors.FilesConflict }
    if ($ShowHidden -and $HideHidden) { throw $uiErrors.HiddenConflict }
    if ($ShowSystem -and $HideSystem) { throw $uiErrors.SystemConflict }
    if ($ShowTargets -and $NoTargets) { throw $uiErrors.TargetsConflict }
    if ($Gap -and $NoGap) { throw $uiErrors.GapConflict }
    
    #
    # Resolve the path
    #
    $resolvedPath = Resolve-TreePath -Path $Path -Mode $Mode
    if (-not $resolvedPath) { return }

    #
    # Compute effective settings
    #
    switch ($Mode) {
        'Tree' {
            $EffectiveMaxDepth    = $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : -1
            $EffectiveColorize    = $Color.IsPresent
            $EffectiveFiles       = $Files.IsPresent
            $EffectiveHideHidden  = -not $ShowHidden.IsPresent
            $EffectiveHideSystem  = -not $ShowSystem.IsPresent
            $EffectiveShowTargets = -not $NoTargets.IsPresent
            $EffectiveGap         = ($Files.IsPresent -or $Gap.IsPresent) -and -not $NoGap.IsPresent
        }
        'List' {
            $EffectiveMaxDepth    = $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : -1
            $EffectiveColorize    = -not $Mono.IsPresent
            $EffectiveFiles       = -not $NoFiles.IsPresent
            $EffectiveHideHidden  = $HideHidden.IsPresent
            $EffectiveHideSystem  = $HideSystem.IsPresent
            $EffectiveShowTargets = $ShowTargets.IsPresent
            $EffectiveGap         = $false
        }
        'Normal' {
            $EffectiveMaxDepth    = $Recurse.IsPresent ? -1 : ($PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : -1)
            $EffectiveColorize    = -not $Mono.IsPresent
            $EffectiveFiles       = -not $NoFiles.IsPresent
            $EffectiveHideHidden  = $HideHidden.IsPresent
            $EffectiveHideSystem  = $HideSystem.IsPresent
            $EffectiveShowTargets = -not $NoTargets.IsPresent
            $EffectiveGap         = -not $NoGap.IsPresent
        }
    }

    #
    # Header Rendering
    #
    if ($Mode -eq 'Tree') {
        $header = Get-TreeModeHeader -Path $resolvedPath -Colorize:$EffectiveColorize -StyleProfile $resolvedStyleProfile
        $header | Where-Object { $_ -is [string] }
        if ($header -contains $false) {
            return
        }
    }
    else {
        # Normal + Listing modes: Print resolved path with style
        $rootItem = Get-Item $resolvedPath
        $native = [PSCustomObject]@{
            Platform = if ($IsWindows) { 'Windows' } else { 'Unix' }
            FileAttributes = $rootItem.Attributes
        }
        $kind = if ($rootItem.PSIsContainer) { 'Directory' } else { 'File' }
        $treeItem = New-TreeItem `
            -FullPath $rootItem.FullName `
            -IsContainer $rootItem.PSIsContainer `
            -Kind $kind `
            -Name $rootItem.Name `
            -Native $native `
            -Depth 0

        $style = Get-ItemStyle -Item $treeItem -Colorize:$EffectiveColorize -StyleProfile $resolvedStyleProfile

        $colorReset = $EffectiveColorize ? $resolvedStyleProfile.Reset : ""
        Write-Output "$($style.Ansi)$resolvedPath${colorReset}"
    }

    #
    # Enumerate -> Select -> Render
    #
    $providerMode = if ($Mode -eq 'Tree') { 'Win32' } else { 'PowerShell' }

    $formatParams = @{
        Mode         = $Mode
        Colorize    = $EffectiveColorize
        ShowTargets = $EffectiveShowTargets
        Ascii       = $Ascii
        NoGap       = -not $EffectiveGap
        StyleProfile = $resolvedStyleProfile
    }

    Get-TreeItem `
        -Path $resolvedPath `
        -Depth $EffectiveMaxDepth `
        -ProviderMode $providerMode `
        -Include $Include `
        -Exclude $Exclude `
        -HideHidden:$EffectiveHideHidden `
        -HideSystem:$EffectiveHideSystem `
        -DirectoryOnly:(!$EffectiveFiles) |
            Format-Tree @formatParams

    #
    # Footer / Last Line logic
    #
    if ($Mode -ne 'Tree') {
        Write-Output ""
    }
}
