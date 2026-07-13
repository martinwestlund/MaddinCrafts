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
        'FauxScrollFrame_Update',
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
    ]:
        assert token in ui


def test_ui_avoids_retail_only_apis():
    ui = read('UI.lua')
    for forbidden in ['Mixin', 'CreateFromMixins', 'C_Timer', 'ScrollBox', 'ButtonFrameTemplate']:
        assert forbidden not in ui
