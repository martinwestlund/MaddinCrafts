from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text()


def test_toc_loads_data_before_seed_files():
    toc = read('MaddinCrafts.toc')
    data = toc.index('Data.lua')
    professions = toc.index('data/Professions.lua')
    blacksmithing = toc.index('data/Blacksmithing.lua')
    assert data < professions < blacksmithing


def test_data_model_declares_schema_and_validation():
    data = read('Data.lua')
    for field in [
        'id', 'name', 'profession', 'requiredSkill', 'sourceType', 'sourceText',
        'recipeItemId', 'teachesSpellId', 'faction', 'reputation', 'phase',
        'verified', 'notes',
    ]:
        assert field in data
    assert 'ValidateRecipe' in data
    assert 'ValidateData' in data
    assert 'Warn' in data


def test_professions_include_required_entries_with_disabled_wrath_customs():
    professions = read('data/Professions.lua')
    for profession in [
        'Alchemy', 'Blacksmithing', 'Enchanting', 'Engineering', 'Herbalism',
        'Inscription', 'Jewelcrafting', 'Leatherworking', 'Mining', 'Skinning',
        'Tailoring', 'Cooking', 'First Aid', 'Fishing', 'Woodcutting', 'Woodworking',
    ]:
        assert profession in professions
    assert 'INSCRIPTION' in professions and 'enabled = false' in professions
    assert 'JEWELCRAFTING' in professions and 'enabled = false' in professions


def test_blacksmithing_seed_has_modest_alliance_first_real_records():
    blacksmithing = read('data/Blacksmithing.lua')
    assert blacksmithing.count('requiredSkill =') >= 8
    assert 'BLACKSMITHING' in blacksmithing
    assert 'Alliance' in blacksmithing
    assert 'verified = false' in blacksmithing
    assert 'Ascension' in blacksmithing or 'CoA' in blacksmithing


def test_toc_loads_state_scanner_before_entrypoint():
    toc = read('MaddinCrafts.toc')
    assert 'State.lua' in toc
    assert toc.index('State.lua') < toc.index('MaddinCrafts.lua')


def test_state_scanner_uses_wotlk_state_apis_and_events():
    state = read('State.lua')
    for token in [
        'UnitFactionGroup("player")', 'GetNumFactions', 'GetFactionInfo',
        'GetProfessions', 'GetProfessionInfo', 'GetNumTradeSkills',
        'GetTradeSkillInfo', 'GetTradeSkillRecipeLink',
        'ADDON_LOADED', 'PLAYER_LOGIN', 'TRADE_SKILL_SHOW',
        'TRADE_SKILL_UPDATE', 'CHAT_MSG_SKILL',
    ]:
        assert token in state
    assert 'ExpandFactionHeader' not in state
    assert 'CollapseFactionHeader' not in state


def test_state_scanner_caches_per_character_learned_recipe_ids():
    state = read('State.lua')
    assert 'GetRealmName()' in state
    assert 'UnitName("player")' in state
    assert 'characters' in state
    assert 'learnedRecipes' in state
    assert 'ExtractIdFromLink' in state
