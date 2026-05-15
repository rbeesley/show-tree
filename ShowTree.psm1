# ShowTree.psm1

$sourceLayoutRoot = Join-Path $PSScriptRoot 'src'

if (Test-Path -LiteralPath $sourceLayoutRoot) {
    $moduleSrcRoot = $sourceLayoutRoot
}
else {
    $moduleSrcRoot = $PSScriptRoot
}

# Dot-source public functions
. (Join-Path $moduleSrcRoot 'Public\Show-Tree.ps1')
. (Join-Path $moduleSrcRoot 'Public\Show-TreeLegend.ps1')
. (Join-Path $moduleSrcRoot 'Public\Set-ShowTreeStyleProfile.ps1')

# Dot-source private functions
. (Join-Path $moduleSrcRoot 'Private\Get-ActiveShowTreeStyleProfile.ps1')
. (Join-Path $moduleSrcRoot 'Private\Get-FilteredTreeItems.ps1')
. (Join-Path $moduleSrcRoot 'Private\Get-RawDirectoryEntries.ps1')
. (Join-Path $moduleSrcRoot 'Private\Get-ShowTreeStyleProfile.ps1')
. (Join-Path $moduleSrcRoot 'Private\Merge-ShowTreeHashtable.ps1')
. (Join-Path $moduleSrcRoot 'Private\New-TreeItem.ps1')
. (Join-Path $moduleSrcRoot 'Private\PathUtilities\Resolve-TreePath.ps1')
. (Join-Path $moduleSrcRoot 'Private\PathUtilities\Get-SetFileAttributes.ps1')
. (Join-Path $moduleSrcRoot 'Private\PathUtilities\Get-NormalizedPath.ps1')
. (Join-Path $moduleSrcRoot 'Private\PathUtilities\Get-NearestExistingParent.ps1')
. (Join-Path $moduleSrcRoot 'Private\PathUtilities\Get-VolumeName.ps1')
. (Join-Path $moduleSrcRoot 'Private\PathUtilities\Get-VolumeSerialNumber.ps1')
. (Join-Path $moduleSrcRoot 'Private\Rendering\Get-Connector.ps1')
. (Join-Path $moduleSrcRoot 'Private\Rendering\Get-ItemStyle.ps1')
. (Join-Path $moduleSrcRoot 'Private\Rendering\Write-TreeItem.ps1')
. (Join-Path $moduleSrcRoot 'Private\Rendering\Write-Gap.ps1')
. (Join-Path $moduleSrcRoot 'Private\Show-TreeInternal.ps1')
. (Join-Path $moduleSrcRoot 'Private\Test-HasChildrenForGap.ps1')
. (Join-Path $moduleSrcRoot 'Private\Test-IsReparsePoint.ps1')

# Load the default style profile
$script:DefaultStyleProfilePath = Join-Path $moduleSrcRoot 'Data\DefaultStyleProfile.psd1'

$script:ShowTreeState = @{
    StyleProfile = $null
}

$script:ShowTreeState.StyleProfile = Import-PowerShellDataFile -LiteralPath $script:DefaultStyleProfilePath

# Export only the public function
Export-ModuleMember -Function Show-Tree, Show-TreeLegend, Set-ShowTreeStyleProfile
