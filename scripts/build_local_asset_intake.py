#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter, defaultdict
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WEBSITE_ROOT = REPO_ROOT.parent / "Pillyliu Pinball Website"
DEFAULT_WEBSITE_PINBALL_ROOT = DEFAULT_WEBSITE_ROOT / "shared" / "pinball"
DEFAULT_IOS_PINBALL_ROOT = REPO_ROOT / "Pinball App 2" / "Pinball App 2" / "PinballStarter.bundle" / "pinball"
DEFAULT_ANDROID_PINBALL_ROOT = REPO_ROOT / "Pinball App Android" / "app" / "src" / "main" / "assets" / "starter-pack" / "pinball"
DEFAULT_SUMMARY_OUTPUT = REPO_ROOT / "output" / "asset-intake" / "local_asset_intake_summary.md"
REPORT_FILENAME = "local_asset_intake_report.json"
SYSTEM_STARTER_PACK_PLAYFIELDS = {"/pinball/images/playfields/fallback-whitewood-playfield_700.webp"}


def iso_now() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def iso_timestamp(ts: float) -> str:
    return datetime.fromtimestamp(ts, UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def write_text(path: Path, payload: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(payload, encoding="utf-8")


def normalized_string(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    trimmed = value.strip()
    return trimmed or None


def resolve_pinball_web_path(root: Path, web_path: str | None) -> Path | None:
    if not web_path:
        return None
    trimmed = web_path.strip()
    if not trimmed.startswith("/pinball/"):
        return None
    return root / trimmed.removeprefix("/pinball/")


def derive_playfield_variant_path(web_path: str | None, suffix: str) -> str | None:
    if not web_path:
        return None
    source = Path(web_path)
    stem = source.stem
    return str(source.with_name(f"{stem}{suffix}"))


def sha256_for_path(path: Path, cache: dict[Path, str]) -> str:
    cached = cache.get(path)
    if cached:
        return cached
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    value = digest.hexdigest()
    cache[path] = value
    return value


def describe_file(path: Path | None, hash_cache: dict[Path, str], include_hash: bool = False) -> dict[str, Any]:
    if path is None:
        return {"exists": False}
    if not path.exists() or not path.is_file():
        return {"exists": False}
    stat = path.stat()
    payload: dict[str, Any] = {
        "exists": True,
        "size_bytes": stat.st_size,
        "modified_at": iso_timestamp(stat.st_mtime),
    }
    if include_hash:
        payload["sha256"] = sha256_for_path(path, hash_cache)
    return payload


def matches_source(source_record: dict[str, Any], target_record: dict[str, Any]) -> bool | None:
    if not source_record.get("exists") or not target_record.get("exists"):
        return None
    source_hash = source_record.get("sha256")
    target_hash = target_record.get("sha256")
    if not source_hash or not target_hash:
        return None
    return source_hash == target_hash


def list_pinball_web_files(root: Path, subdir: str) -> list[str]:
    directory = root / subdir
    if not directory.exists():
        return []
    files: list[str] = []
    for path in sorted(directory.iterdir()):
        if not path.is_file() or path.name.startswith("."):
            continue
        files.append(f"/pinball/{subdir}/{path.name}")
    return files


def bucket_name_from_web_path(web_path: str) -> str:
    name = Path(web_path).name
    if name.endswith("-rulesheet.md") and len(name) == len("ABCDE-rulesheet.md"):
        return "practice_identity"
    if "-playfield" in name and len(name.split("-playfield", 1)[0]) == 5 and name[0].isalnum():
        return "practice_identity"
    return "slug_or_legacy"


def build_inventory_rows(items: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    grouped: dict[str, dict[str, Any]] = {}

    for item in items:
        practice_identity = normalized_string(item.get("practice_identity"))
        if not practice_identity:
            continue
        assets = item.get("assets") if isinstance(item.get("assets"), dict) else {}
        row = grouped.setdefault(
            practice_identity,
            {
                "practice_identity": practice_identity,
                "library_entry_ids": set(),
                "library_names": set(),
                "slugs": set(),
                "names": set(),
                "variants": set(),
                "manufacturers": set(),
                "rulesheet_local_practice_paths": set(),
                "rulesheet_local_legacy_paths": set(),
                "playfield_local_practice_paths": set(),
                "playfield_local_legacy_paths": set(),
                "source_files": set(),
            },
        )

        for field_name, key in (
            ("library_entry_ids", "library_entry_id"),
            ("library_names", "library_name"),
            ("slugs", "slug"),
            ("names", "game"),
            ("variants", "variant"),
            ("manufacturers", "manufacturer"),
        ):
            value = normalized_string(item.get(key))
            if value:
                row[field_name].add(value)

        for field_name, key in (
            ("rulesheet_local_practice_paths", "rulesheet_local_practice"),
            ("rulesheet_local_legacy_paths", "rulesheet_local_legacy"),
            ("playfield_local_practice_paths", "playfield_local_practice"),
            ("playfield_local_legacy_paths", "playfield_local_legacy"),
        ):
            value = normalized_string(assets.get(key))
            if value:
                row[field_name].add(value)

        source = item.get("source") if isinstance(item.get("source"), dict) else {}
        source_file = normalized_string(source.get("file"))
        if source_file:
            row["source_files"].add(source_file)

    conflicts: list[dict[str, Any]] = []
    rows: list[dict[str, Any]] = []
    for practice_identity in sorted(grouped):
        row = grouped[practice_identity]
        conflict_fields = {}
        for key in (
            "slugs",
            "rulesheet_local_practice_paths",
            "rulesheet_local_legacy_paths",
            "playfield_local_practice_paths",
            "playfield_local_legacy_paths",
        ):
            if len(row[key]) > 1:
                conflict_fields[key] = sorted(row[key])

        if conflict_fields:
            conflicts.append(
                {
                    "practice_identity": practice_identity,
                    "conflicts": conflict_fields,
                }
            )

        rows.append(
            {
                "practice_identity": practice_identity,
                "library_entry_ids": sorted(row["library_entry_ids"]),
                "library_names": sorted(row["library_names"]),
                "slug": sorted(row["slugs"])[0] if row["slugs"] else None,
                "name": sorted(row["names"])[0] if row["names"] else None,
                "variant": sorted(row["variants"])[0] if row["variants"] else None,
                "manufacturer": sorted(row["manufacturers"])[0] if row["manufacturers"] else None,
                "rulesheet_local_practice_path": sorted(row["rulesheet_local_practice_paths"])[0] if row["rulesheet_local_practice_paths"] else None,
                "rulesheet_local_legacy_paths": sorted(row["rulesheet_local_legacy_paths"]),
                "playfield_local_practice_path": sorted(row["playfield_local_practice_paths"])[0] if row["playfield_local_practice_paths"] else None,
                "playfield_local_legacy_paths": sorted(row["playfield_local_legacy_paths"]),
                "source_files": sorted(row["source_files"]),
            }
        )
    return rows, conflicts


def build_report(
    *,
    source_root: Path,
    source_label: str,
    source_is_website: bool,
    ios_root: Path,
    android_root: Path,
    library_json_path: Path,
) -> dict[str, Any]:
    raw = load_json(library_json_path)
    items = raw.get("items") if isinstance(raw, dict) else None
    if not isinstance(items, list):
        raise RuntimeError(f"Expected a v3 library object with an items array: {library_json_path}")

    inventory_rows, conflicts = build_inventory_rows(items)
    hash_cache: dict[Path, str] = {}

    expected_source_rulesheets = set()
    expected_source_playfields = set()
    expected_ios_rulesheets = set()
    expected_ios_playfields = set()
    expected_android_rulesheets = set()
    expected_android_playfields = set()

    issue_counts: Counter[str] = Counter()
    rows: list[dict[str, Any]] = []

    for row in inventory_rows:
        rulesheet_path = row["rulesheet_local_practice_path"]
        playfield_path = row["playfield_local_practice_path"]
        playfield_700_path = derive_playfield_variant_path(playfield_path, "_700.webp")
        playfield_1400_path = derive_playfield_variant_path(playfield_path, "_1400.webp")

        if rulesheet_path:
            expected_source_rulesheets.add(rulesheet_path)
            expected_ios_rulesheets.add(rulesheet_path)
            expected_android_rulesheets.add(rulesheet_path)
        if playfield_path:
            expected_source_playfields.add(playfield_path)
        if playfield_700_path:
            expected_source_playfields.add(playfield_700_path)
            expected_ios_playfields.add(playfield_700_path)
            expected_android_playfields.add(playfield_700_path)
        if playfield_1400_path:
            expected_source_playfields.add(playfield_1400_path)

        source_rulesheet = describe_file(resolve_pinball_web_path(source_root, rulesheet_path), hash_cache, include_hash=source_is_website)
        source_playfield_original = describe_file(resolve_pinball_web_path(source_root, playfield_path), hash_cache)
        source_playfield_700 = describe_file(resolve_pinball_web_path(source_root, playfield_700_path), hash_cache, include_hash=source_is_website)
        source_playfield_1400 = describe_file(resolve_pinball_web_path(source_root, playfield_1400_path), hash_cache)
        ios_rulesheet = describe_file(resolve_pinball_web_path(ios_root, rulesheet_path), hash_cache, include_hash=source_is_website)
        ios_playfield_700 = describe_file(resolve_pinball_web_path(ios_root, playfield_700_path), hash_cache, include_hash=source_is_website)
        android_rulesheet = describe_file(resolve_pinball_web_path(android_root, rulesheet_path), hash_cache, include_hash=source_is_website)
        android_playfield_700 = describe_file(resolve_pinball_web_path(android_root, playfield_700_path), hash_cache, include_hash=source_is_website)

        issues: list[str] = []
        if not source_rulesheet["exists"]:
            issues.append("missing_source_rulesheet")
        if not source_playfield_original["exists"]:
            issues.append("missing_source_playfield_original")
        if not source_playfield_700["exists"]:
            issues.append("missing_source_playfield_700")
        if not source_playfield_1400["exists"]:
            issues.append("missing_source_playfield_1400")
        if not ios_rulesheet["exists"]:
            issues.append("missing_ios_rulesheet")
        if not ios_playfield_700["exists"]:
            issues.append("missing_ios_playfield_700")
        if not android_rulesheet["exists"]:
            issues.append("missing_android_rulesheet")
        if not android_playfield_700["exists"]:
            issues.append("missing_android_playfield_700")

        ios_rulesheet_matches = matches_source(source_rulesheet, ios_rulesheet) if source_is_website else None
        android_rulesheet_matches = matches_source(source_rulesheet, android_rulesheet) if source_is_website else None
        ios_playfield_matches = matches_source(source_playfield_700, ios_playfield_700) if source_is_website else None
        android_playfield_matches = matches_source(source_playfield_700, android_playfield_700) if source_is_website else None

        if source_is_website and ios_rulesheet_matches is False:
            issues.append("stale_ios_rulesheet")
        if source_is_website and android_rulesheet_matches is False:
            issues.append("stale_android_rulesheet")
        if source_is_website and ios_playfield_matches is False:
            issues.append("stale_ios_playfield_700")
        if source_is_website and android_playfield_matches is False:
            issues.append("stale_android_playfield_700")

        issue_counts.update(issues)

        rows.append(
            {
                "practice_identity": row["practice_identity"],
                "slug": row["slug"],
                "name": row["name"],
                "variant": row["variant"],
                "manufacturer": row["manufacturer"],
                "library_entry_ids": row["library_entry_ids"],
                "library_names": row["library_names"],
                "source_files": row["source_files"],
                "rulesheet": {
                    "practice_path": rulesheet_path,
                    "legacy_paths": row["rulesheet_local_legacy_paths"],
                    "source": source_rulesheet,
                    "ios": ios_rulesheet,
                    "android": android_rulesheet,
                    "ios_matches_source": ios_rulesheet_matches,
                    "android_matches_source": android_rulesheet_matches,
                },
                "playfield": {
                    "practice_original_path": playfield_path,
                    "practice_700_path": playfield_700_path,
                    "practice_1400_path": playfield_1400_path,
                    "legacy_paths": row["playfield_local_legacy_paths"],
                    "source_original": source_playfield_original,
                    "source_700": source_playfield_700,
                    "source_1400": source_playfield_1400,
                    "ios_700": ios_playfield_700,
                    "android_700": android_playfield_700,
                    "ios_700_matches_source": ios_playfield_matches,
                    "android_700_matches_source": android_playfield_matches,
                },
                "issues": sorted(issues),
                "needs_update": bool(issues),
            }
        )

    rows.sort(key=lambda item: (not item["needs_update"], item["practice_identity"]))

    source_rulesheet_files = list_pinball_web_files(source_root, "rulesheets")
    source_playfield_files = list_pinball_web_files(source_root, "images/playfields")
    ios_rulesheet_files = list_pinball_web_files(ios_root, "rulesheets")
    ios_playfield_files = list_pinball_web_files(ios_root, "images/playfields")
    android_rulesheet_files = list_pinball_web_files(android_root, "rulesheets")
    android_playfield_files = list_pinball_web_files(android_root, "images/playfields")

    source_extra_rulesheets = [path for path in source_rulesheet_files if path not in expected_source_rulesheets]
    source_extra_playfields = [path for path in source_playfield_files if path not in expected_source_playfields]
    ios_extra_rulesheets = [path for path in ios_rulesheet_files if path not in expected_ios_rulesheets]
    android_extra_rulesheets = [path for path in android_rulesheet_files if path not in expected_android_rulesheets]
    ios_extra_playfields = [path for path in ios_playfield_files if path not in expected_ios_playfields and path not in SYSTEM_STARTER_PACK_PLAYFIELDS]
    android_extra_playfields = [path for path in android_playfield_files if path not in expected_android_playfields and path not in SYSTEM_STARTER_PACK_PLAYFIELDS]

    source_rulesheet_buckets = Counter(bucket_name_from_web_path(path) for path in source_extra_rulesheets)
    source_playfield_buckets = Counter(bucket_name_from_web_path(path) for path in source_extra_playfields)

    coverage = {
        "rulesheets": {
            "mapped_practice_identities": len(rows),
            "source_present": sum(1 for row in rows if row["rulesheet"]["source"]["exists"]),
            "ios_present": sum(1 for row in rows if row["rulesheet"]["ios"]["exists"]),
            "android_present": sum(1 for row in rows if row["rulesheet"]["android"]["exists"]),
            "ios_matches_source": None if not source_is_website else sum(1 for row in rows if row["rulesheet"]["ios_matches_source"] is True),
            "android_matches_source": None if not source_is_website else sum(1 for row in rows if row["rulesheet"]["android_matches_source"] is True),
        },
        "playfields": {
            "mapped_practice_identities": len(rows),
            "source_original_present": sum(1 for row in rows if row["playfield"]["source_original"]["exists"]),
            "source_700_present": sum(1 for row in rows if row["playfield"]["source_700"]["exists"]),
            "source_1400_present": sum(1 for row in rows if row["playfield"]["source_1400"]["exists"]),
            "ios_700_present": sum(1 for row in rows if row["playfield"]["ios_700"]["exists"]),
            "android_700_present": sum(1 for row in rows if row["playfield"]["android_700"]["exists"]),
            "ios_700_matches_source": None if not source_is_website else sum(1 for row in rows if row["playfield"]["ios_700_matches_source"] is True),
            "android_700_matches_source": None if not source_is_website else sum(1 for row in rows if row["playfield"]["android_700_matches_source"] is True),
        },
    }

    return {
        "schema_version": 1,
        "generated_at": iso_now(),
        "source_label": source_label,
        "source_root": str(source_root),
        "library_json": str(library_json_path),
        "summary": {
            "library_entry_count": len(items),
            "unique_practice_identity_count": len(rows),
            "practice_identities_needing_update": sum(1 for row in rows if row["needs_update"]),
            "catalog_conflict_count": len(conflicts),
            "coverage": coverage,
            "issue_counts": dict(sorted(issue_counts.items())),
            "available_local_assets": {
                "source_extra_rulesheet_count": len(source_extra_rulesheets),
                "source_extra_playfield_count": len(source_extra_playfields),
                "ios_extra_rulesheet_count": len(ios_extra_rulesheets),
                "ios_extra_playfield_count": len(ios_extra_playfields),
                "android_extra_rulesheet_count": len(android_extra_rulesheets),
                "android_extra_playfield_count": len(android_extra_playfields),
                "starter_pack_system_playfields": sorted(SYSTEM_STARTER_PACK_PLAYFIELDS),
                "source_extra_rulesheet_buckets": dict(sorted(source_rulesheet_buckets.items())),
                "source_extra_playfield_buckets": dict(sorted(source_playfield_buckets.items())),
            },
        },
        "catalog_conflicts": conflicts,
        "practice_assets": rows,
        "available_local_assets": {
            "source_rulesheets_not_mapped_by_current_v3": source_extra_rulesheets,
            "source_playfields_not_mapped_by_current_v3": source_extra_playfields,
            "ios_rulesheets_not_mapped_by_current_v3": ios_extra_rulesheets,
            "ios_playfields_not_mapped_by_current_v3": ios_extra_playfields,
            "android_rulesheets_not_mapped_by_current_v3": android_extra_rulesheets,
            "android_playfields_not_mapped_by_current_v3": android_extra_playfields,
            "starter_pack_system_playfields": sorted(SYSTEM_STARTER_PACK_PLAYFIELDS & set(ios_playfield_files + android_playfield_files)),
        },
    }


def render_summary(report: dict[str, Any], outputs: dict[str, Path]) -> str:
    summary = report["summary"]
    coverage = summary["coverage"]
    available = summary["available_local_assets"]
    needs_update_rows = [row for row in report["practice_assets"] if row["needs_update"]]

    lines = [
        "# Local Asset Intake",
        "",
        f"- Generated: {report['generated_at']}",
        f"- Canonical source: `{report['source_label']}`",
        f"- Library entries: {summary['library_entry_count']}",
        f"- Unique practice identities: {summary['unique_practice_identity_count']}",
        f"- Practice identities needing update: {summary['practice_identities_needing_update']}",
        f"- Catalog conflicts: {summary['catalog_conflict_count']}",
        "",
        "## Coverage",
        "",
        f"- Rulesheets: source {coverage['rulesheets']['source_present']}/{coverage['rulesheets']['mapped_practice_identities']}, iOS {coverage['rulesheets']['ios_present']}/{coverage['rulesheets']['mapped_practice_identities']}, Android {coverage['rulesheets']['android_present']}/{coverage['rulesheets']['mapped_practice_identities']}",
        f"- Playfields: source original {coverage['playfields']['source_original_present']}/{coverage['playfields']['mapped_practice_identities']}, source 700 {coverage['playfields']['source_700_present']}/{coverage['playfields']['mapped_practice_identities']}, source 1400 {coverage['playfields']['source_1400_present']}/{coverage['playfields']['mapped_practice_identities']}",
        f"- Starter packs: iOS 700 {coverage['playfields']['ios_700_present']}/{coverage['playfields']['mapped_practice_identities']}, Android 700 {coverage['playfields']['android_700_present']}/{coverage['playfields']['mapped_practice_identities']}",
    ]

    if coverage["rulesheets"]["ios_matches_source"] is not None:
        lines.append(
            f"- Source sync: iOS rulesheets {coverage['rulesheets']['ios_matches_source']}/{coverage['rulesheets']['mapped_practice_identities']}, Android rulesheets {coverage['rulesheets']['android_matches_source']}/{coverage['rulesheets']['mapped_practice_identities']}, iOS playfield 700 {coverage['playfields']['ios_700_matches_source']}/{coverage['playfields']['mapped_practice_identities']}, Android playfield 700 {coverage['playfields']['android_700_matches_source']}/{coverage['playfields']['mapped_practice_identities']}"
        )

    lines.extend(
        [
            "",
            "## Local Pool",
            "",
            f"- Source rulesheets not mapped by current v3: {available['source_extra_rulesheet_count']}",
            f"- Source playfield files not mapped by current v3: {available['source_extra_playfield_count']}",
            f"- iOS starter-pack extras not mapped by current v3: rulesheets {available['ios_extra_rulesheet_count']}, playfields {available['ios_extra_playfield_count']}",
            f"- Android starter-pack extras not mapped by current v3: rulesheets {available['android_extra_rulesheet_count']}, playfields {available['android_extra_playfield_count']}",
            "",
            "## Outputs",
            "",
        ]
    )

    for label, path in outputs.items():
        lines.append(f"- {label}: `{path}`")

    if needs_update_rows:
        lines.extend(["", "## Needs Update", ""])
        for row in needs_update_rows[:25]:
            issue_list = ", ".join(row["issues"])
            lines.append(f"- `{row['practice_identity']}` `{row['slug']}`: {issue_list}")
    else:
        lines.extend(["", "## Needs Update", "", "- None"])

    return "\n".join(lines) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a local intake inventory for rulesheets and playfield assets.")
    parser.add_argument("--website-root", type=Path, default=DEFAULT_WEBSITE_ROOT, help="Website repo root that contains shared/pinball.")
    parser.add_argument("--ios-root", type=Path, default=DEFAULT_IOS_PINBALL_ROOT, help="iOS starter-pack pinball root.")
    parser.add_argument("--android-root", type=Path, default=DEFAULT_ANDROID_PINBALL_ROOT, help="Android starter-pack pinball root.")
    parser.add_argument("--summary-output", type=Path, default=DEFAULT_SUMMARY_OUTPUT, help="Markdown summary output path.")
    parser.add_argument("--skip-web-output", action="store_true", help="Do not write the report back into the website shared data folder.")
    parser.add_argument("--skip-ios-output", action="store_true", help="Do not write the report into the iOS starter-pack data folder.")
    parser.add_argument("--skip-android-output", action="store_true", help="Do not write the report into the Android starter-pack data folder.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    website_pinball_root = args.website_root / "shared" / "pinball"
    source_root = website_pinball_root if website_pinball_root.exists() else args.ios_root
    source_label = "website_shared" if website_pinball_root.exists() else "ios_starter_pack"
    source_is_website = website_pinball_root.exists()
    library_json_path = source_root / "data" / "pinball_library_v3.json"

    if not library_json_path.exists():
        raise SystemExit(f"Missing pinball_library_v3.json: {library_json_path}")
    if not args.ios_root.exists():
        raise SystemExit(f"Missing iOS starter-pack root: {args.ios_root}")
    if not args.android_root.exists():
        raise SystemExit(f"Missing Android starter-pack root: {args.android_root}")

    report = build_report(
        source_root=source_root,
        source_label=source_label,
        source_is_website=source_is_website,
        ios_root=args.ios_root,
        android_root=args.android_root,
        library_json_path=library_json_path,
    )

    output_paths: dict[str, Path] = {}
    if source_is_website and not args.skip_web_output:
        output_paths["website_report"] = website_pinball_root / "data" / REPORT_FILENAME
    if not args.skip_ios_output:
        output_paths["ios_report"] = args.ios_root / "data" / REPORT_FILENAME
    if not args.skip_android_output:
        output_paths["android_report"] = args.android_root / "data" / REPORT_FILENAME

    for path in output_paths.values():
        write_json(path, report)

    summary_outputs = dict(output_paths)
    summary_outputs["summary"] = args.summary_output
    summary = render_summary(report, summary_outputs)
    write_text(args.summary_output, summary)
    print(summary, end="")


if __name__ == "__main__":
    main()
