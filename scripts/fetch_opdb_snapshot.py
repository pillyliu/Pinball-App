#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from collections import defaultdict
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
PINBALL_SCRAPER_ROOT = Path("/Users/pillyliu/Documents/Codex/Pinball Scraper")
PINBALL_SCRAPER_SCRIPTS = PINBALL_SCRAPER_ROOT / "scripts"
PINBALL_SCRAPER_ENV = PINBALL_SCRAPER_ROOT / ".secrets" / "pinball_api.env"
MATCHPLAY_MERGED_DEFAULT = PINBALL_SCRAPER_ROOT / "output" / "matchplay_opdb_enrichment_merged_2026-02-27.json"
EXTERNAL_RESOURCES_DEFAULT = PINBALL_SCRAPER_ROOT / "output" / "opdb_external_resources_preliminary_2026-02-27.json"
SILVERBALL_SITEMAP_URL = "https://rules.silverballmania.com/sitemap.xml"

DEFAULT_IOS_OUTPUT = REPO_ROOT / "Pinball App 2" / "Pinball App 2" / "PinballStarter.bundle" / "pinball" / "data" / "opdb_catalog_v1.json"
DEFAULT_ANDROID_OUTPUT = REPO_ROOT / "Pinball App Android" / "app" / "src" / "main" / "assets" / "starter-pack" / "pinball" / "data" / "opdb_catalog_v1.json"
SUPPORTED_RULESHEET_PROVIDERS = {"tf", "pp", "bob", "papa"}

MANUAL_RULESHEET_OVERRIDES: dict[str, list[tuple[str, str]]] = {
    "GRwv0": [
        ("tf", "https://tiltforums.com/t/creating-a-rulesheet-for-sharkeys-shootout/345"),
    ],
}

MODERN_MANUFACTURERS = [
    "stern",
    "stern pinball",
    "jersey jack pinball",
    "chicago gaming",
    "american pinball",
    "spooky pinball",
    "multimorphic",
    "barrels of fun",
    "dutch pinball",
    "pinball brothers",
    "turner pinball",
]

FEATURED_HISTORICAL = [
    "gottlieb",
    "williams",
    "bally",
    "stern electronics",
    "chicago coin",
    "playmatic",
    "zaccaria",
    "sega",
    "recel",
    "inder",
]


def normalize_string(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    trimmed = value.strip()
    return trimmed or None


def slugify(value: str) -> str:
    lowered = value.lower().replace("&", " and ")
    lowered = re.sub(r"[^a-z0-9]+", "-", lowered)
    lowered = re.sub(r"-{2,}", "-", lowered)
    return lowered.strip("-") or "unknown"


def derive_variant(machine_name: str | None, group_name: str | None) -> str | None:
    if not machine_name:
        return None
    if not group_name:
        return machine_name
    if machine_name == group_name:
        return None
    prefix = f"{group_name} ("
    if machine_name.startswith(prefix) and machine_name.endswith(")"):
        return machine_name[len(prefix):-1].strip() or None
    if machine_name.lower().startswith(group_name.lower()):
        suffix = machine_name[len(group_name):].strip(" -:()")
        return suffix or machine_name
    return machine_name


def provider_label(provider: str) -> str:
    return {
        "tf": "Rulesheet (TF)",
        "pp": "Rulesheet (PP)",
        "bob": "Rulesheet (Bob)",
        "papa": "Rulesheet (PAPA)",
        "stern": "Rulesheet (Stern)",
        "pinballnews": "Rulesheet (Pinball News)",
        "external": "Rulesheet (External)",
    }[provider]


def sort_name(value: str) -> str:
    return slugify(value).replace("-", " ")


def infer_rulesheet_provider(url: str, default_provider: str | None = None) -> str:
    host = urllib.parse.urlparse(url).netloc.lower()
    if "tiltforums.com" in host:
        return "tf"
    if "pinballprimer.github.io" in host or "pinballprimer.com" in host:
        return "pp"
    if "pinball.org" in host:
        return "papa"
    if "silverballmania.com" in host or "flippers.be" in host or "bobs" in host:
        return "bob"
    if "sternpinball.com" in host:
        return "stern"
    if "pinballnews.com" in host:
        return "pinballnews"
    return default_provider or "external"


def normalize_rulesheet_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    host = parsed.netloc.lower()
    if parsed.scheme == "http" and (
        "tiltforums.com" in host
        or "pinballprimer.github.io" in host
        or "pinballprimer.com" in host
        or "pinball.org" in host
        or "silverballmania.com" in host
        or "flippers.be" in host
    ):
        parsed = parsed._replace(scheme="https")
        return urllib.parse.urlunparse(parsed)
    return url


def should_include_rulesheet(url: str, default_provider: str | None = None) -> bool:
    del default_provider
    return infer_rulesheet_provider(normalize_rulesheet_url(url), None) in SUPPORTED_RULESHEET_PROVIDERS


def rulesheet_preference_key(item: tuple[str, str]) -> tuple[int, str]:
    provider, url = item
    parsed = urllib.parse.urlparse(url)
    path = parsed.path.lower()

    if provider == "tf":
        if "/t/" in path and not path.endswith(".json"):
            return (0, url)
        if "/posts/" in path:
            return (1, url)
        return (2, url)

    return (0, url)


def dedupe_rulesheet_candidates(candidates: list[tuple[str, str]]) -> list[tuple[str, str]]:
    unique_candidates = sorted(set(candidates), key=rulesheet_preference_key)
    selected_by_provider: dict[str, tuple[str, str]] = {}

    for candidate in unique_candidates:
        provider, _ = candidate
        if provider == "tf":
            selected_by_provider.setdefault(provider, candidate)
            continue
        selected_by_provider[f"{provider}|{candidate[1]}"] = candidate

    return list(selected_by_provider.values())


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def load_opdb_export() -> list[dict[str, Any]]:
    sys.path.insert(0, str(PINBALL_SCRAPER_SCRIPTS))
    from pinball_api_auth import load_local_env  # type: ignore
    from pinball_api_clients import OPDBClient  # type: ignore

    load_local_env(paths=(PINBALL_SCRAPER_ENV,), override=False)
    client = OPDBClient(autoload_local_env=False)
    payload = client.export_all()
    if not isinstance(payload, list):
        raise RuntimeError("Unexpected OPDB export payload shape")
    return payload


def build_manufacturers(rows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], dict[int, str]]:
    counts: dict[int, int] = defaultdict(int)
    names: dict[int, str] = {}
    for row in rows:
        manufacturer = row.get("manufacturer") or {}
        manufacturer_id = manufacturer.get("manufacturer_id")
        name = normalize_string((manufacturer or {}).get("name"))
        if not isinstance(manufacturer_id, int) or not name:
            continue
        counts[manufacturer_id] += 1
        names[manufacturer_id] = name

    modern_lookup = {name.lower(): index + 1 for index, name in enumerate(MODERN_MANUFACTURERS)}
    historical_lookup = {name.lower(): index + 1 for index, name in enumerate(FEATURED_HISTORICAL)}
    manufacturers: list[dict[str, Any]] = []
    manufacturer_id_by_opdb: dict[int, str] = {}

    for manufacturer_id, name in names.items():
        key = name.lower()
        modern_rank = modern_lookup.get(key)
        historical_rank = historical_lookup.get(key)
        if modern_rank is not None:
            sort_bucket = 0
            featured_rank = modern_rank
            is_modern = True
        elif historical_rank is not None:
            sort_bucket = 1
            featured_rank = historical_rank
            is_modern = False
        else:
            sort_bucket = 2
            featured_rank = None
            is_modern = False
        catalog_id = f"manufacturer-{manufacturer_id}"
        manufacturer_id_by_opdb[manufacturer_id] = catalog_id
        manufacturers.append(
            {
                "id": catalog_id,
                "name": name,
                "opdb_manufacturer_id": str(manufacturer_id),
                "is_modern": is_modern,
                "featured_rank": featured_rank,
                "game_count": counts[manufacturer_id],
                "sort_bucket": sort_bucket,
                "sort_name": sort_name(name),
            }
        )

    manufacturers.sort(key=lambda item: (item["sort_bucket"], item["featured_rank"] or 9999, item["sort_name"]))
    return manufacturers, manufacturer_id_by_opdb


def extract_primary_image(images: list[dict[str, Any]], image_type: str | None = None) -> dict[str, str] | None:
    filtered = [image for image in images if (image_type is None or image.get("type") == image_type)]
    prioritized = sorted(filtered, key=lambda image: (not bool(image.get("primary")), image.get("title") or ""))
    if not prioritized:
        return None
    urls = prioritized[0].get("urls") or {}
    medium = normalize_string(urls.get("medium"))
    large = normalize_string(urls.get("large"))
    if not medium and not large:
        return None
    return {
        "medium_url": medium or large,
        "large_url": large or medium,
    }


def build_matchplay_indexes(matchplay_payload: dict[str, Any]) -> tuple[dict[str, dict[str, Any]], dict[str, list[dict[str, Any]]]]:
    group_index: dict[str, dict[str, Any]] = {}
    videos_by_group: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in matchplay_payload.get("rows", []):
        payload = row.get("payload") or {}
        entry = payload.get("entry") or {}
        group = entry.get("machineGroup") or {}
        group_id = normalize_string(group.get("opdbId"))
        if not group_id:
            opdb_id = normalize_string(entry.get("opdbId"))
            if opdb_id and "-" in opdb_id:
                group_id = opdb_id.split("-", 1)[0]
        if not group_id:
            continue
        group_index[group_id] = payload
        for video in payload.get("videos") or []:
            if normalize_string(video.get("type")) != "tutorial":
                continue
            url = normalize_string(video.get("videoUrl"))
            if not url:
                continue
            videos_by_group[group_id].append(video)
    return group_index, videos_by_group


def build_external_rulesheets(external_payload: dict[str, Any]) -> dict[str, list[tuple[str, str]]]:
    rulesheets: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for group in external_payload.get("groups", []):
        group_id = normalize_string(group.get("opdb_group_id"))
        if not group_id:
            continue
        by_source = ((group.get("rulesheets") or {}).get("by_source")) or {}
        mapping = [
            ("tiltforums", "tf"),
            ("pinball_primer", "pp"),
            ("pinball_org", "papa"),
        ]
        for source_key, provider in mapping:
            for row in by_source.get(source_key, []) or []:
                url = normalize_string(row.get("url"))
                if url and should_include_rulesheet(url, provider):
                    normalized_url = normalize_rulesheet_url(url)
                    rulesheets[group_id].append((infer_rulesheet_provider(normalized_url, provider), normalized_url))
    return rulesheets


def build_matchplay_rulesheets(group_payload: dict[str, dict[str, Any]]) -> dict[str, list[tuple[str, str]]]:
    rulesheets: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for group_id, payload in group_payload.items():
        machine_group = ((payload.get("entry") or {}).get("machineGroup")) or {}
        ruleset_url = normalize_string(machine_group.get("rulesetUrl"))
        primer_url = normalize_string(machine_group.get("pinballPrimerUrl"))
        bob_url = normalize_string(machine_group.get("bobsGuideUrl"))
        if ruleset_url and should_include_rulesheet(ruleset_url, "tf"):
            normalized_url = normalize_rulesheet_url(ruleset_url)
            rulesheets[group_id].append((infer_rulesheet_provider(normalized_url, "tf"), normalized_url))
        if primer_url and should_include_rulesheet(primer_url, "pp"):
            normalized_url = normalize_rulesheet_url(primer_url)
            rulesheets[group_id].append((infer_rulesheet_provider(normalized_url, "pp"), normalized_url))
        if bob_url and should_include_rulesheet(bob_url, "bob"):
            normalized_url = normalize_rulesheet_url(bob_url)
            rulesheets[group_id].append((infer_rulesheet_provider(normalized_url, "bob"), normalized_url))
    return rulesheets


def fetch_silverball_bob_rulesheets() -> dict[str, list[tuple[str, str]]]:
    request = urllib.request.Request(
        SILVERBALL_SITEMAP_URL,
        headers={"User-Agent": "Mozilla/5.0 PinballApp/1.0"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        xml_text = response.read().decode("utf-8", errors="ignore")

    root = ET.fromstring(xml_text)
    namespace = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    rulesheets: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for loc in root.findall("sm:url/sm:loc", namespace):
        value = normalize_string(loc.text)
        if not value or not value.startswith("https://rules.silverballmania.com/rules/"):
            continue
        slug = value.rsplit("/", 1)[-1]
        group_id = slug.split("-", 1)[0] if "-" in slug else slug
        if not group_id:
            continue
        rulesheets[group_id].append(("bob", value))
    return rulesheets


def build_catalog(
    opdb_rows: list[dict[str, Any]],
    matchplay_payload: dict[str, Any],
    external_payload: dict[str, Any],
    bob_rulesheets: dict[str, list[tuple[str, str]]] | None = None,
) -> dict[str, Any]:
    manufacturers, manufacturer_id_by_opdb = build_manufacturers(opdb_rows)
    matchplay_group_index, videos_by_group = build_matchplay_indexes(matchplay_payload)
    rulesheets_by_group = build_external_rulesheets(external_payload)
    matchplay_rulesheets = build_matchplay_rulesheets(matchplay_group_index)
    for group_id, links in matchplay_rulesheets.items():
        rulesheets_by_group[group_id].extend(links)
    if bob_rulesheets:
        for group_id, links in bob_rulesheets.items():
            rulesheets_by_group[group_id].extend(links)
    for group_id, links in MANUAL_RULESHEET_OVERRIDES.items():
        for provider, url in links:
            if should_include_rulesheet(url, provider):
                normalized_url = normalize_rulesheet_url(url)
                rulesheets_by_group[group_id].append((infer_rulesheet_provider(normalized_url, provider), normalized_url))

    machines: list[dict[str, Any]] = []
    rulesheet_links: list[dict[str, Any]] = []
    video_links: list[dict[str, Any]] = []

    seen_rulesheet_keys: set[tuple[str, str, str]] = set()
    seen_video_keys: set[tuple[str, str]] = set()

    for row in sorted(opdb_rows, key=lambda item: (sort_name(item.get("name") or ""), item.get("manufacture_date") or "")):
        opdb_id = normalize_string(row.get("opdb_id"))
        if not opdb_id:
            continue
        group_id = opdb_id.split("-", 1)[0] if "-" in opdb_id else opdb_id
        matchplay_payload_for_group = matchplay_group_index.get(group_id) or {}
        entry = matchplay_payload_for_group.get("entry") or {}
        machine_group = entry.get("machineGroup") or {}

        manufacturer = row.get("manufacturer") or {}
        manufacturer_name = normalize_string(manufacturer.get("name"))
        manufacturer_catalog_id = None
        manufacturer_id = manufacturer.get("manufacturer_id")
        if isinstance(manufacturer_id, int):
            manufacturer_catalog_id = manufacturer_id_by_opdb.get(manufacturer_id)

        group_name = normalize_string(machine_group.get("name"))
        machine_name = normalize_string(row.get("name")) or normalize_string(entry.get("name")) or group_name or opdb_id
        canonical_name = group_name or machine_name
        variant = derive_variant(machine_name, group_name or machine_name)
        images = row.get("images") or []
        primary_image = extract_primary_image(images, "backglass") or extract_primary_image(images, None)
        playfield_image = extract_primary_image(images, "playfield")

        machines.append(
            {
                "practice_identity": group_id,
                "opdb_machine_id": opdb_id,
                "opdb_group_id": group_id,
                "slug": slugify(" ".join(part for part in [manufacturer_name or "", canonical_name, variant or "", str((row.get('manufacture_date') or '')[:4])] if part)),
                "name": canonical_name,
                "variant": variant,
                "manufacturer_id": manufacturer_catalog_id,
                "manufacturer_name": manufacturer_name,
                "year": int((row.get("manufacture_date") or "0000")[:4]) if normalize_string(row.get("manufacture_date")) else None,
                "primary_image": primary_image,
                "playfield_image": playfield_image,
                "updated_at": normalize_string(row.get("updated_at")) or datetime.now(UTC).isoformat(),
            }
        )

        rulesheet_candidates = dedupe_rulesheet_candidates(rulesheets_by_group.get(group_id, []))
        for priority, (provider, url) in enumerate(rulesheet_candidates):
            key = (group_id, provider, url)
            if key in seen_rulesheet_keys:
                continue
            seen_rulesheet_keys.add(key)
            rulesheet_links.append(
                {
                    "practice_identity": group_id,
                    "provider": provider,
                    "label": provider_label(provider),
                    "local_path": None,
                    "url": url,
                    "priority": priority,
                }
            )

        tutorials = sorted(
            videos_by_group.get(group_id, []),
            key=lambda video: (
                video.get("videoTimestamp") or 0,
                video.get("index") or 0,
                normalize_string(video.get("videoUrl")) or "",
            ),
        )
        tutorial_number = 1
        for video in tutorials:
            url = normalize_string(video.get("videoUrl"))
            if not url:
                continue
            key = (group_id, url)
            if key in seen_video_keys:
                continue
            seen_video_keys.add(key)
            video_links.append(
                {
                    "practice_identity": group_id,
                    "provider": "matchplay",
                    "kind": "tutorial",
                    "label": f"Tutorial {tutorial_number}",
                    "url": url,
                    "priority": tutorial_number - 1,
                }
            )
            tutorial_number += 1

    return {
        "schema_version": 1,
        "generated_at": datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "manufacturers": manufacturers,
        "machines": machines,
        "rulesheet_links": rulesheet_links,
        "video_links": video_links,
    }


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build normalized OPDB catalog snapshot with Match Play enrichment.")
    parser.add_argument("--matchplay-merged", type=Path, default=MATCHPLAY_MERGED_DEFAULT)
    parser.add_argument("--external-resources", type=Path, default=EXTERNAL_RESOURCES_DEFAULT)
    parser.add_argument("--ios-output", type=Path, default=DEFAULT_IOS_OUTPUT)
    parser.add_argument("--android-output", type=Path, default=DEFAULT_ANDROID_OUTPUT)
    parser.add_argument("--skip-android", action="store_true")
    parser.add_argument("--skip-bob-sitemap", action="store_true")
    args = parser.parse_args()

    opdb_rows = load_opdb_export()
    matchplay_payload = load_json(args.matchplay_merged)
    external_payload = load_json(args.external_resources)
    bob_rulesheets: dict[str, list[tuple[str, str]]] = {}
    if not args.skip_bob_sitemap:
        try:
            bob_rulesheets = fetch_silverball_bob_rulesheets()
        except Exception as exc:
            print(f"warning: failed to fetch Silverball Mania Bob rulesheets: {exc}", file=sys.stderr)
    catalog = build_catalog(opdb_rows, matchplay_payload, external_payload, bob_rulesheets=bob_rulesheets)

    write_json(args.ios_output, catalog)
    if not args.skip_android:
        write_json(args.android_output, catalog)

    print(
        f"wrote catalog: machines={len(catalog['machines'])} manufacturers={len(catalog['manufacturers'])} "
        f"rulesheets={len(catalog['rulesheet_links'])} videos={len(catalog['video_links'])} "
        f"bob_groups={len(bob_rulesheets)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
