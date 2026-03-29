# PinProf 3.5.0 Release Snapshot

This document is the current release-facing summary for PinProf version `3.5.0`.

It describes what ships today across both mobile apps rather than preserving the older milestone history from earlier app phases.

## Release anchors

- iOS marketing version: `3.5.0`
- Android marketing version: `3.5.0`
- Android version code: `56`

## Product shape

PinProf now ships as the full five-tab product on both iOS and Android:

- `League`
- `Library`
- `Practice`
- `GameRoom`
- `Settings`

## Core release state

- Both apps run on the CAF runtime contract published from `PinProf Admin`.
- Core pinball data is bundled through the curated mobile preload and refreshed from hosted `/pinball/...` content.
- App-only shared assets now live in `Pinball App 2/Pinball App 2/SharedAppSupport/`.
- `pinside_group_map.json`, intro overlay artwork, and shake-warning artwork are app-owned support files, not hosted website payload.
- The synthetic `PinProf: The Final Exam` machine remains the intentional local-content exception for bundled app resources.

## Current data/runtime model

- Canonical editing and publish generation live in `../PinProf Admin`.
- Hosted runtime data comes from `https://pillyliu.com/pinball/...`.
- Main hosted layers:
  - `opdb_export.json`
  - `rulesheet_assets.json`
  - `video_assets.json`
  - `playfield_assets.json`
  - `gameinfo_assets.json`
  - `backglass_assets.json`
  - `venue_layout_assets.json`
- League CSVs and resolved targets remain part of the hosted payload.
- Apps no longer depend on `starter-pack`, `PinballStarter.bundle`, `pinball_library_v3.json`, or seed-db-era library payloads.

## Release workflow

- iOS migration tests run through `Pinball App 2Tests` (`PracticeStateCodecTests`).
- Android migration tests run through `PracticeCanonicalPersistenceTest`.
- GitHub Actions validates both platforms on pushes to `main`.
- Android production releases use:

```bash
bundle exec fastlane android production
```

## Historical note

The old `2.0` milestone writeup is preserved only as historical local archive material. The current release-facing docs are:

- `README.md`
- `RELEASE_NOTES_3.5.0.md`
- `Pinball_App_Architecture_Blueprint_latest.md`
