# src/Private/PathUtilities/Resolve-TreePath.ps1

<#
.SYNOPSIS
    Resolves and validates a path for tree display.

.DESCRIPTION
    Resolve-TreePath ensures a given path is valid and accessible. It handles PowerShell 
    provider paths and ensures that drive-rooted paths are correctly resolved for 
    both Normal and legacy Tree modes.
#>
function Resolve-TreePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('Normal','Tree','List')]
        [string]$Mode = 'Normal'
    )

    if (-not $PSBoundParameters.ContainsKey('Debug'))
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose'))
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

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