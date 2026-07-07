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
    Forces colorization. Used primarily in Tree mode to override the default monochromatic output.
    Note: Defaults to ON for Normal/List modes and OFF for Tree mode.

.PARAMETER NoColor
    Disables ANSI color coding. (Alias: Mono, NoColor)

.PARAMETER Files
    Shows files in the tree listing. (Alias: ShowFiles)
    Note: Defaults to ON for Normal/List modes and OFF for Tree mode.

.PARAMETER NoFiles
    Forcefully hides files regardless of the active mode.

.PARAMETER Hidden
    Shows hidden items (files or directories marked with the Hidden attribute or dot-prefixed on Unix). (Alias: ShowHidden)
    Note: Defaults to OFF for all modes.

.PARAMETER NoHidden
    Forcefully hides hidden items regardless of the active mode. (Alias: HideHidden)

.PARAMETER System
    Shows system items (items marked with the System attribute on Windows). (Alias: ShowSystem)
    Note: Defaults to OFF for all modes.

.PARAMETER NoSystem
    Forcefully hides system items regardless of the active mode. (Alias: HideSystem)

.PARAMETER Targets
    Displays the targets of symbolic links and junctions. (Alias: ShowTargets)
    Note: Defaults to ON for Normal/List modes and OFF for Tree mode.

.PARAMETER NoTargets
    Suppresses symbolic link and junction targets.

.PARAMETER Gap
    Adds gap lines between item groups to improve visual clarity.
    Note: Defaults to ON for Normal mode and OFF for List/Tree modes. In Tree mode, 
    enabling Files will also enable a specific "Tree" gap policy.

.PARAMETER NoGap
    Removes gap lines.

.PARAMETER Compat
    Enables strict compatibility mode when using -Mode Tree. This mimics the monochromatic, 
    file-less, and target-less output of the classic tree.com utility.

.PARAMETER MaxDepth
    The maximum recursion depth. Defaults to 6. Use -1 or the -Recurse switch for unlimited depth. (Alias: Depth)

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
    Show-Tree -Hidden -NoGap
    Shows hidden files in the current directory and suppresses gap lines.

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
        [switch]$Color,         # Tree
        [Alias('Mono')]         # Normal/Listing
        [switch]$NoColor,

        # Files
        [Alias('ShowFiles')]    # Tree
        [switch]$Files,
        [switch]$NoFiles,       # Normal/Listing

        # Hidden
        [Alias('ShowHidden')]   # Tree
        [switch]$Hidden,
        [Alias('HideHidden')]   # Normal/Listing
        [switch]$NoHidden,

        # System
        [Alias('ShowSystem')]   # Tree
        [switch]$System,
        [Alias('HideSystem')]   # Normal/Listing
        [switch]$NoSystem,

        # Reparse targets
        [Alias('ShowTargets')]  # Listing
        [switch]$Targets,
        [switch]$NoTargets,     # Normal/Tree

        # Gap lines
        [switch]$Gap,           # Tree
        [switch]$NoGap,         # Normal/Tree

        # Strict compatibility
        [switch]$Compat,

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

    if (-not $PSBoundParameters.ContainsKey('Debug') -and $PSCmdlet)
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose') -and $PSCmdlet)
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    #
    # Resolve Style Profile
    #
    $resolvedStyleProfile = Get-ActiveShowTreeStyleProfile
    $script:lastRecordKind = $null
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

    if ($Compat -and $Mode -ne 'Tree') {
        throw $uiErrors.CompatRequiresTree
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
    if ($Color -and $NoColor) { throw $uiErrors.ColorMonoConflict }
    if ($Files -and $NoFiles) { throw $uiErrors.FilesConflict }
    if ($Hidden -and $NoHidden) { throw $uiErrors.HiddenConflict }
    if ($System -and $NoSystem) { throw $uiErrors.SystemConflict }
    if ($Targets -and $NoTargets) { throw $uiErrors.TargetsConflict }
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

    $effectiveInclude = Resolve-FilterPaths -Patterns $Include
    $effectiveExclude = Resolve-FilterPaths -Patterns $Exclude

    #
    # Compute effective settings
    #
    switch ($Mode) {
        'Tree' {
            $EffectiveMaxDepth    = $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : ($Recurse.IsPresent ? -1 : 6)

            # Defaults for Tree mode depend on Compat switch
            $defaultColor   = $Compat.IsPresent ? $false : $true
            $defaultFiles   = $Compat.IsPresent ? $false : $true
            $defaultTargets = $Compat.IsPresent ? $false : $true
            $defaultGap     = $Compat.IsPresent ? ($Files.IsPresent ? 'Tree' : 'None') : 'Show'

            # Resolution
            $EffectiveColorize    = $Color.IsPresent ? $true : ($NoColor.IsPresent ? $false : $defaultColor)
            $EffectiveFiles       = $Files.IsPresent ? $true : ($NoFiles.IsPresent ? $false : $defaultFiles)
            $EffectiveShowHidden  = $Hidden.IsPresent
            $EffectiveShowSystem  = $System.IsPresent
            $EffectiveShowTargets = $Targets.IsPresent ? $true : ($NoTargets.IsPresent ? $false : $defaultTargets)
            $GapPolicy            = $Gap.IsPresent ? 'Show' : ($NoGap.IsPresent ? 'None' : $defaultGap)
        }
        default {
            # Normal and List modes
            $EffectiveMaxDepth    = $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : ($Recurse.IsPresent ? -1 : 6)

            # Defaults for Modern modes
            $defaultColor   = $true
            $defaultFiles   = $true
            $defaultTargets = ($Mode -eq 'Normal') # Normal shows targets by default, List does not
            $defaultGap     = ($Mode -eq 'Normal') ? 'Show' : 'None'

            # Resolution
            $EffectiveColorize    = $NoColor.IsPresent ? $false : ($Color.IsPresent ? $true : $defaultColor)
            $EffectiveFiles       = $NoFiles.IsPresent ? $false : ($Files.IsPresent ? $true : $defaultFiles)
            $EffectiveShowHidden  = $Hidden.IsPresent
            $EffectiveShowSystem  = $System.IsPresent
            $EffectiveShowTargets = ($Mode -eq 'List') `
                    ? ($Targets.IsPresent ? $true : ($NoTargets.IsPresent ? $false : $defaultTargets)) `
                    : ($NoTargets.IsPresent ? $false : ($Targets.IsPresent ? $true : $defaultTargets))

            $GapPolicy            = $Gap.IsPresent ? 'Show' : ($NoGap.IsPresent ? 'None' : $defaultGap)
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
    $providerMode = ($Mode -eq 'Tree' -and $Compat.IsPresent) ? 'Win32' : 'PowerShell'

    if ($providerMode -eq 'Win32' -and -not $localIsWindows) {
        throw $uiErrors.Win32WindowsOnly
    }

    $getTreeItemParams = @{
        Path          = $resolvedPath
        Mode          = $Mode
        Depth         = $EffectiveMaxDepth
        ProviderMode  = $providerMode
        GapPolicy     = $GapPolicy
        Include       = $effectiveInclude
        Exclude       = $effectiveExclude
        HideHidden    = -not $EffectiveShowHidden
        HideSystem    = -not $EffectiveShowSystem
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
    $treeCompatQuirk = $Compat.IsPresent -and $script:lastRecordKind -eq 'Directory'
    if (-not $treeCompatQuirk) {
        Write-Output ""
    }
}
