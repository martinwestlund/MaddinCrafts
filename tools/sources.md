# MaddinCrafts offline data sources

This addon keeps runtime Lua data generated from `tools/recipe_seed.json`. Add source URLs to each JSON record so future imports can be audited.

## Primary Ascension / custom-profession sources

- Ascension database root: <https://db.ascension.gg/>
  - Use direct `?item=<id>` / `?spell=<id>` links when an Ascension record is found.
  - Until a custom Ascension record is confirmed in the database or in-game, set `verified = false` and explain the uncertainty in `notes`.
- Project Ascension wiki / CoA wiki examples:
  - Woodcutting: <https://project-ascension.fandom.com/wiki/Woodcutting>
  - Woodworking: <https://project-ascension.fandom.com/wiki/Woodworking>
- Bronzebeard custom/progression pages:
  - Bronzebeard portal: <https://bronzebeard.ascension.gg/>
  - Treat Bronzebeard-only claims as server-variant data and keep `verified = false` until matched to Ascension DB or in-game data.

## Classic / WotLK recipe references

Use Classic references for broad baseline coverage; these are suitable as `verified = true` only when the record is a standard Classic trainer/vendor/drop recipe and not making an Ascension-specific availability claim.

- Wowhead Classic recipes and spells: <https://www.wowhead.com/classic/>
  - Spell links use `https://www.wowhead.com/classic/spell=<id>/<slug>`.
  - Recipe item links use `https://www.wowhead.com/classic/item=<id>/<slug>`.
- ClassicDB fallback/reference: <https://classicdb.ch/>
  - Example item format: <https://classicdb.ch/?item=2555>.

## Current seed coverage

`recipe_seed.json` intentionally starts small but broad:

- Classic trainer/vendor/drop examples for Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring, Cooking, and First Aid.
- Existing Blacksmithing seed records were moved under generation and keep Ascension-specific uncertainty notes where applicable.
- Ascension custom Woodcutting/Woodworking placeholders are included as `verified = false` with notes to demonstrate layering custom data after the Classic baseline.

## Curation rules

1. Prefer one recipe per JSON object with stable `id` values: `<profession>-<recipe-name-slug>`.
2. Include at least one `sourceUrls` entry per record; the generator strips these from runtime Lua.
3. Keep source-specific claims conservative:
   - Standard Classic record only: `verified = true` is acceptable.
   - Ascension DB, CoA wiki, Bronzebeard, or server-specific claim: `verified = false` unless independently confirmed, and add `notes`.
4. Rebuild generated Lua after changes:

   ```sh
   python3 tools/build_lua_data.py --input tools/recipe_seed.json --output-dir data
   ```

5. Run tests before committing:

   ```sh
   pytest
   ```
