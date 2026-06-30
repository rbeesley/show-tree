# src/Private/PathUtilities/Get-TreeModeHeader.ps1

<#
.SYNOPSIS
    Generates the volume and header information for Tree mode.

.DESCRIPTION
    The Get-TreeModeHeader cmdlet generates the volume label and serial number header,
    matching the classic tree.com output. It also validates the drive and path. Used only in Tree.com compatibility mode.
#>
function Get-TreeModeHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        $Colorize,
        [object]$StyleProfile = $null
    )

    if (-not $PSBoundParameters.ContainsKey('Debug'))
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose'))
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    $StyleProfile = $StyleProfile ? (Get-ActiveShowTreeStyleProfile) : $StyleProfile
    $ui = $StyleProfile.UIStrings.TreeMode

    # Extract drive letter
    $drive = Split-Path $Path -Qualifier
    $driveName = $drive.TrimEnd(':')

    # 1. Invalid drive → tree.com behavior
    if ($driveName -and -not (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue)) {
        Write-Output $ui.InvalidDrive
        return $false
    }

    # 2. Valid drive → print header
    $nearestExistingParent = Get-NearestExistingParent -Path $Path
    $fileSystemLabel       = Get-VolumeName -Path $nearestExistingParent
    $serialNumber          = Get-VolumeSerialNumber -Path $nearestExistingParent

    Write-Output ($ui.VolumeListing -f $fileSystemLabel)
    Write-Output ($ui.VolumeSerial -f $serialNumber)

    # 3. Write the root path and stylize it
    $localIsWindows = $IsWindows ? $IsWindows : $true
    $rootItem = Get-Item -LiteralPath $Path -Force
    $native = [PSCustomObject]@{
        Platform       = $localIsWindows ? 'Windows' : 'Unix'
        FileAttributes = $rootItem.Attributes
    }

    $kind = $rootItem.PSIsContainer ? 'Directory' : 'File'

    $treeItem = New-TreeItem `
        -FullPath $rootItem.FullName `
        -IsContainer $rootItem.PSIsContainer `
        -Kind $kind `
        -Name $rootItem.Name `
        -Native $native `
        -Depth 0

    $style = Get-ItemStyle -Item $treeItem -Colorize:$Colorize -StyleProfile $StyleProfile
    $colorReset = $Colorize ? $StyleProfile.Reset : ""

    Write-Output "$($style.Ansi)$Path${colorReset}"
    
    # 4. Invalid path on valid drive → tree.com behavior
    if (-not (Test-Path $Path)) {
        # Check if it's a rooted path with a drive qualifier
        if ($drive) {
            $sub = $Path.Substring($drive.Length)
            Write-Output ($ui.InvalidPath -f $sub)
        } else {
            Write-Output ($ui.InvalidPath -f $Path)
        }
        Write-Output $ui.NoSubfolders
        return $false
    }

    return $true
}
