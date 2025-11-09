[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string[]] $Path,

    [string] $Title,

    [AllowNull()]
    [string] $Description = '',

    [Nullable[datetime]] $Date,

    [string[]] $Tags,

    [ValidateNotNullOrEmpty()]
    [string] $ConfigJsonPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\PSMetaDataInjector.psd1') -Force -ErrorAction Stop

$parameterOrder = @('Path','Title','Description','Date','Tags')
$configParameters = @{}

if ($PSBoundParameters.ContainsKey('ConfigJsonPath')) {
    try {
        $resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigJsonPath -ErrorAction Stop).ProviderPath
    }
    catch {
        throw ("The configuration file '{0}' could not be resolved: {1}" -f $ConfigJsonPath, $_.Exception.Message)
    }

    try {
        $configContent = Get-Content -LiteralPath $resolvedConfigPath -Raw -ErrorAction Stop
        $configData = $configContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw ("Failed to parse configuration file '{0}': {1}" -f $resolvedConfigPath, $_.Exception.Message)
    }

    foreach ($name in $parameterOrder) {
        if ($null -ne $configData.$name) {
            $configParameters[$name] = $configData.$name
        }
    }
}

$effectiveParameters = @{}

foreach ($name in $parameterOrder) {
    if ($configParameters.ContainsKey($name)) {
        $effectiveParameters[$name] = $configParameters[$name]
    }
}

foreach ($name in $parameterOrder) {
    if ($PSBoundParameters.ContainsKey($name)) {
        $effectiveParameters[$name] = $PSBoundParameters[$name]
    }
}

$required = @('Path','Title','Date')
foreach ($req in $required) {
    if (-not $effectiveParameters.ContainsKey($req) -or [string]::IsNullOrWhiteSpace([string]$effectiveParameters[$req])) {
        throw ("{0} must be supplied either on the command line or in the configuration file." -f $req)
    }
}

$paths = @()
foreach ($target in @($effectiveParameters['Path'])) {
    try {
        $paths += (Resolve-Path -LiteralPath $target -ErrorAction Stop).ProviderPath
    }
    catch {
        throw ("The path '{0}' could not be resolved: {1}" -f $target, $_.Exception.Message)
    }
}

$title = $effectiveParameters['Title']
if ([string]::IsNullOrWhiteSpace($title)) {
    throw 'Title must not be empty.'
}

try {
    $dateValue = [datetime]$effectiveParameters['Date']
}
catch {
    throw ("Date value '{0}' could not be converted to datetime: {1}" -f $effectiveParameters['Date'], $_.Exception.Message)
}

$description = if ($effectiveParameters.ContainsKey('Description')) { $effectiveParameters['Description'] } else { '' }
$tags = if ($effectiveParameters.ContainsKey('Tags')) { [string[]]$effectiveParameters['Tags'] } else { $null }

$controlParameters = @{}
foreach ($control in @('WhatIf','Confirm')) {
    if ($PSBoundParameters.ContainsKey($control)) {
        $controlParameters[$control] = $PSBoundParameters[$control]
    }
}

$callBase = @{
    Title = $title
    Description = $description
    Date = $dateValue
}
if ($null -ne $tags) {
    $callBase['Tags'] = $tags
}

foreach ($targetPath in $paths) {
    $callParameters = $callBase.Clone()
    $callParameters['Path'] = $targetPath
    Set-MarkdownFrontmatter @callParameters @controlParameters
}
