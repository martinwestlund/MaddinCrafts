import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'tools' / 'import_classicdb_skill_lists.py'
SPEC = importlib.util.spec_from_file_location('import_classicdb_skill_lists', SCRIPT)
classicdb_importer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(classicdb_importer)


def test_classicdb_importer_uses_zero_for_unknown_required_skill():
    obj = "{name:'7Arcane Elixir',skill:[171],colors:[,250,270,290],id:'11461'}"

    assert classicdb_importer.extract_required_skill(obj) == 0


def test_classicdb_importer_preserves_known_required_skill():
    obj = "{name:'6Example',skill:[171],colors:[125,150,175,200],id:'123'}"

    assert classicdb_importer.extract_required_skill(obj) == 125


def test_classicdb_importer_refreshes_source_pending_records_but_preserves_curated_records():
    existing = [
        {
            'id': 'classicdb-alchemy-arcane-elixir-11461',
            'name': 'Arcane Elixir',
            'profession': 'ALCHEMY',
            'requiredSkill': 1,
            'sourceType': 'SOURCE_PENDING',
            'teachesSpellId': 11461,
        },
        {
            'id': 'alchemy-minor-healing-potion',
            'name': 'Minor Healing Potion',
            'profession': 'ALCHEMY',
            'requiredSkill': 1,
            'sourceType': 'TRAINER',
            'teachesSpellId': 2330,
        },
    ]
    imported = [
        {
            'id': 'classicdb-alchemy-arcane-elixir-11461',
            'name': 'Arcane Elixir',
            'profession': 'ALCHEMY',
            'requiredSkill': 0,
            'sourceType': 'SOURCE_PENDING',
            'teachesSpellId': 11461,
        },
        {
            'id': 'classicdb-alchemy-minor-healing-potion-2330',
            'name': 'Minor Healing Potion',
            'profession': 'ALCHEMY',
            'requiredSkill': 0,
            'sourceType': 'SOURCE_PENDING',
            'teachesSpellId': 2330,
        },
    ]

    merged = classicdb_importer.merge_records(existing, imported)

    arcane = next(r for r in merged if r['teachesSpellId'] == 11461)
    minor = next(r for r in merged if r['teachesSpellId'] == 2330)
    assert arcane['requiredSkill'] == 0
    assert arcane['id'] == 'classicdb-alchemy-arcane-elixir-11461'
    assert minor['sourceType'] == 'TRAINER'
    assert minor['id'] == 'alchemy-minor-healing-potion'
    assert len(merged) == 2
