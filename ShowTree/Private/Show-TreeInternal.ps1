# Show-Tree\Private\Show-TreeInternal.ps1

#region Entry Point
<#
.SYNOPSIS
    Core recursive engine for Show-Tree.

.DESCRIPTION
    This function renders a directory tree using graphical connectors,
    optional color, optional file inclusion, and optional gap logic.
    It is called once from Show-Tree.ps1 and then recursively by itself.

    Responsibilities:
      • Normalize and validate the root path
      • Initialize gap state
      • Enumerate directories/files (raw Win32 or PowerShell)
      • Applies stable-order filtering using Get-FilteredTreeItems
        (Hidden/System/Include/Exclude with exact/glob precedence)
      • Render files, directories, and gap lines
      • Manage recursion depth and prefix construction
      • Maintain gap-mode state machine (Internal, Tail, Sibling)

    This function is internal-only and not exported.
#>
enum GapMode {
    None
    Internal
    Tail
    Sibling
}

function Show-TreeInternal {
    [CmdletBinding()]
    param (
        # Absolute or relative path to render
        [string]$Path,

        # Tree.com compatibility mode
        [switch]$Tree,

        # Listing mode (indentation only)
        [switch]$List,

        # Maximum recursion depth (-1 = unlimited)
        [int]$MaxDepth = -1,

        # Enable color output
        [switch]$Colorize,

        # Include files in output
        [switch]$IncludeFiles,

        # Hide hidden items
        [switch]$HideHidden,

        # Hide system items
        [switch]$HideSystem,

        # Show reparse point targets
        [switch]$ShowTargets,

        # Glob-based include/exclude filtering
        [string[]]$Exclude,
        [string[]]$Include,

        # Enable gap logic (blank lines between blocks)
        [switch]$Gap,

        # Use ASCII connectors instead of Unicode
        [switch]$Ascii,

        # Show attribute debug info
        [switch]$DebugAttributes,

        # Current recursion depth (internal)
        [int]$CurrentDepth = 0,

        # Prefix string built from parent connectors
        [string]$Prefix = "",

        # Whether the parent directory was the last sibling
        [bool]$IsLastParent = $false
    )

    #
    # Depth cap enforcement
    #
    if ($MaxDepth -ne -1 -and $CurrentDepth -ge $MaxDepth) {
        return
    }

    #
    # Directory enumeration
    #
    if ($Tree) {
        # Raw Win32 enumeration for Tree.com compatibility
        $raw   = Get-RawDirectoryEntries -Path $Path
        $files = $IncludeFiles ? $raw.Files : @()
        $dirs  = $raw.Directories
    }
    else {
        # Standard PowerShell enumeration
        $files = $IncludeFiles ? (Get-ChildItem -Path $Path -File -Force -ErrorAction SilentlyContinue) : @()
        $dirs  = Get-ChildItem -Path $Path -Directory -Force -ErrorAction SilentlyContinue
    }

    #
    # Filtering
    #
    $dirs  = Get-FilteredTreeItems -Items $dirs  -Include $Include -Exclude $Exclude -HideHidden:$HideHidden -HideSystem:$HideSystem
    $files = Get-FilteredTreeItems -Items $files -Include $Include -Exclude $Exclude -HideHidden:$HideHidden -HideSystem:$HideSystem

    $fileCount = $files.Count
    $dirCount  = $dirs.Count

    # Tree.com: suppress file connectors when no subdirectories exist
    $noSpan = $Tree -and $dirCount -eq 0

    #
    # FILE RENDERING
    #
    for ($j = 0; $j -lt $fileCount; $j++) {
        $file       = $files[$j]
        $isLastFile = ($j -eq $fileCount - 1) -and ($dirCount -eq 0)

        Write-TreeItem `
            -Item          $file `
            -Type          File `
            -Prefix        $Prefix `
            -IsLast        $isLastFile `
            -Tree:$Tree `
            -List:$List `
            -Ascii:$Ascii `
            -Colorize:$Colorize `
            -ShowTargets:$ShowTargets `
            -DebugAttributes:$DebugAttributes `
            -Recurse:$false `
            -NoSpan        $noSpan `
            -MaxDepth      $MaxDepth `
            -CurrentDepth  $CurrentDepth `
            -IncludeFiles:$IncludeFiles `
            -Include       $Include `
            -Exclude       $Exclude `
            -Gap:$Gap `
            -HideHidden:$HideHidden `
            -HideSystem:$HideSystem
    }

    #
    # INTERNAL GAP (files → directories)
    #

    # Precompute ANSI sequences
    $esc        = [char]27
    $colorReset = $Colorize ? "${esc}[0m"  : ""
    $colorGap   = $Colorize ? "${esc}[90m" : ""

    # Precompute gap connector
    $gapConnector = Get-Connector -Type Gap -Tree:$Tree -List:$List -Ascii:$Ascii

    if ($Gap -and
        $script:GapState.LastGapMode -eq [GapMode]::None -and
        $IncludeFiles -and
        $fileCount -gt 0) {

        if ($dirCount -gt 0) {
            # Files + directories → connector gap
            Write-Gap $colorGap $Prefix $gapConnector $colorReset ([GapMode]::Internal)
        }
        else {
            # Files only → tail gap
            if ($Tree -or (-not $IsLastParent)) {
                Write-Gap $colorGap $Prefix $null $colorReset ([GapMode]::Tail)
            }
        }
    }

    #
    # DIRECTORY RENDERING
    #
    for ($i = 0; $i -lt $dirCount; $i++) {
        $dir       = $dirs[$i]
        $isLastDir = ($i -eq $dirCount - 1)

        Write-TreeItem `
            -Item           $dir `
            -Type           Directory `
            -Prefix         $Prefix `
            -IsLast         $isLastDir `
            -Tree:$Tree `
            -List:$List `
            -Ascii:$Ascii `
            -Colorize:$Colorize `
            -ShowTargets:$ShowTargets `
            -DebugAttributes:$DebugAttributes `
            -Recurse `
            -NoSpan         $false `
            -MaxDepth       $MaxDepth `
            -CurrentDepth   $CurrentDepth `
            -IncludeFiles:$IncludeFiles `
            -Include       $Include `
            -Exclude       $Exclude `
            -Gap:$Gap `
            -HideHidden:$HideHidden `
            -HideSystem:$HideSystem

        #
        # SIBLING / COUSIN GAP LOGIC
        #
        if ($Gap -and $i -lt $dirCount - 1) {

            # Tail gap suppresses immediate sibling gap
            if ($script:GapState.LastGapMode -eq [GapMode]::Tail) {
                $script:GapState.LastGapMode = [GapMode]::None
                continue
            }

            # Prevent consecutive gaps
            if ($script:GapState.LastGapMode -ne [GapMode]::None) {
                continue
            }

            # Normal mode: only if left sibling has visible children
            if (-not $Tree) {
                if (Test-HasChildrenForGap -Dir $dirs[$i] -CurrentDepth $CurrentDepth -MaxDepth $MaxDepth) {
                    Write-Gap $colorGap $Prefix $gapConnector $colorReset ([GapMode]::Sibling)
                }
            }
        }
    }
}
#endregion

#region Filtering
<#
.SYNOPSIS
    Returns a filtered subset of tree items using Hidden/System attributes and
    PowerShell-style Include/Exclude glob patterns while preserving original order.

.DESCRIPTION
    Get-FilteredTreeItems applies all Show-Tree filtering rules to a collection of
    filesystem items and returns the resulting subset in stable, original order.

    Filtering supports:
    • Hidden and System attribute removal (-HideHidden, -HideSystem)
    • PowerShell-style glob patterns for -Include and -Exclude
    • Exact-match and glob-match precedence rules
    • Include selectively overriding Exclude, Hidden, and System
    • Exclude exact-match patterns taking precedence over globbed Include patterns

    The function evaluates each item against four independent removal sets:
    Hidden, System, ExcludedExact, and ExcludedGlob. It also computes two inclusion
    sets: IncludedExact and IncludedGlob.

    Final item selection follows these rules:

    1. Exact Include always wins.
    2. Exact Exclude always wins, even if the item matches a broader Include glob.
    3. Glob Include resurrects items removed by Hidden, System, or glob Exclude.
    4. Hidden and System remove items unless resurrected by Include.
    5. Glob Exclude removes items unless resurrected by Include.
    6. Items not affected by any rule are kept.

    This produces intuitive, PowerShell-like filtering behavior while maintaining
    the original enumeration order required for correct tree rendering.

.PARAMETER Items
    The collection of file or directory objects to filter. The function preserves
    the original ordering of this list.
#>
function Get-FilteredTreeItems {
    param(
        [array]$Items,

        [string[]]$Include,
        [string[]]$Exclude,

        [switch]$HideHidden,
        [switch]$HideSystem
    )

    if (-not $Items) {
        return @()
    }

    #
    # Capture original order
    #
    $orig = $Items

    #
    # Hidden/System sets
    #
    $hidden = $HideHidden ? ($orig | Where-Object { $_.Attributes -band [IO.FileAttributes]::Hidden }) : @()
    $system = $HideSystem ? ($orig | Where-Object { $_.Attributes -band [IO.FileAttributes]::System }) : @()

    #
    # Exclude sets (exact + glob)
    #
    $excludedExact = @()
    $excludedGlob  = @()

    if ($Exclude) {
        foreach ($item in $orig) {
            $name = $item.Name
            if ($Exclude -contains $name) { $excludedExact += $item; continue }
            if ($Exclude | Where-Object { $name -like $_ }) { $excludedGlob += $item }
        }
    }

    #
    # Include sets (exact + glob)
    #
    $includedExact = @()
    $includedGlob  = @()

    if ($Include) {
        foreach ($item in $orig) {
            $name = $item.Name
            if ($Include -contains $name) { $includedExact += $item; continue }
            if ($Include | Where-Object { $name -like $_ }) { $includedGlob += $item }
        }
    }

    #
    # Final filtering (stable order)
    #
    $final = foreach ($item in $orig) {
        $name = $item.Name

        $isHidden        = $hidden        -contains $item
        $isSystem        = $system        -contains $item
        $isExcludedExact = $excludedExact -contains $item
        $isExcludedGlob  = $excludedGlob  -contains $item
        $isIncludedExact = $includedExact -contains $item
        $isIncludedGlob  = $includedGlob  -contains $item

        #
        # Decision logic
        #
        if ($isIncludedExact) { $item; continue }   # exact include wins
        if ($isExcludedExact) { continue }          # exact exclude wins
        if ($isIncludedGlob)  { $item; continue }   # glob include resurrects
        if ($isHidden)        { continue }          # hidden removes unless included
        if ($isSystem)        { continue }          # system removes unless included
        if ($isExcludedGlob)  { continue }          # glob exclude removes unless included

        $item
    }

    return $final
}
#endregion

#region Rendering (TreeItem, Gap)
<#
.SYNOPSIS
    Renders a single file or directory entry.

.DESCRIPTION
    Handles:
      • Connector selection
      • Style/color application
      • Reparse target display
      • Attribute debug output
      • Recursion into subdirectories
      • Gap-state reset
#>
function Write-TreeItem {
    param(
        [Parameter(Mandatory)]
        $Item,

        [Parameter(Mandatory)]
        [ValidateSet('File','Directory')]
        [string]$Type,

        # Prefix inherited from parent
        [string]$Prefix = "",

        # Whether this item is the last sibling
        [bool]$IsLast,

        # Mode switches
        [switch]$Tree,
        [switch]$List,
        [switch]$Ascii,
        [switch]$Colorize,
        [switch]$ShowTargets,
        [switch]$DebugAttributes,
        [switch]$Recurse,

        # Whether to suppress file connector span
        [bool]$NoSpan = $false,

        # Recursion state
        [int]$MaxDepth,
        [int]$CurrentDepth,

        # Additional flags
        [switch]$IncludeFiles,
        [string[]]$Exclude,
        [string[]]$Include,        
        [switch]$Gap,
        [switch]$HideHidden,
        [switch]$HideSystem
    )

    # Compute connector for this item
    $connector = Get-Connector `
        -Type   $Type `
        -Tree:$Tree `
        -List:$List `
        -Ascii:$Ascii `
        -IsLast $IsLast `
        -NoSpan $NoSpan

    # Compute style
    $style = Get-ItemStyle -Item $Item -Colorize:$Colorize

    #
    # Reparse target resolution
    #
    $target = $null
    if ($ShowTargets -and ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        $info = Get-Item -LiteralPath $Item.FullName -Force -ErrorAction SilentlyContinue
        if ($info -and $info.PSObject.Properties.Match('Target')) {
            $target = $info.Target
        }
    }

    #
    # Output formatting
    #
    $esc   = [char]27
    $reset = $Colorize ? "${esc}[0m"  : ""
    $dim   = $Colorize ? "${esc}[90m" : ""

    $targetText = $target ? " ${dim}->${reset} $target" : ""

    # Optional attribute debug
    $debug = ""
    if ($DebugAttributes) {
        $styleName = $style.Name
        $attrHex   = ('0x{0:X8}' -f [uint32]$Item.Attributes)
        $attrNames = $Item.Attributes.ToString()
        $debug     = " [$attrHex $attrNames | $styleName]"
    }

    Write-Output "${dim}${Prefix}${dim}${connector}$($style.Ansi)$($Item.Name)$reset$targetText$debug"

    #
    # Reset gap state unless tail gap was printed
    #
    if ($script:GapState.LastGapMode -ne [GapMode]::Tail) {
        $script:GapState.LastGapMode = [GapMode]::None
    }

    #
    # Recursion into subdirectories
    #
    if ($Recurse -and
        $Type -eq 'Directory' -and
        -not ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {

        # Build next-level prefix
        $newPrefix = $Prefix + (Get-Connector `
            -Type   Prefix `
            -Tree:$Tree `
            -List:$List `
            -Ascii:$Ascii `
            -IsLast $IsLast)

        # Recurse
        Show-TreeInternal `
            -Path          $Item.FullName `
            -Tree:$Tree `
            -List:$List `
            -MaxDepth      $MaxDepth `
            -Colorize:$Colorize `
            -IncludeFiles:$IncludeFiles `
            -HideHidden:$HideHidden `
            -HideSystem:$HideSystem `
            -ShowTargets:$ShowTargets `
            -Exclude      $Exclude `
            -Include      $Include `
            -Gap:$Gap `
            -Ascii:$Ascii `
            -DebugAttributes:$DebugAttributes `
            -CurrentDepth  ($CurrentDepth + 1) `
            -Prefix        $newPrefix `
            -IsLastParent  $IsLast
    }

    #
    # Reset gap state again after recursion
    #
    if ($script:GapState.LastGapMode -ne [GapMode]::Tail) {
        $script:GapState.LastGapMode = [GapMode]::None
    }
}

<#
.SYNOPSIS
    Writes a gap line between blocks.

.DESCRIPTION
    Handles Internal, Tail, and Sibling gap modes.
    Updates the global gap-state machine.
#>
function Write-Gap {
    param(
        $colorGap,
        $Prefix,
        $GapConnector,
        $colorReset,
        [GapMode]$Mode
    )

    $connector = $GapConnector ? $GapConnector : ""
    Write-Output "${colorGap}${Prefix}${connector}${colorReset}"
    $script:GapState.LastGapMode = $Mode
}
#endregion

#region Gap Logic Helpers
<#
.SYNOPSIS
    Determines whether a directory has visible children.

.DESCRIPTION
    Used to decide whether to print a sibling/cousin gap.
    Respects MaxDepth and treats reparse points as leaf nodes.
#>
function Test-HasChildrenForGap {
    param(
        $Dir,
        [int]$CurrentDepth,
        [int]$MaxDepth
    )

    if (Test-IsReparsePoint $Dir) {
        return $false
    }

    # Depth cap: treat as empty if recursion would stop here
    if ($MaxDepth -ne -1 -and $CurrentDepth + 1 -ge $MaxDepth) {
        return $false
    }

    $children = Get-ChildItem -LiteralPath $Dir.FullName -Force -ErrorAction SilentlyContinue
    return $children.Count -gt 0
}

<#
.SYNOPSIS
    Checks whether an item is a reparse point.

.DESCRIPTION
    Reparse points (symlinks/junctions) are treated as leaf nodes
    for recursion and gap logic.
#>
function Test-IsReparsePoint {
    param($Item)
    [bool]($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}
#endregion

#region Connector Rendering
<#
.SYNOPSIS
    Returns the connector string for a given item type.

.DESCRIPTION
    Handles:
      • Tree.com ASCII mode
      • Unicode graphical mode
      • Prefix vs File vs Directory vs Gap
      • Last-sibling logic
      • NoSpan suppression for Tree.com file connectors
#>
function Get-Connector {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('File','Directory','Gap','Prefix')]
        [string]$Type,

        [switch]$Tree,
        [switch]$List,
        [switch]$Ascii,

        [bool]$IsLast = $false,
        [bool]$NoSpan = $false
    )

    #
    # Listing mode: indentation only
    #
    if ($List) {
        return ' '
    }

    #
    # Tree.com compatibility mode
    #
    if ($Tree) {
        if ($Type -eq 'File' -and $NoSpan) {
            return '    '
        }

        switch ($Type) {
            'File'      { return $Ascii ? '|   '  : '│   ' }
            'Directory' {
                if ($IsLast) { return $Ascii ? '\---' : '└───' }
                else         { return $Ascii ? '+---' : '├───' }
            }
            'Gap'       { return $Ascii ? '|'    : '│' }
            'Prefix'    {
                if ($IsLast) { return '    ' }
                else         { return $Ascii ? '|   ' : '│   ' }
            }
        }
    }

    #
    # Graphical Unicode mode (Show-Tree default)
    #
    switch ($Type) {
        'File' {
            if ($IsLast) { return $Ascii ? '\-- ' : '╙── ' }
            else         { return $Ascii ? '+-- ' : '╟── ' }
        }

        'Directory' {
            if ($IsLast) { return $Ascii ? '\== ' : '╚══ ' }
            else         { return $Ascii ? '+== ' : '╠══ ' }
        }

        'Gap' {
            return $Ascii ? '|' : '║'
        }

        'Prefix' {
            if ($IsLast) { return '    ' }
            else         { return $Ascii ? '|   ' : '║   ' }
        }
    }
}
#endregion

#region Style Rendering
<#
.SYNOPSIS
    Computes the ANSI style for a file or directory.

.DESCRIPTION
    Applies:
      • Base style (directory/file/symlink/junction)
      • Attribute overlays (hidden, system, temporary, etc.)
      • Foreground overrides
      • Combined ANSI escape sequence

    Returns an object:
      @{ Name = "..."; Ansi = "..."; }
#>
function Get-ItemStyle {
    param(
        $Item,
        $Colorize,
        $StyleProfile = $script:StyleProfile
    )

    $esc = [char]27

    $isDir     = $Item.PSIsContainer
    $attrs     = $Item.Attributes
    $isReparse = [bool]($attrs -band [IO.FileAttributes]::ReparsePoint)

    #
    # Determine base style
    #
    if ($isReparse -and $isDir) {
        $styleName = "Junction"
        $base      = $StyleProfile.Base.Junction
    }
    elseif ($isReparse -and -not $isDir) {
        $styleName = "Symlink"
        $base      = $StyleProfile.Base.File
    }
    elseif ($isDir) {
        $styleName = "Directory"
        $base      = $StyleProfile.Base.Directory
    }
    else {
        $styleName = "File"
        $base      = $StyleProfile.Base.File
    }

    #
    # No color mode
    #
    if (-not $Colorize) {
        return [PSCustomObject]@{
            Name = $styleName
            Ansi = ""
        }
    }

    #
    # Parse base style codes
    #
    $codes = @() + ($base -split ';' | Where-Object { $_ -ne '' })

    # Extract foreground codes (30–37, 90–97)
    $fg    = @() + ($codes | Where-Object { $_ -match '^(3[0-7]|9[0-7])$' })
    $codes = @() + ($codes | Where-Object { $_ -notmatch '^(3[0-7]|9[0-7])$' })

    #
    # Apply attribute overlays
    #
    foreach ($flag in Get-SetFileAttributes $attrs) {
        $flagName = $flag.ToString()

        if ($StyleProfile.Attributes.ContainsKey($flagName)) {
            $overlay = $StyleProfile.Attributes[$flagName]

            # Add overlay attributes
            if ($overlay.Attributes) {
                $codes += ($overlay.Attributes -split ';')
            }

            # Foreground override
            if ($overlay.OverrideForeground) {
                if ($overlay.OverrideForeground -is [string]) {
                    $fg = $overlay.OverrideForeground
                }
                elseif ($overlay.OverrideForeground.ContainsKey($styleName)) {
                    $fg = $overlay.OverrideForeground[$styleName]
                }
            }
        }
    }

    #
    # Build final ANSI sequence
    #
    $final = @()
    if ($fg) { $final += $fg }
    $final += $codes

    $ansi = "${esc}[$($final -join ';')m"

    [PSCustomObject]@{
        Name = $styleName
        Ansi = $ansi
    }
}
#endregion

#region Path Utilities
<#
.SYNOPSIS
    Enumerates all set file attributes on an item.

.DESCRIPTION
    Used by Get-ItemStyle to apply attribute overlays.
#>
function Get-SetFileAttributes {
    param([IO.FileAttributes]$Attributes)

    foreach ($flag in [System.Enum]::GetValues([IO.FileAttributes])) {
        if ($Attributes -band $flag) {
            $flag
        }
    }
}

<#
.SYNOPSIS
    Normalizes a path to match actual filesystem casing.

.DESCRIPTION
    Walks each segment and resolves its real casing using Get-ChildItem.
    Ensures consistent display even when user input is lowercase/mixed.
#>
function Get-NormalizedPath {
    param([string]$Path = ".")

    $absPath = [System.IO.Path]::GetFullPath($Path)

    # Trim trailing slash unless root
    if ($absPath.Length -gt 3 -and $absPath.EndsWith("\")) {
        $absPath = $absPath.TrimEnd('\')
    }

    $segments   = $absPath -split '\\'
    $normalized = @()
    $current    = $segments[0] + "\"

    $normalized += $segments[0]

    for ($i = 1; $i -lt $segments.Count; $i++) {
        $segment = $segments[$i]

        try {
            $entries = Get-ChildItem -LiteralPath $current -ErrorAction Stop | Select-Object -ExpandProperty Name
            $match   = $entries | Where-Object { $_.ToLower() -eq $segment.ToLower() }

            if ($match) {
                $normalized += $match
                $current     = Join-Path $current $match
            }
            else {
                $normalized += $segment
                $current     = Join-Path $current $segment
            }
        }
        catch {
            # Parent doesn't exist — keep original casing
            $normalized += $segment
            $current     = Join-Path $current $segment -ErrorAction Stop
        }
    }

    ($normalized -join '\')
}

<#
.SYNOPSIS
    Finds the nearest existing parent directory.

.DESCRIPTION
    Used for Tree.com header generation when the target path
    does not fully exist.
#>
function Get-NearestExistingParent {
    param([string]$Path)

    $current = [System.IO.Path]::GetFullPath($Path)

    while (-not (Test-Path $current)) {
        $parent = [System.IO.Directory]::GetParent($current)
        if ($null -eq $parent) {
            return $null
        }
        $current = $parent.FullName
    }

    $current
}

<#
.SYNOPSIS
    Returns the filesystem label for a drive.

.DESCRIPTION
    Used only in Tree.com compatibility mode.
#>
function Get-VolumeName {
    param([string]$Path = ".")

    $driveLetter = (Get-Item $Path).PSDrive.Name
    $volume      = Get-Volume -DriveLetter $driveLetter
    $volume.FileSystemLabel
}

<#
.SYNOPSIS
    Retrieves the volume serial number using Win32 API.

.DESCRIPTION
    Matches Tree.com output exactly.
#>
function Get-VolumeSerialNumber {
    param (
        [string]$Path = "."
    )

    if (-not ([System.Management.Automation.PSTypeName]'VolumeInfo').Type) {
        $definition = @"
using System;
using System.Runtime.InteropServices;

public class VolumeInfo {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    public static extern bool GetVolumeInformation(
        string lpRootPathName,
        System.Text.StringBuilder lpVolumeNameBuffer,
        int nVolumeNameSize,
        out uint lpVolumeSerialNumber,
        out uint lpMaximumComponentLength,
        out uint lpFileSystemFlags,
        System.Text.StringBuilder lpFileSystemNameBuffer,
        int nFileSystemNameSize);
}
"@
        Add-Type -TypeDefinition $definition -ErrorAction SilentlyContinue | Out-Null
    }

    $root = [System.IO.Path]::GetPathRoot((Resolve-Path $Path).Path)

    $serial  = 0
    $null1   = 0
    $null2   = 0
    $volName = New-Object System.Text.StringBuilder 261
    $fsName  = New-Object System.Text.StringBuilder 261

    [VolumeInfo]::GetVolumeInformation(
        $root, $volName, $volName.Capacity,
        [ref]$serial, [ref]$null1, [ref]$null2,
        $fsName, $fsName.Capacity
    ) | Out-Null

    $serialHigh = ($serial -shr 16)
    $serialLow  = ($serial -band 0xFFFF)

    "{0:X4}-{1:X4}" -f $serialHigh, $serialLow
}
#endregion

#region Raw Directory Enumeration
<#
.SYNOPSIS
    Enumerates directory entries using Win32 FindFirstFile.

.DESCRIPTION
    Used in Tree.com mode to match exact ordering and behavior.
    Returns PSCustomObject with:
      • Directories = [...]
      • Files       = [...]
#>
function Get-RawDirectoryEntries {
    param([string]$Path)

    #
    # Load RawEnum type once
    #
    if (-not ([System.Management.Automation.PSTypeName]'RawEnum').Type) {
        $definition = @"
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class RawEnum {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct WIN32_FIND_DATA {
        public uint dwFileAttributes;
        public System.Runtime.InteropServices.ComTypes.FILETIME ftCreationTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME ftLastAccessTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME ftLastWriteTime;
        public uint nFileSizeHigh;
        public uint nFileSizeLow;
        public uint dwReserved0;
        public uint dwReserved1;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
        public string cFileName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 14)]
        public string cAlternateFileName;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr FindFirstFile(string lpFileName, out WIN32_FIND_DATA lpFindFileData);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern bool FindNextFile(IntPtr hFindFile, out WIN32_FIND_DATA lpFindFileData);

    [DllImport("kernel32.dll")]
    static extern bool FindClose(IntPtr hFindFile);

    public static IEnumerable<WIN32_FIND_DATA> Enum(string path) {
        WIN32_FIND_DATA data;
        IntPtr handle = FindFirstFile(Path.Combine(path, "*"), out data);
        if (handle == new IntPtr(-1)) yield break;

        do {
            string name = data.cFileName;
            if (name != "." && name != "..")
                yield return data;
        }
        while (FindNextFile(handle, out data));

        FindClose(handle);
    }
}
"@
        Add-Type -TypeDefinition $definition -ErrorAction SilentlyContinue | Out-Null
    }

    #
    # Enumerate entries
    #
    $entries = [RawEnum]::Enum($Path)

    $dirs  = @()
    $files = @()

    foreach ($e in $entries) {
        $isDir = ($e.dwFileAttributes -band [IO.FileAttributes]::Directory) -ne 0

        $root = Get-Item -LiteralPath (Join-Path $Path $e.cFileName) -Force -ErrorAction SilentlyContinue
        if (-not $root) { continue }

        $item = [PSCustomObject]@{
            FullName      = $root.FullName
            Name          = $root.Name
            Attributes    = $root.Attributes
            PSIsContainer = $isDir
        }

        if ($isDir) {
            $item.PSObject.TypeNames.Insert(0, 'System.IO.DirectoryInfo')
            $dirs += $item
        }
        else {
            $item.PSObject.TypeNames.Insert(0, 'System.IO.FileInfo')
            $files += $item
        }
    }

    #
    # Return structured result
    #
    [PSCustomObject]@{
        Directories = $dirs
        Files       = $files
    }
}
#endregion
