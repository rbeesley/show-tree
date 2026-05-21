# \src\Public\Get-TreeItem.ps1

function Get-TreeItem {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path = '.',

        [int]$Depth = -1,

        [ValidateSet('PowerShell', 'Win32')]
        [string]$ProviderMode = 'PowerShell',

        [switch]$FollowLinks,

        # Filtering parameters
        [string[]]$Include,
        [string[]]$Exclude,
        [switch]$HideHidden,
        [switch]$HideSystem,
        [switch]$DirectoryOnly,

        # Internal recursion parameters
        [int]$CurrentDepth = 0
    )

    #
    # Resolve Path
    #
    $resolvedPath = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        $resolvedPath = $Path
    }
    else {
        $resolvedPath = $resolvedPath.Path
    }

    #
    # Depth Check
    #
    if ($Depth -ne -1 -and $CurrentDepth -gt $Depth) {
        return
    }

    #
    # Enumeration
    #
    $items = [System.Collections.Generic.List[object]]::new()
    if ($ProviderMode -eq 'Win32' -and $IsWindows) {
        $raw = Get-RawDirectoryEntries -Path $resolvedPath -Depth $CurrentDepth

        $rawDirectories = foreach ($d in $raw.Directories) {
            if (Test-TreeItemVisible -Item $d -Include $Include -Exclude $Exclude -HideHidden:$HideHidden -HideSystem:$HideSystem -DirectoryOnly:$DirectoryOnly) {
                $d
            }
        }
        $rawFiles = foreach ($f in $raw.Files) {
            if (Test-TreeItemVisible -Item $f -Include $Include -Exclude $Exclude -HideHidden:$HideHidden -HideSystem:$HideSystem -DirectoryOnly:$DirectoryOnly) {
                $f
            }
        }

        # Tree.com-compatible ordering:
        #   - files first
        #   - directories second
        #   - preserve Win32 enumeration order inside each group
        foreach ($f in $rawFiles) { [void]$items.Add($f) }
        foreach ($d in $rawDirectories) { [void]$items.Add($d) }
    }
    else {
        $rawItems = Get-ChildItem -Path $resolvedPath -Force -ErrorAction SilentlyContinue

        foreach ($item in $rawItems) {
            $isDir = $item.PSIsContainer
            $native = [PSCustomObject]@{
                Platform = $IsWindows ? 'Windows' : 'Unix'
                FileAttributes = $item.Attributes
            }

            $kind = $isDir ? 'Directory' : 'File'
            $link = $null
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $kind = ($isDir -and $IsWindows) ? 'Junction' : 'Symlink'

                $target = $null
                if ($item.PSObject.Properties.Match('Target')) {
                    $target = $item.Target
                }

                $link = [PSCustomObject]@{
                    Type       = ($kind -eq 'Junction') ? 'Junction' : 'SymbolicLink'
                    Target     = $target
                    TargetPath = $target
                    IsBroken   = $null
                }
            }

            $isHidden = $null
            if ($IsWindows) {
                $isHidden = ($item.Attributes -band [IO.FileAttributes]::Hidden) -ne 0
            }
            else {
                $isHidden = $item.Name.StartsWith('.')
            }

            $treeItem = New-TreeItem `
                    -FullPath $item.FullName `
                    -IsContainer $isDir `
                    -Kind $kind `
                    -Name $item.Name `
                    -Native $native `
                    -Link $link `
                    -Depth $CurrentDepth `
                    -ParentPath $resolvedPath `
                    -IsHidden $isHidden

            if (Test-TreeItemVisible -Item $treeItem -Include $Include -Exclude $Exclude -HideHidden:$HideHidden -HideSystem:$HideSystem -DirectoryOnly:$DirectoryOnly) {
                [void]$items.Add($treeItem)
            }
        }

        #
        # Normalization: Ordering (Deterministic)
        #
        # Deterministic order for PowerShell provider mode.
        # Win32 provider mode intentionally preserves tree.com-compatible enumeration order.
        $items = $items | Sort-Object @{Expression="IsContainer"; Ascending=$true}, @{Expression="Name"; Ascending=$true}
    }

    #
    # Output and Recursion
    #
    foreach ($item in $items) {
        # Return the current item
        $item

        # Recurse if it's a container and we haven't reached MaxDepth
        if ($item.IsContainer -and ($Depth -eq -1 -or $CurrentDepth -lt $Depth)) {
            if (Test-TreeItemRecurse -Item $item -Include $Include -Exclude $Exclude -HideHidden:$HideHidden -HideSystem:$HideSystem -FollowLinks:$FollowLinks) {
                Get-TreeItem -Path $item.FullPath -Depth $Depth -FollowLinks:$FollowLinks -ProviderMode $ProviderMode -Include $Include -Exclude $Exclude -HideHidden:$HideHidden -HideSystem:$HideSystem -DirectoryOnly:$DirectoryOnly -CurrentDepth ($CurrentDepth + 1)
            }
        }
    }
}
