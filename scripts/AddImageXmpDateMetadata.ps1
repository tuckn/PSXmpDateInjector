[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $InputPath,

    [switch] $Recurse,

    [switch] $Passthru,

    [ValidateNotNullOrEmpty()]
    [string] $ExifToolPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\PSXmpDateInjector.psd1') -Force -ErrorAction Stop

Add-ImageXmpDateMetadata @PSBoundParameters
