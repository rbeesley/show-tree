# src/Data/Localization/qps-PLOC.psd1

<#
.SYNOPSIS
    Pseudo-localized (Pig Latin) strings for Show-Tree.

.DESCRIPTION
    Contains Pig Latin translations for UI strings and error messages. Used 
    primarily for testing localization logic and string expansion.
#>
@{
    UIStrings = @{
        Legend = @{
            Header                  = 'Egendlay'
            HeaderUnderline         = '------'
            Types                   = 'Ypestay:'
            States                  = '  Atesstay:'
            File                    = 'Ilefay'
            Directory               = 'Irectoryday'
        }
        TreeMode = @{
            InvalidDrive            = 'Invalidyay ivedray ecificationspay'
            VolumeListing           = 'Olderfay ATHpay istinglay orfay olumevay {0}'
            VolumeSerial            = 'Olumevay erialsay umbernay isyay {0}'
            InvalidPath             = 'Invalidyay athpay - {0}'
            NoSubfolders            = 'Onay ubfolderssay existyay'
        }
        Errors = @{
            WindowsOnly             = "Odemay 'Eetray' isyay onlyyay upportedsay onyay Indowsway."
            ColorMonoConflict       = "Annotcay ecifyspay othbay -Olorcay andyay -Onomay."
            FilesConflict           = "Annotcay ecifyspay othbay -Ilesfay (oryay -OwfayIlesshay) andyay -Ofilesnay."
            HiddenConflict          = "Annotcay ecifyspay othbay -OwhayIddenhay andyay -IdehayIddenhay."
            SystemConflict          = "Annotcay ecifyspay othbay -OwhayYstemsay andyay -IdesayYstemsay."
            TargetsConflict         = "Annotcay ecifyspay othbay -OwhayArgetstay andyay -Otargetsnay."
            GapConflict             = "Annotcay ecifyspay othbay -Apgay andyay -Ogapay."
            CompatRequiresTree      = "Ethay -Ompatcay itchsway ancay onlyyay ebay usedyay ithway -Odemay Eetray."
            PlatformRequiresLegend  = "Ethay -Atformplay arameterpay isyay onlyyay alidvay ithway -Egendlay oryay -EgendlayAllyay."
            InvalidFormatInput      = "Ormatfay-Eetray expectsyay ShowTree.TreeRecord inputyay."
            MissingMetadata         = "Eetray ecordray '{0}' isyay issingmay ShowTree.TreeLayout etadatamay."
            MissingGapMetadata      = "Apgay ecordray isyay issingmay ShowTree.TreeLayout etadatamay."
            Win32WindowsOnly        = "In32way eetray ildchay oviderpray isyay onlyyay upportedsay onyay Indowsway."
            MissingGetChildren      = "Eetray ildchay oviderpray '{0}' oesday otnay efineday aay EtgayIldrenchay iptscrayockblay."
            MissingTreeItem         = "Eetray ecordray ypetay 'Item' equiresray aay TreeItem."
            MissingTreeLayout       = "Eetray ecordray equiresray aay ShowTree.TreeLayout ayoutlay objectyay."
            PathNotFound            = "Annotcay indfay athpay '{0}' ecausebay ityay oesday otnay existyay."
        }
    }
}