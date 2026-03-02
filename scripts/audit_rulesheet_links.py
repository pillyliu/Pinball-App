#!/usr/bin/env python3

from __future__ import annotations

import argparse
import html
import json
import re
import socket
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from fetch_opdb_snapshot import normalize_rulesheet_url

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG = REPO_ROOT / "Pinball App 2" / "Pinball App 2" / "PinballStarter.bundle" / "pinball" / "data" / "opdb_catalog_v1.json"
DEFAULT_IOS_OUTPUT = REPO_ROOT / "Pinball App 2" / "Pinball App 2" / "PinballStarter.bundle" / "pinball" / "data" / "rulesheet_link_audit.json"
DEFAULT_ANDROID_OUTPUT = REPO_ROOT / "Pinball App Android" / "app" / "src" / "main" / "assets" / "starter-pack" / "pinball" / "data" / "rulesheet_link_audit.json"
SUPPORTED_PROVIDERS = {"tf", "pp", "bob", "papa"}
USER_AGENT = "Mozilla/5.0 PinballApp/1.0"
REQUEST_TIMEOUT = 20
MIN_TEXT_CONTENT = 80
MAX_RETRIES = 2


@dataclass(frozen=True)
class RulesheetLink:
    provider: str
    normalized_url: str
    raw_url: str
    practice_identity: str
    label: str
    priority: int


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


def collect_rulesheet_links(catalog: dict[str, Any]) -> list[RulesheetLink]:
    links: list[RulesheetLink] = []
    for row in catalog.get("rulesheet_links", []):
        raw_url = (row.get("url") or "").strip()
        provider = (row.get("provider") or "").strip().lower()
        if not raw_url or provider not in SUPPORTED_PROVIDERS:
            continue
        links.append(
            RulesheetLink(
                provider=provider,
                normalized_url=normalize_rulesheet_url(raw_url),
                raw_url=raw_url,
                practice_identity=(row.get("practice_identity") or "").strip(),
                label=(row.get("label") or "").strip(),
                priority=int(row.get("priority") or 0),
            )
        )
    return links


def build_url_inventory(links: list[RulesheetLink]) -> list[dict[str, Any]]:
    grouped: dict[str, dict[str, Any]] = {}
    for link in links:
        item = grouped.setdefault(
            link.normalized_url,
            {
                "normalized_url": link.normalized_url,
                "provider": link.provider,
                "raw_urls": set(),
                "practice_identities": set(),
                "references": [],
            },
        )
        item["raw_urls"].add(link.raw_url)
        if link.practice_identity:
            item["practice_identities"].add(link.practice_identity)
        item["references"].append(
            {
                "practice_identity": link.practice_identity,
                "label": link.label,
                "priority": link.priority,
            }
        )

    inventory = []
    for item in grouped.values():
        inventory.append(
            {
                "normalized_url": item["normalized_url"],
                "provider": item["provider"],
                "raw_urls": sorted(item["raw_urls"]),
                "practice_identities": sorted(item["practice_identities"]),
                "references": sorted(
                    item["references"],
                    key=lambda ref: (ref["practice_identity"], ref["priority"], ref["label"]),
                ),
                "seen_count": len(item["references"]),
            }
        )
    inventory.sort(key=lambda row: (row["provider"], row["normalized_url"]))
    return inventory


def fetch_document(url: str) -> tuple[str, int | None, str, str | None]:
    last_error: Exception | None = None
    for attempt in range(MAX_RETRIES + 1):
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT) as response:
                body = response.read()
                charset = response.headers.get_content_charset() or "utf-8"
                text = body.decode(charset, errors="replace")
                return (
                    text,
                    getattr(response, "status", None),
                    response.geturl(),
                    response.headers.get_content_type(),
                )
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code in {429, 503} and attempt < MAX_RETRIES:
                time.sleep(2 * (attempt + 1))
                continue
            raise
        except urllib.error.URLError as exc:
            last_error = exc
            if isinstance(exc.reason, (TimeoutError, socket.timeout)) and attempt < MAX_RETRIES:
                time.sleep(2 * (attempt + 1))
                continue
            raise
    if last_error:
        raise last_error
    raise RuntimeError(f"Failed to fetch {url}")


def tiltforums_api_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    path = parsed.path
    if "/posts/" in path and path.lower().endswith(".json"):
        return urllib.parse.urlunparse(parsed._replace(query=""))
    if not path.lower().endswith(".json"):
        path = f"{path}.json"
    return urllib.parse.urlunparse(parsed._replace(path=path, query=""))


def legacy_fetch_url(provider: str, url: str) -> str:
    if provider != "bob":
        return url
    parsed = urllib.parse.urlparse(url)
    host = parsed.netloc.lower()
    if "silverballmania.com" not in host:
        return url
    slug = parsed.path.rstrip("/").split("/")[-1]
    if not slug:
        return url
    return f"https://rules.silverballmania.com/print/{slug}"


def extract_between(pattern: str, text: str) -> str | None:
    match = re.search(pattern, text, flags=re.IGNORECASE | re.DOTALL)
    return match.group(1) if match else None


def strip_html(source: str, patterns: list[str]) -> str:
    text = source
    for pattern in patterns:
        text = re.sub(pattern, "", text, flags=re.IGNORECASE | re.DOTALL)
    return text


def cleanup_primer_html(html_text: str) -> str:
    body = extract_between(r"<body\b[^>]*>(.*?)</body>", html_text) or html_text
    cleaned = strip_html(
        body,
        [
            r"<iframe\b[^>]*>.*?</iframe>",
            r"<script\b[^>]*>.*?</script>",
            r"<style\b[^>]*>.*?</style>",
            r"<!--.*?-->",
        ],
    )
    first_heading = re.search(r"<h1\b[^>]*>", cleaned, flags=re.IGNORECASE | re.DOTALL)
    if first_heading:
        cleaned = cleaned[first_heading.start() :]
    return cleaned.strip()


def should_treat_as_plain_text(html_text: str, mime_type: str | None) -> bool:
    if mime_type and "text/plain" in mime_type.lower():
        return True
    return re.search(r"<[a-zA-Z!/][^>]*>", html_text) is None


def cleanup_legacy_html(html_text: str, mime_type: str | None, provider: str) -> str:
    if should_treat_as_plain_text(html_text, mime_type):
        return html_text.strip()

    if provider == "bob":
        main = extract_between(r"<main\b[^>]*>(.*?)</main>", html_text)
        if main:
            return strip_html(
                main,
                [
                    r"<script\b[^>]*>.*?</script>",
                    r"<!--.*?-->",
                    r"<a\b[^>]*title=\"Print\"[^>]*>.*?</a>",
                ],
            ).strip()

    body = extract_between(r"<body\b[^>]*>(.*?)</body>", html_text) or html_text
    return strip_html(
        body,
        [
            r"<\?.*?\?>",
            r"<script\b[^>]*>.*?</script>",
            r"<style\b[^>]*>.*?</style>",
            r"<iframe\b[^>]*>.*?</iframe>",
            r"<!--.*?-->",
            r"</?(html|head|body|meta|link)\b[^>]*>",
        ],
    ).strip()


def visible_text_length(fragment: str) -> int:
    text = re.sub(r"<[^>]+>", " ", fragment)
    text = html.unescape(text)
    text = re.sub(r"\s+", " ", text).strip()
    return len(text)


def looks_parsed(fragment: str) -> bool:
    return visible_text_length(fragment) >= MIN_TEXT_CONTENT


def audit_one_url(item: dict[str, Any]) -> dict[str, Any]:
    provider = item["provider"]
    normalized_url = item["normalized_url"]
    fetch_url = normalized_url
    parse_kind = "html"

    try:
        if provider == "tf":
            parse_kind = "tiltforums_json"
            fetch_url = tiltforums_api_url(normalized_url)
            payload_text, http_status, final_url, mime_type = fetch_document(fetch_url)
            payload = json.loads(payload_text)
            posts = ((payload.get("post_stream") or {}).get("posts")) or []
            post = posts[0] if posts else payload
            cooked = (post.get("cooked") or "").strip()
            if not cooked:
                return {
                    "current_status": "broken_parse",
                    "broken": True,
                    "provider": provider,
                    "normalized_url": normalized_url,
                    "fetch_url": fetch_url,
                    "final_url": final_url,
                    "http_status": http_status,
                    "mime_type": mime_type,
                    "parse_kind": parse_kind,
                    "content_text_length": 0,
                    "last_error": "Tilt Forums payload missing cooked HTML",
                }
            return {
                "current_status": "ok",
                "broken": False,
                "provider": provider,
                "normalized_url": normalized_url,
                "fetch_url": fetch_url,
                "final_url": final_url,
                "http_status": http_status,
                "mime_type": mime_type,
                "parse_kind": parse_kind,
                "content_text_length": visible_text_length(cooked),
                "last_error": None,
            }

        if provider == "pp":
            payload_text, http_status, final_url, mime_type = fetch_document(fetch_url)
            cleaned = cleanup_primer_html(payload_text)
            if not looks_parsed(cleaned):
                return {
                    "current_status": "broken_parse",
                    "broken": True,
                    "provider": provider,
                    "normalized_url": normalized_url,
                    "fetch_url": fetch_url,
                    "final_url": final_url,
                    "http_status": http_status,
                    "mime_type": mime_type,
                    "parse_kind": parse_kind,
                    "content_text_length": visible_text_length(cleaned),
                    "last_error": "Primer HTML cleanup produced too little readable content",
                }
            return {
                "current_status": "ok",
                "broken": False,
                "provider": provider,
                "normalized_url": normalized_url,
                "fetch_url": fetch_url,
                "final_url": final_url,
                "http_status": http_status,
                "mime_type": mime_type,
                "parse_kind": parse_kind,
                "content_text_length": visible_text_length(cleaned),
                "last_error": None,
            }

        fetch_url = legacy_fetch_url(provider, normalized_url)
        payload_text, http_status, final_url, mime_type = fetch_document(fetch_url)
        cleaned = cleanup_legacy_html(payload_text, mime_type, provider)
        if not looks_parsed(cleaned):
            return {
                "current_status": "broken_parse",
                "broken": True,
                "provider": provider,
                "normalized_url": normalized_url,
                "fetch_url": fetch_url,
                "final_url": final_url,
                "http_status": http_status,
                "mime_type": mime_type,
                "parse_kind": "legacy_html",
                "content_text_length": visible_text_length(cleaned),
                "last_error": "Legacy HTML cleanup produced too little readable content",
            }
        return {
            "current_status": "ok",
            "broken": False,
            "provider": provider,
            "normalized_url": normalized_url,
            "fetch_url": fetch_url,
            "final_url": final_url,
            "http_status": http_status,
            "mime_type": mime_type,
            "parse_kind": "legacy_html",
            "content_text_length": visible_text_length(cleaned),
            "last_error": None,
        }
    except urllib.error.HTTPError as exc:
        status = "blocked" if exc.code in {403, 429} else "broken_http"
        return {
            "current_status": status,
            "broken": status != "blocked",
            "provider": provider,
            "normalized_url": normalized_url,
            "fetch_url": fetch_url,
            "final_url": exc.geturl(),
            "http_status": exc.code,
            "mime_type": exc.headers.get_content_type() if exc.headers else None,
            "parse_kind": parse_kind,
            "content_text_length": 0,
            "last_error": f"HTTP {exc.code}",
        }
    except urllib.error.URLError as exc:
        reason = exc.reason
        if isinstance(reason, (TimeoutError, socket.timeout)):
            status = "broken_timeout"
        else:
            status = "broken_network"
        return {
            "current_status": status,
            "broken": True,
            "provider": provider,
            "normalized_url": normalized_url,
            "fetch_url": fetch_url,
            "final_url": None,
            "http_status": None,
            "mime_type": None,
            "parse_kind": parse_kind,
            "content_text_length": 0,
            "last_error": str(reason),
        }
    except TimeoutError as exc:
        return {
            "current_status": "broken_timeout",
            "broken": True,
            "provider": provider,
            "normalized_url": normalized_url,
            "fetch_url": fetch_url,
            "final_url": None,
            "http_status": None,
            "mime_type": None,
            "parse_kind": parse_kind,
            "content_text_length": 0,
            "last_error": str(exc),
        }
    except Exception as exc:
        return {
            "current_status": "broken_parse",
            "broken": True,
            "provider": provider,
            "normalized_url": normalized_url,
            "fetch_url": fetch_url,
            "final_url": None,
            "http_status": None,
            "mime_type": None,
            "parse_kind": parse_kind,
            "content_text_length": 0,
            "last_error": str(exc),
        }


def merge_with_history(
    inventory_item: dict[str, Any],
    current_result: dict[str, Any],
    previous_by_url: dict[str, dict[str, Any]],
    checked_at: str,
) -> dict[str, Any]:
    previous = previous_by_url.get(inventory_item["normalized_url"], {})
    previous_status = previous.get("current_status")
    previous_failure_count = int(previous.get("failure_count") or 0)
    current_status = current_result["current_status"]
    is_ok = current_status == "ok"
    is_broken = current_result["broken"]

    if previous.get("first_seen_at"):
        first_seen_at = previous["first_seen_at"]
    else:
        first_seen_at = checked_at

    if is_ok:
        failure_count = previous_failure_count
        last_ok_at = checked_at
    elif is_broken:
        failure_count = previous_failure_count + 1
        last_ok_at = previous.get("last_ok_at")
    else:
        failure_count = previous_failure_count
        last_ok_at = previous.get("last_ok_at")

    return {
        "normalized_url": inventory_item["normalized_url"],
        "provider": inventory_item["provider"],
        "raw_urls": inventory_item["raw_urls"],
        "practice_identities": inventory_item["practice_identities"],
        "references": inventory_item["references"],
        "seen_count": inventory_item["seen_count"],
        "first_seen_at": first_seen_at,
        "last_checked_at": checked_at,
        "last_ok_at": last_ok_at,
        "previous_status": previous_status,
        "current_status": current_status,
        "broken": current_result["broken"],
        "failure_count": failure_count,
        "fetch_url": current_result["fetch_url"],
        "final_url": current_result["final_url"],
        "http_status": current_result["http_status"],
        "mime_type": current_result["mime_type"],
        "parse_kind": current_result["parse_kind"],
        "content_text_length": current_result["content_text_length"],
        "last_error": current_result["last_error"],
    }


def summarize(results: list[dict[str, Any]], raw_rows: int) -> dict[str, Any]:
    by_status: dict[str, int] = {}
    by_provider: dict[str, dict[str, int]] = {}
    for row in results:
        by_status[row["current_status"]] = by_status.get(row["current_status"], 0) + 1
        provider_summary = by_provider.setdefault(row["provider"], {"total": 0, "ok": 0, "broken": 0})
        provider_summary["total"] += 1
        if row["broken"]:
            provider_summary["broken"] += 1
        else:
            provider_summary["ok"] += 1
    return {
        "raw_rows": raw_rows,
        "unique_urls": len(results),
        "ok": sum(1 for row in results if not row["broken"]),
        "broken": sum(1 for row in results if row["broken"]),
        "statuses": by_status,
        "providers": by_provider,
    }


def run_audit(
    catalog_path: Path,
    output_path: Path,
    mirror_output_path: Path | None,
    max_workers: int,
    limit: int | None,
) -> dict[str, Any]:
    catalog = load_json(catalog_path)
    links = collect_rulesheet_links(catalog)
    inventory = build_url_inventory(links)
    if limit is not None:
        inventory = inventory[: max(0, limit)]
    previous_payload = load_json(output_path) if output_path.exists() else {"results": []}
    previous_by_url = {
        row["normalized_url"]: row
        for row in previous_payload.get("results", [])
        if isinstance(row, dict) and row.get("normalized_url")
    }
    checked_at = iso_now()

    current_by_url: dict[str, dict[str, Any]] = {}
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_map = {executor.submit(audit_one_url, item): item for item in inventory}
        for future in as_completed(future_map):
            item = future_map[future]
            current_by_url[item["normalized_url"]] = future.result()

    results = [
        merge_with_history(item, current_by_url[item["normalized_url"]], previous_by_url, checked_at)
        for item in inventory
    ]
    results.sort(key=lambda row: (row["broken"], row["provider"], row["normalized_url"]))

    payload = {
        "schema_version": 1,
        "generated_at": checked_at,
        "catalog_path": str(catalog_path),
        "source": "opdb_catalog.rulesheet_links",
        "providers": sorted(SUPPORTED_PROVIDERS),
        "summary": summarize(results, raw_rows=len(links)),
        "results": results,
    }
    write_json(output_path, payload)
    if mirror_output_path:
        write_json(mirror_output_path, payload)
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit OPDB-derived external rulesheet links and preserve broken-link history by normalized URL.")
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--output", type=Path, default=DEFAULT_IOS_OUTPUT)
    parser.add_argument("--android-output", type=Path, default=DEFAULT_ANDROID_OUTPUT)
    parser.add_argument("--skip-android", action="store_true")
    parser.add_argument("--max-workers", type=int, default=8)
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()

    payload = run_audit(
        catalog_path=args.catalog,
        output_path=args.output,
        mirror_output_path=None if args.skip_android else args.android_output,
        max_workers=max(1, args.max_workers),
        limit=args.limit,
    )
    summary = payload["summary"]
    print(
        f"wrote audit: raw_rows={summary['raw_rows']} unique_urls={summary['unique_urls']} "
        f"ok={summary['ok']} broken={summary['broken']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
