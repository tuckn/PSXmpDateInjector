
# PSMetaDataInjector

PSMetaDataInjector adds metadata to files by parsing timestamps from their names (when requested) so that capture dates stay in sync with Lightroom Classic’s “Capture Time” adjustments. The module can also write descriptive metadata—titles, descriptions, keywords—and even seed Markdown frontmatter so every format the workflow touches carries the same information Lightroom updates when you edit those fields.

## Requirements

- Windows PowerShell 5.1
- A local copy of `exiftool`. Install it separately and either add it to your `PATH` or pass `-ExifToolPath` to point at the executable. (The binary is intentionally not bundled in this repository.)

## Usage

### Import the module and use the system `PATH`

```powershell
Import-Module (Join-Path $PSScriptRoot 'PSMetaDataInjector.psd1') -Force
Set-MediaMetadata -InputPath .\assets -InferCreatedDate -Recurse -Verbose
```

- `-InferCreatedDate` tells the module to derive timestamps from file names (using the supported screenshot/numeric patterns).
- `-CreatedDate` supplies an explicit fallback timestamp; when both switches are provided, inference runs first and the fallback is only used when parsing fails.

### Point to a specific exiftool executable

```powershell
$repoRoot = Get-Location
Import-Module (Join-Path $repoRoot 'PSMetaDataInjector.psd1') -Force
$exifTool = 'C:\tools\exiftool\exiftool.exe'
Set-MediaMetadata -InputPath .\assets -InferCreatedDate -Recurse -Passthru -ExifToolPath $exifTool
```

### Stage the updated files in a separate directory

```powershell
Set-MediaMetadata -InputPath .\assets -InferCreatedDate -Recurse -OutputDirectory .\out -ExifToolPath 'C:\tools\exiftool\exiftool.exe'
```

### Apply custom titles and keywords

```powershell
Set-MediaMetadata -InputPath .\assets -InferCreatedDate -Title 'Kyoto Sunrise' -Description 'Trip summary' -Keywords 'travel','kyoto','temple' -Recurse -ExifToolPath 'C:\tools\exiftool\exiftool.exe'
```

Hierarchical keywords use Lightroom's pipe syntax (`Parent|Child|Leaf`). For example:

```powershell
Set-MediaMetadata -InputPath .\assets -InferCreatedDate -Keywords 'IT (information technology)|programming language|JavaScript', 'IT (information technology)|programming language|JavaScript|React', 'IT (information technology)|software|application|WinMerge'
```

This produces the expected XMP fragments (dc:Subject, lr:weightedFlatSubject, and lr:hierarchicalSubject) shown in Lightroom's metadata inspector.

### Write Markdown frontmatter

Use `Set-MarkdownFrontmatter` when you need to seed Markdown files (for example, blog posts) with the same metadata. The cmdlet always emits/updates a `noteId` GUID (preserving the existing value when present) along with title, description, date, and tags:

```powershell
Set-MarkdownFrontmatter -Path .\posts\git-core-autocrlf.md `
                        -Title 'git.exeがcore.autocrlfを無視する' `
                        -Description '' `
                        -Date (Get-Date '2018-01-30') `
                        -Tags 'JavaScript','React','WinMerge'
```

The function replaces any existing block delimited by `---` and rewrites the file using UTF-8 with BOM so static-site generators can ingest it immediately.

### Run via the helper script (with optional JSON configuration)

```powershell
scripts\SetMediaMetadata.ps1 -ConfigJsonPath .\scripts\config_sample.json -Passthru
```

`scripts\config_sample.json` showcases every supported key:

```json
{
  "InputPath": "../assets",
  "ExifToolPath": "C:/tools/exiftool/exiftool.exe",
  "OutputDirectory": "../tests/dest",
  "CreatedDate": "2025-01-01T00:00:00",
  "InferCreatedDate": true,
  "Title": "Sample Title",
  "Description": "Optional description stored with the image.",
  "Keywords": ["travel", "night"],
  "Recurse": true,
  "Passthru": false
}
```

Values supplied on the command line always override values supplied in the JSON file.

### Use the CMD launcher

```cmd
scripts\cmd\SetMediaMetadata.cmd "D:\My Screenshots" -Recurse -InferCreatedDate -ExifToolPath "C:\tools\exiftool\exiftool.exe"
```

Use `-WhatIf` to see what would be changed without writing metadata, `-Passthru` to emit rich objects describing each updated file, `-OutputDirectory` to stage the edits elsewhere, `-Title`/`-Keywords` to push descriptive metadata, and `-ExifToolPath` to target any specific exiftool binary.

## Testing

```powershell
Invoke-Pester -CI
```

Run tests on Windows PowerShell 5.1 to match the target environment. The suite copies sample images into `tests\dest`; it clears the directory before each run but leaves the files in place afterward for inspection.

### Integration test (real exiftool writes)

Use this when you want to confirm end-to-end metadata writes instead of relying on the mocked exiftool calls inside the Pester suite:

```powershell
$repo   = Get-Location
$assets = Join-Path $repo 'assets'
$tests = Join-Path $repo 'tests'
$dest   = Join-Path $tests 'dest'
Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $dest -Force | Out-Null

Get-ChildItem -LiteralPath $assets -Force | Where-Object { $_.Name -ne 'dest' } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
}

Import-Module (Join-Path $repo 'PSMetaDataInjector.psd1') -Force
Set-MediaMetadata -InputPath $assets `
                  -InferCreatedDate `
                  -OutputDirectory $dest `
                  -Recurse `
                  -Title 'Sample Title' `
                  -Description 'Optional description stored with the image.' `
                  -Keywords 'JavaScript','React','WinMerge' `
                  -ExifToolPath $exifTool `
                  -Confirm:$false -Verbose
```

Then inspect any output file with exiftool to verify the expected tags:

```powershell
& (Join-Path $repo 'bin/exiftool.exe') -G -XMP:DateTimeOriginal -XMP:Headline -XMP:Subject (Join-Path $dest '20130630T023600+0900.jpg')
```

This procedure runs against actual files, so undo changes as needed (for example by deleting `tests\dest`) before rerunning the unit test suite.
