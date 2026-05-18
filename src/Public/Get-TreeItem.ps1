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
    $resolvedPath = $null
    $errorAction = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        $resolved = Resolve-Path $Path
        if ($null -ne $resolved) {
            $resolvedPath = $resolved.Path
        }
    } catch {}
    $ErrorActionPreference = $errorAction
    
    if ($null -eq $resolvedPath) {
        $resolvedPath = $Path
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
    $items = New-Object System.Collections.Generic.List[object]
    if ($ProviderMode -eq 'Win32' -and $IsWindows) {
        $raw = Get-RawDirectoryEntries -Path $resolvedPath
        foreach ($d in $raw.Directories) { [void]$items.Add($d) }
        foreach ($f in $raw.Files) { [void]$items.Add($f) }
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

            [void]$items.Add($treeItem)
        }
    }

    #
    # Normalization: Filtering
    #
    if ($Include -or $Exclude -or $HideHidden -or $HideSystem -or $DirectoryOnly) {
        $filteredItems = Get-FilteredTreeItems -Items $items -Include $Include -Exclude $Exclude -HideHidden:$HideHidden -HideSystem:$HideSystem -DirectoryOnly:$DirectoryOnly
        $items = New-Object System.Collections.Generic.List[object]
        foreach ($fi in $filteredItems) { [void]$items.Add($fi) }
    }

    #
    # Normalization: Ordering (Deterministic)
    #
    # Deterministic order: Files first, then Directories, both sorted by Name.
    $items = $items | Sort-Object @{Expression="IsContainer"; Ascending=$true}, @{Expression="Name"; Ascending=$true}

    #
    # Output and Recursion
    #
    $itemsArray = @($items)
    foreach ($item in $itemsArray) {
        # Return the current item
        $item

        # Recurse if it's a container and we haven't reached MaxDepth
        if ($item.IsContainer -and ($Depth -eq -1 -or $CurrentDepth -lt $Depth)) {
            $shouldRecurse = $true
            if ($item.IsLink -and -not $FollowLinks) {
                $shouldRecurse = $false
            }

            if ($shouldRecurse) {
                Get-TreeItem -Path $item.FullPath -Depth $Depth -FollowLinks:$FollowLinks -ProviderMode $ProviderMode -Include $Include -Exclude $Exclude -HideHidden:$HideHidden -HideSystem:$HideSystem -DirectoryOnly:$DirectoryOnly -CurrentDepth ($CurrentDepth + 1)
            }
        }
    }
}
