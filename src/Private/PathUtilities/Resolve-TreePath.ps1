# src/Private/PathUtilities/Resolve-TreePath.ps1

<#
.SYNOPSIS
    Resolves a user-supplied path into a fully qualified provider path with
    correct caller-relative behavior, normalization, and mode-specific error handling.
.DESCRIPTION
    Resolve-TreePath converts user input (relative paths, absolute paths, and
    mixed-case paths) into a canonical provider path suitable for tree rendering.

    The function performs three key operations:

      • Caller-relative resolution  
        Relative paths such as '.', '..', and '.\foo' are resolved against the
        caller's working directory, not the module's import location.

      • Normalization  
        The resulting path is normalized segment-by-segment to match actual
        filesystem casing and to collapse constructs like '..' and redundant
        separators.

      • Mode-specific error behavior  
        In Normal and List modes, nonexistent paths produce a PowerShell-style
        ItemNotFound error.  
        In Tree mode, nonexistent paths are returned verbatim so that the caller
        can reproduce tree.com’s error messages exactly.

    The returned value is always a fully qualified provider path unless the
    path does not exist and Tree mode is active.
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