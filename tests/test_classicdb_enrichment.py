import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'tools' / 'enrich_classicdb_sources.py'
SPEC = importlib.util.spec_from_file_location('enrich_classicdb_sources', SCRIPT)
enrich = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(enrich)


def test_extract_taught_by_item_from_spell_listview():
    html = """
    new Listview({template:'item',id:'taught-by-item',data:[{name:'5Recipe: Swiftness Potion',level:15,id:2555}]});
    """

    assert enrich.extract_taught_item(html) == (2555, 'Recipe: Swiftness Potion')


def test_summarize_vendor_examples_keeps_alliance_and_horde_buckets(monkeypatch):
    monkeypatch.setattr(enrich, 'zone_name', lambda zone: {1519: 'Stormwind City', 1637: 'Orgrimmar'}[zone])
    entries = [
        {'name': 'Maria Lumere', 'tag': 'Alchemy Supplies', 'locations': [1519], 'react': [1, -1], 'id': 1},
        {'name': 'Kor\'geld', 'tag': 'Alchemy Supplies', 'locations': [1637], 'react': [-1, 1], 'id': 2},
    ]

    summary = enrich.summarize_npcs(entries)

    assert 'Alliance: Maria Lumere <Alchemy Supplies> (Stormwind City)' in summary
    assert 'Horde: Kor\'geld <Alchemy Supplies> (Orgrimmar)' in summary


def test_add_source_url_is_idempotent():
    recipe = {'sourceUrls': ['https://classicdb.ch/?spell=2335']}

    enrich.add_source_url(recipe, 'https://classicdb.ch/?spell=2335')
    enrich.add_source_url(recipe, 'https://classicdb.ch/?item=2555')

    assert recipe['sourceUrls'] == ['https://classicdb.ch/?spell=2335', 'https://classicdb.ch/?item=2555']


def test_summarize_drop_examples_does_not_add_faction_buckets(monkeypatch):
    monkeypatch.setattr(enrich, 'zone_name', lambda zone: 'Westfall')
    entries = [
        {'name': 'Defias Looter', 'tag': None, 'locations': [40], 'react': [-1, -1], 'id': 1, 'percent': 2.0},
        {'name': 'Salma Saldean', 'tag': None, 'locations': [40], 'react': [1, -1], 'id': 2, 'percent': 1.0},
    ]

    summary = enrich.summarize_plain(entries, sort_by_percent=True)

    assert summary.startswith('Defias Looter (Westfall); Salma Saldean (Westfall)')
    assert 'Alliance:' not in summary
    assert 'Horde:' not in summary
