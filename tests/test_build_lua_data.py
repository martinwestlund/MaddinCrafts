import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'tools' / 'build_lua_data.py'


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

    for generated in out.glob('*.lua'):
        committed = ROOT / 'data' / generated.name
        assert committed.exists(), f'missing committed {generated.name}'
        assert generated.read_text(encoding='utf-8') == committed.read_text(encoding='utf-8')
