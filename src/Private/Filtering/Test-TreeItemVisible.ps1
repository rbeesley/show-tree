# src/Private/Filtering/Test-TreeItemVisible.ps1

<#
.SYNOPSIS
    Determines if a TreeItem should be displayed.

.DESCRIPTION
    Test-TreeItemVisible evaluates an item against the current traversal settings (Include, Exclude, 
    HideHidden, etc.) to decide if it should be emitted to the pipeline.

    It implements "structural rescue" logic, where an ancestor directory is kept visible if 
    any of its descendants match an inclusion pattern, even if the directory itself doesn't 
    match or is marked for exclusion.
#>
function Test-TreeItemVisible {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Item,

        [string[]]$Include,
        [string[]]$Exclude,

        [string]$RootPath,

        [switch]$HideHidden,
        [switch]$HideSystem,
        [switch]$DirectoryOnly
    )

    if (-not $PSBoundParameters.ContainsKey('Debug'))
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose'))
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    $status = Get-TreeItemFilterStatus -Item $Item -Include $Include -Exclude $Exclude -RootPath $RootPath

    # Structural ancestors to inclusions are ALWAYS visible, 
    # overriding any potential exclusions for that specific branch node.
    if ($status -eq 'Ancestor' -or $status -eq 'Included') { return $true }
    if ($status -eq 'Excluded') { return $false }

    # Files are subject to directory-only filtering even if they aren't explicitly excluded.
    if ($DirectoryOnly -and -not $Item.IsContainer -and $status -ne 'Included') {
        return $false
    }

    if ($status -eq 'Included' -or $status -eq 'Ancestor') { return $true }

    $isHidden = $false
    if ($HideHidden) {
        $isHidden = $Item.IsHidden -or
                ($Item.Native.FileAttributes -and
                        ($Item.Native.FileAttributes -band [IO.FileAttributes]::Hidden) -ne 0
                )
    }

    $isSystem = $false
    if ($HideSystem) {
        $isSystem = $Item.Native.FileAttributes -and
                ($Item.Native.FileAttributes -band [IO.FileAttributes]::System) -ne 0
    }

    if ($isHidden) { return $false }
    if ($isSystem) { return $false }

    return $true
}
