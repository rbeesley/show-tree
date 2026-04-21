#region Style Profile
<#
.SYNOPSIS
    Defines the ANSI color style profile used by Show‑Tree.

.DESCRIPTION
    This profile controls:
      • Base colors for files, directories, symlinks, junctions
      • Attribute overlays (Hidden, System, Temporary, etc.)
      • Foreground overrides for specific attribute/type combinations

    The profile is consumed by Get-ItemStyle in Show‑TreeInternal.ps1.
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
    Displays a directory tree in graphical, tree.com, or listing mode.

.DESCRIPTION
    Show‑Tree is the public entry point for the module. It determines:
      • Which mode is active (Normal, Tree, Listing)
      • Effective defaults for depth, color, file inclusion, and gaps
      • Whether to show hidden/system items
      • Whether to show reparse point targets
      • Whether to use ASCII or Unicode connectors

    After computing effective settings, it delegates all rendering to
    Show‑TreeInternal, which performs recursion, gap logic, and formatting.

.PARAMETER Path
    The root path to display. Defaults to the current directory.

.PARAMETER Tree
    Enables DOS tree.com compatibility mode.

.PARAMETER List
    Enables indentation‑only listing mode.

.PARAMETER MaxDepth
    Maximum recursion depth. -1 means unlimited.

.PARAMETER Recurse
    Shortcut for unlimited depth.

.PARAMETER Mono
    Disable color output.

.PARAMETER Color
    Enable color output in Tree mode.

.PARAMETER NoFiles / Files
    Control whether files are included.

.PARAMETER HideHidden / ShowHidden
    Control visibility of hidden items.

.PARAMETER HideSystem / ShowSystem
    Control visibility of system items.

.PARAMETER NoGap
    Disable gap lines between blocks.

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
    Version: 1.1.0
    Last Updated: April 2026
#>
function Show-Tree {
    [CmdletBinding(DefaultParameterSetName = 'Normal')]
    param (
        # Root path to display
        [Parameter(Position = 0, ParameterSetName='Normal')]
        [Parameter(Position = 0, ParameterSetName='Tree')]
        [Parameter(Position = 0, ParameterSetName='Listing')]
        [string]$Path = ".",

        # Tree.com compatibility mode
        [Parameter(ParameterSetName='Tree')]
        [switch]$Tree,

        # Listing mode (indentation only)
        [Parameter(ParameterSetName='Listing')]
        [Alias("Listing")]
        [switch]$List,

        # Maximum recursion depth
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Tree')]
        [Parameter(ParameterSetName='Listing')]
        [Alias("Depth")]
        [int]$MaxDepth = $null,

        # Unlimited depth
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Tree')]
        [Parameter(ParameterSetName='Listing')]
        [switch]$Recurse,

        # Disable color
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Listing')]
        [Alias("NoColor")]
        [switch]$Mono,

        # Enable color in Tree mode
        [Parameter(ParameterSetName='Tree')]
        [switch]$Color,

        # Hide files
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Listing')]
        [switch]$NoFiles,

        # Show files in Tree mode
        [Parameter(ParameterSetName='Tree')]
        [switch]$Files,

        # Hide hidden items
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Listing')]
        [switch]$HideHidden,

        # Show hidden items in Tree mode
        [Parameter(ParameterSetName='Tree')]
        [switch]$ShowHidden,

        # Hide system items
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Listing')]
        [switch]$HideSystem,

        # Show system items in Tree mode
        [Parameter(ParameterSetName='Tree')]
        [switch]$ShowSystem,

        # Disable gap lines
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Tree')]
        [switch]$NoGap,

        # Disable reparse point targets
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Tree')]
        [switch]$NoTargets,

        # Show reparse point targets in Listing mode
        [Parameter(ParameterSetName='Listing')]
        [switch]$ShowTargets,

        # ASCII connectors
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Tree')]
        [switch]$Ascii,

        # Show attribute debug info
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Tree')]
        [Parameter(ParameterSetName='Listing')]
        [switch]$DebugAttributes,

        # Show color legend
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
    # Compute effective mode settings
    #
    if ($PSCmdlet.ParameterSetName -eq 'Tree') {
        $EffectiveMaxDepth    = $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : -1
        $EffectiveColorize    = $Color.IsPresent
        $EffectiveFiles       = $Files.IsPresent
        $EffectiveHideHidden  = -not $ShowHidden.IsPresent
        $EffectiveHideSystem  = -not $ShowSystem.IsPresent
        $EffectiveShowTargets = -not $NoTargets.IsPresent
        $EffectiveGap         = -not $NoGap
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Listing') {
        $EffectiveMaxDepth    = $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : -1
        $EffectiveColorize    = -not $Mono
        $EffectiveFiles       = -not $NoFiles
        $EffectiveHideHidden  = $HideHidden.IsPresent
        $EffectiveHideSystem  = $HideSystem.IsPresent
        $EffectiveShowTargets = $ShowTargets.IsPresent
        $EffectiveGap         = $false
    }
    else {
        # Normal mode
        $EffectiveMaxDepth    = $Recurse.IsPresent ? -1 : ($PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : 6)
        $EffectiveColorize    = -not $Mono
        $EffectiveFiles       = -not $NoFiles
        $EffectiveHideHidden  = $HideHidden.IsPresent
        $EffectiveHideSystem  = $HideSystem.IsPresent
        $EffectiveShowTargets = -not $NoTargets.IsPresent
        $EffectiveGap         = -not $NoGap
    }

    #
    # Resolve the path (with proper error record)
    #
    try {
        $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        $Path = $resolved.ProviderPath
    }
    catch {
        $msg = "Cannot find path '$Path' because it does not exist."
        $exception = New-Object System.Management.Automation.ItemNotFoundException $msg
        $category  = [System.Management.Automation.ErrorCategory]::ObjectNotFound

        $errorRecord = New-Object System.Management.Automation.ErrorRecord `
            $exception,
            'ItemNotFound',
            $category,
            $Path

        $PSCmdlet.WriteError($errorRecord)
        return
    }

    #
    # Delegate to internal engine
    #
    Show-TreeInternal `
        -Path          $Path `
        -Tree:$Tree `
        -List:$List `
        -MaxDepth      $EffectiveMaxDepth `
        -Colorize:$EffectiveColorize `
        -IncludeFiles:$EffectiveFiles `
        -HideHidden:$EffectiveHideHidden `
        -HideSystem:$EffectiveHideSystem `
        -ShowTargets:$EffectiveShowTargets `
        -Gap:$EffectiveGap `
        -Ascii:$Ascii `
        -DebugAttributes:$DebugAttributes
}
#endregion

#region Legend Rendering
<#
.SYNOPSIS
    Displays a color legend for all base types and attribute overlays.

.DESCRIPTION
    Useful for understanding how Show‑Tree applies color to files,
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
