# src/Private/StyleProfile/Get-ShowTreeStyleProfile.ps1

<#
.SYNOPSIS
    Loads a style profile from disk or returns the default.

.DESCRIPTION
    The Get-ShowTreeStyleProfile cmdlet constructs a style profile by merging the base profile, 
    the default profile, localized strings for the requested culture, and an optional user profile from disk.
#>
function Get-ShowTreeStyleProfile {
    [CmdletBinding()]
    param(
        [string] $Path,
        [string] $Culture
    )

    if (-not $PSBoundParameters.ContainsKey('Debug'))
    {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }
    if (-not $PSBoundParameters.ContainsKey('Verbose'))
    {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    $baseProfile    = Import-PowerShellDataFile -LiteralPath $script:BaseStyleProfilePath
    $defaultProfile = Import-PowerShellDataFile -LiteralPath $script:DefaultStyleProfilePath

    $foundation = Merge-ShowTreeHashtable -Base $baseProfile -Override $defaultProfile

    #
    # Localization
    #
    if ([string]::IsNullOrWhiteSpace($Culture)) {
        $Culture = [System.Globalization.CultureInfo]::CurrentUICulture.Name
    }

    $localizationFolder = Join-Path (Split-Path $script:BaseStyleProfilePath) 'Localization'
    
    $culturesToTry = [System.Collections.Generic.List[string]]::new()
    $currentCulture = $Culture
    while ($currentCulture) {
        $culturesToTry.Add($currentCulture)
        if ($currentCulture -match '-') {
            $currentCulture = $currentCulture.Substring(0, $currentCulture.LastIndexOf('-'))
        }
        else {
            $currentCulture = $null
        }
    }

    foreach ($c in $culturesToTry) {
        $locPath = Join-Path $localizationFolder "$c.psd1"
        if (Test-Path -LiteralPath $locPath) {
            $localizedStrings = Import-PowerShellDataFile -LiteralPath $locPath
            $foundation = Merge-ShowTreeHashtable -Base $foundation -Override $localizedStrings
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Join-Path $HOME '.showtree\StyleProfile.psd1'
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        return $foundation
    }

    $userProfile = Import-PowerShellDataFile -LiteralPath $Path
    return Merge-ShowTreeHashtable -Base $foundation -Override $userProfile
}