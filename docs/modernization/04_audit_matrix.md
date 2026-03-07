# Audit Matrix

Use this file to track architecture and cleanup decisions at a high level.

Status values:
- `not started`
- `in audit`
- `stable`
- `needs refactor`
- `needs split`
- `needs rewrite`
- `parity risk`

## Feature summary

| Feature | iOS status | Android status | Parity status | Notes |
| --- | --- | --- | --- | --- |
| League | in audit | in audit | in audit | Shell already aligned at tab level; nested About now exists under League. |
| Library | in audit | in audit | in audit | Shared library behavior is critical for GameRoom integration and resource handling. |
| Practice | in audit | in audit | parity risk | Large surface area and high risk of duplication and drift. |
| GameRoom | stable | stable | in audit | 3.1 shipped baseline exists; needs post-ship audit and hardening. |
| Settings | in audit | in audit | in audit | Smaller surface, but still needs design-system consistency pass. |

## Initial file-level hotspots

| File | Action | Reason |
| --- | --- | --- |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/gameroom/GameRoomScreen.swift` | needs split | Very large screen surface with mixed responsibilities. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/gameroom/GameRoomScreen.kt` | needs split | Android parity landed, but screen size indicates structural pressure. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/practice/PracticeGameSection.swift` | needs refactor | Large UI and behavior surface. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/practice/PracticeStore.kt` | needs refactor | Central state surface likely to accumulate mixed responsibilities. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/library/LibraryCatalogStore.swift` | in audit | Important cross-feature integration point. |
| `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/library/LibraryDataLoader.kt` | in audit | Important cross-feature integration point. |

## Next audit additions

Add rows as each feature is reviewed:
- screen files
- store/state files
- persistence files
- theme/component files
- duplicated helpers
