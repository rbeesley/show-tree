# ShowTree.psm1

$sourceLayoutRoot = Join-Path $PSScriptRoot 'src'

if (Test-Path -LiteralPath $sourceLayoutRoot) {
    $moduleSrcRoot = $sourceLayoutRoot
}
else {
    $moduleSrcRoot = $PSScriptRoot
}

# Dot-source public functions
. (Join-Path $moduleSrcRoot 'Public\Format-Tree.ps1')
. (Join-Path $moduleSrcRoot 'Public\Get-TreeItem.ps1')
. (Join-Path $moduleSrcRoot 'Public\New-TreeItem.ps1')
. (Join-Path $moduleSrcRoot 'Public\Set-ShowTreeStyleProfile.ps1')
. (Join-Path $moduleSrcRoot 'Public\Show-Tree.ps1')
. (Join-Path $moduleSrcRoot 'Public\Show-TreeLegend.ps1')

# Dot-source private functions
. (Join-Path $moduleSrcRoot 'Private\TreeItemPredicates.ps1')
. (Join-Path $moduleSrcRoot 'Private\PathUtilities\Resolve-TreePath.ps1')
. (Join-Path $moduleSrcRoot 'Private\PathUtilities\Get-FileAttributes.ps1')
. (Join-Path $moduleSrcRoot 'Private\PathUtilities\Get-NearestExistingParent.ps1')
. (Join-Path $moduleSrcRoot 'Private\PathUtilities\Get-RawDirectoryEntries.ps1')
. (Join-Path $moduleSrcRoot 'Private\PathUtilities\Get-TreeModeHeader.ps1')
. (Join-Path $moduleSrcRoot 'Private\PathUtilities\Get-VolumeName.ps1')
. (Join-Path $moduleSrcRoot 'Private\PathUtilities\Get-VolumeSerialNumber.ps1')
. (Join-Path $moduleSrcRoot 'Private\Rendering\Get-Connector.ps1')
. (Join-Path $moduleSrcRoot 'Private\Rendering\Get-ItemStyle.ps1')
. (Join-Path $moduleSrcRoot 'Private\Rendering\Get-LegendStateNames.ps1')
. (Join-Path $moduleSrcRoot 'Private\StyleProfile\Get-ActiveShowTreeStyleProfile.ps1')
. (Join-Path $moduleSrcRoot 'Private\StyleProfile\Get-ShowTreeStyleProfile.ps1')
. (Join-Path $moduleSrcRoot 'Private\StyleProfile\Merge-ShowTreeHashtable.ps1')
. (Join-Path $moduleSrcRoot 'Private\Traversal\Get-ImmediateTreeChild.ps1')
. (Join-Path $moduleSrcRoot 'Private\Traversal\Invoke-TreeTraversal.ps1')
. (Join-Path $moduleSrcRoot 'Private\Traversal\New-TreeChildProvider.ps1')
. (Join-Path $moduleSrcRoot 'Private\Traversal\New-TreeLayout.ps1')
. (Join-Path $moduleSrcRoot 'Private\Traversal\New-TreeRecord.ps1')

# Load the style profiles
$script:BaseStyleProfilePath    = Join-Path $moduleSrcRoot 'Data\BaseStyleProfile.psd1'
$script:DefaultStyleProfilePath = Join-Path $moduleSrcRoot 'Data\DefaultStyleProfile.psd1'

$script:ShowTreeState = @{
    StyleProfile = $null
}

$script:ShowTreeState.StyleProfile = Get-ShowTreeStyleProfile

# <ShowTreeDistributionExportBlock>
# This block is rewritten when building the published distribution.
# Do not edit the content inside this block in generated dist files.
# Source builds intentionally discover public functions from src/Public.
$script:PublicFunctions = `
        Get-ChildItem -Path $PSScriptRoot `
            -Recurse `
            -Filter *.ps1 `
            -File `
            -PipelineVariable file `
            | ForEach-Object {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile( `
                $file.FullName, `
                    [ref] $null, `
                    [ref] $null)
    if ($ast.EndBlock.Statements.Name) {
        $ast.EndBlock.Statements.Name
    }
}
Export-ModuleMember -Function $script:PublicFunctions
# </ShowTreeDistributionExportBlock>