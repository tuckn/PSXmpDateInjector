
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function New-FrontmatterNoteId {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [string] $ExistingNoteId
    )

    if (-not [string]::IsNullOrWhiteSpace($ExistingNoteId)) {
        return $ExistingNoteId.Trim()
    }

    return ([guid]::NewGuid().ToString())
}

function ConvertTo-YamlQuoted {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string] $Value
    )

    $result = if ($null -eq $Value) { '' } else { $Value }
    return ('"{0}"' -f ($result -replace '"', '\"'))
}

function ConvertTo-YamlTagArray {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [string[]] $Tags
    )

    if (-not $Tags -or $Tags.Count -eq 0) {
        return '[]'
    }

    $encoded = $Tags | ForEach-Object { ('"{0}"' -f ($_ -replace '"', '\"')) }
    return ('[{0}]' -f ($encoded -join ', '))
}

function Set-MarkdownFrontmatter {
<#$
.SYNOPSIS
Writes (or replaces) a YAML frontmatter block at the top of a Markdown file.

.DESCRIPTION
Set-MarkdownFrontmatter inserts a YAML block containing noteId, title, description, date, and tags metadata at the beginning of a Markdown document. When the file already starts with a frontmatter block delimited by `---`, the block is replaced; otherwise, the new block is prepended. Existing noteId values are preserved unless blank, in which case a new GUID is issued.

.PARAMETER Path
Specifies the target Markdown file.

.PARAMETER Title
Sets the `title` property inside the frontmatter block.

.PARAMETER Description
Sets the `description` property. Defaults to an empty string when omitted.

.PARAMETER Date
Sets the `date` property. The value is formatted as yyyy-MM-dd.

.PARAMETER Tags
Specifies one or more tag strings that are emitted as a YAML array.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('FullName')]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Title,

        [AllowNull()]
        [string] $Description = '',

        [Parameter(Mandatory)]
        [datetime] $Date,

        [string[]] $Tags
    )

    $resolvedPath = $null
    try {
        $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    }
    catch {
        throw ("The Markdown file '{0}' could not be resolved: {1}" -f $Path, $_.Exception.Message)
    }

    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw ("The Markdown file '{0}' was not found." -f $resolvedPath)
    }

    $lineEnding = [System.Environment]::NewLine
    $existingContent = Get-Content -LiteralPath $resolvedPath -Raw -ErrorAction Stop
    $frontmatterRegex = [regex]'(?s)^(---\s*\r?\n.*?\r?\n---\s*\r?\n*)'
    $frontmatterMatch = $frontmatterRegex.Match($existingContent)

    $existingNoteId = $null
    if ($frontmatterMatch.Success) {
        $noteIdMatch = [regex]::Match($frontmatterMatch.Value, '(?m)^\s*noteId:\s*"?([^"\r\n]+)"?\s*$')
        if ($noteIdMatch.Success) {
            $existingNoteId = $noteIdMatch.Groups[1].Value
        }
    }

    $noteId = New-FrontmatterNoteId -ExistingNoteId $existingNoteId
    $noteIdValue = ConvertTo-YamlQuoted -Value $noteId
    $titleValue = ConvertTo-YamlQuoted -Value $Title
    $descriptionValue = ConvertTo-YamlQuoted -Value $Description
    $dateValue = $Date.ToString('yyyy-MM-dd')
    $tagsValue = ConvertTo-YamlTagArray -Tags $Tags

    $frontmatterLines = @(
        '---'
        ("noteId: {0}" -f $noteIdValue)
        ("title: {0}" -f $titleValue)
        ("description: {0}" -f $descriptionValue)
        ("date: {0}" -f $dateValue)
        ("tags: {0}" -f $tagsValue)
        '---'
    )
    $frontmatterBlock = $frontmatterLines -join $lineEnding

    $body = if ($frontmatterMatch.Success) {
        $existingContent.Substring($frontmatterMatch.Length)
    }
    else {
        $existingContent
    }
    # After the existing frontmatter block is removed, the remaining body is passed through $body.TrimStart() before being re-written. TrimStart eliminates all leading whitespace, so if the file begins with indentation-sensitive Markdown (e.g., a code block or blockquote immediately after the frontmatter), the indentation is stripped and the semantics of the document change. We only need to drop the extra blank line that separates the frontmatter from the content; trimming every leading space/tabs corrupts formatted content. Please preserve the original indentation when rebuilding the file
    # $body = $body.TrimStart()

    $updatedContent = $frontmatterBlock + $lineEnding + $lineEnding + $body

    if ($PSCmdlet.ShouldProcess($resolvedPath, 'Write Markdown frontmatter')) {
        $updatedContent | Set-Content -LiteralPath $resolvedPath -Encoding utf8BOM
    }
}

Export-ModuleMember -Function Set-MarkdownFrontmatter
