# MaddinCrafts data quality

MaddinCrafts ships generated Lua recipe data from the curated seed file at `tools/recipe_seed.json`. The generated files in `data/*.lua` are runtime artifacts and should not be edited by hand.

> **Coverage notice:** The bundled seed is currently partial coverage only, not an exhaustive recipe database. In-game progress counts and Learned/Available/Unlearned totals only describe the bundled records until more recipes are added.

## Source confidence

Recipe records include a `verified` flag and `notes` field:

- `verified = true`: the recipe is a standard Classic/WotLK-era profession recipe or has been confirmed against a reliable source.
- `verified = false`: the record contains an Ascension, CoA wiki, Bronzebeard, server-variant, or otherwise uncertain claim.

Ascension custom-profession data can vary by server and patch. CoA wiki and Bronzebeard pages are useful leads, but they are treated as uncertain until the recipe is independently confirmed in Ascension DB or in game. Keep these records unverified and explain the uncertainty in `notes`.

## Adding or correcting recipes

1. Edit `tools/recipe_seed.json`.
2. Add one JSON object per recipe with the runtime fields plus `sourceUrls`.
3. Use stable ids in the form `<profession>-<recipe-name-slug>`.
4. Include at least one source URL for auditability.
5. For Ascension/CoA/Bronzebeard/custom records, set `verified` to `false` and include a note describing what still needs confirmation.
6. Regenerate the Lua data:

   ```sh
   python3 tools/build_lua_data.py --input tools/recipe_seed.json --output-dir data
   ```

7. Run validation and tests:

   ```sh
   pytest
   ```

8. If `luac` is installed, run a Lua syntax check:

   ```sh
   find . -name '*.lua' -print -exec luac -p {} \;
   ```

## Data review checklist

Before committing data changes, confirm that:

- Generated `data/*.lua` files changed only as expected.
- `sourceUrls` are present in the seed but not in generated Lua.
- Custom or uncertain records remain `verified = false`.
- Notes are clear enough for a future maintainer to verify or replace the record.
- `pytest` passes and, when available, `luac -p` accepts every Lua file.
