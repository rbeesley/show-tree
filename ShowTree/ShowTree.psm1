# ShowTree\ShowTree.psm1

# Dot-source internal and public functions
. $PSScriptRoot\Public\Show-Tree.ps1
. $PSScriptRoot\Private\Resolve-TreePath.ps1
. $PSScriptRoot\Private\Show-TreeInternal.ps1
. $PSScriptRoot\Private\Filtering.ps1
. $PSScriptRoot\Private\Rendering.ps1
. $PSScriptRoot\Private\GapLogicHelpers.ps1
. $PSScriptRoot\Private\PathUtilities.ps1
. $PSScriptRoot\Private\RawDirectoryEnumeration.ps1

# Export only the public function
Export-ModuleMember -Function Show-Tree