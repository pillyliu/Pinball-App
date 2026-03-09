#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
PINBALL_SCRAPER_ROOT = Path("/Users/pillyliu/Documents/Codex/Pinball Scraper")
DEFAULT_OUTPUT = PINBALL_SCRAPER_ROOT / "output" / "matchplay_opdb_tutorial_enrichment.json"
DEFAULT_REFERENCE_CATALOGS = [
    Path("/Users/pillyliu/Documents/Codex/Pillyliu Pinball Website/shared/pinball/data/opdb_catalog_v1.json"),
    REPO_ROOT / "Pinball App 2" / "Pinball App 2" / "PinballStarter.bundle" / "pinball" / "data" / "opdb_catalog_v1.json",
    REPO_ROOT / "Pinball App Android" / "app" / "src" / "main" / "assets" / "starter-pack" / "pinball" / "data" / "opdb_catalog_v1.json",
]


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
        score = len(payload.get("video_links", [])) if isinstance(payload, dict) else -1
        if score > best_score:
            best_score = score
            best_path = path
            best_payload = payload if isinstance(payload, dict) else None
    if best_path is None or best_payload is None:
        raise FileNotFoundError(f"No reference catalog found in: {', '.join(str(path) for path in paths)}")
    return best_path, best_payload


def build_rows(reference_catalog: dict[str, Any]) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    seen: set[tuple[str, str]] = set()

    for row in reference_catalog.get("video_links", []):
        provider = normalize_string(row.get("provider"))
        kind = normalize_string(row.get("kind"))
        group_id = normalize_string(row.get("practice_identity"))
        url = normalize_string(row.get("url"))
        if provider != "matchplay" or kind != "tutorial" or not group_id or not url:
            continue
        key = (group_id, url)
        if key in seen:
            continue
        seen.add(key)
        grouped[group_id].append(
            {
                "type": "tutorial",
                "label": normalize_string(row.get("label")) or "Tutorial",
                "videoUrl": url,
                "index": int(row.get("priority") or 0),
            }
        )

    rows: list[dict[str, Any]] = []
    for group_id in sorted(grouped):
        videos = sorted(grouped[group_id], key=lambda item: (int(item.get("index") or 0), item.get("videoUrl") or ""))
        rows.append(
            {
                "payload": {
                    "entry": {
                        "machineGroup": {
                            "opdbId": group_id,
                        }
                    },
                    "videos": videos,
                }
            }
        )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Build Match Play tutorial enrichment from the current catalog reference.")
    parser.add_argument("--reference-catalog", type=Path, action="append", dest="reference_catalogs")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    reference_catalogs = args.reference_catalogs or DEFAULT_REFERENCE_CATALOGS
    reference_catalog_path, reference_catalog = resolve_reference_catalog(reference_catalogs)

    payload = {
        "schema_version": 1,
        "generated_at": iso_now(),
        "reference_catalog": str(reference_catalog_path),
        "rows": build_rows(reference_catalog),
    }
    write_json(args.output, payload)
    print(f"wrote Match Play tutorial enrichment: rows={len(payload['rows'])} source={reference_catalog_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
