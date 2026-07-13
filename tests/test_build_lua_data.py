import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'tools' / 'build_lua_data.py'
SPEC = importlib.util.spec_from_file_location('build_lua_data', SCRIPT)
build_lua_data = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(build_lua_data)


def write_seed(path):
    path.write_text(json.dumps({
        'recipes': [
            {
                'id': 'tailoring-linen-bag',
                'name': 'Linen Bag',
                'profession': 'TAILORING',
                'requiredSkill': 45,
                'sourceType': 'TRAINER',
                'sourceText': 'Tailoring trainer',
                'recipeItemId': None,
                'teachesSpellId': 3755,
                'faction': 'Neutral',
                'reputation': None,
                'phase': 'Classic',
                'verified': True,
                'notes': 'Classic trainer baseline.',
                'sourceUrls': ['https://www.wowhead.com/classic/spell=3755/linen-bag'],
            },
            {
                'id': 'alchemy-minor-healing-potion',
                'name': 'Minor Healing Potion',
                'profession': 'ALCHEMY',
                'requiredSkill': 1,
                'sourceType': 'TRAINER',
                'sourceText': 'Alchemy trainer',
                'recipeItemId': None,
                'teachesSpellId': 2330,
                'faction': 'Neutral',
                'reputation': None,
                'phase': 'Classic',
                'verified': True,
                'notes': 'Classic trainer baseline.',
                'sourceUrls': ['https://www.wowhead.com/classic/spell=2330/minor-healing-potion'],
            },
        ]
    }), encoding='utf-8')


def test_generator_groups_recipes_by_profession_with_stable_order(tmp_path):
    seed = tmp_path / 'seed.json'
    out = tmp_path / 'data'
    write_seed(seed)

    subprocess.run([sys.executable, str(SCRIPT), '--input', str(seed), '--output-dir', str(out)], check=True)

    alchemy = (out / 'Alchemy.lua').read_text(encoding='utf-8')
    tailoring = (out / 'Tailoring.lua').read_text(encoding='utf-8')
    assert 'MC:RegisterRecipes("ALCHEMY", {' in alchemy
    assert 'name = "Minor Healing Potion"' in alchemy
    assert 'teachesSpellId = 2330' in alchemy
    assert 'sourceUrls' not in alchemy
    assert 'MC:RegisterRecipes("TAILORING", {' in tailoring

    generated_files = sorted(p.name for p in out.glob('*.lua'))
    assert generated_files == ['Alchemy.lua', 'Tailoring.lua']


def test_generator_requires_uncertain_custom_records_to_be_unverified(tmp_path):
    seed = tmp_path / 'bad_seed.json'
    out = tmp_path / 'data'
    seed.write_text(json.dumps({'recipes': [{
        'id': 'woodworking-custom-chair',
        'name': 'Custom Chair',
        'profession': 'WOODWORKING',
        'requiredSkill': 1,
        'sourceType': 'ASCENSION_CUSTOM',
        'sourceText': 'Ascension DB',
        'recipeItemId': None,
        'teachesSpellId': 900001,
        'faction': 'Neutral',
        'reputation': None,
        'phase': 'Ascension',
        'verified': True,
        'notes': '',
        'sourceUrls': ['https://db.ascension.gg/'],
    }]}), encoding='utf-8')

    result = subprocess.run([sys.executable, str(SCRIPT), '--input', str(seed), '--output-dir', str(out)], text=True, capture_output=True)

    assert result.returncode != 0
    assert 'Ascension/CoA/Bronzebeard records must be verified=false' in result.stderr


def test_committed_seed_generates_current_lua_data(tmp_path):
    out = tmp_path / 'data'
    subprocess.run([sys.executable, str(SCRIPT), '--input', str(ROOT / 'tools' / 'recipe_seed.json'), '--output-dir', str(out)], check=True)

    generated_files = sorted(p.name for p in out.glob('*.lua'))
    committed_files = sorted(p.name for p in (ROOT / 'data').glob('*.lua') if p.name != 'Professions.lua')
    assert committed_files == generated_files

    for generated in out.glob('*.lua'):
        committed = ROOT / 'data' / generated.name
        assert generated.read_text(encoding='utf-8') == committed.read_text(encoding='utf-8')


def run_generator(seed_path, out):
    return subprocess.run(
        [sys.executable, str(SCRIPT), '--input', str(seed_path), '--output-dir', str(out)],
        text=True,
        capture_output=True,
    )


def write_single_recipe_seed(path, **overrides):
    recipe = {
        'id': 'tailoring-linen-bag',
        'name': 'Linen Bag',
        'profession': 'TAILORING',
        'requiredSkill': 45,
        'sourceType': 'TRAINER',
        'sourceText': 'Tailoring trainer',
        'recipeItemId': None,
        'teachesSpellId': 3755,
        'faction': 'Neutral',
        'reputation': None,
        'phase': 'Classic',
        'verified': True,
        'notes': 'Classic trainer baseline.',
        'sourceUrls': ['https://www.wowhead.com/classic/spell=3755/linen-bag'],
    }
    recipe.update(overrides)
    path.write_text(json.dumps({'recipes': [recipe]}), encoding='utf-8')


@pytest.mark.parametrize(('field', 'value', 'message'), [
    ('id', 123, 'field id must be str'),
    ('name', 123, 'field name must be str'),
    ('profession', 'MINING', 'unknown profession MINING'),
    ('requiredSkill', -1, 'field requiredSkill must be a non-negative integer'),
    ('requiredSkill', True, 'field requiredSkill must be a non-negative integer'),
    ('sourceType', 'QUEST', 'field sourceType must be one of'),
    ('sourceText', 123, 'field sourceText must be str'),
    ('recipeItemId', -1, 'field recipeItemId must be a non-negative integer or null'),
    ('recipeItemId', True, 'field recipeItemId must be a non-negative integer or null'),
    ('teachesSpellId', '3755', 'field teachesSpellId must be a non-negative integer or null'),
    ('faction', 'Aldor', 'field faction must be one of'),
    ('reputation', 1, 'field reputation must be str or null'),
    ('phase', 'Cataclysm', 'field phase must be one of'),
    ('verified', 'true', 'field verified must be bool'),
    ('notes', 123, 'field notes must be str'),
    ('sourceUrls', 'https://example.test', 'field sourceUrls must be a non-empty list of strings'),
    ('sourceUrls', ['https://example.test', 123], 'field sourceUrls must be a non-empty list of strings'),
])
def test_generator_rejects_invalid_seed_field_types_and_enums(tmp_path, field, value, message):
    seed = tmp_path / 'bad_seed.json'
    out = tmp_path / 'data'
    write_single_recipe_seed(seed, **{field: value})

    result = run_generator(seed, out)

    assert result.returncode != 0
    assert message in result.stderr


def test_generator_accepts_scope_enums_without_seed_records(tmp_path):
    seed = tmp_path / 'seed.json'
    out = tmp_path / 'data'
    write_single_recipe_seed(seed, faction='Horde', phase='WotLK')

    result = run_generator(seed, out)

    assert result.returncode == 0, result.stderr
    generated = (out / 'Tailoring.lua').read_text(encoding='utf-8')
    assert 'faction = "Horde"' in generated
    assert 'phase = "WotLK"' in generated


def test_generator_rejects_duplicate_recipe_ids(tmp_path):
    seed = tmp_path / 'bad_seed.json'
    out = tmp_path / 'data'
    write_seed(seed)
    data = json.loads(seed.read_text(encoding='utf-8'))
    data['recipes'][1]['id'] = data['recipes'][0]['id']
    seed.write_text(json.dumps(data), encoding='utf-8')

    result = run_generator(seed, out)

    assert result.returncode != 0
    assert 'duplicate recipe id tailoring-linen-bag' in result.stderr


def test_lua_string_escapes_all_ascii_control_characters_for_lua_51():
    assert build_lua_data.lua_string('a\b\tf\f\v\x01\x1fb') == '"a\\008\\009f\\012\\011\\001\\031b"'
