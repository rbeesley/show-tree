# src/Public/Get-TreeItem.ps1

<#
.SYNOPSIS
    Streams tree traversal records for a path.

.DESCRIPTION
    The Get-TreeItem cmdlet resolves a path and performs a depth-first traversal of its children.
    It emits ShowTree.TreeRecord objects that contain both the item information and layout metadata
    required for hierarchical rendering.

.PARAMETER Path
    The path to traverse. Default is '.'.
    
.PARAMETER Mode
    The formatting mode ('Normal', 'Tree', 'List'). This affects how traversal is prioritized and filtered.

.PARAMETER Depth
    The maximum depth to traverse. -1 for unlimited, 0 for the root item only.

.PARAMETER ProviderMode
    The provider to use for enumerating items ('PowerShell' or 'Win32').
    'Win32' is significantly faster on Windows for large directories but may have different behavior for certain virtual or networked file types.
    'PowerShell' is the default and provides cross-platform compatibility.
    
.PARAMETER GapPolicy
    Policy followed when rendering the gaps ('None', 'Tree', 'Show').
    'None' suppresses all gaps, 'Show' shows all gaps, and 'Tree' is used for a special tree.com compatible mode where gaps only appear between files and folders.

.PARAMETER FollowLinks
    If set, follows symbolic links and junctions during traversal. Use with caution to avoid infinite loops.

.PARAMETER Include
    Filters items to include based on glob patterns.

.PARAMETER Exclude
    Filters items to exclude based on glob patterns.

.PARAMETER HideHidden
    If set, hides hidden files and directories.

.PARAMETER HideSystem
    If set, hides system files and directories.

.PARAMETER DirectoryOnly
    If set, only directories are included in the traversal.

.EXAMPLE
    Get-TreeItem -Path C:\Source -Depth 2 | Format-Tree
    Retrieves items from C:\Source up to 2 levels deep and formats them using the default style.

.EXAMPLE
    Get-TreeItem -Path . -ProviderMode Win32 -DirectoryOnly
    Efficiently retrieves only directories from the current path using Win32 APIs on Windows.

.LINK
    Invoke-TreeTraversal
    Format-Tree
    New-TreeItem
#>
function Get-TreeItem {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string] $Path = '.',

        [ValidateSet('Normal', 'Tree', 'List')]
        [string] $Mode = 'Normal',
        
        [int] $Depth = -1,

        [ValidateSet('PowerShell', 'Win32')]
        [string] $ProviderMode = 'PowerShell',

        [ValidateSet('None', 'Tree', 'Show')]
        [string] $GapPolicy = 'Show',

        [switch] $FollowLinks,

        [string[]] $Include,
        [string[]] $Exclude,

        [switch] $HideHidden,
        [switch] $HideSystem,
        [switch] $DirectoryOnly
    )

    if (-not $PSBoundParameters.ContainsKey('Debug') -and $PSCmdlet)
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose') -and $PSCmdlet)
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    $resolvedPathInfo = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue

    $resolvedPath = $resolvedPathInfo `
                ? ($resolvedPathInfo.PSObject.Properties.Match('ProviderPath')) `
                        ? $resolvedPathInfo.ProviderPath `
                        : $resolvedPathInfo.Path `
                : $Path

    # Preprocessing Step: Resolve relative filters to explicit path candidates.
    # We generate candidates by joining every exclusion with every inclusion.
    # This enables "structural rescue" for relative inclusions under excluded directories.
    $processedInclude = [System.Collections.Generic.List[string]]::new()
    if ($Include) {
        foreach ($pattern in $Include) {
            [void]$processedInclude.Add($pattern)

            if ($Exclude) {
                foreach ($exPattern in $Exclude) {
                    $exFilter = ConvertTo-TreeFilterPattern -Pattern $exPattern -RootPath $resolvedPath

                    # If it's a path pattern, or a name that happens to be a directory, we should attempt rescue joins
                    $isExDir = $exFilter.DirectoryOnly -or (Test-Path -LiteralPath (Join-Path $resolvedPath $exFilter.Pattern) -PathType Container)
                    $hasSep = $exPattern.Contains([System.IO.Path]::DirectorySeparatorChar)
                    
                    if ($hasSep -or $isExDir) {
                        $candidate = [System.IO.Path]::Combine($exFilter.Pattern, $pattern)

                        # Verify if the candidate exists before adding it as an explicit rescue
                        $absCandidate = if ([System.IO.Path]::IsPathRooted($candidate)) {
                            $candidate
                        } else {
                            [System.IO.Path]::Combine($resolvedPath, $candidate)
                        }

                        if (Test-Path -LiteralPath $absCandidate) {
                            [void]$processedInclude.Add($candidate)
                        }
                    }
                }
            }
        }
    }
    
    Write-Verbose "processedInclude: $processedInclude"
    
    $provider = New-TreeChildProvider -ProviderMode $ProviderMode

    $traversalDepth = ($Depth -eq -1) ? -1 : ($Depth -le 0) ? 0 : ($Depth - 1)

    $invokeTreeTraversalParams = @{
        Path          = $resolvedPath
        Mode          = $Mode
        RootPath      = $resolvedPath
        MaxDepth      = $traversalDepth
        CurrentDepth  = 0
        Provider      = $provider
        GapPolicy     = $GapPolicy
        Include       = $processedInclude.ToArray()
        Exclude       = $Exclude
        HideHidden    = $HideHidden
        HideSystem    = $HideSystem
        DirectoryOnly = $DirectoryOnly
        FollowLinks   = $FollowLinks
    }

    Invoke-TreeTraversal @invokeTreeTraversalParams
}
