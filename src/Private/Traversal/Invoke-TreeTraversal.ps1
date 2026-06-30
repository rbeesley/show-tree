# src/Private/Traversal/Invoke-TreeTraversal.ps1

<#
.SYNOPSIS
    Streams tree traversal records for a path.

.DESCRIPTION
    Invoke-TreeTraversal is the internal recursive engine for ShowTree. It performs a 
    depth-first search of the file system using a provided TreeChildProvider. It emits 
    ShowTree.TreeRecord objects for every item and "gap" (structural separator) found.

    It handles recursion depth, visibility logic (via predicates), and layout state 
    tracking (e.g., whether an ancestor was a last sibling).

.PARAMETER Path
    The path to traverse. Defaults to the current directory ('.'). Supports both relative and absolute paths.
    If the path represents a file, only that file will be emitted.

.PARAMETER Mode
    The formatting mode ('Normal', 'Tree', 'List'). This influence how layout metadata (gaps, connectors) 
    is computed during traversal.

.PARAMETER Depth
    The maximum depth to traverse. 
    - Use -1 for unlimited traversal.
    - Use 0 for the root item only.
    - Defaults to -1.

.PARAMETER ProviderMode
    The enumeration provider to use ('PowerShell' or 'Win32'). 
    'Win32' is significantly faster on Windows for deep trees but may exhibit different behavior for 
    certain virtualized or specialized file types.

.PARAMETER GapPolicy
    The policy for rendering gap lines ('None', 'Tree', 'Show').
    - 'None': No gaps are emitted.
    - 'Show': Emits gap lines between logical groups (e.g., between a set of files and the next directory).
    - 'Tree': A legacy-compatible mode specifically for Tree.com behavior.

.PARAMETER Include
    An array of glob patterns to include. If specified, only items matching these patterns (or their 
    ancestors required for structural integrity) will be emitted.

.PARAMETER Exclude
    An array of glob patterns to exclude. Items matching these patterns and their descendants will be 
    pruned from the traversal.

.PARAMETER HideHidden
    If specified, hides items marked with the Hidden attribute (Windows) or dot-prefixed items (Unix).

.PARAMETER HideSystem
    If specified, hides items marked with the System attribute.

.PARAMETER DirectoryOnly
    If specified, only directories are included in the traversal output.
    
.PARAMETER FollowLinks
    If specified, the cmdlet will follow symbolic links and directory junctions during traversal.
#>
function Invoke-TreeTraversal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [ValidateSet('Normal', 'Tree', 'List')]
        [string] $Mode = 'Normal',
        
        [string] $RootPath,

        [int] $MaxDepth = -1,

        [int] $CurrentDepth = 0,

        [Parameter(Mandatory)]
        [object] $Provider,

        [ValidateSet('None', 'Tree', 'Show')]
        [string] $GapPolicy = 'Show',

        [bool[]] $AncestorIsLastSibling = @(),

        [bool] $HasNextSiblingAfterThisDirectory = $false,

        [string[]] $Include,
        [string[]] $Exclude,

        [switch] $HideHidden,
        [switch] $HideSystem,
        [switch] $DirectoryOnly,
        [switch] $FollowLinks
    )

    if (-not $PSBoundParameters.ContainsKey('Debug'))
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose'))
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        $RootPath = $Path
    }

    $children = @(
        Get-ImmediateTreeChild `
            -Path $Path `
            -RootPath $RootPath `
            -Depth $CurrentDepth `
            -Provider $Provider `
            -Include $Include `
            -Exclude $Exclude `
            -HideHidden:$HideHidden `
            -HideSystem:$HideSystem `
            -DirectoryOnly:$DirectoryOnly
    )

    $emittedVisibleChild = $false

    if ($children.Count -eq 0) {
        return
    }

    for ($i = 0; $i -lt $children.Count; $i++) {
        $child = $children[$i]
        $emittedVisibleChild = $true

        $isLastSibling = $i -eq ($children.Count - 1)
        $hasNextSibling = -not $isLastSibling

        $hasLaterSiblingDirectory = $false
        for ($j = $i + 1; $j -lt $children.Count; $j++) {
            if ($children[$j].IsContainer) {
                $hasLaterSiblingDirectory = $true
                break
            }
        }

        $layout = New-TreeLayout `
            -Depth $child.Depth `
            -RelativeDepth $child.Depth `
            -IsLastSibling:$isLastSibling `
            -AncestorIsLastSibling $AncestorIsLastSibling `
            -HasLaterSiblingDirectory:$hasLaterSiblingDirectory

        New-TreeRecord `
            -RecordType Item `
            -TreeItem $child `
            -TreeLayout $layout
        
        $script:lastRecordKind = $child.Kind

        # Sibling Gap Logic
        if (-not $child.IsContainer -and $hasNextSibling -and $children[$i + 1].IsContainer) {
            $fileToDirectoryGapLayout = New-TreeLayout `
                -Depth $CurrentDepth `
                -RelativeDepth $CurrentDepth `
                -AncestorIsLastSibling $AncestorIsLastSibling

            New-TreeRecord `
                -RecordType Gap `
                -TreeLayout $fileToDirectoryGapLayout
        }

        $shouldRecurse =
            $child.IsContainer -and
            ($MaxDepth -eq -1 -or $CurrentDepth -lt $MaxDepth) -and
            (Test-TreeItemRecurse `
                -Item $child `
                -Include $Include `
                -Exclude $Exclude `
                -RootPath $RootPath `
                -HideHidden:$HideHidden `
                -HideSystem:$HideSystem `
                -FollowLinks:$FollowLinks)

        if ($shouldRecurse) {
            $nextAncestorIsLastSibling = [System.Collections.Generic.List[bool]]::new()

            foreach ($ancestorIsLast in $AncestorIsLastSibling) {
                [void] $nextAncestorIsLastSibling.Add([bool] $ancestorIsLast)
            }

            [void] $nextAncestorIsLastSibling.Add([bool] $isLastSibling)

            $recurseParams = @{
                Path                             = $child.FullPath
                Mode                             = $Mode
                RootPath                         = $RootPath
                MaxDepth                         = $MaxDepth
                CurrentDepth                     = $CurrentDepth + 1
                Provider                         = $Provider
                GapPolicy                        = $GapPolicy
                HasNextSiblingAfterThisDirectory = $hasNextSibling
                Include                          = $Include
                Exclude                          = $Exclude
                HideHidden                       = $HideHidden
                HideSystem                       = $HideSystem
                DirectoryOnly                    = $DirectoryOnly
                FollowLinks                      = $FollowLinks
            }

            $nextAncestorArray = $nextAncestorIsLastSibling.ToArray()
            if ($nextAncestorArray.Count -gt 0) {
                $recurseParams.AncestorIsLastSibling = $nextAncestorArray
            }

            Invoke-TreeTraversal @recurseParams
        }
    }

    # Only for Tree mode, if the last tree item was a directory and the next tree item is a directory,
    # then regardless of how close they are on the tree, suppress the gap.
    $supressGap = $Mode -eq 'Tree' -and $GapPolicy -eq 'Tree' -and $script:lastRecordKind -ne 'File'
    if ($emittedVisibleChild -and $HasNextSiblingAfterThisDirectory -and -not $supressGap) {
        $gapAncestorIsLastSibling = [System.Collections.Generic.List[bool]]::new()

        if ($AncestorIsLastSibling.Count -gt 1) {
            for ($i = 0; $i -lt ($AncestorIsLastSibling.Count - 1); $i++) {
                [void] $gapAncestorIsLastSibling.Add([bool] $AncestorIsLastSibling[$i])
            }
        }

        $gapDepth = ($CurrentDepth -gt 0) ? ($CurrentDepth - 1) : 0

        $gapLayoutParams = @{
            Depth          = $gapDepth
            RelativeDepth  = $gapDepth
        }

        $gapAncestorArray = $gapAncestorIsLastSibling.ToArray()
        if ($gapAncestorArray.Count -gt 0) {
            $gapLayoutParams.AncestorIsLastSibling = $gapAncestorArray
        }

        $gapLayout = New-TreeLayout @gapLayoutParams

        New-TreeRecord `
            -RecordType Gap `
            -TreeLayout $gapLayout
    }
}
