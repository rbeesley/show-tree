# src/Data/Localization/fr.psd1

<#
.SYNOPSIS
    French localization strings for Show-Tree.

.DESCRIPTION
    Contains translated UI strings and error messages for the French (fr) culture.
    Note: This was machine translated. Please submit PRs for corrections.
#>
@{
    UIStrings = @{
        Legend = @{
            Header                  = 'Légende'
            HeaderUnderline         = '-------'
            Types                   = 'Types :'
            States                  = '  États :'
            File                    = 'Fichier'
            Directory               = 'Dossier'
        }
        TreeMode = @{
            InvalidDrive            = 'Spécification de lecteur non valide'
            VolumeListing           = 'Liste des CHEMINS de dossiers pour le volume {0}'
            VolumeSerial            = 'Le numéro de série du volume est {0}'
            InvalidPath             = 'Chemin non valide - {0}'
            NoSubfolders            = "Il n'existe aucun sous-dossier"
        }
        Errors = @{
            WindowsOnly             = "Le mode 'Tree' n'est pris en charge que sur Windows."
            ColorMonoConflict       = 'Impossible de spécifier à la fois -Color et -Mono.'
            FilesConflict           = 'Impossible de spécifier à la fois -Files (ou -ShowFiles) et -NoFiles.'
            HiddenConflict          = 'Impossible de spécifier à la fois -ShowHidden et -HideHidden.'
            SystemConflict          = 'Impossible de spécifier à la fois -ShowSystem et -HideSystem.'
            TargetsConflict         = 'Impossible de spécifier à la fois -ShowTargets et -NoTargets.'
            GapConflict             = 'Impossible de spécifier à la fois -Gap et -NoGap.'
            CompatRequiresTree      = "Le commutateur -Compat ne peut être utilisé qu'avec -Mode Tree."
            PlatformRequiresLegend  = 'Le paramètre -Platform est uniquement valide avec -Legend ou -LegendAll.'
            InvalidFormatInput      = "Format-Tree attend une entrée de type ShowTree.TreeRecord."
            MissingMetadata         = "L'enregistrement d'arborescence '{0}' manque de métadonnées ShowTree.TreeLayout."
            MissingGapMetadata      = "L'enregistrement d'espacement manque de métadonnées ShowTree.TreeLayout."
            Win32WindowsOnly        = "Le fournisseur d'enfants d'arborescence Win32 est pris en charge uniquement sur Windows."
            MissingGetChildren      = "Le fournisseur d'enfants d'arborescence '{0}' ne définit pas de bloc de script GetChildren."
            MissingTreeItem         = "Le type d'enregistrement d'arborescence 'Item' nécessite un TreeItem."
            MissingTreeLayout       = "L'enregistrement d'arborescence nécessite un objet de mise en page ShowTree.TreeLayout."
            PathNotFound            = "Impossible de trouver le chemin '{0}' car il n'existe pas."
        }
    }
}
