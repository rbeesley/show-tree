# ShowTree\ShowTree.psm1

# Dot-source internal and public functions
. $PSScriptRoot\Private\Show-TreeInternal.ps1
. $PSScriptRoot\Public\Show-Tree.ps1

# Export only the public function
Export-ModuleMember -Function Show-Tree