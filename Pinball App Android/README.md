# Pinball App Android

Android app for the Pinball project.

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
- Compose app with 4 working tabs: `Stats`, `Standings`, `Targets`, `Library`.
- Data is loaded from `https://pillyliu.com/pinball/...` with local cache support.
- Main source: `app/src/main/java/com/pillyliu/pinballandroid`.
