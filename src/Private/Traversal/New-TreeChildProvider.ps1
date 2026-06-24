# src/Private/Traversal/New-TreeChildProvider.ps1

<#
.SYNOPSIS
    Creates a tree child provider used by streaming tree traversal.

.DESCRIPTION
    The New-TreeChildProvider cmdlet returns a provider object (PowerShell or Win32)
    that is used to enumerate files and directories during a tree traversal.
#>
function New-TreeChildProvider {
    [CmdletBinding()]
    param(
        [ValidateSet('PowerShell', 'Win32')]
        [string] $ProviderMode = 'PowerShell'
    )

    $localIsWindows = $IsWindows ? $IsWindows : $true
    if ($ProviderMode -eq 'Win32' -and -not $localIsWindows) {
        throw "Win32 tree child provider is only supported on Windows."
    }
    
    switch ($ProviderMode) {
        'Win32' {
            return [PSCustomObject]@{
                PSTypeName   = 'ShowTree.TreeChildProvider'
                Name         = 'Win32'
                ProviderMode = 'Win32'
                GetChildren  = {
                    param(
                        [Parameter(Mandatory)]
                        [string] $Path,

                        [int] $Depth = 0
                    )

                    Get-RawDirectoryEntries -Path $Path -Depth $Depth
                }
            }
        }

        'PowerShell' {
            return [PSCustomObject]@{
                PSTypeName   = 'ShowTree.TreeChildProvider'
                Name         = 'PowerShell'
                ProviderMode = 'PowerShell'
                GetChildren  = {
                    param(
                        [Parameter(Mandatory)]
                        [string] $Path,

                        [int] $Depth = 0
                    )

                    $localIsWindows = $null -ne $IsWindows ? $IsWindows : $true

                    $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
                    if ($resolvedPath) {
                        $Path = $resolvedPath.ProviderPath
                    }

                    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
                        return [PSCustomObject]@{
                            Files       = @()
                            Directories = @()
                        }
                    }

                    $files = [System.Collections.Generic.List[object]]::new()
                    $directories = [System.Collections.Generic.List[object]]::new()

                    $rawItems = Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue

                    foreach ($item in @($rawItems)) {
                        $isContainer = $item.PSIsContainer

                        $native = [PSCustomObject]@{
                            Platform       = $localIsWindows ? 'Windows' : 'Unix'
                            FileAttributes = $item.Attributes
                            Raw            = $null
                        }

                        $kind = $isContainer ? 'Directory' : 'File'
                        $link = $null
                        $states = [System.Collections.Generic.HashSet[string]]::new()

                        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                            $kind = ($isContainer -and $localIsWindows) ? 'Junction' : 'Symlink'

                            $target = $null
                            if ($item.PSObject.Properties.Match('Target')) {
                                $target = $item.Target
                            }

                            $targetPath = $target
                            if ($target -is [array]) {
                                $targetPath = $target | Select-Object -First 1
                            }

                            $isBroken = $null
                            if (-not [string]::IsNullOrWhiteSpace([string] $targetPath)) {
                                $targetText = [string] $targetPath

                                $linkParentPath = $null
                                if ($item.PSObject.Properties.Match('DirectoryName') -and
                                        -not [string]::IsNullOrWhiteSpace([string] $item.DirectoryName)) {
                                    $linkParentPath = [string] $item.DirectoryName
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
                                TargetMetadata = $null
                            }

                            if (-not $isBroken) {
                                $targetInfo = Get-Item -LiteralPath $candidateTargetPath -Force -ErrorAction SilentlyContinue
                                if ($targetInfo) {
                                    $link.TargetMetadata = [PSCustomObject]@{
                                        IsContainer = $targetInfo.PSIsContainer
                                        Attributes  = $targetInfo.Attributes
                                    }
                                }
                            }                            
                        }

                        $isHidden = if ($localIsWindows) {
                            ($item.Attributes -band [IO.FileAttributes]::Hidden) -ne 0
                        }
                        else {
                            $item.Name.StartsWith('.')
                        }

                        if ($isHidden) {
                            [void] $states.Add('Hidden')
                        }

                        if (($item.Attributes -band [IO.FileAttributes]::ReadOnly) -ne 0) {
                            [void] $states.Add('ReadOnly')
                        }

                        if (($item.Attributes -band [IO.FileAttributes]::System) -ne 0) {
                            [void] $states.Add('System')
                        }

                        if ($kind -eq 'Symlink') {
                            [void] $states.Add('Symlink')
                        }
                        elseif ($kind -eq 'Junction') {
                            [void] $states.Add('Junction')
                        }

                        if ($link -and $link.IsBroken) {
                            [void] $states.Add('BrokenLink')
                        }

                        if (-not $localIsWindows -and $kind -notin @('Symlink', 'Junction') -and $item.PSObject.Properties.Match('UnixMode')) {
                            $unixMode = [string] $item.UnixMode

                            # PowerShell commonly exposes UnixMode as a 10-character string
                            # like "-rwxr-xr-x", but tests may pass the 9 permission
                            # characters directly. Normalize to the final 9 permission chars.
                            $permissionText = if ($unixMode.Length -ge 10) {
                                $unixMode.Substring($unixMode.Length - 9)
                            }
                            else {
                                $unixMode
                            }

                            if ($permissionText.Length -ge 9) {
                                $ownerWrite = $permissionText[1] -eq 'w'
                                $groupWrite = $permissionText[4] -eq 'w'
                                $otherWrite = $permissionText[7] -eq 'w'

                                if ($ownerWrite) {
                                    [void] $states.Add('OwnerWritable')
                                }

                                if ($groupWrite) {
                                    [void] $states.Add('GroupWritable')
                                }

                                if ($otherWrite) {
                                    [void] $states.Add('OtherWritable')
                                }

                                if (-not ($ownerWrite -or $groupWrite -or $otherWrite)) {
                                    [void] $states.Add('NoWriteBits')
                                }

                                $hasSetUid = $permissionText[2] -match '[sS]'
                                $hasSetGid = $permissionText[5] -match '[sS]'
                                $hasSticky = $permissionText[8] -match '[tT]'

                                if ($hasSetUid) {
                                    [void] $states.Add('SetUid')
                                }

                                if ($hasSetGid) {
                                    [void] $states.Add('SetGid')
                                }

                                if ($isContainer -and $hasSticky) {
                                    [void] $states.Add('Sticky')
                                }

                                if ($isContainer -and $otherWrite -and $hasSticky) {
                                    [void] $states.Add('StickyOtherWritable')
                                }

                                if ($kind -eq 'File' -and (
                                    $permissionText[2] -match '[xs]' -or
                                    $permissionText[5] -match '[xs]' -or
                                    $permissionText[8] -match '[xt]'
                                )) {
                                    [void] $states.Add('Executable')
                                }
                            }
                        }

                        $length = if (-not $isContainer -and $item.PSObject.Properties.Match('Length')) {
                            $item.Length
                        }
                        else {
                            -1
                        }
                        
                        $statesArray = New-Object string[] $states.Count
                        $states.CopyTo($statesArray)

                        $treeItem = New-TreeItem `
                            -FullPath $item.FullName `
                            -Name $item.Name `
                            -ParentPath $Path `
                            -Kind $kind `
                            -IsContainer $isContainer `
                            -Depth $Depth `
                            -Length $length `
                            -CreationTime $item.CreationTime `
                            -LastWriteTime $item.LastWriteTime `
                            -LastAccessTime $item.LastAccessTime `
                            -Link $link `
                            -Native $native `
                            -States $statesArray

                        if ($isContainer) {
                            [void] $directories.Add($treeItem)
                        }
                        else {
                            [void] $files.Add($treeItem)
                        }
                    }

                    [PSCustomObject]@{
                        Files       = @($files | Sort-Object Name)
                        Directories = @($directories | Sort-Object Name)
                    }
                }
            }
        }
    }
}
