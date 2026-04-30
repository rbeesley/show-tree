function Resolve-TreePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('Normal','Tree','List')]
        [string]$Mode = 'Normal'
    )

    try {
        # Normalize path casing and separators
        $Path = Get-NormalizedPath -Path $Path -ErrorAction Stop

        # If normalization returned a relative path, re-root it
        # Expand relative paths safely ('.', '..', '.\foo', etc.)
        if (-not [System.IO.Path]::IsPathRooted($Path)) {
            $Path = Join-Path -Path (Get-Location).ProviderPath -ChildPath $Path
        }

        # Resolve to provider path
        $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        return $resolved.ProviderPath
    }
    catch {
        # For Tree mode, we have a different method of reporting a failure because we're trying to
        # recreate the same error messaging as tree.com. This will be handled by the next script block.
        if ($Mode -ne 'Tree') {
            # PowerShell-style error
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

        # Tree.com mode: caller handles invalid path
        return $Path
    }
}
