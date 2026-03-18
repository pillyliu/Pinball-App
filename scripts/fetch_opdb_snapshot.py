#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import UTC, datetime, timedelta
import urllib.parse
import urllib.request
from collections import defaultdict
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
LOCAL_SCRIPTS_DIR = Path(__file__).resolve().parent
PINBALL_SCRAPER_ROOT = Path("/Users/pillyliu/Documents/Codex/Pinball Scraper")
PINBALL_SCRAPER_SCRIPTS = PINBALL_SCRAPER_ROOT / "scripts"
PINBALL_SCRAPER_ENV = PINBALL_SCRAPER_ROOT / ".secrets" / "pinball_api.env"
MATCHPLAY_MERGED_DEFAULT = PINBALL_SCRAPER_ROOT / "output" / "matchplay_opdb_tutorial_enrichment.json"
EXTERNAL_RESOURCES_DEFAULT = PINBALL_SCRAPER_ROOT / "output" / "opdb_external_rulesheet_resources.json"

DEFAULT_IOS_OUTPUT = REPO_ROOT / "Pinball App 2" / "Pinball App 2" / "PinballStarter.bundle" / "pinball" / "data" / "opdb_catalog_v1.json"
DEFAULT_ANDROID_OUTPUT = REPO_ROOT / "Pinball App Android" / "app" / "src" / "main" / "assets" / "starter-pack" / "pinball" / "data" / "opdb_catalog_v1.json"
DEFAULT_RAW_SAVE_DIR = PINBALL_SCRAPER_ROOT / "output" / "opdb-raw"
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


def load_optional_json(path: Path, default: Any) -> Any:
    if not path.exists():
        print(f"warning: optional input missing: {path}", file=sys.stderr)
        return default
    return load_json(path)


def parse_generated_at(payload: Any) -> datetime | None:
    if not isinstance(payload, dict):
        return None
    generated_at = normalize_string(payload.get("generated_at"))
    if not generated_at:
        return None
    try:
        return datetime.fromisoformat(generated_at.replace("Z", "+00:00")).astimezone(UTC)
    except ValueError:
        return None


def load_recent_catalog(paths: list[Path], min_age: timedelta) -> tuple[Path, dict[str, Any]] | None:
    cutoff = datetime.now(UTC) - min_age
    for path in paths:
        if not path.exists():
            continue
        payload = load_json(path)
        generated_at = parse_generated_at(payload)
        if generated_at and generated_at >= cutoff:
            return path, payload
    return None


def iso_now() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_opdb_env() -> dict[str, str]:
    sys.path.insert(0, str(LOCAL_SCRIPTS_DIR))
    sys.path.insert(0, str(PINBALL_SCRAPER_SCRIPTS))
    from pinball_api_auth import load_local_env  # type: ignore

    load_local_env(paths=(PINBALL_SCRAPER_ENV,), override=False)
    return dict(os.environ)


def opdb_token_candidates() -> list[tuple[str, str]]:
    env = load_opdb_env()
    out: list[tuple[str, str]] = []
    for key in ("OPDB_API_TOKEN", "OPDB_API_TOKEN_BACKUP"):
        value = env.get(key, "").strip()
        if value:
            out.append((key, value))
    return out


def fetch_json_url(url: str) -> Any:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "PinballAppSnapshot/1.0",
        },
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        return json.load(response)


def fetch_opdb_api_payload(base_url: str, *, label: str) -> tuple[Any, str]:
    last_error: Exception | None = None
    for env_key, token in opdb_token_candidates():
        url = f"{base_url}?{urllib.parse.urlencode({'api_token': token})}"
        try:
            return fetch_json_url(url), env_key
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            print(f"warning: {label} failed with {env_key}: {exc}", file=sys.stderr)
    if last_error is not None:
        raise last_error
    raise RuntimeError("Missing OPDB_API_TOKEN / OPDB_API_TOKEN_BACKUP")


def save_raw_payload(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def normalize_matchplay_manufacturer(manufacturer: Any) -> dict[str, Any]:
    if not isinstance(manufacturer, dict):
        return {}
    return {
        "manufacturer_id": manufacturer.get("manufacturerId"),
        "name": manufacturer.get("name"),
        "full_name": manufacturer.get("fullName"),
        "created_at": manufacturer.get("createdAt"),
        "updated_at": manufacturer.get("updatedAt"),
    }


def normalize_matchplay_machine_row(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "common_name": row.get("commonName"),
        "created_at": row.get("createdAt"),
        "description": row.get("description"),
        "display": row.get("display"),
        "features": row.get("features") if isinstance(row.get("features"), list) else [],
        "images": row.get("images") if isinstance(row.get("images"), list) else [],
        "ipdb_id": row.get("ipdbId"),
        "is_machine": row.get("isMachine"),
        "keywords": row.get("keywords") if isinstance(row.get("keywords"), list) else [],
        "manufacture_date": row.get("manufactureDate"),
        "manufacturer": normalize_matchplay_manufacturer(row.get("manufacturer")),
        "name": row.get("name"),
        "opdb_id": row.get("opdbId"),
        "physical_machine": row.get("physicalMachine"),
        "player_count": row.get("playerCount"),
        "shortname": row.get("shortname"),
        "type": row.get("type"),
        "updated_at": row.get("updatedAt"),
    }


def normalize_matchplay_group_row(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "opdb_id": row.get("opdbId"),
        "name": row.get("name"),
        "shortname": row.get("shortname"),
        "description": row.get("description"),
        "created_at": row.get("createdAt"),
        "updated_at": row.get("updatedAt"),
    }


def normalize_opdb_source_payload(payload: Any) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    if not isinstance(payload, list):
        if isinstance(payload, dict) and {"machineGroups", "machines", "aliases"}.issubset(payload.keys()):
            machines = [
                normalize_matchplay_machine_row(row)
                for row in payload.get("machines", [])
                if isinstance(row, dict)
            ]
            aliases = [
                normalize_matchplay_machine_row(row)
                for row in payload.get("aliases", [])
                if isinstance(row, dict)
            ]
            groups = [
                normalize_matchplay_group_row(row)
                for row in payload.get("machineGroups", [])
                if isinstance(row, dict)
            ]
            return machines + aliases, groups
        raise RuntimeError(f"Unexpected OPDB payload shape: {type(payload).__name__}")
    rows = [row for row in payload if isinstance(row, dict)]
    return rows, []


def load_opdb_dataset(
    *,
    raw_export_path: Path | None,
    raw_groups_path: Path | None,
    matchplay_snapshot_path: Path | None,
    raw_save_dir: Path | None,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], str, str | None]:
    if matchplay_snapshot_path is not None:
        payload = load_json(matchplay_snapshot_path)
        rows, groups = normalize_opdb_source_payload(payload)
        exported_at = iso_now()
        return rows, groups, exported_at, exported_at if groups else None

    if raw_export_path is not None:
        rows, inferred_groups = normalize_opdb_source_payload(load_json(raw_export_path))
        groups = load_json(raw_groups_path) if raw_groups_path is not None else inferred_groups
        if groups and not isinstance(groups, list):
            raise RuntimeError("Unexpected OPDB groups payload shape")
        exported_at = iso_now()
        return rows, list(groups or []), exported_at, exported_at if groups else None

    env = load_opdb_env()
    export_url = env.get("OPDB_EXPORT_URL", "https://opdb.org/api/export").strip() or "https://opdb.org/api/export"
    groups_url = "https://opdb.org/api/export/groups"
    export_payload, export_token_key = fetch_opdb_api_payload(export_url, label="OPDB export")
    rows, _ = normalize_opdb_source_payload(export_payload)
    groups_payload, _groups_token_key = fetch_opdb_api_payload(groups_url, label="OPDB groups export")
    groups = groups_payload if isinstance(groups_payload, list) else []
    exported_at = iso_now()

    if raw_save_dir is not None:
        raw_save_dir.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime("%Y-%m-%dT%H-%M-%S")
        save_raw_payload(raw_save_dir / f"opdb-export-{stamp}.json", export_payload)
        save_raw_payload(raw_save_dir / "latest-opdb-export.json", export_payload)
        save_raw_payload(raw_save_dir / f"opdb-groups-{stamp}.json", groups)
        save_raw_payload(raw_save_dir / "latest-opdb-groups.json", groups)
        print(f"saved raw OPDB payloads using {export_token_key} to {raw_save_dir}", file=sys.stderr)

    return rows, groups, exported_at, exported_at


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
            ("bobs_guide", "bob"),
        ]
        for source_key, provider in mapping:
            for row in by_source.get(source_key, []) or []:
                url = normalize_string(row.get("url"))
                if url and should_include_rulesheet(url, provider):
                    normalized_url = normalize_rulesheet_url(url)
                    rulesheets[group_id].append((infer_rulesheet_provider(normalized_url, provider), normalized_url))
    return rulesheets


def build_rulesheet_link_rows(
    group_ids: list[str],
    rulesheets_by_group: dict[str, list[tuple[str, str]]],
) -> list[dict[str, Any]]:
    rulesheet_links: list[dict[str, Any]] = []
    seen_rulesheet_keys: set[tuple[str, str, str]] = set()

    for group_id in group_ids:
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
    return rulesheet_links


def build_video_link_rows(
    group_ids: list[str],
    videos_by_group: dict[str, list[dict[str, Any]]],
) -> list[dict[str, Any]]:
    video_links: list[dict[str, Any]] = []
    seen_video_keys: set[tuple[str, str]] = set()

    for group_id in group_ids:
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
    return video_links


def enrich_group_links(
    matchplay_payload: dict[str, Any],
    external_payload: dict[str, Any],
) -> tuple[dict[str, list[tuple[str, str]]], dict[str, list[dict[str, Any]]]]:
    _matchplay_group_index, videos_by_group = build_matchplay_indexes(matchplay_payload)
    rulesheets_by_group = build_external_rulesheets(external_payload)
    for group_id, links in MANUAL_RULESHEET_OVERRIDES.items():
        for provider, url in links:
            if should_include_rulesheet(url, provider):
                normalized_url = normalize_rulesheet_url(url)
                rulesheets_by_group[group_id].append((infer_rulesheet_provider(normalized_url, provider), normalized_url))
    return rulesheets_by_group, videos_by_group


def build_catalog(
    opdb_rows: list[dict[str, Any]],
    matchplay_payload: dict[str, Any],
    external_payload: dict[str, Any],
    opdb_groups: list[dict[str, Any]] | None = None,
    opdb_exported_at: str | None = None,
    opdb_groups_exported_at: str | None = None,
) -> dict[str, Any]:
    manufacturers, manufacturer_id_by_opdb = build_manufacturers(opdb_rows)
    matchplay_group_index, _videos_by_group = build_matchplay_indexes(matchplay_payload)
    rulesheets_by_group, videos_by_group = enrich_group_links(matchplay_payload, external_payload)

    machines: list[dict[str, Any]] = []
    group_ids: list[str] = []
    group_rows = opdb_groups or []
    groups_by_id = {
        normalize_string(row.get("opdb_id")): row
        for row in group_rows
        if isinstance(row, dict) and normalize_string(row.get("opdb_id"))
    }

    for row in sorted(opdb_rows, key=lambda item: (sort_name(item.get("name") or ""), item.get("manufacture_date") or "")):
        opdb_id = normalize_string(row.get("opdb_id"))
        if not opdb_id:
            continue
        group_id = opdb_id.split("-", 1)[0] if "-" in opdb_id else opdb_id
        group_ids.append(group_id)
        matchplay_payload_for_group = matchplay_group_index.get(group_id) or {}
        entry = matchplay_payload_for_group.get("entry") or {}
        machine_group = entry.get("machineGroup") or {}

        manufacturer = row.get("manufacturer") or {}
        manufacturer_name = normalize_string(manufacturer.get("name"))
        manufacturer_catalog_id = None
        manufacturer_id = manufacturer.get("manufacturer_id")
        if isinstance(manufacturer_id, int):
            manufacturer_catalog_id = manufacturer_id_by_opdb.get(manufacturer_id)

        group_row = groups_by_id.get(group_id) or {}
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
                "opdb_name": normalize_string(row.get("name")),
                "opdb_common_name": normalize_string(row.get("common_name")),
                "opdb_shortname": normalize_string(row.get("shortname")),
                "opdb_description": normalize_string(row.get("description")),
                "opdb_type": normalize_string(row.get("type")),
                "opdb_display": normalize_string(row.get("display")),
                "opdb_player_count": row.get("player_count") if isinstance(row.get("player_count"), int) else None,
                "opdb_manufacture_date": normalize_string(row.get("manufacture_date")),
                "opdb_physical_machine": row.get("physical_machine"),
                "opdb_ipdb_id": row.get("ipdb_id") if isinstance(row.get("ipdb_id"), int) else None,
                "opdb_created_at": normalize_string(row.get("created_at")),
                "opdb_updated_at": normalize_string(row.get("updated_at")),
                "opdb_group_shortname": normalize_string(group_row.get("shortname")),
                "opdb_group_description": normalize_string(group_row.get("description")),
            }
        )
    rulesheet_links = build_rulesheet_link_rows(group_ids, rulesheets_by_group)
    video_links = build_video_link_rows(group_ids, videos_by_group)

    return {
        "schema_version": 1,
        "generated_at": datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "opdb_exported_at": opdb_exported_at or datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "opdb_groups_exported_at": opdb_groups_exported_at,
        "manufacturers": manufacturers,
        "machines": machines,
        "rulesheet_links": rulesheet_links,
        "video_links": video_links,
    }


def refresh_existing_catalog_links(
    existing_catalog: dict[str, Any],
    matchplay_payload: dict[str, Any],
    external_payload: dict[str, Any],
) -> dict[str, Any]:
    rulesheets_by_group, videos_by_group = enrich_group_links(matchplay_payload, external_payload)
    group_ids: list[str] = []
    for row in existing_catalog.get("machines", []):
        if not isinstance(row, dict):
            continue
        group_id = normalize_string(row.get("opdb_group_id")) or normalize_string(row.get("practice_identity"))
        if group_id:
            group_ids.append(group_id)

    refreshed = dict(existing_catalog)
    refreshed["generated_at"] = datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    refreshed["rulesheet_links"] = build_rulesheet_link_rows(group_ids, rulesheets_by_group)
    refreshed["video_links"] = build_video_link_rows(group_ids, videos_by_group)
    return refreshed


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
    parser.add_argument("--raw-export", type=Path)
    parser.add_argument("--raw-groups-export", type=Path)
    parser.add_argument("--matchplay-opdb-snapshot", type=Path)
    parser.add_argument("--raw-save-dir", type=Path, default=DEFAULT_RAW_SAVE_DIR)
    parser.add_argument("--skip-android", action="store_true")
    parser.add_argument("--skip-bob-sitemap", action="store_true")
    parser.add_argument("--min-export-age-minutes", type=int, default=60)
    parser.add_argument("--force-export", action="store_true")
    args = parser.parse_args()

    matchplay_payload = load_optional_json(args.matchplay_merged, {"rows": []})
    external_payload = load_optional_json(args.external_resources, {"groups": []})

    output_candidates = [args.ios_output]
    if not args.skip_android:
        output_candidates.append(args.android_output)
    if not args.force_export:
        recent_catalog = load_recent_catalog(output_candidates, timedelta(minutes=max(args.min_export_age_minutes, 0)))
        if recent_catalog is not None:
            source_path, payload = recent_catalog
            refreshed_catalog = refresh_existing_catalog_links(payload, matchplay_payload, external_payload)
            write_json(args.ios_output, refreshed_catalog)
            if not args.skip_android:
                write_json(args.android_output, refreshed_catalog)
            generated_at = normalize_string(payload.get("generated_at")) or "unknown"
            print(
                f"skipping OPDB export: reusing recent catalog from {source_path} and refreshing links "
                f"(source_generated_at={generated_at}, min_age_minutes={max(args.min_export_age_minutes, 0)}, "
                f"rulesheets={len(refreshed_catalog['rulesheet_links'])}, videos={len(refreshed_catalog['video_links'])})"
            )
            return 0

    opdb_rows, opdb_groups, opdb_exported_at, opdb_groups_exported_at = load_opdb_dataset(
        raw_export_path=args.raw_export,
        raw_groups_path=args.raw_groups_export,
        matchplay_snapshot_path=args.matchplay_opdb_snapshot,
        raw_save_dir=args.raw_save_dir,
    )
    if args.skip_bob_sitemap:
        print("warning: --skip-bob-sitemap is deprecated; Bob rulesheets now come from external resources input", file=sys.stderr)
    catalog = build_catalog(
        opdb_rows,
        matchplay_payload,
        external_payload,
        opdb_groups=opdb_groups,
        opdb_exported_at=opdb_exported_at,
        opdb_groups_exported_at=opdb_groups_exported_at,
    )

    write_json(args.ios_output, catalog)
    if not args.skip_android:
        write_json(args.android_output, catalog)

    print(
        f"wrote catalog: machines={len(catalog['machines'])} manufacturers={len(catalog['manufacturers'])} "
        f"rulesheets={len(catalog['rulesheet_links'])} videos={len(catalog['video_links'])} "
        f"external_groups={len(external_payload.get('groups', []))}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
