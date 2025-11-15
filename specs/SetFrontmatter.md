# SetFrontmatter — Markdown Frontmatter Injector

Update YAML frontmatter at the top of Markdown notes.

- Status: Draft (tracking Set-MarkdownFrontmatter module work)
- Owner: @tuckn
- Links: modules/SetFrontmatter.psm1, scripts/SetFrontmatter.ps1, tests/SetMediaMetadata.Tests.ps1

## 1. Summary (Introduction)

`Set-MarkdownFrontmatter` writes (or replaces) a YAML block at the head of a Markdown file. It manages `noteId`, `title`, `description`, `date`, and `tags`, inserting the block when missing and updating specific keys when present. The command is shipped both as a module function and as wrapper scripts (`scripts/SetFrontmatter.ps1` / `scripts/cmd/SetFrontmatter.cmd`).

## 2. Intent (User Story / Goal)

As a note taker,
I want consistent frontmatter metadata (GUID, title, tags, dates),
so that my Markdown vault stays searchable by static-site generators and note tools.

## 3. Scope

### In-Scope

- YAML block management bounded by `---` delimiters at the top of Markdown files.
- Automatic issuance/preservation of `noteId` GUIDs per file.
- Title/description/date/tags updates with configurable inputs (direct parameters or JSON config via wrapper script).
- Support for batch invocation via wrapper script targeting multiple files.

### Non-Goals

- Manipulating Markdown body content (headings, reflow, etc.).
- Managing metadata stored outside frontmatter (HTML comments, footers, etc.).
- Markdown parsing beyond frontmatter detection (no AST work).

## 4. Contract (API / CLI / Data)

### 4.1 Module API (`Set-MarkdownFrontmatter`)

| Param       | Type            | Req | Default | Notes |
|-------------|-----------------|-----|---------|-------|
| `-Path`     | string          | ✓   | —       | File path; resolved via `Resolve-Path` |
| `-Title`    | string          | ✓   | —       | Empty/whitespace rejected |
| `-Description` | string       | —   | `""`   | `null` treated as empty |
| `-Date`     | datetime        | ✓   | —       | Serialized as `yyyy-MM-dd` |
| `-Tags`     | string[]        | —   | `[]`    | Output as YAML array |

- Control params: `-WhatIf`, `-Confirm` supported.
- Encoding: always writes UTF-8 with BOM, ensuring Windows PowerShell compatibility.

### 4.2 Wrapper CLI (`scripts/SetFrontmatter.ps1` / `.cmd`)

- Accepts the same logical parameters plus `-ConfigJsonPath` for bulk edits.
- Resolves multiple `-Path` values (array) before calling the module.
- `.cmd` helper chooses `pwsh` when available, otherwise falls back to Windows PowerShell.

### 4.3 Data Spec

新規作成例：

```markdown
---
noteId: "d3f29c4e-8b6a-4f3e-9e3b-2c1f5e9a7c1a"
title: "git.exeがcore.autocrlfを無視する"
description: ""
date: 2018-01-30
tags: ["JavaScript", "React", "WinMerge"]
---

本文…
````

## 5. Rules & Invariants

- **MUST** insert exactly one blank line between the closing `---` and Markdown body.
- **MUST** preserve an existing non-empty `noteId`; generate a GUID when absent/blank.
- **MUST** quote scalar values (title/description/noteId) with escaped quotes; tags emitted as `['tag']` array.
- **MUST** strip leading frontmatter (if any) before rewriting; body text otherwise untouched (aside from leading whitespace trimming).
- **SHOULD** retain the file’s original newline convention when possible (CRLF on Windows).
- **SHOULD** produce deterministic output ordering: noteId → title → description → date → tags.

## 6. Acceptance

### 6.1 Criteria

- Unit tests in `tests/SetMediaMetadata.Tests.ps1` covering new/replace noteId scenarios pass via `Invoke-Pester -CI` on pwsh.
- README documents usage and explains noteId/tag behavior.
- Wrapper script resolves config overrides (command-line args win over JSON).

### 6.2 Scenarios (Gherkin)

```gherkin
Scenario: Insert frontmatter when none exists
  Given a Markdown file without a YAML header
  When I run Set-MarkdownFrontmatter -Path note.md -Title "Foo" -Date (Get-Date '2024-10-05')
  Then a frontmatter block is prepended with a generated noteId and the specified title/date
  And exactly one blank line separates the block from the original body

Scenario: Preserve existing noteId while updating other fields
  Given note.md already includes noteId "1234"
  When I run Set-MarkdownFrontmatter -Title "New" -Description "Updated" -Date (Get-Date '2024-11-09')
  Then noteId remains "1234" and other keys reflect the new values

Scenario: Generate noteId when frontmatter lacks it
  Given note.md has a frontmatter without noteId
  When I run Set-MarkdownFrontmatter with required fields
  Then a new GUID noteId is inserted
```

## 7. Quality (Non-Functional Gates)

| Attribute       | Gate                                      |
|-----------------|-------------------------------------------|
| Static analysis | PSScriptAnalyzer 0 errors/warnings        |
| Tests           | `Invoke-Pester -CI` succeeds (pwsh)        |
| Encoding        | Output encoded as UTF-8 with BOM           |
| Idempotence     | Repeated runs with same inputs keep file stable |

## 8. Open Questions

1. Should tags preserve order or be alphabetized? (current: preserve input order)
2. Need a dry-run summary mode for batch operations? (currently `-WhatIf` logs only)
3. Support for custom frontmatter keys beyond the core ones?

## 9. Decisions & Rationale

- `noteId` chosen as GUID because downstream systems expect global uniqueness.
- YAML quoting enforced to handle multibyte strings and embedded quotes reliably.
- Wrapper script introduced to share config loading semantics with Set-MediaMetadata.

## 10. References & Changelog

- 2025-11-15: Structured spec based on `specs/sample.md` template and aligned with latest module implementation.
