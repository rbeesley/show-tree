# src/Private/Traversal/Get-ImmediateTreeChild.ps1

<#
.SYNOPSIS
    Gets the visible immediate children for a single tree traversal step.

.DESCRIPTION
    The Get-ImmediateTreeChild cmdlet enumerates only the direct children of Path using the supplied child provider.
    It applies visibility and filtering rules (Include, Exclude, Hidden, System) and returns the visible sibling group.
    This function does not recurse; recursion is handled by Invoke-TreeTraversal.
#>
function Get-ImmediateTreeChild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [string] $RootPath,

        [int] $Depth = 0,

        [Parameter(Mandatory)]
        [object] $Provider,

        [string[]] $Include,
        [string[]] $Exclude,

        [switch] $HideHidden,
        [switch] $HideSystem,
        [switch] $DirectoryOnly
    )

    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        $RootPath = $Path
    }

    if ($null -eq $Provider.GetChildren) {
        throw "Tree child provider '$($Provider.Name)' does not define a GetChildren scriptblock."
    }

    $raw = & $Provider.GetChildren $Path $Depth

    if ($null -eq $raw) {
        return
    }

    foreach ($item in @($raw.Files)) {
        if (Test-TreeItemVisible `
                -Item $item `
                -Include $Include `
                -Exclude $Exclude `
                -RootPath $RootPath `
                -HideHidden:$HideHidden `
                -HideSystem:$HideSystem `
                -DirectoryOnly:$DirectoryOnly) {
            $item
        }
    }

    foreach ($item in @($raw.Directories)) {
        if (Test-TreeItemVisible `
                -Item $item `
                -Include $Include `
                -Exclude $Exclude `
                -RootPath $RootPath `
                -HideHidden:$HideHidden `
                -HideSystem:$HideSystem `
                -DirectoryOnly:$DirectoryOnly) {
            $item
        }
    }
}
