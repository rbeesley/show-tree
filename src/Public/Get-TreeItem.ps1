# src/Public/Get-TreeItem.ps1

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
    $orderedItems = [System.Collections.Generic.List[object]]::new()
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
        foreach ($f in $rawFiles) {
            [void]$orderedItems.Add($f)
        }
        foreach ($d in $rawDirectories) {
            [void]$orderedItems.Add($d)
        }
    }
    else {
        $rawItems = Get-ChildItem -Path $resolvedPath -Force -ErrorAction SilentlyContinue
        $items = [System.Collections.Generic.List[object]]::new()
        
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

                $targetPath = $target
                if ($target -is [array]) {
                    $targetPath = $target | Select-Object -First 1
                }

                $isBroken = $null
                if (-not [string]::IsNullOrWhiteSpace([string]$targetPath)) {
                    $targetText = [string]$targetPath

                    $linkParentPath = $null
                    if ($item.PSObject.Properties.Match('DirectoryName') -and
                            -not [string]::IsNullOrWhiteSpace([string]$item.DirectoryName)) {
                        $linkParentPath = [string]$item.DirectoryName
                    }

                    if ([string]::IsNullOrWhiteSpace($linkParentPath)) {
                        $linkParentPath = Split-Path -Path $item.FullName -Parent
                    }

                    if ([string]::IsNullOrWhiteSpace($linkParentPath)) {
                        $linkParentPath = [System.IO.Path]::GetPathRoot($item.FullName)
                    }

                    $candidateTargetPath = if ([System.IO.Path]::IsPathRooted($targetText)) {
                        $targetText
                    }
                    elseif (-not [string]::IsNullOrWhiteSpace($linkParentPath)) {
                        Join-Path -Path $linkParentPath -ChildPath $targetText
                    }
                    else {
                        $null
                    }

                    if (-not [string]::IsNullOrWhiteSpace($candidateTargetPath)) {
                        $isBroken = -not (Test-Path -LiteralPath $candidateTargetPath)
                    }
                }

                $link = [PSCustomObject]@{
                    Type       = ($kind -eq 'Junction') ? 'Junction' : 'SymbolicLink'
                    Target     = $target
                    TargetPath = $targetPath
                    IsBroken   = $isBroken
                }
            }

            $isHidden = $null
            $states = [System.Collections.Generic.List[string]]::new()

            if ($IsWindows) {
                $isHidden = ($item.Attributes -band [IO.FileAttributes]::Hidden) -ne 0
            }
            else {
                $isHidden = $item.Name.StartsWith('.')
            }

            if ($isHidden) { [void]$states.Add('Hidden') }
            if ($item.Attributes -band [IO.FileAttributes]::ReadOnly) { [void]$states.Add('ReadOnly') }
            if ($item.Attributes -band [IO.FileAttributes]::System) { [void]$states.Add('System') }

            if (-not $IsWindows -and $kind -notin @('Symlink', 'Junction') -and $item.PSObject.Properties.Match('UnixMode')) {
                $unixMode = [string]$item.UnixMode

                if ($unixMode.Length -ge 10) {
                    $hasSetUid = $unixMode[3] -match '[sS]'
                    $hasSetGid = $unixMode[6] -match '[sS]'
                    $isOtherWritable = $unixMode[8] -eq 'w'
                    $hasSticky = $unixMode[9] -match '[tT]'

                    if ($hasSetUid) {
                        [void]$states.Add('SetUid')
                    }

                    if ($hasSetGid) {
                        [void]$states.Add('SetGid')
                    }

                    if ($isDir -and $isOtherWritable) {
                        [void]$states.Add('OtherWritable')
                    }

                    if ($isDir -and $hasSticky) {
                        [void]$states.Add('Sticky')
                    }

                    if ($isDir -and $isOtherWritable -and $hasSticky) {
                        [void]$states.Add('StickyOtherWritable')
                    }

                    if ($kind -eq 'File' -and (
                    $unixMode[3] -match '[xs]' -or
                            $unixMode[6] -match '[xs]' -or
                            $unixMode[9] -match '[xt]'
                    )) {
                        [void]$states.Add('Executable')
                    }
                }
            }

            if ($kind -eq 'Symlink') { [void]$states.Add('Symlink') }
            elseif ($kind -eq 'Junction') { [void]$states.Add('Junction') }

            if ($link -and $link.IsBroken -eq $true) {
                [void]$states.Add('BrokenLink')
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
                    -States $states.ToArray()

            if (Test-TreeItemVisible -Item $treeItem -Include $Include -Exclude $Exclude -HideHidden:$HideHidden -HideSystem:$HideSystem -DirectoryOnly:$DirectoryOnly) {
                [void]$items.Add($treeItem)
            }
        }

        #
        # Normalization: Ordering (Deterministic)
        #
        # Deterministic order for PowerShell provider mode.
        # Win32 provider mode intentionally preserves tree.com-compatible enumeration order.
        $orderedItems = $items | Sort-Object @{ Expression="IsContainer"; Ascending=$true }, @{ Expression="Name"; Ascending=$true }
    }

    #
    # Output and Recursion
    #
    foreach ($item in $orderedItems) {
        # Return the current item
        $item

        # Recurse if it's a container and we haven't reached MaxDepth
        if ($item.IsContainer -and ($Depth -eq -1 -or $CurrentDepth -lt $Depth)) {
            if (Test-TreeItemRecurse `
                    -Item $item `
                    -Include $Include `
                    -Exclude $Exclude `
                    -HideHidden:$HideHidden `
                    -HideSystem:$HideSystem `
                    -FollowLinks:$FollowLinks) {
                Get-TreeItem `
                        -Path $item.FullPath `
                        -Depth $Depth `
                        -FollowLinks:$FollowLinks `
                        -ProviderMode $ProviderMode `
                        -Include $Include `
                        -Exclude $Exclude `
                        -HideHidden:$HideHidden `
                        -HideSystem:$HideSystem `
                        -DirectoryOnly:$DirectoryOnly `
                        -CurrentDepth ($CurrentDepth + 1)
            }
        }
    }
}
