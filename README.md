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

On a lure itself, the tooltip lists what it takes and what you already hold:

```
Majestic Eversong Lure
──────────────────────────────────────────────
Lure reagents:                       can craft 2
  Arcane Wyrmfish                          16 / 8
  Lynxfish                                 37 / 8
```

Counts include your bank, reagent bank and warband bank by default.

## Options

`/lr` lists every option and its state, `/lr <option>` toggles one, and
`/lr config` opens the settings panel. Everything is also under
*Options → AddOns → Lures Reagents*.

| Option | Default | Effect |
| --- | --- | --- |
| `enabled` | on | Master switch for all tooltip additions |
| `showOnReagents` | on | Annotate fish tooltips |
| `showOnLures` | on | Annotate lure tooltips |
| `showCounts` | on | Show how many you own |
| `showCraftable` | on | Show how many you can craft |
| `showShortage` | on | Name the reagent that caps the recipe |
| `includeBank` | on | Count bank and reagent bank |
| `includeWarband` | on | Count the warband bank |

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
pwsh ./tools/Update-Data.ps1
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

## Building a release

Tag a commit `vX.Y.Z` and push the tag. The GitHub Actions workflow runs the
[BigWigs packager](https://github.com/BigWigsMods/packager), which builds the zip,
substitutes `@project-version@` in the TOC and attaches it to a GitHub release. To
publish to CurseForge as well, add a `CF_API_KEY` secret and a `CF_PROJECT_ID`
repository variable.

## Licence

MIT — see [LICENSE](LICENSE).
