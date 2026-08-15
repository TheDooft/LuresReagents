# Changelog

## v1.1.0

- Counts can come from **Syndicator**, **Altoholic** or **Warband Nexus**, so the
  craftable figure covers every character on the account. The stock line shows how
  much of the total is reachable right now. `/lr source` picks a provider.
- Item icons in front of every lure and reagent name (`/lr showIcons` to turn off).
- The amount you own is now coloured on a gradient — red at nothing, through
  orange, to green once you have enough for one craft — on both the fish tooltip
  and the reagent list of a lure.
- The addon list now shows a version. The TOC carries a literal version, bumped by
  `tools/Set-Version.ps1`, and the release workflow refuses to publish if the tag
  and the TOC disagree.

## v1.0.0

- Fish tooltips name the Majestic Beast Lure they are a reagent for, the amount
  the recipe takes, and how many lures you can craft with what you currently hold.
- Lure tooltips list their reagents with your stock against the amount required.
- When another reagent caps the recipe, it is named along with the shortfall.
- Counts optionally include bank, reagent bank and warband bank.
- Options panel and `/lr` slash command.
- English and French.
- Data generated from client build 12.1.0.69273.
