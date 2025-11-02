
# PSXmpDateInjector

PSXmpDateInjector adds XMP creation date metadata to image files by parsing timestamps from their file names and invoking exiftool to update the XMP `exif:DateTimeOriginal`, `photoshop:DateCreated`, and `xmp:CreateDate` tags.

## Requirements

- Windows PowerShell 5.1
- `exiftool` available on the system `PATH`, or provide `-ExifToolPath` to point at `bin\exiftool.exe` (bundled with the repository).

## Usage

### Use exiftool from the system `PATH`

```powershell
Import-Module (Join-Path $PSScriptRoot 'PSXmpDateInjector.psd1') -Force
Add-ImageXmpDateMetadata -InputPath .\assets -Recurse -Verbose
```

### Use the bundled exiftool executable

```powershell
$repoRoot = Get-Location
Import-Module (Join-Path $repoRoot 'PSXmpDateInjector.psd1') -Force
$exifTool = Join-Path $repoRoot 'bin\exiftool.exe'
Add-ImageXmpDateMetadata -InputPath .\assets -Recurse -Passthru -ExifToolPath $exifTool
```

### Run via the helper script

```powershell
scripts\AddImageXmpDateMetadata.ps1 -InputPath .\assets -Recurse -Passthru -ExifToolPath (Join-Path (Get-Location) 'bin\exiftool.exe')
```

### Use the CMD launcher

```cmd
scripts\cmd\AddImageXmpDateMetadata.cmd .\assets -Recurse -Passthru -ExifToolPath .\bin\exiftool.exe
```

Use `-WhatIf` to review the planned updates without writing metadata, `-Passthru` to emit processing results to the pipeline, and `-ExifToolPath` when you need to target a specific exiftool binary.

## Testing

Execute the Pester test suite (requires Pester v5):

```powershell
Invoke-Pester -CI
```

Run tests on Windows PowerShell 5.1 to match the module's target environment. The test suite copies sample images into `assets\dest`; the directory is cleared before each run but left populated afterwards for inspection.
