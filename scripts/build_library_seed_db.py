#!/usr/bin/env python3

from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
IOS_DATA_DIR = REPO_ROOT / "Pinball App 2" / "Pinball App 2" / "PinballStarter.bundle" / "pinball" / "data"
ANDROID_DATA_DIR = REPO_ROOT / "Pinball App Android" / "app" / "src" / "main" / "assets" / "starter-pack" / "pinball" / "data"
LEGACY_JSON = IOS_DATA_DIR / "pinball_library_v3.json"
CATALOG_JSON = IOS_DATA_DIR / "opdb_catalog_v1.json"
IOS_DB = IOS_DATA_DIR / "pinball_library_seed_v1.sqlite"
ANDROID_DB = ANDROID_DATA_DIR / "pinball_library_seed_v1.sqlite"


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def normalized(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    trimmed = value.strip()
    return trimmed or None


def build_catalog_indexes(catalog: dict[str, Any]) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]], dict[str, list[dict[str, Any]]], dict[str, list[dict[str, Any]]]]:
    machines_by_practice = {row["practice_identity"]: row for row in catalog.get("machines", [])}
    machines_by_opdb = {row["opdb_machine_id"]: row for row in catalog.get("machines", []) if row.get("opdb_machine_id")}
    rulesheets_by_practice: dict[str, list[dict[str, Any]]] = {}
    for row in catalog.get("rulesheet_links", []):
        rulesheets_by_practice.setdefault(row["practice_identity"], []).append(row)
    videos_by_practice: dict[str, list[dict[str, Any]]] = {}
    for row in catalog.get("video_links", []):
        videos_by_practice.setdefault(row["practice_identity"], []).append(row)
    return machines_by_practice, machines_by_opdb, rulesheets_by_practice, videos_by_practice


def curated_override_rows(legacy_games: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    overrides: dict[str, dict[str, Any]] = {}
    override_rulesheets: list[dict[str, Any]] = []
    override_videos: list[dict[str, Any]] = []

    for game in legacy_games:
        practice_identity = normalized(game.get("practice_identity"))
        if not practice_identity:
            opdb_id = normalized(game.get("opdb_id"))
            if opdb_id and "-" in opdb_id:
                practice_identity = opdb_id.split("-", 1)[0]
        if not practice_identity:
            continue

        assets = game.get("assets") or {}
        playfield_local = normalized(game.get("playfieldLocal")) or normalized(assets.get("playfield_local_practice")) or normalized(assets.get("playfield_local_legacy"))
        rulesheet_local = normalized(assets.get("rulesheet_local_practice")) or normalized(assets.get("rulesheet_local_legacy"))
        gameinfo_local = normalized(assets.get("gameinfo_local_practice")) or normalized(assets.get("gameinfo_local_legacy"))
        override = overrides.setdefault(
            practice_identity,
            {
                "practice_identity": practice_identity,
                "name_override": None,
                "variant_override": None,
                "manufacturer_override": None,
                "year_override": None,
                "playfield_local_path": None,
                "playfield_source_url": None,
                "gameinfo_local_path": None,
                "rulesheet_local_path": None,
            },
        )
        override["name_override"] = override["name_override"] or normalized(game.get("name"))
        override["variant_override"] = override["variant_override"] or normalized(game.get("variant"))
        override["manufacturer_override"] = override["manufacturer_override"] or normalized(game.get("manufacturer"))
        override["year_override"] = override["year_override"] or game.get("year")
        override["playfield_local_path"] = override["playfield_local_path"] or playfield_local
        override["playfield_source_url"] = override["playfield_source_url"] or normalized(game.get("playfield_image_url")) or normalized(game.get("playfieldImageUrl"))
        override["gameinfo_local_path"] = override["gameinfo_local_path"] or gameinfo_local
        override["rulesheet_local_path"] = override["rulesheet_local_path"] or rulesheet_local

        if rulesheet_local:
            continue

        rulesheet_links = game.get("rulesheet_links") or []
        if not rulesheet_links:
            rulesheet_url = normalized(game.get("rulesheet_url")) or normalized(game.get("rulesheetUrl"))
            if rulesheet_url:
                rulesheet_links = [{"label": "Rulesheet", "url": rulesheet_url}]
        for priority, link in enumerate(rulesheet_links):
            url = normalized(link.get("url"))
            if not url:
                continue
            override_rulesheets.append(
                {
                    "practice_identity": practice_identity,
                    "label": normalized(link.get("label")) or "Rulesheet",
                    "url": url,
                    "priority": priority,
                }
            )

        videos = game.get("videos") or []
        for priority, video in enumerate(videos):
            url = normalized(video.get("url"))
            if not url:
                continue
            override_videos.append(
                {
                    "practice_identity": practice_identity,
                    "kind": normalized(video.get("kind")) or "tutorial",
                    "label": normalized(video.get("label")) or f"Tutorial {priority + 1}",
                    "url": url,
                    "priority": priority,
                }
            )

    return list(overrides.values()), override_rulesheets, override_videos


def resolved_builtin_rows(
    legacy_games: list[dict[str, Any]],
    catalog: dict[str, Any],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    machines_by_practice, machines_by_opdb, rulesheets_by_practice, videos_by_practice = build_catalog_indexes(catalog)
    overrides, override_rulesheets, override_videos = curated_override_rows(legacy_games)
    overrides_by_practice = {row["practice_identity"]: row for row in overrides}
    override_rules_by_practice: dict[str, list[dict[str, Any]]] = {}
    for row in override_rulesheets:
        override_rules_by_practice.setdefault(row["practice_identity"], []).append(row)
    override_videos_by_practice: dict[str, list[dict[str, Any]]] = {}
    for row in override_videos:
        override_videos_by_practice.setdefault(row["practice_identity"], []).append(row)

    built_in_games: list[dict[str, Any]] = []
    built_in_rulesheets: list[dict[str, Any]] = []
    built_in_videos: list[dict[str, Any]] = []
    seen_library_entry_ids: dict[str, int] = {}

    for game in legacy_games:
        library_entry_id = normalized(game.get("library_entry_id"))
        if not library_entry_id:
            continue
        occurrence = seen_library_entry_ids.get(library_entry_id, 0)
        seen_library_entry_ids[library_entry_id] = occurrence + 1
        if occurrence > 0:
            library_entry_id = f"{library_entry_id}--dup{occurrence + 1}"
        practice_identity = normalized(game.get("practice_identity"))
        opdb_id = normalized(game.get("opdb_id"))
        if not practice_identity and opdb_id and "-" in opdb_id:
            practice_identity = opdb_id.split("-", 1)[0]
        machine = (opdb_id and machines_by_opdb.get(opdb_id)) or (practice_identity and machines_by_practice.get(practice_identity))
        override = overrides_by_practice.get(practice_identity or "") if practice_identity else None

        assets = game.get("assets") or {}
        playfield_local = normalized(game.get("playfieldLocal")) or normalized(assets.get("playfield_local_practice")) or normalized(assets.get("playfield_local_legacy"))
        rulesheet_local = normalized(assets.get("rulesheet_local_practice")) or normalized(assets.get("rulesheet_local_legacy"))
        gameinfo_local = normalized(assets.get("gameinfo_local_practice")) or normalized(assets.get("gameinfo_local_legacy"))
        playfield_image_url = normalized(game.get("playfield_image_url")) or normalized(game.get("playfieldImageUrl"))

        primary_image = (machine or {}).get("primary_image") or {}
        playfield_image = (machine or {}).get("playfield_image") or {}

        built_in_games.append(
            {
                "library_entry_id": library_entry_id,
                "source_id": normalized(game.get("library_id")) or normalized(game.get("sourceId")),
                "source_name": normalized(game.get("library_name")) or normalized(game.get("venue")) or normalized(game.get("sourceName")),
                "source_type": normalized(game.get("library_type")) or normalized(game.get("sourceType")) or "venue",
                "practice_identity": practice_identity,
                "opdb_id": opdb_id or ((machine or {}).get("opdb_machine_id")),
                "area": normalized(game.get("area")) or normalized(game.get("location")),
                "area_order": game.get("area_order") or game.get("areaOrder"),
                "group_number": game.get("group"),
                "position": game.get("position"),
                "bank": game.get("bank"),
                "name": normalized(game.get("name")) or normalized(game.get("game")) or (machine or {}).get("name"),
                "variant": normalized(game.get("variant")) or (machine or {}).get("variant"),
                "manufacturer": normalized(game.get("manufacturer")) or (machine or {}).get("manufacturer_name"),
                "year": game.get("year") or (machine or {}).get("year"),
                "slug": normalized(game.get("slug")) or (machine or {}).get("slug"),
                "primary_image_url": primary_image.get("medium_url"),
                "primary_image_large_url": primary_image.get("large_url"),
                "playfield_image_url": playfield_image_url or playfield_image.get("large_url") or playfield_image.get("medium_url"),
                "playfield_local_path": playfield_local,
                "playfield_source_label": None if playfield_local or playfield_image_url else ("Playfield (OPDB)" if playfield_image else None),
                "gameinfo_local_path": gameinfo_local,
                "rulesheet_local_path": rulesheet_local,
                "rulesheet_url": normalized(game.get("rulesheet_url")) or normalized(game.get("rulesheetUrl")),
            }
        )

        if rulesheet_local:
            pass
        else:
            custom_rules = list(override_rules_by_practice.get(practice_identity or "", []))
            if custom_rules:
                for row in custom_rules:
                    built_in_rulesheets.append(
                        {
                            "library_entry_id": library_entry_id,
                            "label": row["label"],
                            "url": row["url"],
                            "priority": row["priority"],
                        }
                    )
            else:
                for row in rulesheets_by_practice.get(practice_identity or "", []):
                    url = normalized(row.get("url"))
                    if not url:
                        continue
                    built_in_rulesheets.append(
                        {
                            "library_entry_id": library_entry_id,
                            "label": row.get("label") or "Rulesheet",
                            "url": url,
                            "priority": row.get("priority") or 0,
                        }
                    )

        custom_videos = list(override_videos_by_practice.get(practice_identity or "", []))
        if custom_videos:
            for row in custom_videos:
                built_in_videos.append(
                    {
                        "library_entry_id": library_entry_id,
                        "kind": row["kind"],
                        "label": row["label"],
                        "url": row["url"],
                        "priority": row["priority"],
                    }
                )
        else:
            for row in videos_by_practice.get(practice_identity or "", []):
                built_in_videos.append(
                    {
                        "library_entry_id": library_entry_id,
                        "kind": row.get("kind") or "tutorial",
                        "label": row.get("label") or "Tutorial 1",
                        "url": row.get("url"),
                        "priority": row.get("priority") or 0,
                    }
                )

    return built_in_games, built_in_rulesheets, built_in_videos, overrides, override_rulesheets, override_videos


def create_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        PRAGMA journal_mode=WAL;
        PRAGMA synchronous=NORMAL;

        CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        CREATE TABLE manufacturers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            opdb_manufacturer_id TEXT,
            is_modern INTEGER NOT NULL,
            featured_rank INTEGER,
            game_count INTEGER NOT NULL,
            sort_bucket INTEGER NOT NULL,
            sort_name TEXT NOT NULL
        );

        CREATE TABLE machines (
            opdb_machine_id TEXT PRIMARY KEY,
            practice_identity TEXT NOT NULL,
            opdb_group_id TEXT,
            slug TEXT NOT NULL,
            name TEXT NOT NULL,
            variant TEXT,
            manufacturer_id TEXT,
            manufacturer_name TEXT,
            year INTEGER,
            primary_image_medium_url TEXT,
            primary_image_large_url TEXT,
            playfield_image_medium_url TEXT,
            playfield_image_large_url TEXT,
            updated_at TEXT
        );

        CREATE TABLE catalog_rulesheet_links (
            practice_identity TEXT NOT NULL,
            provider TEXT NOT NULL,
            label TEXT NOT NULL,
            url TEXT,
            priority INTEGER NOT NULL
        );

        CREATE TABLE catalog_video_links (
            practice_identity TEXT NOT NULL,
            provider TEXT NOT NULL,
            kind TEXT NOT NULL,
            label TEXT NOT NULL,
            url TEXT NOT NULL,
            priority INTEGER NOT NULL
        );

        CREATE TABLE built_in_sources (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            sort_rank INTEGER NOT NULL
        );

        CREATE TABLE built_in_games (
            library_entry_id TEXT PRIMARY KEY,
            source_id TEXT NOT NULL,
            source_name TEXT NOT NULL,
            source_type TEXT NOT NULL,
            practice_identity TEXT,
            opdb_id TEXT,
            area TEXT,
            area_order INTEGER,
            group_number INTEGER,
            position INTEGER,
            bank INTEGER,
            name TEXT NOT NULL,
            variant TEXT,
            manufacturer TEXT,
            year INTEGER,
            slug TEXT,
            primary_image_url TEXT,
            primary_image_large_url TEXT,
            playfield_image_url TEXT,
            playfield_local_path TEXT,
            playfield_source_label TEXT,
            gameinfo_local_path TEXT,
            rulesheet_local_path TEXT,
            rulesheet_url TEXT
        );

        CREATE TABLE built_in_rulesheet_links (
            library_entry_id TEXT NOT NULL,
            label TEXT NOT NULL,
            url TEXT NOT NULL,
            priority INTEGER NOT NULL
        );

        CREATE TABLE built_in_videos (
            library_entry_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            label TEXT NOT NULL,
            url TEXT NOT NULL,
            priority INTEGER NOT NULL
        );

        CREATE TABLE overrides (
            practice_identity TEXT PRIMARY KEY,
            name_override TEXT,
            variant_override TEXT,
            manufacturer_override TEXT,
            year_override INTEGER,
            playfield_local_path TEXT,
            playfield_source_url TEXT,
            gameinfo_local_path TEXT,
            rulesheet_local_path TEXT
        );

        CREATE TABLE override_rulesheet_links (
            practice_identity TEXT NOT NULL,
            label TEXT NOT NULL,
            url TEXT NOT NULL,
            priority INTEGER NOT NULL
        );

        CREATE TABLE override_videos (
            practice_identity TEXT NOT NULL,
            kind TEXT NOT NULL,
            label TEXT NOT NULL,
            url TEXT NOT NULL,
            priority INTEGER NOT NULL
        );

        CREATE INDEX idx_built_in_games_source ON built_in_games(source_id);
        CREATE INDEX idx_built_in_games_practice ON built_in_games(practice_identity);
        CREATE INDEX idx_machines_manufacturer ON machines(manufacturer_id);
        CREATE INDEX idx_machines_practice ON machines(practice_identity);
        CREATE INDEX idx_catalog_rulesheets_practice ON catalog_rulesheet_links(practice_identity);
        CREATE INDEX idx_catalog_videos_practice ON catalog_video_links(practice_identity);
        CREATE INDEX idx_overrides_practice ON overrides(practice_identity);
        """
    )


def write_database(output_path: Path, legacy: dict[str, Any], catalog: dict[str, Any]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.exists():
        output_path.unlink()

    legacy_sources = legacy.get("sources") or legacy.get("libraries") or []
    legacy_games = legacy.get("items") or legacy.get("games") or []
    built_in_games, built_in_rulesheets, built_in_videos, overrides, override_rulesheets, override_videos = resolved_builtin_rows(legacy_games, catalog)

    conn = sqlite3.connect(output_path)
    try:
        create_schema(conn)
        conn.executemany("INSERT INTO meta(key, value) VALUES(?, ?)", [
            ("seed_schema_version", "1"),
            ("catalog_generated_at", catalog.get("generated_at") or ""),
        ])
        conn.executemany(
            """
            INSERT INTO manufacturers(id, name, opdb_manufacturer_id, is_modern, featured_rank, game_count, sort_bucket, sort_name)
            VALUES(:id, :name, :opdb_manufacturer_id, :is_modern, :featured_rank, :game_count, :sort_bucket, :sort_name)
            """,
            [
                {
                    **row,
                    "is_modern": 1 if row.get("is_modern") else 0,
                }
                for row in catalog.get("manufacturers", [])
            ],
        )
        conn.executemany(
            """
            INSERT INTO machines(
                practice_identity, opdb_machine_id, opdb_group_id, slug, name, variant, manufacturer_id,
                manufacturer_name, year, primary_image_medium_url, primary_image_large_url,
                playfield_image_medium_url, playfield_image_large_url, updated_at
            )
            VALUES(
                :practice_identity, :opdb_machine_id, :opdb_group_id, :slug, :name, :variant, :manufacturer_id,
                :manufacturer_name, :year, :primary_image_medium_url, :primary_image_large_url,
                :playfield_image_medium_url, :playfield_image_large_url, :updated_at
            )
            """,
            [
                {
                    "practice_identity": row.get("practice_identity"),
                    "opdb_machine_id": row.get("opdb_machine_id"),
                    "opdb_group_id": row.get("opdb_group_id"),
                    "slug": row.get("slug"),
                    "name": row.get("name"),
                    "variant": row.get("variant"),
                    "manufacturer_id": row.get("manufacturer_id"),
                    "manufacturer_name": row.get("manufacturer_name"),
                    "year": row.get("year"),
                    "primary_image_medium_url": (row.get("primary_image") or {}).get("medium_url"),
                    "primary_image_large_url": (row.get("primary_image") or {}).get("large_url"),
                    "playfield_image_medium_url": (row.get("playfield_image") or {}).get("medium_url"),
                    "playfield_image_large_url": (row.get("playfield_image") or {}).get("large_url"),
                    "updated_at": row.get("updated_at"),
                }
                for row in catalog.get("machines", [])
            ],
        )
        conn.executemany(
            "INSERT INTO catalog_rulesheet_links(practice_identity, provider, label, url, priority) VALUES(:practice_identity, :provider, :label, :url, :priority)",
            catalog.get("rulesheet_links", []),
        )
        conn.executemany(
            "INSERT INTO catalog_video_links(practice_identity, provider, kind, label, url, priority) VALUES(:practice_identity, :provider, :kind, :label, :url, :priority)",
            catalog.get("video_links", []),
        )
        conn.executemany(
            "INSERT INTO built_in_sources(id, name, type, sort_rank) VALUES(:library_id, :library_name, :library_type, :sort_rank)",
            [
                {
                    "library_id": row.get("library_id"),
                    "library_name": row.get("library_name"),
                    "library_type": row.get("library_type"),
                    "sort_rank": index,
                }
                for index, row in enumerate(legacy_sources)
            ],
        )
        conn.executemany(
            """
            INSERT INTO built_in_games(
                library_entry_id, source_id, source_name, source_type, practice_identity, opdb_id,
                area, area_order, group_number, position, bank, name, variant, manufacturer, year,
                slug, primary_image_url, primary_image_large_url, playfield_image_url, playfield_local_path,
                playfield_source_label, gameinfo_local_path, rulesheet_local_path, rulesheet_url
            )
            VALUES(
                :library_entry_id, :source_id, :source_name, :source_type, :practice_identity, :opdb_id,
                :area, :area_order, :group_number, :position, :bank, :name, :variant, :manufacturer, :year,
                :slug, :primary_image_url, :primary_image_large_url, :playfield_image_url, :playfield_local_path,
                :playfield_source_label, :gameinfo_local_path, :rulesheet_local_path, :rulesheet_url
            )
            """,
            built_in_games,
        )
        conn.executemany(
            "INSERT INTO built_in_rulesheet_links(library_entry_id, label, url, priority) VALUES(:library_entry_id, :label, :url, :priority)",
            built_in_rulesheets,
        )
        conn.executemany(
            "INSERT INTO built_in_videos(library_entry_id, kind, label, url, priority) VALUES(:library_entry_id, :kind, :label, :url, :priority)",
            built_in_videos,
        )
        conn.executemany(
            """
            INSERT INTO overrides(
                practice_identity, name_override, variant_override, manufacturer_override, year_override,
                playfield_local_path, playfield_source_url, gameinfo_local_path, rulesheet_local_path
            )
            VALUES(
                :practice_identity, :name_override, :variant_override, :manufacturer_override, :year_override,
                :playfield_local_path, :playfield_source_url, :gameinfo_local_path, :rulesheet_local_path
            )
            """,
            overrides,
        )
        conn.executemany(
            "INSERT INTO override_rulesheet_links(practice_identity, label, url, priority) VALUES(:practice_identity, :label, :url, :priority)",
            override_rulesheets,
        )
        conn.executemany(
            "INSERT INTO override_videos(practice_identity, kind, label, url, priority) VALUES(:practice_identity, :kind, :label, :url, :priority)",
            override_videos,
        )
        conn.commit()
    finally:
        conn.close()


def main() -> int:
    legacy = load_json(LEGACY_JSON)
    catalog = load_json(CATALOG_JSON)
    write_database(IOS_DB, legacy, catalog)
    write_database(ANDROID_DB, legacy, catalog)
    print(f"wrote sqlite seed to {IOS_DB}")
    print(f"wrote sqlite seed to {ANDROID_DB}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
