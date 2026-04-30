# Show-Tree\Public\Show-Tree.ps1

#region Style Profile
<#
.SYNOPSIS
    Defines the ANSI color style profile used by Show-Tree.

.DESCRIPTION
    This profile controls:
      • Base colors for files, directories, symlinks, junctions
      • Attribute overlays (Hidden, System, Temporary, etc.)
      • Foreground overrides for specific attribute/type combinations

    The profile is consumed by Get-ItemStyle in Show-TreeInternal.ps1.
#>
$script:StyleProfile = @{
    Base = @{
        File      = "37"
        Directory = "36"
        Symlink   = "37"
        Junction  = "36"
    }
    Attributes = @{
        None              = @{ Attributes = "90" }
        ReadOnly          = @{ Attributes = "3" }
        Hidden            = @{ Attributes = "2" }
        System            = @{
            OverrideForeground = @{
                File      = "31"
                Directory = "35"
            }
        }
        Directory         = @{ Attributes = "" }
        Archive           = @{ Attributes = "" }
        Device            = @{ Attributes = "" }
        Normal            = @{ Attributes = "" }
        Temporary         = @{ Attributes = "7" }
        SparseFile        = @{ Attributes = "7" }
        ReparsePoint      = @{ Attributes = "4" }
        Compressed        = @{ Attributes = "" }
        Offline           = @{ Attributes = "7" }
        NotContentIndexed = @{ Attributes = "" }
        Encrypted         = @{ Attributes = "" }
        IntegrityStream   = @{ Attributes = "" }
        NoScrubData       = @{ Attributes = "" }
    }
}
#endregion

#region Public Entry Point
<#
.SYNOPSIS
    Displays a directory tree in Normal, Tree.com-compatible, or Listing mode.

.DESCRIPTION
    Show-Tree renders directory structures using one of three modes:

      • Normal   - Modern, colorized output with Unicode connectors (default)
      • Tree     - DOS tree.com compatibility mode
      • List     - Indentation-only listing mode

    The active mode is determined by:
      • -Mode Normal|Tree|List
      • -Tree or -List (backward-compatible aliases)
      • Defaulting to Normal when no mode is specified

    After resolving the mode, Show-Tree computes effective settings for:
      • Depth (MaxDepth, Recurse)
      • Colorization (Color, Mono)
      • File visibility (Files, NoFiles)
      • Hidden/system filtering (ShowHidden/HideHidden, ShowSystem/HideSystem)
      • Reparse point targets (ShowTargets/NoTargets)
      • Gap lines (NoGap)
      • ASCII vs Unicode connectors (Ascii)

    Paired switches (e.g., Color/Mono, Files/NoFiles) are mutually exclusive.
    If both halves of a pair are supplied, an error is raised.

    Once effective settings are computed, rendering is delegated to
    Show-TreeInternal, which performs recursion, gap logic, connector selection,
    and formatting.

.PARAMETER Path
    The root path to display. Defaults to the current directory.

.PARAMETER Mode
    Explicitly selects the output mode: Normal, Tree, or Listing.
    Defaults to Normal.

.PARAMETER Tree
    Backward-compatible alias for: -Mode Tree

.PARAMETER List
    Backward-compatible alias for: -Mode Listing

.PARAMETER MaxDepth
    Maximum recursion depth. -1 means unlimited.

.PARAMETER Recurse
    Shortcut for unlimited depth (equivalent to -MaxDepth -1).

.PARAMETER Mono
    Disable color output (Normal and Listing modes).

.PARAMETER Color
    Enable color output. In Tree mode, this matches tree.com behavior.
    In Normal mode, this simply forces color on.

.PARAMETER NoFiles / Files
    Control whether files are included. Files is Tree-only; NoFiles applies to
    Normal and Listing modes.

.PARAMETER HideHidden / ShowHidden
    Control visibility of hidden items.

.PARAMETER HideSystem / ShowSystem
    Control visibility of system items.

.PARAMETER Include
    Glob patterns that explicitly include matching items.
    Exact matches override all other filtering rules.
    Glob matches resurrect items removed by Hidden, System, or Exclude (glob).

.PARAMETER Exclude
    Glob patterns that remove matching items.
    Exact matches override Include (glob).
    Glob matches are overridden by Include (exact or glob).

.PARAMETER NoGap
    Disable gap lines between blocks (Normal and Tree modes).

.PARAMETER NoTargets / ShowTargets
    Control whether reparse point targets are shown.

.PARAMETER Ascii
    Use ASCII connectors instead of Unicode.

.PARAMETER DebugAttributes
    Show attribute debug info for each item.

.PARAMETER Legend
    Display a color legend instead of rendering a tree.

.EXAMPLE
    Show-Tree C:\

.EXAMPLE
    Show-Tree -Tree C:\Windows

.EXAMPLE
    Show-Tree -List -Recurse

.NOTES
    Author: Ryan Beesley
    Version: 1.2.0
    Last Updated: April 2026
#>
function Show-Tree {
    [CmdletBinding()]
    param(
        #
        # MODE SELECTION
        #
        [ValidateSet('Normal','Tree','List')]
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
        [string]$Path = ".",


        #
        # MODE-SPECIFIC SWITCHES
        #

        # Colorization
        [switch]$Color,      # Tree
        [Alias('NoColor')]
        [switch]$Mono,       # Normal/Listing

        # Files
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
        [switch]$NoGap,       # Normal/Tree

        # Depth
        [Alias('Depth')]
        [int]$MaxDepth,
        [switch]$Recurse,

        # ASCII connectors
        [switch]$Ascii,

        # Debugging
        [switch]$DebugAttributes,

        # Show the color legend
        [switch]$Legend
    )

    #
    # Legend mode: no tree rendering
    #
    if ($Legend) {
        Show-TreeLegend
        return
    }

    #
    # Resolve Mode (explicit or implied)
    #
    if ($AsTree)    { $Mode = 'Tree' }
    if ($AsListing) { $Mode = 'List' }

    #
    # Validate paired switches
    #
    if ($Color -and $Mono) {
        throw "Cannot specify both -Color and -Mono."
    }

    if ($Files -and $NoFiles) {
        throw "Cannot specify both -Files and -NoFiles."
    }

    if ($ShowHidden -and $HideHidden) {
        throw "Cannot specify both -ShowHidden and -HideHidden."
    }

    if ($ShowSystem -and $HideSystem) {
        throw "Cannot specify both -ShowSystem and -HideSystem."
    }

    if ($ShowTargets -and $NoTargets) {
        throw "Cannot specify both -ShowTargets and -NoTargets."
    }

    #
    # Resolve the path (with proper error record)
    #
    $Path = Resolve-TreePath -Path $Path -Mode $Mode
    if (-not $Path) { return }

    # Tree Mode: Output should follow `tree.com` output
    if ($Mode -eq 'Tree') {

        # Extract drive letter
        $drive = Split-Path $Path -Qualifier
        $driveName = $drive.TrimEnd(':')

        # 1. Invalid drive → tree.com behavior
        if (-not (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue)) {
            Write-Output "Invalid drive specification"
            return
        }

        # 2. Valid drive → print header
        $nearestExistingParent = Get-NearestExistingParent -Path $Path
        $fileSystemLabel       = Get-VolumeName -Path $nearestExistingParent
        $serialNumber          = Get-VolumeSerialNumber -Path $nearestExistingParent

        Write-Output "Folder PATH listing for volume $fileSystemLabel"
        Write-Output "Volume serial number is $serialNumber"

        Write-Output $Path

        # 3. Invalid path on valid drive → tree.com behavior
        if (-not (Test-Path $Path)) {
            $sub = $Path.Substring(2)  # remove drive letter
            Write-Output "Invalid path - $sub"
            Write-Output "No subfolders exist"
            return
        }
    }

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
            $EffectiveGap         = -not $NoGap.IsPresent
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
            $EffectiveMaxDepth    = $Recurse.IsPresent ? -1 : ($PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : 6)
            $EffectiveColorize    = -not $Mono.IsPresent
            $EffectiveFiles       = -not $NoFiles.IsPresent
            $EffectiveHideHidden  = $HideHidden.IsPresent
            $EffectiveHideSystem  = $HideSystem.IsPresent
            $EffectiveShowTargets = -not $NoTargets.IsPresent
            $EffectiveGap         = -not $NoGap.IsPresent
        }
    }

    if ($Mode -ne 'Tree') {
        # Render root directory name (Normal + Listing modes only)
        $root = Get-Item $Path
        $dir  = [PSCustomObject]@{
            FullName      = $root.FullName
            Name          = $root.Name
            Attributes    = $root.Attributes
            PSIsContainer = $true
        }
        $dir.PSObject.TypeNames.Insert(0, 'System.IO.DirectoryInfo')

        $style = Get-ItemStyle -Item $dir -Colorize:$EffectiveColorize

        if ($DebugAttributes) {
            $styleName = $style.Name
            $attrHex   = ('0x{0:X8}' -f [uint32]$dir.Attributes)
            $attrNames = $dir.Attributes.ToString()
            $debug     = " [$attrHex $attrNames | $styleName]"
        }

        $esc = [char]27
        $colorReset = $EffectiveColorize ? "${esc}[0m" : ""

        Write-Output "$($style.Ansi)$Path${colorReset}${debug}"
    }

    # Initialize gap state machine
    $script:GapState = [PSCustomObject]@{
        LastGapMode = [GapMode]::None
    }

    #
    # Delegate to internal engine
    #
    Show-TreeInternal `
        -Path          $Path `
        -Mode          $Mode `
        -MaxDepth      $EffectiveMaxDepth `
        -Colorize:$EffectiveColorize `
        -IncludeFiles:$EffectiveFiles `
        -HideHidden:$EffectiveHideHidden `
        -HideSystem:$EffectiveHideSystem `
        -ShowTargets:$EffectiveShowTargets `
        -Exclude $Exclude `
        -Include $Include `
        -Gap:$EffectiveGap `
        -Ascii:$Ascii `
        -DebugAttributes:$DebugAttributes

    #
    # Final newline for normal mode root
    #
    if ($Mode -ne 'Tree') {
        Write-Output ""
    }    
}
#endregion

#region Legend
<#
.SYNOPSIS
    Displays a color legend for all base types and attribute overlays.

.DESCRIPTION
    Useful for understanding how Show-Tree applies color to files,
    directories, symlinks, junctions, and attribute combinations.
#>
function Show-TreeLegend {
    param(
        $StyleProfile = $script:StyleProfile
    )

    $esc   = [char]27
    $reset = "${esc}[0m"

    Write-Output ""
    Write-Output "Legend"
    Write-Output "------"
    Write-Output ""

    #
    # Helper to render a sample line
    #
    function Show-Sample {
        param(
            [string]$Name,
            $Item
        )

        $style = Get-ItemStyle -Item $Item -Colorize:$true
        $ansi  = $style.Ansi
        Write-Output ("{0,-18} {1}{2}{3}" -f $Name, $ansi, $Name, $reset)
    }

    #
    # Base types
    #
    Write-Output "Types:"
    Show-Sample "Directory" ([pscustomobject]@{ PSIsContainer = $true;  Attributes = [IO.FileAttributes]::Directory })
    Show-Sample "File"      ([pscustomobject]@{ PSIsContainer = $false; Attributes = [IO.FileAttributes]::Archive })
    Show-Sample "Symlink"   ([pscustomobject]@{ PSIsContainer = $false; Attributes = [IO.FileAttributes]::ReparsePoint })
    Show-Sample "Junction"  ([pscustomobject]@{ PSIsContainer = $true;  Attributes = [IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint })
    Write-Output ""

    #
    # Attribute overlays
    #
    Write-Output "Attributes:"
    foreach ($attr in $StyleProfile.Attributes.Keys) {
        $flag = [IO.FileAttributes]::$attr
        $item = [pscustomobject]@{
            PSIsContainer = $false
            Attributes    = $flag
        }
        Show-Sample $attr $item
    }

    Write-Output ""
}
#endregion
