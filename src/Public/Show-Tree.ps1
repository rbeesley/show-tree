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
    Forces colorization in Tree mode. Colorization is applied by default in Normal and List modes.

.PARAMETER Mono
    Disables colorization in Normal or List modes.

.PARAMETER Files
    Shows files in Tree mode. (Alias: ShowFiles)

.PARAMETER NoFiles
    Hides files in Normal or List modes.

.PARAMETER ShowHidden
    Shows hidden items in Tree mode. Hidden items are shown by default in Normal and List modes.

.PARAMETER HideHidden
    Hides hidden items in Normal or List modes.

.PARAMETER ShowSystem
    Shows system items in Tree mode. System items are shown by default in Normal and List modes.

.PARAMETER HideSystem
    Hides system items in Normal or List modes.

.PARAMETER ShowTargets
    Shows symbolic link and junction targets in List and Tree modes.

.PARAMETER NoTargets
    Hides symbolic link and junction targets in Normal mode.

.PARAMETER Gap
    Adds gap lines between items in List or Tree modes for better readability.

.PARAMETER NoGap
    Removes gap lines in Normal or Tree modes.

.PARAMETER MaxDepth
    The maximum depth to traverse. This defaults to 6 for all modes and can be overridden to no maximum depth with a setting of -1 or using Recurse.

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
    Show-Tree -Mode Tree -Files -Color
    Displays the current directory in Tree mode, including files, and using color rendering.

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
    # Resolve Style Profile
    #
    $resolvedStyleProfile = Get-ActiveShowTreeStyleProfile
    if ($Culture) {
        $resolvedStyleProfile = Get-ShowTreeStyleProfile -Culture $Culture
    }
    elseif ($resolvedStyleProfile) {
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

    $localIsWindows = $IsWindows ? $IsWindows : $true
    if ($Mode -eq 'Tree' -and -not $localIsWindows) {
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
            $EffectiveMaxDepth    = $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : $Recurse.IsPresent ? -1 : 6
            $EffectiveColorize    = $Color.IsPresent
            $EffectiveFiles       = $Files.IsPresent
            $EffectiveHideHidden  = -not $ShowHidden.IsPresent
            $EffectiveHideSystem  = -not $ShowSystem.IsPresent
            $EffectiveShowTargets = $ShowTargets.IsPresent
            $GapPolicy = if ($NoGap.IsPresent) { 'None' }
                elseif ($Gap.IsPresent) { 'Show' }
                elseif ($Mode -eq 'Tree' -and $Files.IsPresent) { 'Tree' }
                else { 'None' }
        }
        'List' {
            $EffectiveMaxDepth    = $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : $Recurse.IsPresent ? -1 : 6
            $EffectiveColorize    = -not $Mono.IsPresent
            $EffectiveFiles       = -not $NoFiles.IsPresent
            $EffectiveHideHidden  = $HideHidden.IsPresent
            $EffectiveHideSystem  = $HideSystem.IsPresent
            $EffectiveShowTargets = $ShowTargets.IsPresent
            $GapPolicy            = 'None'
        }
        'Normal' {
            $EffectiveMaxDepth    = $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : $Recurse.IsPresent ? -1 : 6
            $EffectiveColorize    = -not $Mono.IsPresent
            $EffectiveFiles       = -not $NoFiles.IsPresent
            $EffectiveHideHidden  = $HideHidden.IsPresent
            $EffectiveHideSystem  = $HideSystem.IsPresent
            $EffectiveShowTargets = -not $NoTargets.IsPresent
            $GapPolicy            = $NoGap.IsPresent ? 'None' : 'Show'
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
            Platform = $localIsWindows ? 'Windows' : 'Unix'
            FileAttributes = $rootItem.Attributes
        }
        $kind = $rootItem.PSIsContainer ? 'Directory' : 'File'
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
    $providerMode = ($Mode -eq 'Tree') ? 'Win32' : 'PowerShell'

    $getTreeItemParams = @{
        Path          = $resolvedPath
        Mode          = $Mode
        Depth         = $EffectiveMaxDepth
        ProviderMode  = $providerMode
        GapPolicy     = $GapPolicy
        Include       = $Include
        Exclude       = $Exclude
        HideHidden    = $EffectiveHideHidden
        HideSystem    = $EffectiveHideSystem
        DirectoryOnly = (-not $EffectiveFiles)
    }

    $formatTreeParams = @{
        Mode         = $Mode
        Colorize     = $EffectiveColorize
        ShowTargets  = $EffectiveShowTargets
        Ascii        = $Ascii
        GapPolicy    = $GapPolicy
        StyleProfile = $resolvedStyleProfile
    }

    Get-TreeItem @getTreeItemParams |
            Format-Tree @formatTreeParams

    #
    # Footer / Last Line logic
    #
    if ($Mode -ne 'Tree') {
        Write-Output ""
    }
}
