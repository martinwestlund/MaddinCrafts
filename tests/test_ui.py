from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text()


def test_toc_loads_ui_after_catalog_before_entrypoint():
    toc = read('MaddinCrafts.toc')
    assert 'UI.lua' in toc
    assert toc.index('Catalog.lua') < toc.index('UI.lua') < toc.index('MaddinCrafts.lua')


def test_ui_declares_wotlk_frame_slash_and_lists():
    ui = read('UI.lua')
    for token in [
        'CreateFrame("Frame", "MaddinCraftsFrame", UIParent)',
        'UIPanelButtonTemplate',
        'SLASH_MADDINCRAFTS1 = "/maddincrafts"',
        'SLASH_MADDINCRAFTS2 = "/mc"',
        'SLASH_MADDINCRAFTS3 = "/mcrafts"',
        'SlashCmdList["MADDINCRAFTS"]',
        'Overall',
        'Learned',
        'Available',
        'Unlearned',
        'sourceText',
        'requiredSkill',
        'notes',
        'verified',
        'pageOffset',
        'MaddinCraftsPrevPage',
        'MaddinCraftsNextPage',
    ]:
        assert token in ui


def test_ui_uses_plain_buttons_instead_of_fragile_radio_or_scroll_templates():
    ui = read('UI.lua')
    assert 'UIRadioButtonTemplate' not in ui
    assert 'FauxScrollFrameTemplate' not in ui
    assert 'FauxScrollFrame_Update' not in ui
    assert 'FauxScrollFrame_OnVerticalScroll' not in ui


def test_ui_filters_profession_buttons_to_professions_with_recipes_and_reports_counts():
    ui = read('UI.lua')
    assert 'HasRecipes(professionId)' in ui
    assert 'shown / ' in ui
    assert 'No profession data loaded' in ui


def test_ui_avoids_retail_only_apis():
    ui = read('UI.lua')
    for forbidden in ['Mixin', 'CreateFromMixins', 'C_Timer', 'ScrollBox', 'ButtonFrameTemplate']:
        assert forbidden not in ui
