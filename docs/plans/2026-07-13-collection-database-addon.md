# MaddinCrafts Collection Database Addon Implementation Plan

> **REQUIRED SUB-SKILL:** Use the executing-plans skill to implement this plan task-by-task.

**Goal:** Build a WotLK/Ascension-compatible profession recipe collection addon that ships with bundled recipe data and categorizes recipes as Learned, Available, or Unlearned.

**Architecture:** The addon is a Lua 5.1 / WoW 3.3.5 addon with a small core, state scanner, recipe categorizer, UI module, and modular data files. Recipe data is static Lua generated/curated from Ascension DB, CoA/Bronzebeard sources, and Classic/Vanilla references, with source confidence flags.

**Tech Stack:** WoW 3.3.5 addon API, Lua 5.1, `.toc` Interface 30300, optional Python 3 tooling for offline data conversion/validation.

---

### Task 1: Minimal Addon Skeleton

**Files:**
- Create: `MaddinCrafts.toc`
- Create: `MaddinCrafts.lua`
- Create: `Core.lua`
- Create: `Debug.lua`
- Create: `README.md`

**Steps:**
1. Create `.toc` with `## Interface: 30300`, SavedVariables `MaddinCraftsDB`, and Lua file order.
2. Create namespace table `MaddinCrafts` and defensive SavedVariables initialization on `ADDON_LOADED`.
3. Add debug logger controlled by saved setting `debug`.
4. Add README install instructions for `Interface/AddOns/MaddinCrafts`.
5. Verify Lua syntax with `luac -p` if available.
6. Commit: `feat: add addon skeleton`.

### Task 2: Recipe Data Model and Seed Data

**Files:**
- Create: `Data.lua`
- Create: `data/Professions.lua`
- Create: `data/Blacksmithing.lua`
- Modify: `MaddinCrafts.toc`

**Steps:**
1. Define professions including Alchemy, Blacksmithing, Enchanting, Engineering, Herbalism, Inscription-if-present-only-as-disabled, Jewelcrafting-if-present-only-as-disabled, Leatherworking, Mining, Skinning, Tailoring, Cooking, First Aid, Fishing, Woodcutting, Woodworking.
2. Define recipe schema: id, name, profession, requiredSkill, sourceType, sourceText, recipeItemId, teachesSpellId, faction, reputation, phase, verified, notes.
3. Add Alliance-first seed Blacksmithing records from Classic/Ascension research to prove categorization.
4. Validate all data records at load time and log warnings for missing required fields.
5. Commit: `feat: add recipe data model`.

### Task 3: Player State Scanner

**Files:**
- Create: `State.lua`
- Modify: `MaddinCrafts.toc`

**Steps:**
1. Detect player faction with `UnitFactionGroup("player")`.
2. Detect reputation standings using `GetNumFactions` / `GetFactionInfo`, with recursive collapsed-header expansion avoided in v1.
3. Detect profession skill levels using WotLK APIs when available, with graceful fallback to zero/unknown.
4. Detect learned recipes from opened trade skill windows using `GetNumTradeSkills`, `GetTradeSkillInfo`, `GetTradeSkillRecipeLink`, and item/spell ID extraction from links where available.
5. Cache learned IDs in SavedVariables per character.
6. Register WotLK-era events: `ADDON_LOADED`, `PLAYER_LOGIN`, `TRADE_SKILL_SHOW`, `TRADE_SKILL_UPDATE`, `CHAT_MSG_SKILL`.
7. Commit: `feat: add player state scanner`.

### Task 4: Categorization Engine

**Files:**
- Create: `Catalog.lua`
- Modify: `MaddinCrafts.toc`

**Steps:**
1. Implement `IsLearned(recipe, state)` using cached recipe item/spell IDs and exact name fallback.
2. Implement `IsAvailable(recipe, state)` requiring not learned, skill >= requiredSkill when known, correct faction or neutral, and reputation standing >= requirement.
3. Everything else unlearned.
4. Add overall profession progress counts.
5. Add Lua-only test harness script `tools/run_lua_tests.lua` if `lua` is available outside WoW; otherwise include manual debug command instructions.
6. Commit: `feat: add recipe categorization`.

### Task 5: Basic WotLK-Compatible UI

**Files:**
- Create: `UI.lua`
- Modify: `MaddinCrafts.toc`

**Steps:**
1. Create main frame using `CreateFrame("Frame", "MaddinCraftsFrame", UIParent)`.
2. Add profession list, category buttons Overall/Learned/Available/Unlearned, scrollable recipe list using WotLK-compatible FauxScrollFrame or simple button rows.
3. Add slash commands `/maddincrafts`, `/mc`, `/mcrafts` to toggle UI.
4. Add recipe detail panel with source text, requirements, notes, verification status.
5. No Retail mixins/templates/C_Timer.
6. Commit: `feat: add basic collection UI`.

### Task 6: Offline Data Research and Import Tooling

**Files:**
- Create: `tools/sources.md`
- Create: `tools/recipe_seed.json`
- Create: `tools/build_lua_data.py`
- Create/Update: `data/*.lua`

**Steps:**
1. Record source URLs: Ascension DB, CoA wiki, Bronzebeard pages, Classic recipe references.
2. Add structured JSON records gathered from sources.
3. Generate Lua data files from JSON with stable ordering.
4. Mark uncertain CoA/Bronzebeard/Ascension-only records as `verified = false` with notes.
5. Start with broad Classic profession coverage, then layer Ascension custom additions when sourceable.
6. Commit: `feat: add recipe data import tooling`.

### Task 7: Documentation and Verification

**Files:**
- Modify: `README.md`
- Create: `docs/data-quality.md`

**Steps:**
1. Document install, usage, first-run learned recipe scan requirement, and known Ascension uncertainty.
2. Document how to add/correct recipes.
3. Run syntax checks: `find . -name '*.lua' -print -exec luac -p {} \;` if `luac` exists.
4. Run data generation/validation scripts.
5. Commit: `docs: document usage and data quality`.
