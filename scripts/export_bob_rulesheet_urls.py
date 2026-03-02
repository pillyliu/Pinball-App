#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
import xml.etree.ElementTree as ET
from datetime import UTC, datetime
from pathlib import Path

SITEMAP_URL = "https://rules.silverballmania.com/sitemap.xml"
RULE_PREFIX = "https://rules.silverballmania.com/rules/"


def fetch_sitemap(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 PinballApp/1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", errors="ignore")


def extract_rule_urls(xml_text: str) -> list[str]:
    root = ET.fromstring(xml_text)
    namespace = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    urls: list[str] = []
    for loc in root.findall("sm:url/sm:loc", namespace):
        value = (loc.text or "").strip()
        if value.startswith(RULE_PREFIX):
            urls.append(value)
    return sorted(set(urls))


def build_payload(urls: list[str]) -> dict[str, object]:
    generated_at = datetime.now(UTC).isoformat()
    return {
        "generated_at": generated_at,
        "source": SITEMAP_URL,
        "count": len(urls),
        "urls": urls,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Export Bob/Silverball Mania rulesheet URLs from sitemap.xml")
    parser.add_argument("--output", type=Path, help="Optional JSON output path")
    args = parser.parse_args()

    xml_text = fetch_sitemap(SITEMAP_URL)
    urls = extract_rule_urls(xml_text)
    payload = build_payload(urls)

    rendered = json.dumps(payload, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        sys.stdout.write(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
