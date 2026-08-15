<#
.SYNOPSIS
    Regenerates LuresReagents/Data.lua from Blizzard's client data.

.DESCRIPTION
    Pulls DB2 tables from wago.tools for a given client build and walks the
    crafting chain that Blizzard actually uses:

        SkillLineAbility (SkillLine = 393, Skinning)
            -> Spell
            -> SpellEffect (Effect = 288, craft item)
            -> EffectMiscValue_0 = CraftingData.ID
            -> CraftingData.CraftedItemID
        Spell -> SpellReagents -> Reagent_N / ReagentCount_N

    Recipes whose crafted item name matches -NameFilter are written out. Item
    names are the enUS ones; they only serve as a fallback in game, which reads
    the localised name from the client.

    Run this after each patch. If the recipe count changes, the script says so.

.EXAMPLE
    .\Update-Data.ps1
    Uses the build of the local WoW installation.

.EXAMPLE
    .\Update-Data.ps1 -Build 12.1.0.69299 -Force
    Targets a specific build and re-downloads the cached DB2 exports.
#>
[CmdletBinding()]
param(
    # Client build to pull, e.g. 12.1.0.69273. Defaults to the local installation.
    [string] $Build,

    # WoW installation used to detect the build.
    [string] $WowPath = 'D:\World of Warcraft',

    # Skinning. Change it to target another profession's craftables.
    [int] $SkillLine = 393,

    # Only crafted items whose enUS name matches this are kept.
    [string] $NameFilter = 'Lure$',

    # Only crafted items from this expansion are kept. 11 = Midnight. Skinning has
    # carried a "... Lure" recipe in several expansions, so the name alone is not
    # enough to isolate the Majestic Beast Lures. Pass 0 to keep every expansion.
    [int] $ExpansionID = 11,

    # Where the generated file goes.
    [string] $OutFile = (Join-Path $PSScriptRoot '..\Data.lua'),

    # Re-download the DB2 exports even if they are already cached.
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

$EFFECT_CRAFT_ITEM = 288

# ---------------------------------------------------------------------------
# Build detection
# ---------------------------------------------------------------------------

function Get-LocalBuild {
    param([string] $Path)

    $infoFile = Join-Path $Path '.build.info'
    if (-not (Test-Path $infoFile)) { return $null }

    # Pipe-delimited, with headers like "Version!STRING:0".
    $lines = Get-Content $infoFile
    if ($lines.Count -lt 2) { return $null }

    $headers = ($lines[0] -split '\|') | ForEach-Object { ($_ -split '!')[0] }
    $versionIndex = [array]::IndexOf($headers, 'Version')
    $productIndex = [array]::IndexOf($headers, 'Product')
    if ($versionIndex -lt 0) { return $null }

    foreach ($line in $lines[1..($lines.Count - 1)]) {
        $fields = $line -split '\|'
        if ($productIndex -lt 0 -or $fields[$productIndex] -eq 'wow') {
            return $fields[$versionIndex]
        }
    }
    return $null
}

if (-not $Build) {
    $Build = Get-LocalBuild -Path $WowPath
    if (-not $Build) {
        throw "Could not read the client build from '$WowPath\.build.info'. Pass -Build explicitly."
    }
    Write-Host "Detected local build $Build" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# DB2 downloads
# ---------------------------------------------------------------------------

$cacheDir = Join-Path $env:TEMP "LuresReagents-db2\$Build"
if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null }

function Get-Db2 {
    param([string] $Table)

    $path = Join-Path $cacheDir "$Table.csv"
    if ((Test-Path $path) -and -not $Force) {
        Write-Host "  $Table (cached)"
        return $path
    }

    $url = "https://wago.tools/db2/$Table/csv?build=$Build"
    Write-Host "  $Table ..."
    Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
    return $path
}

Write-Host "Fetching DB2 exports for $Build" -ForegroundColor Cyan
$skillLineAbilityPath = Get-Db2 'SkillLineAbility'
$spellEffectPath      = Get-Db2 'SpellEffect'
$craftingDataPath     = Get-Db2 'CraftingData'
$spellReagentsPath    = Get-Db2 'SpellReagents'
$itemSparsePath       = Get-Db2 'ItemSparse'

# ---------------------------------------------------------------------------
# Streaming helpers
#
# ItemSparse and SpellEffect are tens of megabytes with hundreds of columns;
# Import-Csv on them is unusably slow. Scan them line by line instead and only
# parse the handful of rows that matter.
# ---------------------------------------------------------------------------

function Get-CsvHeaderIndex {
    param([string] $Path)

    $reader = [System.IO.StreamReader]::new($Path)
    try { $header = $reader.ReadLine() } finally { $reader.Dispose() }

    $index = @{}
    $columns = $header -split ','
    for ($i = 0; $i -lt $columns.Count; $i++) { $index[$columns[$i]] = $i }
    return $index
}

# Scans a CSV, keeping rows whose leading ID column is in $Wanted.
# Fields are split naively, which is safe here because the rows we keep are numeric.
function Select-RowsByFirstColumn {
    param([string] $Path, [hashtable] $Wanted)

    $rows = New-Object System.Collections.ArrayList
    $reader = [System.IO.StreamReader]::new($Path)
    try {
        $null = $reader.ReadLine()
        while ($null -ne ($line = $reader.ReadLine())) {
            $comma = $line.IndexOf(',')
            if ($comma -lt 1) { continue }
            $id = $line.Substring(0, $comma)
            if ($Wanted.ContainsKey($id)) { $null = $rows.Add($line) }
        }
    } finally {
        $reader.Dispose()
    }
    return $rows
}

# ---------------------------------------------------------------------------
# 1. Spells taught by the profession
# ---------------------------------------------------------------------------

Write-Host "Walking the crafting chain" -ForegroundColor Cyan

$professionSpells = @{}
Import-Csv $skillLineAbilityPath | Where-Object { [int]$_.SkillLine -eq $SkillLine } | ForEach-Object {
    $professionSpells[$_.Spell] = $true
}
Write-Host "  $($professionSpells.Count) spells on skill line $SkillLine"

# ---------------------------------------------------------------------------
# 2. Spell -> CraftingData id, via the craft-item effect
# ---------------------------------------------------------------------------

$effectIndex = Get-CsvHeaderIndex $spellEffectPath
$colEffect    = $effectIndex['Effect']
$colSpellID   = $effectIndex['SpellID']
$colMiscValue = $effectIndex['EffectMiscValue_0']

$spellToCraftingData = @{}
$reader = [System.IO.StreamReader]::new($spellEffectPath)
try {
    $null = $reader.ReadLine()
    while ($null -ne ($line = $reader.ReadLine())) {
        $fields = $line -split ','
        if ($fields[$colEffect] -ne $EFFECT_CRAFT_ITEM) { continue }
        $spellID = $fields[$colSpellID]
        if (-not $professionSpells.ContainsKey($spellID)) { continue }
        $spellToCraftingData[$spellID] = $fields[$colMiscValue]
    }
} finally {
    $reader.Dispose()
}
Write-Host "  $($spellToCraftingData.Count) of them craft an item"

# ---------------------------------------------------------------------------
# 3. CraftingData id -> crafted item
# ---------------------------------------------------------------------------

$craftingDataToItem = @{}
Import-Csv $craftingDataPath | ForEach-Object {
    $craftingDataToItem[$_.ID] = $_.CraftedItemID
}

$recipes = @{}   # spellID -> crafted item id
foreach ($spellID in $spellToCraftingData.Keys) {
    $itemID = $craftingDataToItem[$spellToCraftingData[$spellID]]
    if ($itemID -and $itemID -ne '0') { $recipes[$spellID] = $itemID }
}

# ---------------------------------------------------------------------------
# 4. Reagents
# ---------------------------------------------------------------------------

$reagentsBySpell = @{}
Import-Csv $spellReagentsPath | Where-Object { $recipes.ContainsKey($_.SpellID) } | ForEach-Object {
    $list = New-Object System.Collections.ArrayList
    for ($slot = 0; $slot -lt 8; $slot++) {
        $reagent = $_."Reagent_$slot"
        $count = $_."ReagentCount_$slot"
        if ($reagent -and $reagent -ne '0') {
            $null = $list.Add([pscustomobject]@{ Id = $reagent; Count = [int]$count })
        }
    }
    if ($list.Count -gt 0) { $reagentsBySpell[$_.SpellID] = $list }
}

# ---------------------------------------------------------------------------
# 5. Item names
# ---------------------------------------------------------------------------

$wantedItems = @{}
foreach ($spellID in $recipes.Keys) {
    $wantedItems[$recipes[$spellID]] = $true
    if ($reagentsBySpell.ContainsKey($spellID)) {
        foreach ($reagent in $reagentsBySpell[$spellID]) { $wantedItems[$reagent.Id] = $true }
    }
}

$itemRows = Select-RowsByFirstColumn -Path $itemSparsePath -Wanted $wantedItems
$itemHeader = (Get-Content $itemSparsePath -TotalCount 1) -split ','

$itemNames = @{}
$itemExpansions = @{}
if ($itemRows.Count -gt 0) {
    # ConvertFrom-Csv handles the quoting in the flavour-text columns correctly.
    foreach ($row in ($itemRows | ConvertFrom-Csv -Header $itemHeader)) {
        $itemNames[$row.ID] = $row.Display_lang
        $itemExpansions[$row.ID] = [int]$row.ExpansionID
    }
}

# ---------------------------------------------------------------------------
# 6. Keep the lures
# ---------------------------------------------------------------------------

$lures = New-Object System.Collections.ArrayList
foreach ($spellID in $recipes.Keys) {
    $itemID = $recipes[$spellID]
    $name = $itemNames[$itemID]
    if (-not $name -or $name -notmatch $NameFilter) { continue }
    if ($ExpansionID -ne 0 -and $itemExpansions[$itemID] -ne $ExpansionID) { continue }
    if (-not $reagentsBySpell.ContainsKey($spellID)) {
        Write-Warning "'$name' (spell $spellID) has no reagents; skipped."
        continue
    }
    $null = $lures.Add([pscustomobject]@{
        ItemId   = [int]$itemID
        SpellId  = [int]$spellID
        Name     = $name
        Reagents = $reagentsBySpell[$spellID]
    })
}

if ($lures.Count -eq 0) {
    throw "No recipe on skill line $SkillLine matched '$NameFilter' for expansion $ExpansionID. Did the data layout change?"
}

$lures = $lures | Sort-Object ItemId
Write-Host "  $($lures.Count) matching recipes" -ForegroundColor Green
foreach ($lure in $lures) {
    $parts = $lure.Reagents | ForEach-Object { "$($_.Count)x $($itemNames[$_.Id])" }
    Write-Host "    $($lure.Name): $($parts -join ', ')"
}

# ---------------------------------------------------------------------------
# 7. Emit Data.lua
# ---------------------------------------------------------------------------

function Get-LuaString {
    param([string] $Value)
    return '"' + ($Value -replace '\\', '\\\\' -replace '"', '\"') + '"'
}

$out = New-Object System.Text.StringBuilder
$null = $out.AppendLine("-- Generated by tools/Update-Data.ps1 - do not edit by hand.")
$null = $out.AppendLine("-- Source: wago.tools DB2 exports (SkillLineAbility, SpellEffect, CraftingData, SpellReagents, ItemSparse)")
$null = $out.AppendLine("-- Build: $Build")
$null = $out.AppendLine("-- Generated: $(Get-Date -Format 'yyyy-MM-dd')")
$null = $out.AppendLine("")
$null = $out.AppendLine("local _, ns = ...")
$null = $out.AppendLine("")
$null = $out.AppendLine("ns.DATA_BUILD = `"$Build`"")
$null = $out.AppendLine("")
$null = $out.AppendLine("-- Recipes, keyed by the item the recipe produces.")
$null = $out.AppendLine("-- ``name`` is the enUS name, used only as a fallback until the client has the item cached.")
$null = $out.AppendLine("ns.lures = {")

foreach ($lure in $lures) {
    $null = $out.AppendLine("`t[$($lure.ItemId)] = {")
    $null = $out.AppendLine("`t`tspellID = $($lure.SpellId),")
    $null = $out.AppendLine("`t`tname = $(Get-LuaString $lure.Name),")
    $null = $out.AppendLine("`t`treagents = {")
    foreach ($reagent in $lure.Reagents) {
        $reagentName = Get-LuaString $itemNames[$reagent.Id]
        $null = $out.AppendLine("`t`t`t{ id = $($reagent.Id), count = $($reagent.Count), name = $reagentName },")
    }
    $null = $out.AppendLine("`t`t},")
    $null = $out.AppendLine("`t},")
}

$null = $out.AppendLine("}")
$null = $out.AppendLine("")
$null = $out.AppendLine("-- Reverse index: which lures consume a given reagent.")
$null = $out.AppendLine("ns.reagentToLures = {")

$reagentToLures = @{}
foreach ($lure in $lures) {
    foreach ($reagent in $lure.Reagents) {
        $key = [int]$reagent.Id
        if (-not $reagentToLures.ContainsKey($key)) {
            $reagentToLures[$key] = New-Object System.Collections.ArrayList
        }
        $null = $reagentToLures[$key].Add($lure.ItemId)
    }
}

foreach ($reagentId in ($reagentToLures.Keys | Sort-Object)) {
    $ids = ($reagentToLures[$reagentId] | Sort-Object) -join ', '
    $null = $out.AppendLine("`t[$reagentId] = { $ids },")
}

$null = $out.AppendLine("}")

$resolved = [System.IO.Path]::GetFullPath($OutFile)
# UTF-8 without BOM: the WoW client chokes on a BOM at the top of a Lua file.
[System.IO.File]::WriteAllText($resolved, $out.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Wrote $resolved" -ForegroundColor Green
