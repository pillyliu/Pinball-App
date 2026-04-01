# PinProf Android

Android app for PinProf.

Current source version:
- `versionName`: `3.5.2`
- `versionCode`: `59`

## Open In Android Studio

- File -> Open -> select this folder.
- Let Gradle sync.

## Run On Device

1. Enable Developer options and USB debugging on the device.
2. Connect by USB.
3. Verify device visibility:
   ```bash
   adb devices
   ```
4. Install a debug build:
   ```bash
   ./gradlew installDebug
   ```

## Current App Shape

- Compose app with five tabs: `League`, `Library`, `Practice`, `GameRoom`, `Settings`
- Hosted runtime data comes from `https://pillyliu.com/pinball/...`
- Local-first state is stored in `SharedPreferences` plus the app cache directory
- Shared app-only assets originate in `../Pinball App 2/Pinball App 2/SharedAppSupport/`
- Android preload assets live in `app/src/main/assets/pinprof-preload/`
- Main source root is `app/src/main/java/com/pillyliu/pinprofandroid`

## Documentation

- Workspace overview: `../README.md`
- Android ownership map: `../docs/codebase/android.md`
- Tooling and scripts map: `../docs/codebase/tooling-and-scripts.md`
- Workspace inventory: `../docs/workspace-catalog.md`
- System blueprint: `../Pinball_App_Architecture_Blueprint.md`

## Build And Test Anchors

- Debug assemble:
  ```bash
  ./gradlew :app:assembleDebug
  ```
- Unit tests:
  ```bash
  ./gradlew :app:testDebugUnitTest
  ```
- Migration test focus:
  ```bash
  ./gradlew :app:testDebugUnitTest --tests com.pillyliu.pinprofandroid.practice.PracticeCanonicalPersistenceTest
  ```

## Release Notes And Upload

- The latest checked-in release notes snapshot is `../RELEASE_NOTES_3.5.0.md`.
- Production upload lane:
  ```bash
  bundle exec fastlane android production
  ```
