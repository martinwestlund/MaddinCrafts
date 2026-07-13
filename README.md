# MaddinCrafts

MaddinCrafts is a World of Warcraft 3.3.5a / Project Ascension addon.

## Install

1. Copy or clone this repository into your WoW installation's addon folder:
   `Interface/AddOns/MaddinCrafts`
2. Ensure `MaddinCrafts.toc` is directly inside that folder.
3. Restart WoW, or reload the UI with `/reload` if the client is already running.
4. Enable **MaddinCrafts** from the character selection AddOns menu.

## Debug logging

Debug logging is disabled by default. It is controlled by the saved variable:

```lua
MaddinCraftsDB = MaddinCraftsDB or {}
MaddinCraftsDB.debug = true
```

## Manual catalog verification

No standalone `lua` interpreter is available in this worktree environment, so catalog checks should be verified in-game after loading the addon. With debug logging enabled, open a profession window to scan learned recipes, then run:

```lua
/run MaddinCrafts:DebugCatalogSummary()
```

The `DebugCatalogSummary` helper prints overall learned, available, and unlearned recipe counts and returns the progress table for deeper inspection.
