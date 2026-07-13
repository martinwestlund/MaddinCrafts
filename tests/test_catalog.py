from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text()


def test_toc_loads_catalog_after_state_before_entrypoint():
    toc = read('MaddinCrafts.toc')
    assert 'Catalog.lua' in toc
    assert toc.index('State.lua') < toc.index('Catalog.lua') < toc.index('MaddinCrafts.lua')


def test_catalog_declares_recipe_categorization_api():
    catalog = read('Catalog.lua')
    for token in [
        'function MC:IsLearned(recipe, state)',
        'function MC:IsAvailable(recipe, state)',
        'function MC:GetRecipeCategory(recipe, state)',
        'function MC:GetProfessionProgress(professionId, state)',
        'function MC:GetOverallProgress(state)',
        'recipeItemId',
        'teachesSpellId',
        'learnedRecipeNames',
        'requiredSkill',
        'reputation',
    ]:
        assert token in catalog


def test_catalog_manual_debug_instructions_exist_when_no_local_lua():
    readme = read('README.md')
    assert 'Manual catalog verification' in readme
    assert 'DebugCatalogSummary' in readme
