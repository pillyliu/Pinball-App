# Pinball App

This repository contains both mobile apps:

- `Pinball App 2/` -> iOS (SwiftUI + Xcode project)
- `Pinball App Android/` -> Android (Kotlin + Jetpack Compose)

## Notes

- Runtime stats, standings, library, game info, and rulesheets are fetched from `https://pillyliu.com/pinball/...`.
- Build output, local machine files, and signing artifacts are ignored via `.gitignore`.
- iOS 2.0 major update notes: `Pinball App 2/RELEASE_NOTES_2.0.md`

## Migration Test Gates

- iOS migration tests run via XCTest target `Pinball App 2Tests` (`PracticeStateCodecTests`).
- Android migration tests run via `PracticeCanonicalPersistenceTest`.
- CI and Fastlane release lanes now run these migration checks before shipping steps.
