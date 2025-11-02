Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..\PSXmpDateInjector.psd1'
Import-Module $modulePath -Force -ErrorAction Stop

Describe 'PSXmpDateInjector' {
    BeforeAll {
        try {
            $script:OriginalWhatIfPreference = Get-Variable -Name WhatIfPreference -Scope Global -ValueOnly
        }
        catch {
            $script:OriginalWhatIfPreference = $false
        }

        $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
        $assetsRootCandidate = [System.IO.Path]::Combine($repoRoot, 'assets')
        if (-not (Test-Path -LiteralPath $assetsRootCandidate -PathType Container)) {
            throw "Assets directory was not found at '$assetsRootCandidate'."
        }

        $script:AssetsRoot = (Resolve-Path -LiteralPath $assetsRootCandidate).ProviderPath
        $script:AssetsDest = [System.IO.Path]::Combine($script:AssetsRoot, 'dest')

        if (Test-Path -LiteralPath $script:AssetsDest) {
            Remove-Item -LiteralPath $script:AssetsDest -Recurse -Force
        }

        $destExclusionPattern = [System.IO.Path]::Combine($script:AssetsDest, '*')
        $script:SourceAssets = Get-ChildItem -LiteralPath $script:AssetsRoot -File -Recurse | Where-Object {
            $_.FullName -notlike $destExclusionPattern
        }

        $preferredExifTool = [System.IO.Path]::Combine($repoRoot, 'bin', 'exiftool')
        if (-not (Test-Path -LiteralPath $preferredExifTool -PathType Leaf)) {
            $alternateExifTool = [System.IO.Path]::Combine($repoRoot, 'bin', 'exiftool.exe')
            if (Test-Path -LiteralPath $alternateExifTool -PathType Leaf) {
                $preferredExifTool = $alternateExifTool
            }
        }

        if (-not (Test-Path -LiteralPath $preferredExifTool -PathType Leaf)) {
            throw 'Test exiftool was not found. Ensure ./bin/exiftool (or exiftool.exe) exists before running tests.'
        }

        $script:TestExifToolPath = (Resolve-Path -LiteralPath $preferredExifTool).ProviderPath
    }

    BeforeEach {
        Set-Variable -Name WhatIfPreference -Value $false -Scope Global

        if (Test-Path -LiteralPath $script:AssetsDest) {
            Remove-Item -LiteralPath $script:AssetsDest -Recurse -Force
        }

        New-Item -ItemType Directory -Path $script:AssetsDest | Out-Null

        foreach ($source in $script:SourceAssets) {
            $relative = $source.FullName.Substring($script:AssetsRoot.Length).TrimStart('\', '/')
            $target = [System.IO.Path]::Combine($script:AssetsDest, $relative)
            $targetDir = [System.IO.Path]::GetDirectoryName($target)
            if ($targetDir -and -not (Test-Path -LiteralPath $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }

            Copy-Item -LiteralPath $source.FullName -Destination $target -Force
        }
    }

    AfterAll {
        Set-Variable -Name WhatIfPreference -Value $script:OriginalWhatIfPreference -Scope Global
    }

    Context 'Get-DateFromFileName' {
        It 'parses yyyyMMddThhmmss pattern with offset' {
            InModuleScope AddImageXmpDateMetadata -ScriptBlock {
                $result = Get-DateFromFileName -FileName '20130630T023600+0900.jpg'
                $result | Should -Not -BeNull
                $result | Should -BeOfType ([datetime])
                $result.ToString("yyyy-MM-dd'T'HH:mm:ss") | Should -Be '2013-06-30T02:36:00'
            }
        }

        It 'parses yyyyMMddhhmmss pattern without separator' {
            InModuleScope AddImageXmpDateMetadata -ScriptBlock {
                $result = Get-DateFromFileName -FileName 'FP20090511182604_LED.jpg'
                $result | Should -Not -BeNull
                $result.ToString("yyyy-MM-dd'T'HH:mm:ss") | Should -Be '2009-05-11T18:26:04'
            }
        }

        It 'parses yyyy-MM-dd hhmmss pattern with space' {
            InModuleScope AddImageXmpDateMetadata -ScriptBlock {
                $result = Get-DateFromFileName -FileName 'Screenshot 2025-11-02 073031.png'
                $result | Should -Not -BeNull
                $result.ToString("yyyy-MM-dd'T'HH:mm:ss") | Should -Be '2025-11-02T07:30:31'
            }
        }

        It 'parses yyyy-MM-dd-hh-mm-ss pattern with dashes' {
            InModuleScope AddImageXmpDateMetadata -ScriptBlock {
                $result = Get-DateFromFileName -FileName '2015-07-02 12-16-05.jpg'
                $result | Should -Not -BeNull
                $result.ToString("yyyy-MM-dd'T'HH:mm:ss") | Should -Be '2015-07-02T12:16:05'
            }
        }

        It 'parses dd_MM_yyyy_hh_mm_ss pattern with underscores' {
            InModuleScope AddImageXmpDateMetadata -ScriptBlock {
                $result = Get-DateFromFileName -FileName 'screencapture-VirtualBox_Windows XP Mode_15_10_2016_07_49_43.png'
                $result | Should -Not -BeNull
                $result.ToString("yyyy-MM-dd'T'HH:mm:ss") | Should -Be '2016-10-15T07:49:43'
            }
        }
    }

    Context 'Add-ImageXmpDateMetadata' {
        It 'invokes exiftool for a single file and returns metadata when Passthru is set' {
            $filePath = [System.IO.Path]::Combine($script:AssetsDest, '20130630T023600+0900.jpg')
            $expectedExifToolPath = $script:TestExifToolPath

            InModuleScope AddImageXmpDateMetadata -ScriptBlock {
                param($fp, $toolPath)
                Mock Invoke-PSXmpDateInjectorExifTool { param($ExecutablePath, $Arguments) return 0 } -ModuleName AddImageXmpDateMetadata

                $result = Add-ImageXmpDateMetadata -InputPath $fp -Passthru -ExifToolPath $toolPath -Confirm:$false

                Assert-MockCalled Invoke-PSXmpDateInjectorExifTool -Times 1 -ParameterFilter {
                    $ExecutablePath -eq $toolPath -and
                    $Arguments[-1] -eq $fp -and
                    $Arguments -contains '-overwrite_original' -and
                    $Arguments -contains "-XMP-exif:DateTimeOriginal=2013-06-30T02:36:00" -and
                    $Arguments -contains "-XMP-photoshop:DateCreated=2013-06-30T02:36:00" -and
                    $Arguments -contains "-XMP-xmp:CreateDate=2013-06-30T02:36:00"
                }

                $result | Should -Not -BeNull
                $result.FilePath | Should -Be $fp
                $result.Timestamp | Should -Be '2013-06-30T02:36:00'
                $result.ExifTool | Should -Be $toolPath
            } -ArgumentList $filePath, $expectedExifToolPath
        }

        It 'skips processing when WhatIf is specified' {
            $filePath = [System.IO.Path]::Combine($script:AssetsDest, '20130630T023600+0900.jpg')
            $toolPath = $script:TestExifToolPath

            InModuleScope AddImageXmpDateMetadata -ScriptBlock {
                param($fp, $tp)
                Mock Invoke-PSXmpDateInjectorExifTool { param($ExecutablePath, $Arguments) return 0 } -ModuleName AddImageXmpDateMetadata

                Add-ImageXmpDateMetadata -InputPath $fp -WhatIf -ExifToolPath $tp -Confirm:$false

                Assert-MockCalled Invoke-PSXmpDateInjectorExifTool -Times 0
            } -ArgumentList $filePath, $toolPath
        }

        It 'skips files that do not contain a supported timestamp' {
            $filePath = [System.IO.Path]::Combine($script:AssetsDest, '20130630T023600+0900.jpg')
            $toolPath = $script:TestExifToolPath

            InModuleScope AddImageXmpDateMetadata -ScriptBlock {
                param($fp, $tp)
                Mock Invoke-PSXmpDateInjectorExifTool { param($ExecutablePath, $Arguments) return 0 } -ModuleName AddImageXmpDateMetadata
                Mock Get-DateFromFileName { return $null } -ModuleName AddImageXmpDateMetadata

                Add-ImageXmpDateMetadata -InputPath $fp -ExifToolPath $tp -Confirm:$false

                Assert-MockCalled Invoke-PSXmpDateInjectorExifTool -Times 0
            } -ArgumentList $filePath, $toolPath
        }

        It 'processes every supported image in a directory when Recurse is used' {
            $toolPath = $script:TestExifToolPath
            $assetsDest = $script:AssetsDest

            InModuleScope AddImageXmpDateMetadata -ScriptBlock {
                param($dest, $tp)
                Mock Invoke-PSXmpDateInjectorExifTool { param($ExecutablePath, $Arguments) return 0 } -ModuleName AddImageXmpDateMetadata

                $results = Add-ImageXmpDateMetadata -InputPath $dest -Recurse -Passthru -ExifToolPath $tp -Confirm:$false | Sort-Object FilePath

                Assert-MockCalled Invoke-PSXmpDateInjectorExifTool -Times 4
                $results.Count | Should -Be 4
                ($results | Where-Object { $_.FilePath -like '*20130630T023600+0900.jpg' }).Timestamp | Should -Be '2013-06-30T02:36:00'
                ($results | Where-Object { $_.FilePath -like '*2003-01-28-224920_yuno-Image1.jpg' }).Timestamp | Should -Be '2003-01-28T22:49:20'
                ($results | Where-Object { $_.FilePath -like '*Screenshot 2025-11-02 073031.png' }).Timestamp | Should -Be '2025-11-02T07:30:31'
                ($results | Where-Object { $_.FilePath -like '*screencapture-VirtualBox_Windows XP Mode_15_10_2016_07_49_43.png' }).Timestamp | Should -Be '2016-10-15T07:49:43'
            } -ArgumentList $assetsDest, $toolPath
        }
    }
}
