# Settings Ledger

## 2026-03-06

- Added as a lower-risk modernization feature after shell, Library, Practice, and GameRoom audits.

## 2026-03-08

- iOS `Add Manufacturer`, `Add Venue`, and `Add Tournament` now use shared panel/control chrome and compact menu labels instead of keeping segmented-picker and plain-list form treatment local to Settings.
- Android `Add Manufacturer`, `Add Venue`, and `Add Tournament` now use shared dropdown/card chrome instead of keeping segmented-selector and plain form treatment local to Settings.
- Settings source rows now use shared compact refresh/delete action-chip chrome on both platforms instead of keeping row-button styling local to the feature.
- Settings home section titles now use the shared section-title seams on both platforms instead of feature-local title styling.
- Android `Add Manufacturer`, `Add Venue`, and `Add Tournament` now also use the shared `AppScreenHeader` seam instead of feature-local back-button plus centered-title rows.
- iOS and Android `Add Venue` / `Add Tournament` now also use shared inline task-status messaging for search/import progress and local errors instead of keeping feature-local alerts and text blocks.
- iOS and Android Settings home now also use shared panel-status messaging for loading and root library-source errors instead of a feature-local alert/full-screen spinner split.
- iOS and Android Settings home now also use shared panel-empty cards for the “no additional sources” state instead of feature-local secondary text blocks inside the Library card.
- iOS and Android Settings home now include a manual `Refresh Pinball Data` action in the Library section that force-refreshes the hosted Library payload and OPDB catalog from `pillyliu.com`, reports progress/error through the shared task-status seams, and then reloads Settings against the refreshed hosted catalog instead of waiting for the normal hosted refresh interval.
- That manual hosted-data refresh now consumes the shared Library hosted-data seams instead of keeping duplicate hosted fetch/decode logic inside Settings:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryHostedData.swift`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryHostedData.kt`
- Android Settings source import/remove/refresh persistence now lives behind `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/settings/SettingsDataIntegration.kt`, so `SettingsScreen.kt` no longer owns hosted manufacturer reload, hosted-data force refresh, or imported-source mutation wiring inline.

## Next audit targets

- exact section inventory
- settings persistence inventory
- remaining shared row styling inventory
