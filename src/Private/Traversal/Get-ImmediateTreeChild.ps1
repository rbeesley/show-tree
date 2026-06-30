# src/Private/Traversal/Get-ImmediateTreeChild.ps1

<#
.SYNOPSIS
    Enumerates the immediate children of a path.

.DESCRIPTION
    Get-ImmediateTreeChild uses the provided TreeChildProvider to fetch the files and 
    directories directly under a path. It applies immediate filtering (like HideHidden) 
    and sorts the results (usually files before directories) before returning them 
    to the traversal engine.
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

    if (-not $PSBoundParameters.ContainsKey('Debug'))
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose'))
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

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
