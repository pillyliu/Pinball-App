# Pinball App

This repository contains both mobile apps:

- `Pinball App 2/` -> iOS (SwiftUI + Xcode project)
- `Pinball App Android/` -> Android (Kotlin + Jetpack Compose)

## Notes

- Runtime stats, standings, library, game info, and rulesheets are fetched from `https://pillyliu.com/pinball/...`.
- Build output, local machine files, and signing artifacts are ignored via `.gitignore`.

## iOS Fastlane (TestFlight/App Store)

From `Pinball App 2/`:

1. Install Fastlane via Bundler:
   - `bundle install`
2. Create your local env file:
   - `cp fastlane/.env.default.example fastlane/.env.default`
3. Fill in these values in `fastlane/.env.default`:
   - `APP_STORE_CONNECT_KEY_ID`
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APP_STORE_CONNECT_KEY_PATH` (absolute path to your `.p8` key file)
4. Run lanes:
   - Build only: `bundle exec fastlane ios build`
   - Upload TestFlight: `bundle exec fastlane ios beta`
   - Upload App Store Connect: `bundle exec fastlane ios release`
