# src/Private/PathUtilities/Get-VolumeName.ps1

<#
.SYNOPSIS
    Returns the filesystem label for a drive.

.DESCRIPTION
    The Get-VolumeName cmdlet retrieves the filesystem label (volume name) for the drive associated
    with the specified path. Used only in Tree.com compatibility mode. 
#>
function Get-VolumeName {
    param([string]$Path = ".")

    $driveLetter = (Get-Item $Path).PSDrive.Name
    $volume      = Get-Volume -DriveLetter $driveLetter
    $volume.FileSystemLabel
}
