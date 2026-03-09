#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import urllib.request
import xml.etree.ElementTree as ET
from collections import defaultdict
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
PINBALL_SCRAPER_ROOT = Path("/Users/pillyliu/Documents/Codex/Pinball Scraper")
DEFAULT_OUTPUT = PINBALL_SCRAPER_ROOT / "output" / "opdb_external_rulesheet_resources.json"
DEFAULT_REFERENCE_CATALOGS = [
    Path("/Users/pillyliu/Documents/Codex/Pillyliu Pinball Website/shared/pinball/data/opdb_catalog_v1.json"),
    REPO_ROOT / "Pinball App 2" / "Pinball App 2" / "PinballStarter.bundle" / "pinball" / "data" / "opdb_catalog_v1.json",
    REPO_ROOT / "Pinball App Android" / "app" / "src" / "main" / "assets" / "starter-pack" / "pinball" / "data" / "opdb_catalog_v1.json",
]
SILVERBALL_SITEMAP_URL = "https://rules.silverballmania.com/sitemap.xml"
RULE_PREFIX = "https://rules.silverballmania.com/rules/"
PROVIDER_TO_SOURCE_KEY = {
    "tf": "tiltforums",
    "pp": "pinball_primer",
    "papa": "pinball_org",
    "bob": "bobs_guide",
}


def iso_now() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def normalize_string(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    trimmed = value.strip()
    return trimmed or None


def resolve_reference_catalog(paths: list[Path]) -> tuple[Path, dict[str, Any]]:
    best_path: Path | None = None
    best_payload: dict[str, Any] | None = None
    best_score = -1
    for path in paths:
        if not path.exists():
            continue
        payload = load_json(path)
        score = len(payload.get("rulesheet_links", [])) if isinstance(payload, dict) else -1
        if score > best_score:
            best_score = score
            best_path = path
            best_payload = payload if isinstance(payload, dict) else None
    if best_path is None or best_payload is None:
        raise FileNotFoundError(f"No reference catalog found in: {', '.join(str(path) for path in paths)}")
    return best_path, best_payload


def extract_reference_rulesheets(reference_catalog: dict[str, Any]) -> dict[str, dict[str, list[str]]]:
    grouped: dict[str, dict[str, list[str]]] = defaultdict(lambda: defaultdict(list))
    seen: set[tuple[str, str, str]] = set()

    for row in reference_catalog.get("rulesheet_links", []):
        group_id = normalize_string(row.get("practice_identity"))
        provider = normalize_string(row.get("provider"))
        url = normalize_string(row.get("url"))
        if not group_id or provider not in PROVIDER_TO_SOURCE_KEY or not url:
            continue
        key = (group_id, provider, url)
        if key in seen:
            continue
        seen.add(key)
        grouped[group_id][provider].append(url)
    return grouped


def fetch_live_bob_rulesheets() -> dict[str, list[str]]:
    request = urllib.request.Request(
        SILVERBALL_SITEMAP_URL,
        headers={"User-Agent": "Mozilla/5.0 PinballApp/1.0"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        xml_text = response.read().decode("utf-8", errors="ignore")

    root = ET.fromstring(xml_text)
    namespace = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    grouped: dict[str, list[str]] = defaultdict(list)
    for loc in root.findall("sm:url/sm:loc", namespace):
        value = normalize_string(loc.text)
        if not value or not value.startswith(RULE_PREFIX):
            continue
        slug = value.rsplit("/", 1)[-1]
        group_id = slug.split("-", 1)[0] if "-" in slug else slug
        if not group_id:
            continue
        grouped[group_id].append(value)
    return grouped


def build_groups(reference_catalog: dict[str, Any], include_live_bob: bool) -> list[dict[str, Any]]:
    grouped = extract_reference_rulesheets(reference_catalog)
    if include_live_bob:
        for group_id, urls in fetch_live_bob_rulesheets().items():
            grouped[group_id]["bob"] = sorted(set(urls))

    groups: list[dict[str, Any]] = []
    for group_id in sorted(grouped):
        by_source: dict[str, list[dict[str, str]]] = {}
        for provider, urls in sorted(grouped[group_id].items()):
            source_key = PROVIDER_TO_SOURCE_KEY.get(provider)
            if not source_key:
                continue
            by_source[source_key] = [{"url": url} for url in sorted(dict.fromkeys(urls))]
        if not by_source:
            continue
        groups.append(
            {
                "opdb_group_id": group_id,
                "rulesheets": {
                    "by_source": by_source,
                },
            }
        )
    return groups


def main() -> int:
    parser = argparse.ArgumentParser(description="Build unified external rulesheet resources keyed by OPDB group.")
    parser.add_argument("--reference-catalog", type=Path, action="append", dest="reference_catalogs")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--skip-live-bob", action="store_true")
    args = parser.parse_args()

    reference_catalogs = args.reference_catalogs or DEFAULT_REFERENCE_CATALOGS
    reference_catalog_path, reference_catalog = resolve_reference_catalog(reference_catalogs)

    payload = {
        "schema_version": 1,
        "generated_at": iso_now(),
        "reference_catalog": str(reference_catalog_path),
        "groups": build_groups(reference_catalog, include_live_bob=not args.skip_live_bob),
    }
    write_json(args.output, payload)
    print(f"wrote external rulesheet resources: groups={len(payload['groups'])} source={reference_catalog_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
