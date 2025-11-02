
# PSXmpDateInjector

PSXmpDateInjector adds XMP creation date metadata to image files by parsing timestamps from their file names and invoking exiftool to update the XMP `exif:DateTimeOriginal`, `photoshop:DateCreated`, and `xmp:CreateDate` tags. These tags are the same ones Lightroom Classic rewrites when you adjust a photo’s Capture Time, so keeping them synchronized preserves compatibility with Lightroom’s date handling.

## Requirements

- Windows PowerShell 5.1
- Install `exiftool` separately or ensure it is available on the system `PATH`. When it is not on `PATH`, pass `-ExifToolPath` to point at your copy of the executable. (The repository intentionally does not bundle the binary.)

## Usage

### Run via the helper script

```powershell
scripts\AddImageXmpDateMetadata.ps1 -InputPath "D:\My Screenshots"
```

### with optional JSON configuration

```powershell
scripts\AddImageXmpDateMetadata.ps1 -ConfigJsonPath .\scripts\config_sample.json -Passthru
```

`scripts\config_sample.json` illustrates the available keys (`InputPath`, `Recurse`, `Passthru`, `ExifToolPath`, `OutputDirectory`). Values supplied on the command line always override values from the JSON file.

### Use the CMD launcher

```cmd
scripts\cmd\AddImageXmpDateMetadata.cmd "D:\My Screenshots" -Recurse -ExifToolPath "C:\Program Files\Exiftool\exiftool.exe"
```

Use `-WhatIf` to review the planned updates without writing metadata, `-Passthru` to emit processing results to the pipeline, `-OutputDirectory` to stage changes in another folder, and `-ExifToolPath` when you need to target a specific exiftool binary.

### Use exiftool from the system `PATH`

```powershell
Import-Module (Join-Path $PSScriptRoot 'PSXmpDateInjector.psd1') -Force
Add-ImageXmpDateMetadata -InputPath .ssets -Recurse -Verbose
```

### Point to a specific exiftool executable

```powershell
Import-Module (Join-Path (Get-Location) 'PSXmpDateInjector.psd1') -Force
$exifTool = 'C:	ools\exiftool\exiftool.exe'
Add-ImageXmpDateMetadata -InputPath .ssets -Recurse -Passthru -ExifToolPath $exifTool
```

### Write results into a separate directory

```powershell
Import-Module (Join-Path $PSScriptRoot 'PSXmpDateInjector.psd1') -Force
Add-ImageXmpDateMetadata -InputPath .\assets -Recurse -OutputDirectory .\out -ExifToolPath 'C:\Program Files\Exiftool\exiftool.exe'
```

## Testing

Execute the Pester test suite (requires Pester v5):

```powershell
Invoke-Pester -CI
```

Run tests on Windows PowerShell 5.1 to match the module's target environment. The test suite copies sample images into `assets\dest`; the directory is cleared before each run but left populated afterwards for inspection.
