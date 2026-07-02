# src/Private/Filtering/Test-TreeItemRecurse.ps1

<#
.SYNOPSIS
    Determines if a directory should be traversed.

.DESCRIPTION
    Test-TreeItemRecurse checks if the traversal engine should enter a specific directory. 
    It prunes the search tree based on Exclude patterns, recursion depth, and visibility 
    settings like HideHidden.
#>
function Test-TreeItemRecurse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Item,

        [string[]]$Include,
        [string[]]$Exclude,

        [string]$RootPath,

        [switch]$HideHidden,
        [switch]$HideSystem,

        [switch]$FollowLinks
    )

    if (-not $PSBoundParameters.ContainsKey('Debug') -and $PSCmdlet)
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose') -and $PSCmdlet)
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    if (-not $Item.IsContainer) { return $false }
    if ($Item.IsLink -and -not $FollowLinks) { return $false }

    $status = Get-TreeItemFilterStatus -Item $Item -Include $Include -Exclude $Exclude -RootPath $RootPath

    # If it's excluded, we ONLY recurse if it's an ancestor to an inclusion.
    if ($status -eq 'Excluded') { return $false }
    if ($status -eq 'Included' -or $status -eq 'Ancestor') { return $true }

    # Standard traversal pruning for hidden/system items.
    if ($HideHidden) {
        $isHidden = $Item.IsHidden -or (
        $null -ne $Item.Native.FileAttributes -and
                ($Item.Native.FileAttributes -band [IO.FileAttributes]::Hidden) -ne 0
        )
        if ($isHidden) { return $false }
    }

    if ($HideSystem) {
        $isSystem = $Item.Native.FileAttributes -and
                ($Item.Native.FileAttributes -band [IO.FileAttributes]::System) -ne 0
        if ($isSystem) { return $false }
    }

    return $true
}
