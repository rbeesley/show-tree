# ShowTree.psm1

$moduleSrcRoot = Join-Path $PSScriptRoot 'src'

# Dot-source public functions
. $moduleSrcRoot\Public\Show-Tree.ps1
. $moduleSrcRoot\Public\Show-TreeLegend.ps1
. $moduleSrcRoot\Public\Set-ShowTreeStyleProfile.ps1

# Dot-source private functions
. $moduleSrcRoot\Private\Get-ActiveShowTreeStyleProfile.ps1
. $moduleSrcRoot\Private\Get-FilteredTreeItems.ps1
. $moduleSrcRoot\Private\Get-RawDirectoryEntries.ps1
. $moduleSrcRoot\Private\Get-ShowTreeStyleProfile.ps1
. $moduleSrcRoot\Private\Merge-ShowTreeHashtable.ps1
. $moduleSrcRoot\Private\New-TreeItem.ps1
. $moduleSrcRoot\Private\PathUtilities\Resolve-TreePath.ps1
. $moduleSrcRoot\Private\PathUtilities\Get-SetFileAttributes.ps1
. $moduleSrcRoot\Private\PathUtilities\Get-NormalizedPath.ps1
. $moduleSrcRoot\Private\PathUtilities\Get-NearestExistingParent.ps1
. $moduleSrcRoot\Private\PathUtilities\Get-VolumeName.ps1
. $moduleSrcRoot\Private\PathUtilities\Get-VolumeSerialNumber.ps1
. $moduleSrcRoot\Private\Rendering\Get-Connector.ps1
. $moduleSrcRoot\Private\Rendering\Get-ItemStyle.ps1
. $moduleSrcRoot\Private\Rendering\Write-TreeItem.ps1
. $moduleSrcRoot\Private\Rendering\Write-Gap.ps1
. $moduleSrcRoot\Private\Show-TreeInternal.ps1
. $moduleSrcRoot\Private\Test-HasChildrenForGap.ps1
. $moduleSrcRoot\Private\Test-IsReparsePoint.ps1

# Load the default style profile
$script:DefaultStyleProfilePath = Join-Path $moduleSrcRoot 'Data\DefaultStyleProfile.psd1'

$script:ShowTreeState = @{
    StyleProfile = $null
}

$script:ShowTreeState.StyleProfile = Import-PowerShellDataFile -LiteralPath $script:DefaultStyleProfilePath

# Export only the public function
Export-ModuleMember -Function Show-Tree, Show-TreeLegend, Set-ShowTreeStyleProfile
