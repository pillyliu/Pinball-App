# Pinball App

This repository contains both mobile apps:

- `Pinball App 2/` -> iOS (SwiftUI + Xcode project)
- `Pinball App Android/` -> Android (Kotlin + Jetpack Compose)

## Notes

- Canonical pinball data editing and publish generation now belongs in `../PinProf Admin`.
- Runtime stats, standings, library, game info, and rulesheets are fetched from `https://pillyliu.com/pinball/...`.
- `Pinball App 2/Pinball App 2/SharedAppSupport/` is the app-owned shared support home for both iOS and Android.
- `Pinball App 2/Pinball App 2/SharedAppSupport/pinside_group_map.json` is the single source of truth for the Pinside group map used by both apps.
- `Pinball App 2/Pinball App 2/SharedAppSupport/shake-warnings/` is the single source of truth for the shared shake-warning art used by both apps.
- `Pinball App 2/Pinball App 2/SharedAppSupport/app-intro/` is the single source of truth for intro overlay source images; run `./scripts/sync_shared_app_assets.sh` after editing them to refresh iOS asset catalog files and Android drawables.
- The mobile apps no longer rely on bundled `starter-pack` / `PinballStarter.bundle` pinball payloads at runtime.
- Historical planning docs and superseded blueprint revisions now live under the local-only `archive/` folder so the repo root stays focused on current docs.
- Build output, local machine files, and signing artifacts are ignored via `.gitignore`.
- iOS 2.0 major update notes: `Pinball App 2/RELEASE_NOTES_2.0.md`

## Migration Test Gates

- iOS migration tests run via XCTest target `Pinball App 2Tests` (`PracticeStateCodecTests`).
- Android migration tests run via `PracticeCanonicalPersistenceTest`.
- CI and Fastlane release lanes now run these migration checks before shipping steps.
