# MaddinCrafts

MaddinCrafts is a World of Warcraft 3.3.5a / Project Ascension addon for tracking profession recipe collection progress.

It ships with bundled recipe data, scans recipes your character has learned, and groups recipes into Learned, Available, and Unlearned categories.

> **Data coverage notice:** The bundled database now includes broad Vanilla/Classic skill-cap-300 profession spell coverage from ClassicDB, with source/location enrichment for most imported records. Some records remain `SOURCE_PENDING`, meaning the recipe exists in the ClassicDB profession list but the exact trainer/vendor/drop/quest acquisition source still needs verification.

## Install

1. Copy or clone this repository into your WoW installation's addon folder:
   `Interface/AddOns/MaddinCrafts`
2. Ensure `MaddinCrafts.toc` is directly inside that folder.
3. Restart WoW, or reload the UI with `/reload` if the client is already running.
4. Enable **MaddinCrafts** from the character selection AddOns menu.

## Usage

Open the addon with any of these slash commands:

```text
/maddincrafts
/mc
/mcrafts
```

Use the profession list to choose a profession, then switch between:

- **Overall**: summary view for the selected profession.
- **Learned**: recipes MaddinCrafts has detected on this character.
- **Available**: recipes that appear learnable based on known skill, faction, reputation data, and a usable source type. `SOURCE_PENDING` records and records with unknown skill (`requiredSkill = 0`) stay Unlearned until their requirements are curated.
- **Unlearned**: recipes not currently known or available according to the addon cache.

Selecting a recipe shows its source text, requirements, notes, and verification status. The profession buttons include bundled record counts, and the recipe list header shows how many records are displayed for the current filter.

## First-run learned recipe scan

MaddinCrafts can only know learned recipes after the WoW trade skill window has exposed them to the addon. On first run for each character:

1. Log into the character.
2. Open each known profession window at least once.
3. Let the list load, then close it or switch professions.
4. Open MaddinCrafts again to see updated Learned/Available/Unlearned counts.

The learned recipe cache is stored per character in `MaddinCraftsDB`. If a profession has never been opened on that character, some learned recipes may temporarily appear as unlearned until the scan runs.

## Data quality and Ascension uncertainty

The bundled records now include broad Vanilla/Classic skill-cap-300 coverage imported from ClassicDB profession spell lists, plus source/location enrichment from ClassicDB spell and recipe-item pages. Most records now include trainer examples, vendor NPCs/zones, or drop examples. Some remain `SOURCE_PENDING` when ClassicDB did not expose a clear acquisition source. `requiredSkill = 0` means the skill requirement is still unknown and the recipe will not be shown as Available. Ascension DB, CoA wiki, and Bronzebeard/server-variant records can be incomplete or differ between realms and patches. Uncertain records are marked unverified and include notes.

See [docs/data-quality.md](docs/data-quality.md) for the curation rules, source-confidence policy, and how to add or correct recipes.

## Adding or correcting recipes

Recipe data is curated in `tools/recipe_seed.json` and generated into `data/*.lua`. Do not edit generated Lua data by hand.

To add or fix a recipe:

1. Update the matching record, or add a new record, in `tools/recipe_seed.json`.
2. Include a source URL in `sourceUrls`.
3. Keep Ascension/CoA/Bronzebeard/custom claims as `verified = false` until independently confirmed, and explain uncertainty in `notes`. Use `SOURCE_PENDING` for broad imported records whose exact acquisition source is not known yet.
4. Optionally refresh ClassicDB source/location enrichment:

   ```sh
   python3 tools/enrich_classicdb_sources.py --input tools/recipe_seed.json --output tools/recipe_seed.json
   ```

5. Regenerate data:

   ```sh
   python3 tools/build_lua_data.py --input tools/recipe_seed.json --output-dir data
   ```

6. Run validation/tests before committing:

   ```sh
   pytest
   ```

## Debug logging

Debug logging is disabled by default. It is controlled by the saved variable:

```lua
MaddinCraftsDB = MaddinCraftsDB or {}
MaddinCraftsDB.debug = true
```

## Manual catalog verification

With debug logging enabled, open a profession window to scan learned recipes, then run:

```lua
/run MaddinCrafts:DebugCatalogSummary()
```

The `DebugCatalogSummary` helper prints overall learned, available, and unlearned recipe counts and returns the progress table for deeper inspection.
