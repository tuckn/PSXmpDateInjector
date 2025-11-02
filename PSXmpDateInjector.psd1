
@{
    RootModule           = 'PSXmpDateInjector.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '2a894c3c-8895-40bd-9ad4-4d5341930c1b'
    Author               = 'Tuckn'
    CompanyName          = 'Unknown'
    Copyright            = '(c) 2025 Tuckn. All rights reserved.'
    Description          = 'Injects XMP creation dates into image files based on their names.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop')
    NestedModules        = @(
        'modules/AddImageXmpDateMetadata.psm1'
    )
    FunctionsToExport    = @('Add-ImageXmpDateMetadata', 'Get-DateFromFileName')
    CmdletsToExport      = @()
    AliasesToExport      = @()
    VariablesToExport    = @()
    PrivateData          = @{
        PSData = @{
            Tags       = @('exif','xmp','metadata','images','powershell-module')
            ProjectUri = 'https://github.com/tuckn/PSXmpDateInjector'
            LicenseUri = 'https://github.com/tuckn/PSXmpDateInjector/blob/main/LICENSE'
        }
    }
}
