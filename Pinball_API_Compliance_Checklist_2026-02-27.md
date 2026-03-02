# Pinball API Compliance Checklist

Date: February 27, 2026  
Scope: OPDB, Pinball Map, Match Play, IFPA integrations for Pinball App iOS/Android data feeds.

## 1) Core Rules (All Providers)

- [ ] Use official API endpoints only (no scraping when API exists).
- [ ] Use your own account credentials/tokens only.
- [ ] Store tokens server-side only (never in mobile app bundles, never in client code).
- [ ] Rotate tokens/API keys and revoke on suspected leak.
- [ ] Respect rate limits; implement retries with backoff and jitter.
- [ ] Cache responses and run scheduled syncs instead of frequent live pulls.
- [ ] Maintain source attribution in-app where required/recommended.
- [ ] Add per-provider feature flag/kill switch.
- [ ] Keep audit logs of sync runs (time, endpoint, status, record counts, errors).
- [ ] Document a takedown/removal process for third-party content.

## 2) OPDB Checklist

Source: https://opdb.org/api/

- [ ] Generate and use OPDB `api_token` for required endpoints.
- [ ] Use `/api/export` for bulk bootstrap, not repeated record-by-record crawling.
- [ ] Enforce OPDB export cadence limit (max once per hour).
- [ ] Use `/api/changelog` for incremental OPDB ID moves/deletes.
- [ ] Maintain OPDB ID mapping table (current_id, previous_id, replaced_by).
- [ ] Do not expose OPDB token in app binaries or public repos.

## 3) Pinball Map Checklist

Source: https://pinballmap.com/api/v1/docs

- [ ] Use read endpoints for venue/machine ingestion.
- [ ] If using write endpoints, require authenticated Pinball Map account token flow.
- [ ] Include Pinball Map attribution in app/about screen.
- [ ] Preserve `opdb_id` from Pinball Map for cross-provider joins.
- [ ] Handle missing/partial machine details defensively.
- [ ] Respect service availability; throttle heavy location syncs.

## 4) Match Play Checklist

Sources:  
https://docs.matchplay.events/data-crunching/match-play-api  
https://app.matchplay.events/api-docs/

- [ ] Use bearer token auth (`Authorization: Bearer ...`) for protected endpoints.
- [ ] Scope tokens to least privilege account needed.
- [ ] Separate public-resource pulls from private user/tournament data pulls.
- [ ] If using `/api/pintips`, link by `opdbId` and keep source attribution.
- [ ] Do not sync private tournament/player data without explicit account ownership/permission.
- [ ] Respect API pagination and rate behavior.

## 5) IFPA Checklist

Sources:  
https://www.ifpapinball.com/api/  
https://api.ifpapinball.com/docs/

- [ ] Generate IFPA API key from your IFPA account.
- [ ] Pass IFPA key via documented `api_key` query auth scheme.
- [ ] Treat IFPA as read-only data source (GET endpoints).
- [ ] Use IFPA number (`ifpaId`) as canonical cross-provider player identity key.
- [ ] Maintain mapping: `ifpaId` <-> Match Play user/player IDs <-> local player IDs.
- [ ] Respect endpoint filters/pagination to avoid excessive pulls.

## 6) Data Model & Rights Checklist

- [ ] Keep `opdb_id` as canonical machine key in unified library records.
- [ ] Keep `ifpaId` as canonical player key where available.
- [ ] Track content provenance per field (`source`, `source_url`, `fetched_at`).
- [ ] Do not assume rights to redistribute third-party images/rulesheets beyond allowed usage.
- [ ] Prefer storing external URLs for copyrighted resources unless licensed for mirroring.
- [ ] Add record-level `last_verified_at` and `provider_etag/hash` where available.

## 7) Security Checklist

- [ ] Put API secrets in server environment variables / secret manager.
- [ ] Restrict secret access by environment and role.
- [ ] Add outbound allowlist for provider domains from sync worker.
- [ ] Add alerting on auth failures and unusual request bursts.
- [ ] Redact tokens/keys from logs and crash reports.

## 8) Operational Checklist (Your Current App Shape)

- [ ] Continue publishing app-facing static artifacts to `https://pillyliu.com/pinball/...`.
- [ ] Keep mobile clients consuming `pinball_library_v3.json`-style contract (or versioned successor).
- [ ] Run ingestion in server pipeline, not on-device.
- [ ] Publish manifest/update-log deltas compatible with existing cache refresh flow.
- [ ] Add rollback artifact for each publish batch.
- [ ] Add canary validation before full publish (schema + sample app load test).

## 9) Pre-Launch Sign-off

- [ ] Verify each provider’s latest published API docs on launch week.
- [ ] Send courtesy emails to provider contacts for high-volume production usage.
- [ ] Confirm attribution text placement in both iOS and Android app.
- [ ] Verify token rotation and emergency revocation runbook.
- [ ] Capture legal/product owner approval for third-party data usage posture.

## 10) Ongoing Governance (Monthly)

- [ ] Re-check docs/changelog for auth/rate/terms changes.
- [ ] Re-run data provenance and broken-link checks.
- [ ] Review top failed endpoints and adjust sync frequency.
- [ ] Audit secret exposure risk and rotate credentials.
- [ ] Reconfirm that deprecated endpoints are not in use.
