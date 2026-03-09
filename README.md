# Pinball App

This repository contains both mobile apps:

- `Pinball App 2/` -> iOS (SwiftUI + Xcode project)
- `Pinball App Android/` -> Android (Kotlin + Jetpack Compose)

## Notes

- Runtime stats, standings, library, game info, and rulesheets are fetched from `https://pillyliu.com/pinball/...`.
- Build output, local machine files, and signing artifacts are ignored via `.gitignore`.
- iOS 2.0 major update notes: `Pinball App 2/RELEASE_NOTES_2.0.md`

## Local Asset Intake

- Run `python3 scripts/build_local_asset_intake.py` to inventory local rulesheets and playfield art.
- The script uses `../Pillyliu Pinball Website/shared/pinball` as the canonical source when it exists, compares that against the iOS and Android starter packs, and writes `local_asset_intake_report.json` into the app data folders plus `output/asset-intake/local_asset_intake_summary.md`.

## Migration Test Gates

- iOS migration tests run via XCTest target `Pinball App 2Tests` (`PracticeStateCodecTests`).
- Android migration tests run via `PracticeCanonicalPersistenceTest`.
- CI and Fastlane release lanes now run these migration checks before shipping steps.
