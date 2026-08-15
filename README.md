# Lures Reagents

A small World of Warcraft addon for Midnight. Hover a fish, and its tooltip tells
you which **Majestic Beast Lure** it is used for, how many the recipe takes, and
how many lures you could craft right now.

Renowned beasts only spawn from those lures, and the lures are the only route to
Majestic Fin, Majestic Claw and Majestic Hide — but nothing in game connects a
fish in your bags back to the lure that wants it. This addon draws that line.

## What it shows

On a fish that is a lure reagent:

```
Lynxfish
──────────────────────────────────────────────
Used in Skinning lures:              you have 37
  Majestic Eversong Lure    8 per craft · 2 craftable
    short 20 Arcane Wyrmfish
```

The *craftable* count considers every reagent of the recipe, not just the one you
are hovering, and the line underneath names whichever reagent runs out first.

The amount you own is coloured on a gradient: red at nothing, orange as it climbs,
green once you have enough for one craft of the cheapest lure that wants it. So a
fish reads as "worth keeping" at a glance, without reading the numbers.

On a lure itself, the tooltip lists what it takes and what you already hold:

```
Majestic Eversong Lure
──────────────────────────────────────────────
Lure reagents:                       can craft 2
  Arcane Wyrmfish                          16 / 8
  Lynxfish                                 37 / 8
```

Counts include your bank, reagent bank and warband bank by default.

## Counting your other characters

If you have an inventory addon installed, the totals cover your whole account
instead of just the character you are playing, and the stock line says how much of
that is within reach right now:

```
Used in Skinning lures:          you have 137 · 37 here
  Majestic Eversong Lure   8 per craft · 17 craftable
```

Supported, tried in this order: **Syndicator**, **Altoholic** (through its
DataStore modules), **Warband Nexus**. Pick a specific one with `/lr source
syndicator`, or `/lr source character` to ignore them all.

None of them is required — without any, the addon counts what the client can see.
Guild banks are always excluded: shared stock is not reliably yours to spend on a
craft. Those addons already print their own per-character breakdown into the same
tooltip, so this one takes the total and leaves the breakdown to them. If a
provider reports less than the client can see — a stale cache, usually — the live
count wins.

## Options

`/lr` lists every option and its state, `/lr <option>` toggles one, and
`/lr config` opens the settings panel. Everything is also under
*Options → AddOns → Lures Reagents*.

| Option | Default | Effect |
| --- | --- | --- |
| `enabled` | on | Master switch for all tooltip additions |
| `showOnReagents` | on | Annotate fish tooltips |
| `showOnLures` | on | Annotate lure tooltips |
| `showIcons` | on | Put each item's icon in front of its name |
| `showCounts` | on | Show how many you own |
| `showCraftable` | on | Show how many you can craft |
| `showShortage` | on | Name the reagent that caps the recipe |
| `includeBank` | on | Count bank and reagent bank |
| `includeWarband` | on | Count the warband bank |

`/lr source <auto\|character\|syndicator\|altoholic\|warbandnexus>` chooses where
counts come from; it is a dropdown in the settings panel.

## Languages

English and French. Item names always come from the client, so they are correct
in every locale; only the addon's own wording needs translating. Pull requests
adding a locale to `Locales.lua` are welcome.

## Updating the data after a patch

`Data.lua` is generated, never hand-edited. It is built straight from Blizzard's
client data via [wago.tools](https://wago.tools), following the chain the game
itself uses:

```
SkillLineAbility (SkillLine 393, Skinning)
  → Spell
  → SpellEffect (Effect 288, craft item)
  → CraftingData.CraftedItemID
Spell → SpellReagents → reagents and quantities
```

To regenerate against your installed client:

```bash
.\tools\Update-Data.ps1
```

The script detects the build from `.build.info`, downloads the DB2 exports (cached
under `%TEMP%`), prints every recipe it found, and rewrites `Data.lua`. Pass
`-Build`, `-SkillLine`, `-NameFilter` or `-ExpansionID` to target something else —
`-ExpansionID 0 -NameFilter 'Lure$'` will show you every lure Skinning has ever
had, across all expansions.

## Tests

`tests/harness.lua` stubs the slice of the WoW API the addon touches and renders
tooltips as plain text, so the display logic can be checked without launching the
game. From the repo root:

```bash
lua tests/run.lua
```

CI runs the same file on every push.

## Releasing

The scripts under `tools/` run on Windows PowerShell 5.1 — PowerShell 7 is not
required. Run them from the repo root, with the leading `.\`, which PowerShell
insists on for a script in the current directory.

Windows blocks `.ps1` files by default (`Restricted`), so a fresh clone will hit
*"running scripts is disabled on this system"*. Either bypass it per call:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Set-Version.ps1 1.2.0
```

or allow local scripts once, for your user only, which needs no admin rights:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

The TOC holds a **literal** version rather than the packager's
`@project-version@` token, so the version shows in the in-game addon list even on
a working copy that was never packaged. That means the TOC and the tag have to be
kept in step, which `tools/Set-Version.ps1` does and CI enforces.

Every release, whatever changed:

```bash
.\tools\Set-Version.ps1 1.2.0
```

Fill in the changelog section it opened, then:

```bash
.\tools\Set-Version.ps1 1.2.0 -Tag
```

```bash
git push origin main --tags
```

Pushing a `v*` tag runs the release workflow, which

1. refuses to continue if the TOC version and the tag disagree,
2. carves this version's section out of `CHANGELOG.md` so the release page shows
   its own notes rather than the whole history,
3. hands off to the [BigWigs packager](https://github.com/BigWigsMods/packager),
   which builds the zip, attaches it to a GitHub release, and uploads to
   CurseForge if it is set up.

The release type follows the tag name: a tag containing `alpha` or `beta` is
marked as such on CurseForge, anything else is a full release. So `v1.2.0-beta1`
publishes to the beta channel from the same pipeline.

### Connecting CurseForge

One-time, in this order:

1. Create the project from the author dashboard at
   [authors.curseforge.com](https://authors.curseforge.com/) and note its
   **Project ID**, shown on the project's own page.
2. Add `## X-Curse-Project-ID: <id>` to `LuresReagents.toc`. The packager reads it
   from there; there is nothing to configure in the workflow.
3. Generate an **author** API token — *Account settings → API Tokens*, at
   [authors-old.curseforge.com/account/api-tokens](https://authors-old.curseforge.com/account/api-tokens)
   as of writing. This is not the Core API key from `console.curseforge.com`,
   which reads the public API and cannot upload. Add it to the repository as the
   secret **`CF_API_KEY`** (*Settings → Secrets and variables → Actions*), or:

   ```bash
   gh secret set CF_API_KEY --repo TheDooft/LuresReagents
   ```

Until all three exist the workflow still runs and still produces a GitHub
release — it just skips the upload.

### After a WoW patch

```bash
.\tools\Update-Data.ps1
```

Then bump `## Interface:` in the TOC to the new build's interface number. The
packager derives the CurseForge game version from that line, so marking the addon
compatible with the new patch is the same one-line edit. Release as above.

## Licence

MIT — see [LICENSE](LICENSE).
