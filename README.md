# Pinball App

Current workspace release line:
- iOS marketing version: `3.5.4` (build `100`)
- Android `versionName`: `3.5.4` (`versionCode` `61`)

This repository contains both mobile apps:
- `Pinball App 2/` -> iOS (SwiftUI + Xcode project)
- `Pinball App Android/` -> Android (Kotlin + Jetpack Compose)

## Product Surface

The current product footprint on both platforms is the full five-tab PinProf app:
- `League`
- `Library`
- `Practice`
- `GameRoom`
- `Settings`

Both apps consume hosted runtime content from `https://pillyliu.com/pinball/...`, then layer on local-first user data for practice, library state, and owned-machine workflows.

## Workspace Layout

Core app work:
- `Pinball App 2/Pinball App 2/` -> iOS source
- `Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/` -> Android source
- `Pinball App 2/Pinball App 2/SharedAppSupport/` -> app-owned shared support assets used by both apps

Documentation:
- `docs/codebase/README.md` -> code bible index and maintenance rules
- `docs/codebase/ios.md` -> detailed iOS ownership map
- `docs/codebase/android.md` -> detailed Android ownership map
- `docs/codebase/tooling-and-scripts.md` -> build, release, script, CI, and docs workflow map
- `docs/workspace-catalog.md` -> inventory of non-app-code workspace assets and cleanup candidates
- `Pinball_App_Architecture_Blueprint.md` -> system-level architecture blueprint
- `Pinball_App_Architecture_Blueprint_print_layout.pdf` -> rendered print layout of the active blueprint

Supporting doc layers:
- `docs/review/` -> cleanup and review history
- `docs/modernization/` -> parity and longer-range planning
- `docs/marketing/` -> promo and collateral planning
- `archive/` -> retired or historical docs and scripts

## Runtime Data Model

The active runtime contract is the hosted CAF / OPDB pipeline:
- `opdb_export.json`
- `practice_identity_curations_v1.json`
- `rulesheet_assets.json`
- `video_assets.json`
- `playfield_assets.json`
- `gameinfo_assets.json`
- `backglass_assets.json`
- `venue_layout_assets.json`
- league CSV and support files under `/pinball/data/`

Important current notes:
- Canonical publish generation now belongs in `../PinProf Admin`.
- The apps consume hosted `/pinball` payloads and do not talk directly to the admin database.
- `SharedAppSupport/pinside_group_map.json` is the bundled source of truth for shared Pinside title/group mapping.
- `SharedAppSupport/shake-warnings/` is the bundled source of truth for shake-warning art.
- `SharedAppSupport/app-intro/` is the bundled source of truth for intro overlay source images.
- Run `./scripts/sync_shared_app_assets.sh` after changing shared app-intro or shake-warning assets so iOS and Android bundles stay aligned.

## Version And Release Anchors

- iOS versioning lives in `Pinball App 2/Pinball App 2.xcodeproj/project.pbxproj`.
- Android versioning lives in `Pinball App Android/app/build.gradle.kts`.
- The latest checked-in release-notes snapshot is still `RELEASE_NOTES_3.5.0.md`.
- The source tree itself is already on the `3.5.4` release line.

## Validation Gates

- iOS build:
  - `xcodebuild build -project "Pinball App 2/Pinball App 2.xcodeproj" -scheme "PinProf"`
- iOS migration tests:
  - `Pinball App 2Tests/PracticeStateCodecTests`
- Android build:
  - `./gradlew :app:assembleDebug`
- Android migration tests:
  - `./gradlew :app:testDebugUnitTest --tests com.pillyliu.pinprofandroid.practice.PracticeCanonicalPersistenceTest`
- CI:
  - `.github/workflows/ci.yml`

## Documentation Workflow

When the codebase changes in a way that affects ownership, routing, runtime contracts, or release flow:
1. update the relevant platform map in `docs/codebase/`
2. update `Pinball_App_Architecture_Blueprint.md` if the system model changed
3. archive major document snapshots under `archive/` with a dated folder name instead of renaming the active file
4. rerun `./scripts/generate_architecture_blueprint.sh` if the blueprint markdown changed
5. keep this README aligned with current version anchors and doc entrypoints
