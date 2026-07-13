# MaddinCrafts data quality

MaddinCrafts ships generated Lua recipe data from the curated seed file at `tools/recipe_seed.json`. The generated files in `data/*.lua` are runtime artifacts and should not be edited by hand.

> **Coverage notice:** The bundled data now includes broad Vanilla/Classic skill-cap-300 profession spell coverage imported from ClassicDB and source/location enrichment for most imported records. Remaining `SOURCE_PENDING` records still need acquisition-source curation, and `requiredSkill = 0` means the skill requirement is unknown.

## Source confidence

Recipe records include a `verified` flag and `notes` field:

- `verified = true`: the recipe and its acquisition source have been confirmed against a reliable source.
- `verified = false`: the record contains an Ascension, CoA wiki, Bronzebeard, server-variant, broad ClassicDB import, or otherwise uncertain claim.
- `sourceType = "SOURCE_PENDING"`: the recipe is present in a broad profession spell-list import, but the exact trainer/vendor/drop/quest/reputation source has not been verified yet. These records are intentionally not treated as Available by the addon.
- `requiredSkill = 0`: the recipe exists but the skill requirement is unknown. These records are also not treated as Available until the skill requirement is curated.

Ascension custom-profession data can vary by server and patch. CoA wiki and Bronzebeard pages are useful leads, but they are treated as uncertain until the recipe is independently confirmed in Ascension DB or in game. Keep these records unverified and explain the uncertainty in `notes`.

## Adding or correcting recipes

1. Edit `tools/recipe_seed.json`.
2. Add one JSON object per recipe with the runtime fields plus `sourceUrls`.
3. Use stable ids in the form `<profession>-<recipe-name-slug>`.
4. Include at least one source URL for auditability.
5. For Ascension/CoA/Bronzebeard/custom records, set `verified` to `false` and include a note describing what still needs confirmation.
6. For broad ClassicDB imports, use the importer rather than editing records by hand:

   ```sh
   python3 tools/import_classicdb_skill_lists.py --input tools/recipe_seed.json --output tools/recipe_seed.json
   ```

7. Enrich ClassicDB source/location hints when desired:

   ```sh
   python3 tools/enrich_classicdb_sources.py --input tools/recipe_seed.json --output tools/recipe_seed.json
   ```

8. Replace `SOURCE_PENDING` with `TRAINER`, `VENDOR`, `QUEST`, `DROP`, or `ASCENSION_CUSTOM` only after confirming the acquisition source. Set a positive `requiredSkill` before expecting the recipe to appear as Available.

9. Regenerate the Lua data:

   ```sh
   python3 tools/build_lua_data.py --input tools/recipe_seed.json --output-dir data
   ```

10. Run validation and tests:

   ```sh
   pytest
   ```

11. If `luac` is installed, run a Lua syntax check:

   ```sh
   find . -name '*.lua' -print -exec luac -p {} \;
   ```

## Data review checklist

Before committing data changes, confirm that:

- Generated `data/*.lua` files changed only as expected.
- `sourceUrls` are present in the seed but not in generated Lua.
- Custom, imported, or uncertain records remain `verified = false` until their acquisition source is confirmed.
- Notes are clear enough for a future maintainer to verify or replace the record.
- `pytest` passes and, when available, `luac -p` accepts every Lua file.
