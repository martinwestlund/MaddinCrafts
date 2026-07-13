#!/usr/bin/env python3
"""Enrich ClassicDB-imported recipes with acquisition source/location hints.

This script reads `tools/recipe_seed.json`, fetches ClassicDB spell pages, follows
`taught-by-item` recipe-item pages, and fills sourceType/sourceText where ClassicDB
shows trainers, vendors, drops, or quests. It is deliberately conservative:
requiredSkill=0 remains unknown, so the addon will not mark these recipes
Available until skill/source curation is stronger.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any

CACHE_DIR = Path(".cache/classicdb")
CLASSICDB = "https://classicdb.ch/"


def fetch_cached(kind: str, identifier: int) -> str:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = CACHE_DIR / f"{kind}-{identifier}.html"
    if path.exists():
        return path.read_text(encoding="utf-8", errors="ignore")
    url = f"{CLASSICDB}?{kind}={identifier}"
    with urllib.request.urlopen(url, timeout=30) as response:
        text = response.read().decode("utf-8", "ignore")
    path.write_text(text, encoding="utf-8")
    time.sleep(0.05)
    return text


def strip_quality_prefix(name: str) -> str:
    return re.sub(r"^[^A-Za-z]+", "", html.unescape(name)).strip()


def extract_data_array_from(html_text: str, start: int) -> str | None:
    marker = "data:["
    start = html_text.find(marker, start)
    if start == -1:
        return None
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
    return None


def find_listview_data(html_text: str, list_id: str) -> str | None:
    pattern = f"id:'{list_id}'"
    start = html_text.find(pattern)
    if start == -1:
        pattern = f'id:"{list_id}"'
        start = html_text.find(pattern)
    if start == -1:
        return None
    return extract_data_array_from(html_text, start)


def split_objects(data: str | None) -> list[str]:
    if not data:
        return []
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


def js_string(obj: str, field: str) -> str | None:
    match = re.search(rf"{field}:'((?:\\.|[^'])*)'", obj)
    if not match:
        return None
    value = match.group(1)
    value = value.replace("\\'", "'").replace('\\"', '"').replace("\\\\", "\\")
    return strip_quality_prefix(value)


def js_int(obj: str, field: str) -> int | None:
    match = re.search(rf"{field}:'?(\d+)'?", obj)
    if not match:
        return None
    return int(match.group(1))


def js_float(obj: str, field: str) -> float | None:
    match = re.search(rf"{field}:([0-9]+(?:\.[0-9]+)?)", obj)
    if not match:
        return None
    return float(match.group(1))


def js_int_list(obj: str, field: str) -> list[int]:
    match = re.search(rf"{field}:\[([^\]]*)\]", obj)
    if not match:
        raw = re.search(rf"{field}:(\d+)", obj)
        return [int(raw.group(1))] if raw else []
    result = []
    for part in match.group(1).split(','):
        part = part.strip()
        if part.lstrip('-').isdigit():
            result.append(int(part))
    return result


def parse_entries(data: str | None) -> list[dict[str, Any]]:
    entries = []
    for obj in split_objects(data):
        entry = {
            "name": js_string(obj, "name"),
            "tag": js_string(obj, "tag"),
            "id": js_int(obj, "id"),
            "percent": js_float(obj, "percent"),
            "locations": js_int_list(obj, "location"),
            "react": js_int_list(obj, "react"),
        }
        if entry["name"] and entry["id"] is not None:
            entries.append(entry)
    return entries


def zone_name(zone_id: int) -> str:
    if zone_id <= 0:
        return "unknown zone"
    text = fetch_cached("zone", zone_id)
    match = re.search(r"<title>(.*?) - Zone - Classic wow database</title>", text, re.S)
    if match:
        return html.unescape(match.group(1)).strip()
    return f"zone {zone_id}"


def format_location(entry: dict[str, Any]) -> str:
    zones = [zone_name(zone) for zone in entry.get("locations", []) if zone > 0]
    suffix = f" ({', '.join(zones[:2])})" if zones else ""
    tag = f" <{entry['tag']}>" if entry.get("tag") else ""
    return f"{entry['name']}{tag}{suffix}"


def faction_bucket(entry: dict[str, Any]) -> str:
    react = entry.get("react") or []
    if len(react) >= 2:
        if react[0] == 1 and react[1] == -1:
            return "Alliance"
        if react[0] == -1 and react[1] == 1:
            return "Horde"
    return "Neutral"


def summarize_plain(entries: list[dict[str, Any]], *, limit: int = 8, sort_by_percent: bool = False) -> str:
    if sort_by_percent:
        entries = sorted(entries, key=lambda e: (-(e.get("percent") or 0), e.get("name") or ""))
    else:
        entries = sorted(entries, key=lambda e: e.get("name") or "")
    return "; ".join(format_location(entry) for entry in entries[:limit])


def summarize_npcs(entries: list[dict[str, Any]], *, limit_per_faction: int = 4) -> str:
    entries = sorted(entries, key=lambda e: (faction_bucket(e), e.get("name") or ""))
    buckets = {"Alliance": [], "Horde": [], "Neutral": []}
    for entry in entries:
        bucket = faction_bucket(entry)
        if len(buckets[bucket]) < limit_per_faction:
            buckets[bucket].append(format_location(entry))
    parts = []
    for label in ["Alliance", "Horde", "Neutral"]:
        if buckets[label]:
            parts.append(f"{label}: " + "; ".join(buckets[label]))
    if not parts and entries:
        parts.append("; ".join(format_location(e) for e in entries[:limit_per_faction]))
    return " | ".join(parts)


def extract_taught_item(spell_html: str) -> tuple[int | None, str | None]:
    entries = parse_entries(find_listview_data(spell_html, "taught-by-item"))
    if not entries:
        return None, None
    return entries[0]["id"], entries[0]["name"]


def classify_item_source(item_id: int) -> tuple[str, str, list[str]] | None:
    item_html = fetch_cached("item", item_id)
    urls = [f"https://classicdb.ch/?item={item_id}"]
    sold_by = parse_entries(find_listview_data(item_html, "sold-by"))
    if sold_by:
        return "VENDOR", "Sold by: " + summarize_npcs(sold_by, limit_per_faction=5), urls

    reward_from = parse_entries(find_listview_data(item_html, "reward-from-quest"))
    if reward_from:
        names = "; ".join(entry["name"] for entry in reward_from[:5])
        return "QUEST", "Quest reward: " + names, urls

    dropped_by = parse_entries(find_listview_data(item_html, "dropped-by"))
    if dropped_by:
        return "DROP", "Dropped by, examples: " + summarize_plain(dropped_by, limit=8, sort_by_percent=True), urls

    contained = parse_entries(find_listview_data(item_html, "contained-in-object"))
    if contained:
        names = "; ".join(format_location(entry) for entry in contained[:6])
        return "DROP", "Contained in objects, examples: " + names, urls

    return None


def add_source_url(recipe: dict[str, Any], url: str) -> None:
    urls = recipe.setdefault("sourceUrls", [])
    if url not in urls:
        urls.append(url)


def normalize_source_urls(recipe: dict[str, Any]) -> None:
    urls = recipe.get("sourceUrls")
    if not isinstance(urls, list):
        return
    seen = set()
    deduped = []
    for url in urls:
        if url not in seen:
            seen.add(url)
            deduped.append(url)
    recipe["sourceUrls"] = deduped


def enrich_recipe(recipe: dict[str, Any]) -> bool:
    normalize_source_urls(recipe)
    before = json.dumps(recipe, sort_keys=True, ensure_ascii=False)
    spell_id = recipe.get("teachesSpellId")
    if not isinstance(spell_id, int):
        return False
    if recipe.get("sourceType") != "SOURCE_PENDING":
        return False

    spell_html = fetch_cached("spell", spell_id)
    trainers = parse_entries(find_listview_data(spell_html, "taught-by-npc"))
    if trainers:
        recipe["sourceType"] = "TRAINER"
        recipe["sourceText"] = "Profession trainer, examples: " + summarize_npcs(trainers, limit_per_faction=4)
        recipe["verified"] = False
        recipe["notes"] = "ClassicDB lists trainer NPCs for this recipe. Required skill may still need confirmation on CoA/Ascension."
        add_source_url(recipe, f"https://classicdb.ch/?spell={spell_id}")
        return json.dumps(recipe, sort_keys=True, ensure_ascii=False) != before

    item_id, item_name = extract_taught_item(spell_html)
    if item_id is None:
        return False

    item_source = classify_item_source(item_id)
    if item_source is None:
        recipe["sourceText"] = f"Taught by {item_name or 'recipe item'}; acquisition source not found in ClassicDB scrape."
        add_source_url(recipe, f"https://classicdb.ch/?spell={spell_id}")
        add_source_url(recipe, f"https://classicdb.ch/?item={item_id}")
        return json.dumps(recipe, sort_keys=True, ensure_ascii=False) != before

    source_type, source_text, urls = item_source
    recipe["sourceType"] = source_type
    recipe["sourceText"] = f"{item_name or 'Recipe item'} — {source_text}"
    recipe["recipeItemId"] = item_id
    recipe["verified"] = False
    recipe["notes"] = "ClassicDB source/location scrape. Required skill and CoA/Ascension availability may still need in-game confirmation."
    add_source_url(recipe, f"https://classicdb.ch/?spell={spell_id}")
    for url in urls:
        add_source_url(recipe, url)
    return json.dumps(recipe, sort_keys=True, ensure_ascii=False) != before


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", default="tools/recipe_seed.json", type=Path)
    parser.add_argument("--output", default="tools/recipe_seed.json", type=Path)
    parser.add_argument("--limit", type=int, default=0, help="Limit records for debugging")
    args = parser.parse_args(argv)

    seed = json.loads(args.input.read_text(encoding="utf-8"))
    recipes = seed["recipes"]
    changed = 0
    inspected = 0
    for recipe in recipes:
        normalize_source_urls(recipe)
        if recipe.get("sourceType") != "SOURCE_PENDING":
            continue
        inspected += 1
        if args.limit and inspected > args.limit:
            break
        try:
            if enrich_recipe(recipe):
                changed += 1
        except Exception as exc:  # keep long enrichment runs useful
            print(f"warning: failed to enrich {recipe.get('id')}: {exc}", file=sys.stderr)
    args.output.write_text(json.dumps(seed, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Inspected {inspected} SOURCE_PENDING records; enriched {changed}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
