#!/usr/bin/env python3
"""Import broad ClassicDB skill-cap-300 profession spell lists.

This importer intentionally creates SOURCE_PENDING records. ClassicDB list pages
prove that a craft/smelt/enchant spell exists, but they do not consistently
prove required skill or exact acquisition source. Existing curated records with the same
profession + teachesSpellId are preserved so verified trainer/vendor/drop notes
win over broad imported placeholders.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import urllib.request
from pathlib import Path

PROFESSION_PAGES = {
    "ALCHEMY": "https://classicdb.ch/?spells=11.171",
    "BLACKSMITHING": "https://classicdb.ch/?spells=11.164",
    "ENCHANTING": "https://classicdb.ch/?spells=11.333",
    "ENGINEERING": "https://classicdb.ch/?spells=11.202",
    "LEATHERWORKING": "https://classicdb.ch/?spells=11.165",
    "TAILORING": "https://classicdb.ch/?spells=11.197",
    "COOKING": "https://classicdb.ch/?spells=9.185",
    "FIRST_AID": "https://classicdb.ch/?spells=9.129",
    "MINING": "https://classicdb.ch/?spells=11.186",
}

PROFESSION_NAMES = {
    "ALCHEMY": "Alchemy",
    "BLACKSMITHING": "Blacksmithing",
    "ENCHANTING": "Enchanting",
    "ENGINEERING": "Engineering",
    "LEATHERWORKING": "Leatherworking",
    "TAILORING": "Tailoring",
    "COOKING": "Cooking",
    "FIRST_AID": "First Aid",
    "MINING": "Mining",
}

SKIP_NAMES = {
    "Alchemy",
    "Blacksmithing",
    "Cooking",
    "Enchanting",
    "Engineering",
    "First Aid",
    "Leatherworking",
    "Mining",
    "Tailoring",
}

SOURCE_TEXT = "ClassicDB profession spell list; exact trainer/vendor/drop/quest source not verified yet."
NOTES = "Imported from ClassicDB skill-list page for broad CoA/Vanilla skill-cap-300 coverage; acquisition source still needs verification."


def slugify(value: str) -> str:
    value = value.lower().replace("&", "and")
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return value or "recipe"


def fetch(url: str) -> str:
    with urllib.request.urlopen(url, timeout=30) as response:
        return response.read().decode("utf-8", "ignore")


def extract_data_array(html_text: str) -> str:
    marker = "data:["
    start = html_text.find(marker)
    if start == -1:
        raise ValueError("ClassicDB listview data array not found")
    pos = start + len(marker)
    depth = 1
    in_string = False
    escaped = False
    quote = ""
    while pos < len(html_text):
        char = html_text[pos]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                in_string = False
        else:
            if char in "'\"":
                in_string = True
                quote = char
            elif char == "[":
                depth += 1
            elif char == "]":
                depth -= 1
                if depth == 0:
                    return html_text[start + len(marker):pos]
        pos += 1
    raise ValueError("ClassicDB listview data array did not terminate")


def split_objects(data: str) -> list[str]:
    objects: list[str] = []
    start = None
    depth = 0
    in_string = False
    escaped = False
    quote = ""
    for index, char in enumerate(data):
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                in_string = False
            continue
        if char in "'\"":
            in_string = True
            quote = char
        elif char == "{":
            if depth == 0:
                start = index
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0 and start is not None:
                objects.append(data[start:index + 1])
                start = None
    return objects


def extract_js_string(obj: str, field: str) -> str | None:
    match = re.search(rf"{field}:'((?:\\.|[^'])*)'", obj)
    if not match:
        return None
    value = match.group(1)
    value = value.replace("\\'", "'").replace('\\"', '"').replace("\\\\", "\\")
    return html.unescape(value)


def extract_js_int(obj: str, field: str) -> int | None:
    match = re.search(rf"{field}:'?(\d+)'?", obj)
    if not match:
        return None
    return int(match.group(1))


def extract_first_create_item(obj: str) -> int | None:
    match = re.search(r"creates:\[\s*(\d+)\s*,", obj)
    if not match:
        return None
    return int(match.group(1))


def extract_required_skill(obj: str) -> int:
    match = re.search(r"colors:\[([^\]]*)\]", obj)
    if not match:
        return 0
    raw_values = [part.strip() for part in match.group(1).split(",")]
    if raw_values and raw_values[0].isdigit():
        return int(raw_values[0])
    # ClassicDB often omits the orange/required value and only includes
    # yellow/green/gray thresholds. Use 0 to mean unknown rather than
    # pretending high-skill recipes are skill 1.
    return 0


def clean_name(raw_name: str) -> str:
    # ClassicDB prefixes list names with display/quality markers such as 6/7/@.
    name = re.sub(r"^[^A-Za-z]+", "", raw_name).strip()
    return name


def should_import_spell(profession: str, name: str, created_item_id: int | None) -> bool:
    if not name or name in SKIP_NAMES:
        return False
    if profession == "MINING":
        return name.startswith("Smelt ") and created_item_id is not None
    if profession == "ENCHANTING":
        return name != "Disenchant"
    return created_item_id is not None


def import_profession(profession: str, url: str) -> list[dict]:
    page = fetch(url)
    data = extract_data_array(page)
    records: list[dict] = []
    seen_keys = set()
    for obj in split_objects(data):
        raw_name = extract_js_string(obj, "name")
        spell_id = extract_js_int(obj, "id")
        if not raw_name or not spell_id:
            continue
        name = clean_name(raw_name)
        item_id = extract_first_create_item(obj)
        if not should_import_spell(profession, name, item_id):
            continue
        key = (profession, spell_id)
        if key in seen_keys:
            continue
        seen_keys.add(key)
        required_skill = extract_required_skill(obj)
        if required_skill > 300:
            continue
        records.append({
            "id": f"classicdb-{profession.lower()}-{slugify(name)}-{spell_id}",
            "name": name,
            "profession": profession,
            "requiredSkill": required_skill,
            "sourceType": "SOURCE_PENDING",
            "sourceText": SOURCE_TEXT,
            "recipeItemId": None,
            "teachesSpellId": spell_id,
            "faction": "Neutral",
            "reputation": None,
            "phase": "Classic",
            "verified": False,
            "notes": NOTES,
            "sourceUrls": [url, f"https://classicdb.ch/?spell={spell_id}"],
        })
        if item_id is not None:
            records[-1]["sourceUrls"].append(f"https://classicdb.ch/?item={item_id}")
    return records


def merge_records(existing: list[dict], imported: list[dict]) -> list[dict]:
    imported_by_key = {
        (recipe["profession"], recipe["teachesSpellId"]): recipe
        for recipe in imported
    }
    existing_ids = {recipe.get("id") for recipe in existing}
    handled_keys = set()
    merged: list[dict] = []

    for recipe in existing:
        key = (recipe.get("profession"), recipe.get("teachesSpellId"))
        replacement = imported_by_key.get(key)
        if replacement and recipe.get("sourceType") == "SOURCE_PENDING":
            replacement = dict(replacement)
            replacement["id"] = recipe["id"]
            merged.append(replacement)
            handled_keys.add(key)
        else:
            merged.append(recipe)
            if replacement:
                handled_keys.add(key)

    for recipe in imported:
        key = (recipe["profession"], recipe["teachesSpellId"])
        if key in handled_keys:
            continue
        recipe_id = recipe["id"]
        suffix = 2
        while recipe_id in existing_ids:
            recipe_id = f"{recipe['id']}-{suffix}"
            suffix += 1
        recipe["id"] = recipe_id
        existing_ids.add(recipe_id)
        merged.append(recipe)
    return sorted(merged, key=lambda r: (r["profession"], int(r["requiredSkill"]), r["name"].lower(), r["id"]))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", default="tools/recipe_seed.json", type=Path)
    parser.add_argument("--output", default="tools/recipe_seed.json", type=Path)
    args = parser.parse_args(argv)

    seed = json.loads(args.input.read_text(encoding="utf-8"))
    if not isinstance(seed, dict) or not isinstance(seed.get("recipes"), list):
        raise SystemExit("seed JSON must be an object with a recipes array")

    imported: list[dict] = []
    for profession, url in PROFESSION_PAGES.items():
        records = import_profession(profession, url)
        print(f"{PROFESSION_NAMES[profession]}: {len(records)} ClassicDB records", file=sys.stderr)
        imported.extend(records)

    before = len(seed["recipes"])
    seed["recipes"] = merge_records(seed["recipes"], imported)
    after = len(seed["recipes"])
    args.output.write_text(json.dumps(seed, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Merged {after - before} new records ({after} total)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
