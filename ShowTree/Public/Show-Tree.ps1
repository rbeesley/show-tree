<#
.SYNOPSIS
    Displays the directory structure of a path in multiple formats.

.DESCRIPTION
    Show-Tree provides three display modes:

      • Normal mode (default)
      • Tree mode (-Tree) — compatible with DOS tree.com
      • Listing mode (-List) — compact, indentation-only output

    Each mode has its own defaults for depth, color, file inclusion, and layout,
    all of which can be overridden with parameters.

.PARAMETER Path
    The root path to display. Defaults to the current directory.

.PARAMETER Tree
    Enables DOS tree.com compatibility mode.
    This mode changes defaults to match tree.com behavior:

        -MaxDepth -1     (unlimited)
        -Mono            (no color)
        -NoFiles         (directories only)

    These defaults may be overridden with -MaxDepth, -Color, or -Files.

.PARAMETER Listing
    Enables compact listing mode.
    This mode uses indentation only (no graphical connectors) and is ideal for
    piping, grepping, exporting, or scanning large directory structures.

    Defaults in Listing mode:

        -MaxDepth -1     (unlimited)
        -Color           (unless -Mono is used)
        -Files           (unless -NoFiles is used)
        -NoGap           (always)

.PARAMETER List
    Alias for -Listing

.PARAMETER MaxDepth
    Maximum recursion depth. A value of -1 removes the depth limit.

    Defaults:
        Normal mode:   6
        Tree mode:    -1
        Listing mode: -1

    If -Recurse is used, MaxDepth is forced to -1.

.PARAMETER Depth
    Alias for -MaxDepth.

.PARAMETER Recurse
    Shortcut for unlimited depth. Equivalent to -MaxDepth -1.

.PARAMETER Mono
    Disables color output.

    Defaults:
        Normal mode:  color enabled unless -Mono is used
        Tree mode:    mono enabled unless -Color is used
        Listing mode: color enabled unless -Mono is used

.PARAMETER Color
    Enables color output in Tree mode (overrides the default -Mono).

.PARAMETER NoFiles
    Hides files from the output.

    Defaults:
        Normal mode:  files shown unless -NoFiles is used
        Tree mode:    files hidden unless -Files is used
        Listing mode: files shown unless -NoFiles is used

.PARAMETER Files
    Shows files in Tree mode (overrides the default -NoFiles).

.PARAMETER NoGap
    Removes spacing between file and directory sections.
    Useful for compact output in Normal or Tree mode.

.PARAMETER Ascii
    Uses ASCII characters instead of extended Unicode connectors.

.EXAMPLE
    PS> .\Show-Tree.ps1 \
    Displays the directory tree of the current drive with default settings.

.EXAMPLE
    PS> .\Show-Tree.ps1 C:\ -NoFiles
    Displays only directories under C:\ using Normal mode.

.EXAMPLE
    PS> .\Show-Tree.ps1 -Tree C:\ | Out-Host -Paging
    Displays a tree.com-style listing of C:\ with paging.

.EXAMPLE
    PS> .\Show-Tree.ps1 -List C:\ > listing.txt
    Writes a compact, indentation-only listing to a file.

.LINK
    https://learn.microsoft.com/windows-server/administration/windows-commands/tree

.NOTES
    Author: Ryan Beesley
    Version: 1.0.1
    Last Updated: April 2026

    This script is a modern reimplementation of the classic DOS tree.com
    command, with additional modes for graphical Unicode output and compact
    listing output.    
#>

function Show-Tree {
    [CmdletBinding(DefaultParameterSetName = 'Normal')]
    param (
        [Parameter(Position = 0, ParameterSetName='Normal')]
        [Parameter(Position = 0, ParameterSetName='Tree')]
        [Parameter(Position = 0, ParameterSetName='Listing')]
        # Root path.
        [string]$Path = ".",
        # Simulate DOS tree.com command.
        [Parameter(ParameterSetName='Tree')]
        [switch]$Tree,
        # No "graphical" output, just directories and files as a listing.
        [Parameter(ParameterSetName='Listing')]
        [Alias("Listing")]
        [switch]$List,
        # Maximum depth to recurse into. Normal mode: 6, Tree mode: -1.
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Tree')]
        [Parameter(ParameterSetName='Listing')]
        [Alias("Depth")]
        [int]$MaxDepth = $null,
        # Set maximum depth to recurse into, to the maximum depth.
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Tree')]
        [Parameter(ParameterSetName='Listing')]
        [switch]$Recurse,
        # Normal mode: color by default.
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Listing')]
        [switch]$Mono,
        # Tree mode: mono by default, but allow -Color to override
        [Parameter(ParameterSetName='Tree')]
        [switch]$Color,    
        # Don't show files in listing. Normal mode: show files.
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Listing')]
        [switch]$NoFiles,
        # Show files in listing. Tree mode: don't show files.
        [Parameter(ParameterSetName='Tree')]
        [switch]$Files,
        # Pack output compressed for space over readability.
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Tree')]
        [switch]$NoGap,
        # Use ASCII instead of extended characters.
        [Parameter(ParameterSetName='Normal')]
        [Parameter(ParameterSetName='Tree')]
        [switch]$Ascii
    )

    if ($PSCmdlet.ParameterSetName -eq 'Tree') {
        $EffectiveMaxDepth = $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : -1
        $EffectiveColorize = $Color.IsPresent
        $EffectiveFiles = $Files.IsPresent
        $EffectiveGap = -not $NoGap
    } elseif ($PSCmdlet.ParameterSetName -eq 'Listing') {
        $EffectiveMaxDepth = $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : -1
        $EffectiveColorize = -not $Mono
        $EffectiveFiles = -not $NoFiles
        $EffectiveGap = $false
    } else {
        $EffectiveMaxDepth = $Recurse.IsPresent ? -1 : $PSBoundParameters.ContainsKey('MaxDepth') ? $MaxDepth : 6
        $EffectiveColorize = -not $Mono
        $EffectiveFiles = -not $NoFiles
        $EffectiveGap = -not $NoGap
    }

    # Resolve relative paths to absolute literal paths
    try {
        $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        $Path = $resolved.ProviderPath
    }
    catch {
        # Reproduce Resolve-Path style error
        $msg = "Cannot find path '$Path' because it does not exist."

        $exception = New-Object System.Management.Automation.ItemNotFoundException $msg

        $category = [System.Management.Automation.ErrorCategory]::ObjectNotFound

        $errorRecord = New-Object System.Management.Automation.ErrorRecord `
            $exception,
            'ItemNotFound',
            $category,
            $Path

        $PSCmdlet.WriteError($errorRecord)
        return
    }

    $params = @{
        Path = $Path
        Tree = $Tree
        List = $List
        MaxDepth = $EffectiveMaxDepth
        Colorize = $EffectiveColorize
        IncludeFiles = $EffectiveFiles
        Gap = $EffectiveGap
        Ascii = $Ascii
    }
    Show-TreeInternal @params
}