from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


class OPDBClient:
    def __init__(self, _autoload_local_env: bool = True) -> None:
        self.api_token = os.environ.get("OPDB_API_TOKEN", "").strip()
        self.export_url = os.environ.get("OPDB_EXPORT_URL", "https://opdb.org/api/export").strip()
        if not self.api_token:
            raise RuntimeError("Missing OPDB_API_TOKEN")
        self.max_retries = 3

    def export_all(self) -> list[dict[str, Any]]:
        url = f"{self.export_url}?{urllib.parse.urlencode({'api_token': self.api_token})}"
        last_error: Exception | None = None
        for attempt in range(self.max_retries + 1):
            request = urllib.request.Request(
                url,
                headers={
                    "Accept": "application/json",
                    "User-Agent": "PinballAppSnapshot/1.0",
                },
            )
            try:
                with urllib.request.urlopen(request, timeout=120) as response:
                    payload = json.load(response)
                if not isinstance(payload, list):
                    raise RuntimeError("Unexpected OPDB export payload shape")
                return payload
            except urllib.error.HTTPError as exc:
                last_error = exc
                if exc.code not in {429, 503} or attempt >= self.max_retries:
                    raise
            except urllib.error.URLError as exc:
                last_error = exc
                if attempt >= self.max_retries:
                    raise
            time.sleep(2 * (attempt + 1))
        if last_error:
            raise last_error
        raise RuntimeError("Failed to fetch OPDB export")
