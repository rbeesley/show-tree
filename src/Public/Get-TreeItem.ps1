function Get-TreeItem {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path = '.',

        [int]$Depth = -1,

        [ValidateSet('PowerShell', 'Win32')]
        [string]$ProviderMode = 'PowerShell',

        [switch]$FollowLinks,

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
    $items = @()
    if ($ProviderMode -eq 'Win32' -and $IsWindows) {
        $raw = Get-RawDirectoryEntries -Path $resolvedPath
        $items = $raw.Directories + $raw.Files
    }
    else {
        $rawItems = Get-ChildItem -Path $resolvedPath -Force -ErrorAction SilentlyContinue
        
        foreach ($item in $rawItems) {
            $isDir = $item.PSIsContainer
            $native = [PSCustomObject]@{
                Platform = if ($IsWindows) { 'Windows' } else { 'Unix' }
                FileAttributes = $item.Attributes
            }
            
            $kind = if ($isDir) { 'Directory' } else { 'File' }
            $link = $null
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $kind = if ($isDir -and $IsWindows) { 'Junction' } else { 'Symlink' }
                
                $target = $null
                if ($item.PSObject.Properties.Match('Target')) {
                    $target = $item.Target
                }

                $link = [PSCustomObject]@{
                    Type       = if ($kind -eq 'Junction') { 'Junction' } else { 'SymbolicLink' }
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

            $items += $treeItem
        }
    }

    #
    # Normalization: Filtering
    #

    #
    # Normalization: Ordering (Deterministic)
    #
    # Deterministic order: Directories first, then Files, both sorted by Name.
    $items = $items | Sort-Object @{Expression="IsContainer"; Descending=$true}, @{Expression="Name"; Ascending=$true}

    #
    # Output and Recursion
    #
    foreach ($item in $items) {
        # Return the current item
        $item

        # Recurse if it's a container and we haven't reached MaxDepth
        if ($item.IsContainer -and ($Depth -eq -1 -or $CurrentDepth -lt $Depth)) {
            $shouldRecurse = $true
            if ($item.IsLink -and -not $FollowLinks) {
                $shouldRecurse = $false
            }

            if ($shouldRecurse) {
                Get-TreeItem -Path $item.FullPath -Depth $Depth -FollowLinks:$FollowLinks -ProviderMode $ProviderMode -CurrentDepth ($CurrentDepth + 1)
            }
        }
    }
}
