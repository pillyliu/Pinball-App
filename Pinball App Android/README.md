# PinProf Android

Android app for PinProf.

Current release: `3.4.9`

## Open in Android Studio
- File -> Open -> select this folder.
- Let Gradle sync.

## Run on tablet
1. Enable Developer options + USB debugging on the tablet.
2. Connect by USB.
3. Verify device:
   ```bash
   adb devices
   ```
4. Install debug build:
   ```bash
   ./gradlew installDebug
   ```

## Current state
- Compose app with 5 tabs: `League`, `Library`, `Practice`, `GameRoom`, `Settings`.
- Data is loaded from `https://pillyliu.com/pinball/...` with local preload and cache support.
- Shared app-only assets come from `../Pinball App 2/Pinball App 2/SharedAppSupport/`.
- Main source: `app/src/main/java/com/pillyliu/pinprofandroid`.

## Release versioning

- Current `versionName`: `3.4.9`
- Current `versionCode`: `55`
- Current release snapshot: `../RELEASE_NOTES_3.4.9.md`
- Production upload lane:
  ```bash
  bundle exec fastlane android production
  ```
