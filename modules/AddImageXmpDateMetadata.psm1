
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Get-DateFromFileName {
    [OutputType([Nullable[datetime]])]
    param(
        [Parameter(Mandatory)]
        [string] $FileName
    )

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $nameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($FileName)

    if (-not $nameWithoutExtension) {
        return $null
    }

    $patterns = @(
        @{
            Regex = [regex]::new('(?<year>\d{4})(?<month>\d{2})(?<day>\d{2})T(?<hour>\d{2})(?<minute>\d{2})(?<second>\d{2})(?<offset>[+-]\d{4})?', [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
            Handler = {
                param($match, $cultureInfo, $fileName)
                $year = $match.Groups['year'].Value
                $month = $match.Groups['month'].Value
                $day = $match.Groups['day'].Value
                $hour = $match.Groups['hour'].Value
                $minute = $match.Groups['minute'].Value
                $second = $match.Groups['second'].Value

                if ($match.Groups['offset'].Success) {
                    Write-Verbose ("Ignoring UTC offset '{0}' in '{1}'." -f $match.Groups['offset'].Value, $fileName)
                }

                $dateTimeString = '{0}{1}{2}{3}{4}{5}' -f $year, $month, $day, $hour, $minute, $second
                return [datetime]::ParseExact($dateTimeString, 'yyyyMMddHHmmss', $cultureInfo)
            }
        },
        @{
            Regex = [regex]::new('(?<year>\d{4})(?<month>\d{2})(?<day>\d{2})(?<hour>\d{2})(?<minute>\d{2})(?<second>\d{2})', [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
            Handler = {
                param($match, $cultureInfo, $fileName)
                $year = $match.Groups['year'].Value
                $month = $match.Groups['month'].Value
                $day = $match.Groups['day'].Value
                $hour = $match.Groups['hour'].Value
                $minute = $match.Groups['minute'].Value
                $second = $match.Groups['second'].Value

                $dateTimeString = '{0}{1}{2}{3}{4}{5}' -f $year, $month, $day, $hour, $minute, $second
                return [datetime]::ParseExact($dateTimeString, 'yyyyMMddHHmmss', $cultureInfo)
            }
        },
        @{
            Regex = [regex]::new('(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})[ _-](?<time>\d{6})', [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
            Handler = {
                param($match, $cultureInfo, $fileName)
                $year = $match.Groups['year'].Value
                $month = $match.Groups['month'].Value
                $day = $match.Groups['day'].Value
                $time = $match.Groups['time'].Value

                $dateTimeString = '{0}-{1}-{2} {3}' -f $year, $month, $day, $time
                return [datetime]::ParseExact($dateTimeString, 'yyyy-MM-dd HHmmss', $cultureInfo)
            }
        },
        @{
            Regex = [regex]::new('(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})[ _-](?<hour>\d{2})[-_ ](?<minute>\d{2})[-_ ](?<second>\d{2})', [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
            Handler = {
                param($match, $cultureInfo, $fileName)
                $year = $match.Groups['year'].Value
                $month = $match.Groups['month'].Value
                $day = $match.Groups['day'].Value
                $hour = $match.Groups['hour'].Value
                $minute = $match.Groups['minute'].Value
                $second = $match.Groups['second'].Value

                $dateTimeString = '{0}-{1}-{2} {3}{4}{5}' -f $year, $month, $day, $hour, $minute, $second
                return [datetime]::ParseExact($dateTimeString, 'yyyy-MM-dd HHmmss', $cultureInfo)
            }
        },
        @{
            Regex = [regex]::new('(?<day>\d{2})_(?<month>\d{2})_(?<year>\d{4})_(?<hour>\d{2})_(?<minute>\d{2})_(?<second>\d{2})', [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
            Handler = {
                param($match, $cultureInfo, $fileName)
                $year = $match.Groups['year'].Value
                $month = $match.Groups['month'].Value
                $day = $match.Groups['day'].Value
                $hour = $match.Groups['hour'].Value
                $minute = $match.Groups['minute'].Value
                $second = $match.Groups['second'].Value

                $dateTimeString = '{0}-{1}-{2} {3}{4}{5}' -f $year, $month, $day, $hour, $minute, $second
                return [datetime]::ParseExact($dateTimeString, 'yyyy-MM-dd HHmmss', $cultureInfo)
            }
        }
    )

    foreach ($pattern in $patterns) {
        $match = $pattern.Regex.Match($nameWithoutExtension)
        if ($match.Success) {
            try {
                return & $pattern.Handler $match $culture $nameWithoutExtension
            }
            catch {
                Write-Verbose ("Failed to parse '{0}' with pattern '{1}': {2}" -f $nameWithoutExtension, $pattern.Regex.ToString(), $_.Exception.Message)
            }
        }
    }

    return $null
}

function Invoke-PSXmpDateInjectorExifTool {
    param(
        [Parameter(Mandatory)]
        [string] $ExecutablePath,

        [Parameter(Mandatory)]
        [string[]] $Arguments
    )

    & $ExecutablePath @Arguments
    return $LASTEXITCODE
}



function Add-ImageXmpDateMetadata {
<#
.SYNOPSIS
Adds XMP creation date metadata to image files based on timestamps embedded in their names.

.DESCRIPTION
The Add-ImageXmpDateMetadata function scans image file names for supported timestamp patterns, extracts the date and time, and writes the value to XMP-exif:DateTimeOriginal, XMP-photoshop:DateCreated, and XMP-xmp:CreateDate using exiftool. The function accepts a single image file or a directory that contains image files and can optionally recurse into subdirectories. Metadata is only written when a supported timestamp pattern is found.

.PARAMETER InputPath
Specifies the path to a single image file or a directory that contains image files. Wildcards are supported. The parameter also accepts values from the pipeline.

.PARAMETER Recurse
When InputPath is a directory, include image files from all child directories.

.PARAMETER Passthru
Outputs an object describing each updated file to the pipeline.

.PARAMETER ExifToolPath
Provides the path to the exiftool executable. When omitted, the function searches for exiftool on the PATH.

.PARAMETER OutputDirectory
Specifies a directory where processed files are written. When provided, source files are copied to the directory (preserving relative structure for directory inputs) before metadata is updated. When omitted, files are updated in place.

.EXAMPLE
Add-ImageXmpDateMetadata -InputPath (Join-Path $PWD 'assets') -Recurse -Verbose -ExifToolPath 'C:\tools\exiftool\exiftool.exe'

Processes every supported image beneath the assets directory, recursing into child folders, and writes XMP creation date metadata using the specified exiftool.

.EXAMPLE
Add-ImageXmpDateMetadata -InputPath (Join-Path $PWD 'assets') -OutputDirectory (Join-Path $PWD 'out') -Recurse -Passthru -ExifToolPath 'C:\tools\exiftool\exiftool.exe'

Copies supported images to the out directory, preserving their relative structure, updates XMP creation date metadata, and outputs information about the processed files.

.EXAMPLE
Get-ChildItem -Path (Join-Path $PWD 'assets') -Filter '*0900.jpg' | Add-ImageXmpDateMetadata -Passthru

Pipes matching image files to the function and outputs the files that were updated.
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string] $InputPath,

        [switch] $Recurse,

        [switch] $Passthru,

        [ValidateNotNullOrEmpty()]
        [string] $ExifToolPath,

        [ValidateNotNullOrEmpty()]
        [string] $OutputDirectory
    )

    begin {
        $supportedExtensions = @(
            '.jpg', '.jpeg', '.png', '.tif', '.tiff', '.bmp', '.gif',
            '.heic', '.heif', '.webp', '.dng', '.nef', '.cr2', '.cr3', '.arw'
        )

        $culture = [System.Globalization.CultureInfo]::InvariantCulture
        $resolvedExifToolPath = $null
        $resolvedOutputDirectory = $null

        if ($PSBoundParameters.ContainsKey('ExifToolPath')) {
            try {
                $resolvedExifToolPath = (Resolve-Path -LiteralPath $ExifToolPath -ErrorAction Stop).ProviderPath
            }
            catch {
                throw ("The specified exiftool path '{0}' could not be resolved: {1}" -f $ExifToolPath, $_.Exception.Message)
            }
        }
        else {
            $command = Get-Command -Name 'exiftool' -ErrorAction SilentlyContinue
            if (-not $command) {
                $command = Get-Command -Name 'exiftool.exe' -ErrorAction SilentlyContinue
            }

            if (-not $command) {
                throw 'exiftool was not found on PATH. Provide -ExifToolPath or install exiftool.'
            }

            $resolvedExifToolPath = $command.Path
        }

        if ($PSBoundParameters.ContainsKey('OutputDirectory')) {
            try {
                $resolvedOutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory -ErrorAction Stop).ProviderPath
            }
            catch {
                throw ("The specified output directory '{0}' could not be resolved: {1}" -f $OutputDirectory, $_.Exception.Message)
            }

            if (-not (Test-Path -LiteralPath $resolvedOutputDirectory -PathType Container)) {
                try {
                    New-Item -ItemType Directory -Path $resolvedOutputDirectory -Force | Out-Null
                }
                catch {
                    throw ("Failed to create output directory '{0}': {1}" -f $resolvedOutputDirectory, $_.Exception.Message)
                }
            }
        }

        if (-not (Test-Path -LiteralPath $resolvedExifToolPath -PathType Leaf)) {
            throw ("Resolved exiftool path '{0}' is not a file." -f $resolvedExifToolPath)
        }

        $script:PSXmpDateInjector_ExifToolPath = $resolvedExifToolPath
        $script:PSXmpDateInjector_OutputDirectory = $resolvedOutputDirectory
        $script:PSXmpDateInjector_InputRoot = $null
    }

    process {
        Write-Verbose ("Resolving input path '{0}'." -f $InputPath)

        $resolvedPaths = @()

        try {
            $resolvedPaths = Resolve-Path -Path $InputPath -ErrorAction Stop
        }
        catch {
            Write-Error ("Input path '{0}' could not be resolved: {1}" -f $InputPath, $_.Exception.Message)
            return
        }

        foreach ($resolvedPath in $resolvedPaths) {
            try {
                $item = Get-Item -LiteralPath $resolvedPath.Path -ErrorAction Stop
            }
            catch {
                Write-Error ("Failed to retrieve '{0}': {1}" -f $resolvedPath.Path, $_.Exception.Message)
                continue
            }

            $filesToProcess = @()

            if ($item.PSIsContainer) {
                $script:PSXmpDateInjector_InputRoot = $item.FullName

                $searchParameters = @{
                    LiteralPath = $item.FullName
                    File        = $true
                    ErrorAction = 'Stop'
                }

                if ($Recurse.IsPresent) {
                    $searchParameters['Recurse'] = $true
                }

                try {
                    $filesToProcess = Get-ChildItem @searchParameters | Where-Object {
                        $supportedExtensions -contains ([System.IO.Path]::GetExtension($_.Name).ToLowerInvariant())
                    }
                }
                catch {
                    Write-Error ("Failed to enumerate files in '{0}': {1}" -f $item.FullName, $_.Exception.Message)
                    continue
                }

                if (-not $filesToProcess) {
                    Write-Verbose ("No supported image files were found in '{0}'." -f $item.FullName)
                    continue
                }
            }
            else {
                if (-not $script:PSXmpDateInjector_InputRoot) {
                    $script:PSXmpDateInjector_InputRoot = [System.IO.Path]::GetDirectoryName($item.FullName)
                }

                $extension = [System.IO.Path]::GetExtension($item.Name).ToLowerInvariant()

                if ($supportedExtensions -contains $extension) {
                    $filesToProcess = @($item)
                }
                else {
                    Write-Verbose ("Skipping '{0}' because extension '{1}' is not supported." -f $item.FullName, $extension)
                    continue
                }
            }

            foreach ($file in $filesToProcess) {
                Write-Verbose ("Processing file '{0}'." -f $file.FullName)
                $timestamp = Get-DateFromFileName -FileName $file.Name

                if (-not $timestamp) {
                    Write-Warning ("Skipping '{0}' because no supported timestamp pattern was found in the file name." -f $file.FullName)
                    continue
                }

                $metadataValue = $timestamp.ToString("yyyy-MM-dd'T'HH:mm:ss", $culture)
                Write-Verbose ("Extracted timestamp '{0}' from '{1}'." -f $metadataValue, $file.Name)

                $sourcePath = $file.FullName
                $targetPath = $sourcePath

                if ($script:PSXmpDateInjector_OutputDirectory) {
                    $relativePath = if ($script:PSXmpDateInjector_InputRoot) {
                        $sourceUri = New-Object System.Uri $sourcePath
                        $rootUri = New-Object System.Uri (([System.IO.Path]::GetFullPath($script:PSXmpDateInjector_InputRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar))) + [System.IO.Path]::DirectorySeparatorChar)
                        $rootUri.MakeRelativeUri($sourceUri).ToString().Replace('/', [System.IO.Path]::DirectorySeparatorChar)
                    }
                    else {
                        $file.Name
                    }

                    if ([string]::IsNullOrEmpty($relativePath)) {
                        $relativePath = $file.Name
                    }

                    $targetPath = [System.IO.Path]::Combine($script:PSXmpDateInjector_OutputDirectory, $relativePath)
                }

                if ($PSCmdlet.ShouldProcess($targetPath, "Set XMP creation dates to $metadataValue")) {
                    if ($script:PSXmpDateInjector_OutputDirectory -and ($targetPath -ne $sourcePath)) {
                        $targetDirectory = [System.IO.Path]::GetDirectoryName($targetPath)
                        if ($targetDirectory -and -not (Test-Path -LiteralPath $targetDirectory)) {
                            New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
                        }

                        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
                    }

                    $arguments = @(
                        '-overwrite_original'
                        '-P'
                        '-q'
                        '-q'
                        ("-XMP-exif:DateTimeOriginal={0}" -f $metadataValue)
                        ("-XMP-photoshop:DateCreated={0}" -f $metadataValue)
                        ("-XMP-xmp:CreateDate={0}" -f $metadataValue)
                        $targetPath
                    )

                    $exitCode = Invoke-PSXmpDateInjectorExifTool -ExecutablePath $script:PSXmpDateInjector_ExifToolPath -Arguments $arguments

                    if ($exitCode -ne 0) {
                        throw ("exiftool exited with code {0} while processing '{1}'." -f $exitCode, $targetPath)
                    }

                    if ($Passthru.IsPresent) {
                        [pscustomobject]@{
                            SourcePath      = $sourcePath
                            FilePath        = $targetPath
                            Timestamp       = $metadataValue
                            ExifTool        = $script:PSXmpDateInjector_ExifToolPath
                            OutputDirectory = $script:PSXmpDateInjector_OutputDirectory
                        }
                    }
                }
            }
        }
    }
}

Export-ModuleMember -Function Add-ImageXmpDateMetadata, Get-DateFromFileName

Export-ModuleMember -Function Add-ImageXmpDateMetadata, Get-DateFromFileName
