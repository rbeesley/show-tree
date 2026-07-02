# src/Private/Traversal/Get-TreeChild.ps1

<#
.SYNOPSIS
    Enumerates the children of a path.

.DESCRIPTION
    Get-TreeChild uses the provided TreeChildProvider to fetch the files and 
    directories directly under a path. It applies filtering (like HideHidden) 
    and returns the visible items to the traversal engine.
#>
function Get-TreeChild {
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

    if (-not $PSBoundParameters.ContainsKey('Debug') -and $PSCmdlet)
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose') -and $PSCmdlet)
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        $RootPath = $Path
    }

    if ($null -eq $Provider.GetChildren) {
        $styleProfile = Get-ActiveShowTreeStyleProfile
        throw ($styleProfile.UIStrings.Errors.MissingGetChildren -f $Provider.Name)
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
