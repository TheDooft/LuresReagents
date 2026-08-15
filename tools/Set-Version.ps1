<#
.SYNOPSIS
    Sets the addon version in the TOC and opens a changelog section for it.

.DESCRIPTION
    The TOC carries a literal version rather than the packager's @project-version@
    token, so the version shows in the in-game addon list even on a working copy
    that was never packaged. That means the TOC and the release tag have to be kept
    in step by hand — this script does it, and the release workflow refuses to
    publish if they ever disagree.

.EXAMPLE
    .\Set-Version.ps1 1.1.0
    Rewrites the TOC and adds a changelog heading.

.EXAMPLE
    .\Set-Version.ps1 1.1.0 -Tag
    Also commits both files and creates the v1.1.0 tag. Push it to release:
        git push origin main --tags
#>
[CmdletBinding()]
param(
    # Version to set, without the leading v. Example: 1.1.0
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string] $Version,

    # Commit the changed files and create the matching git tag.
    [switch] $Tag
)

$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$tocPath = Join-Path $root 'LuresReagents.toc'
$changelogPath = Join-Path $root 'CHANGELOG.md'

# --- TOC -------------------------------------------------------------------

# Read as UTF-8 explicitly. Windows PowerShell's Get-Content defaults to the
# system ANSI codepage, which mangles the accented lines in the localised TOC
# fields on the way back out.
$utf8 = New-Object System.Text.UTF8Encoding($false)
$toc = [System.IO.File]::ReadAllLines($tocPath, $utf8)
$current = ($toc | Select-String -Pattern '^## Version:\s*(.+)$').Matches.Groups[1].Value.Trim()

if ($current -eq $Version) {
    Write-Host "TOC is already at $Version" -ForegroundColor Yellow
} else {
    $toc = $toc -replace '^## Version:.*$', "## Version: $Version"
    # UTF-8 without BOM: the client does not tolerate a BOM in the TOC.
    [System.IO.File]::WriteAllLines($tocPath, $toc, $utf8)
    Write-Host "TOC: $current -> $Version" -ForegroundColor Green
}

# --- Changelog -------------------------------------------------------------

$changelog = [System.IO.File]::ReadAllText($changelogPath, $utf8)
if ($changelog -match "(?m)^## v$([regex]::Escape($Version))\s*$") {
    Write-Host "CHANGELOG already has a v$Version section" -ForegroundColor Yellow
} else {
    $entry = "## v$Version`r`n`r`n- _describe the change_`r`n`r`n"
    $changelog = $changelog -replace '(?m)^(# Changelog\r?\n\r?\n)', "`$1$entry"
    [System.IO.File]::WriteAllText($changelogPath, $changelog, $utf8)
    Write-Host "CHANGELOG: added a v$Version section - fill it in before tagging" -ForegroundColor Green
}

# --- Git -------------------------------------------------------------------

if (-not $Tag) {
    Write-Host ""
    Write-Host "Edit the changelog, then run this again with -Tag, or tag by hand:" -ForegroundColor Cyan
    Write-Host "  git commit -am `"Release v$Version`" && git tag v$Version && git push origin main --tags"
    return
}

git -C $root add LuresReagents.toc CHANGELOG.md

# Both files can already be committed at this version — the usual case when the
# changelog was written in an earlier commit. That is not a failure; tag anyway.
git -C $root diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git -C $root commit -m "Release v$Version"
    if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
} else {
    Write-Host "TOC and changelog are already committed at $Version; tagging the current commit." -ForegroundColor Yellow
}

$existing = git -C $root tag --list "v$Version"
if ($existing) {
    throw "Tag v$Version already exists. Delete it first (git tag -d v$Version) or pick another version."
}

git -C $root tag "v$Version"
if ($LASTEXITCODE -ne 0) { throw "git tag failed" }

Write-Host ""
Write-Host "Tagged v$Version. Push it to trigger the release workflow:" -ForegroundColor Green
Write-Host "  git push origin main --tags"
