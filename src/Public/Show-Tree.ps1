# src/Public/Show-Tree.ps1

<#
.SYNOPSIS
    Displays a directory tree in Normal, Tree.com-compatible, or Listing mode.

.DESCRIPTION
    The Show-Tree cmdlet provides a modern, colorized directory tree visualization for the console. 
    It is designed as a feature-rich replacement for the classic tree.com utility, supporting 
    three distinct display modes:

    - Normal: A clean, modern Unicode tree view with gap lines and rich styling.
    - Tree: A legacy-compatible view mimicking the classic tree.com output, including drive headers.
    - List: A flat listing of items that retains hierarchical context.

    Show-Tree supports deep customization via style profiles, allows filtering by glob patterns, 
    and handles symbolic links, hidden files, and system files across Windows and Unix platforms.

.PARAMETER Mode
    Specifies the output mode. Valid values are 'Normal', 'Tree', and 'List'. 
    Default is 'Normal'.

.PARAMETER Path
    The path to the directory to display. Defaults to the current directory ('.').

.PARAMETER Include
    Includes only items that match the specified glob patterns. Ancestor directories of matching 
    files are automatically included to maintain tree structure.

.PARAMETER Exclude
    Excludes items and their descendants that match the specified glob patterns.

.PARAMETER Color
    Forces colorization in Tree mode. By default, Tree mode matches the original utility and is monochromatic.

.PARAMETER Mono
    Disables colorization in Normal or List modes.

.PARAMETER Files
    Shows files when using Tree mode. (Alias: ShowFiles)

.PARAMETER NoFiles
    Hides files in Normal or List modes (where they are shown by default).

.PARAMETER ShowHidden
    Shows hidden items in Tree mode.

.PARAMETER HideHidden
    Hides hidden items in Normal or List modes (where they are shown by default).

.PARAMETER ShowSystem
    Shows system items in Tree mode.

.PARAMETER HideSystem
    Hides system items in Normal or List modes (where they are shown by default).

.PARAMETER ShowTargets
    Displays the targets of symbolic links and junctions in List and Tree modes.

.PARAMETER NoTargets
    Suppresses symbolic link and junction targets in Normal mode.

.PARAMETER Gap
    Adds gap lines between item groups in List or Tree modes.

.PARAMETER NoGap
    Removes gap lines in Normal or Tree modes.

.PARAMETER MaxDepth
    The maximum recursion depth. Defaults to 6. Use -1 or the -Recurse switch for unlimited depth.

.PARAMETER Recurse
    Recursively traverses all subdirectories. Equivalent to -MaxDepth -1.

.PARAMETER Ascii
    Uses standard ASCII characters (|, +, -) for tree connectors instead of Unicode box-drawing characters.

.PARAMETER Legend
    Displays the color legend for the active style profile instead of showing a directory tree.

.PARAMETER LegendAll
    Displays the full color legend for all supported platforms (Windows and Unix).

.PARAMETER Platform
    Specifies which platform's style to show in legend mode ('Current', 'Windows', 'Unix').

.PARAMETER Culture
    Overrides the current system culture for selecting localized strings and style profiles.

.EXAMPLE
    Show-Tree -Recurse
    Displays the full tree structure starting from the current directory.

.EXAMPLE
    Show-Tree -Mode Tree -Files -Color
    Displays a colorized, legacy-style tree including files.

.EXAMPLE
    Show-Tree -Include "src\*", "*.md" -Exclude "node_modules\"
    Shows Markdown files and the contents of the 'src' directory while ignoring 'node_modules'.

.LINK
    Get-TreeItem
    Format-Tree
    Set-ShowTreeStyleProfile
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

    if (-not $PSBoundParameters.ContainsKey('Debug'))
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose'))
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

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
    # Resolve Filters against CWD
    #
    function Resolve-FilterPaths {
        param([string[]]$Patterns)
        if (-not $Patterns) { return $null }
        $results = New-Object System.Collections.Generic.List[string]
        $cwd = $PWD.ProviderPath
        foreach ($p in $Patterns) {
            # Only resolve if it's an explicit relative path or a drive-rooted path.
            # Names with trailing slashes (e.g. folder/) should remain as name patterns.
            $isRelative = $p.StartsWith('.' + [System.IO.Path]::DirectorySeparatorChar) -or
                    $p.StartsWith('..' + [System.IO.Path]::DirectorySeparatorChar) -or
                    $p.StartsWith('./') -or $p.StartsWith('../')

            if ($isRelative -or [System.IO.Path]::IsPathRooted($p)) {
                $resolved = $p
                if ($p.StartsWith('.\') -or $p.StartsWith('./')) { $resolved = $p.Substring(2) }
                if (-not [System.IO.Path]::IsPathRooted($resolved)) {
                    $resolved = [System.IO.Path]::Combine($cwd, $resolved)
                }
                # Preserve wildcards
                $results.Add($resolved)
            }
            else {
                $results.Add($p)
            }
        }
        
        return $results.ToArray()
    }
    
    Write-Verbose "Include: $Include"
    Write-Verbose "Exclude: $Exclude"

    $effectiveInclude = Resolve-FilterPaths -Patterns $Include
    $effectiveExclude = Resolve-FilterPaths -Patterns $Exclude

    Write-Verbose "effectiveInclude: $effectiveInclude"
    Write-Verbose "effectiveExclude: $effectiveExclude"

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
        Include       = $effectiveInclude
        Exclude       = $effectiveExclude
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
