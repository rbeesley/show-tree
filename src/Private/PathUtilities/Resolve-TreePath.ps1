# src/Private/PathUtilities/Resolve-TreePath.ps1

<#
.SYNOPSIS
    Resolves a user-supplied path into a fully qualified provider path.

.DESCRIPTION
    The Resolve-TreePath cmdlet converts user input into a canonical provider path. 
    It handles caller-relative resolution, normalization, and mode-specific error behavior 
    (Normal/List vs. Tree mode).
#>
function Resolve-TreePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('Normal','Tree','List')]
        [string]$Mode = 'Normal'
    )

    try {
        # Use the caller/runspace working directory, not the module session state's location.
        $cwd = $PWD.ProviderPath

        if (-not [System.IO.Path]::IsPathRooted($Path)) {
            $Path = Join-Path -Path $cwd -ChildPath $Path
        }

        # Resolve to provider path
        $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        return $resolved.ProviderPath
    }
    catch {
        if ($Mode -ne 'Tree') {
            $msg = "Cannot find path '$Path' because it does not exist."
            $exception = New-Object System.Management.Automation.ItemNotFoundException $msg
            $category  = [System.Management.Automation.ErrorCategory]::ObjectNotFound
            
            $errorRecord = New-Object System.Management.Automation.ErrorRecord `
                $exception,
                'ItemNotFound',
                $category,
                $Path

            $PSCmdlet.WriteError($errorRecord)
            return $null
        }

        return $Path
    }
}