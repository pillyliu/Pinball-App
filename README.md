# Pinball App

Current mobile release: `3.4.9`

This repository contains both mobile apps:

- `Pinball App 2/` -> iOS (SwiftUI + Xcode project)
- `Pinball App Android/` -> Android (Kotlin + Jetpack Compose)

## Current Product

- Version `3.4.9` is the current iOS and Android release line.
- The app now ships as the full five-tab PinProf product:
  - `League`
  - `Library`
  - `Practice`
  - `GameRoom`
  - `Settings`
- Canonical pinball data is published from `../PinProf Admin`, then consumed by both apps through preload plus hosted refresh.

## Notes

- Canonical pinball data editing and publish generation now belongs in `../PinProf Admin`.
- Runtime stats, standings, library, game info, and rulesheets are fetched from `https://pillyliu.com/pinball/...`.
- `Pinball App 2/Pinball App 2/SharedAppSupport/` is the app-owned shared support home for both iOS and Android.
- `Pinball App 2/Pinball App 2/SharedAppSupport/pinside_group_map.json` is the single source of truth for the Pinside group map used by both apps.
- `Pinball App 2/Pinball App 2/SharedAppSupport/shake-warnings/` is the single source of truth for the shared shake-warning art used by both apps.
- `Pinball App 2/Pinball App 2/SharedAppSupport/app-intro/` is the single source of truth for intro overlay source images; run `./scripts/sync_shared_app_assets.sh` after editing them to refresh the iOS launch-logo asset catalog files and Android intro drawables.
- The mobile apps no longer rely on bundled `starter-pack` / `PinballStarter.bundle` pinball payloads at runtime.
- Historical planning docs and superseded blueprint revisions now live under the local-only `archive/` folder so the repo root stays focused on current docs.
- Build output, local machine files, and signing artifacts are ignored via `.gitignore`.
- Current release snapshot: `RELEASE_NOTES_3.4.9.md`
- Historical iOS 2.0 milestone notes are archived locally under `archive/`

## Documentation

- `Pinball_App_Architecture_Blueprint_latest.md` is the active architecture blueprint source.
- Run `./scripts/generate_architecture_blueprint.sh` to refresh `Pinball_App_Architecture_Blueprint_latest_print_layout.pdf` from the current markdown plus Mermaid diagrams. The script bootstraps a local ignored virtualenv if `reportlab` is not already available.
- Historical blueprint revisions, retired generated PDFs, and older helper scripts live under `archive/`.

## Release Versioning

- Android release version is defined in `Pinball App Android/app/build.gradle.kts`.
- Android production uploads use the existing Gradle version through Fastlane.
- Current Android marketing version: `3.4.9`
- Current Android version code: `55`

## Migration Test Gates

- iOS migration tests run via XCTest target `Pinball App 2Tests` (`PracticeStateCodecTests`).
- Android migration tests run via `PracticeCanonicalPersistenceTest`.
- CI and Fastlane release lanes now run these migration checks before shipping steps.
