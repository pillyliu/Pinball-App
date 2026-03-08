# GameRoom Spec

## Status

- Baseline shipped in `3.1`
- Source documents still apply

## Canonical references

- `/Users/pillyliu/Documents/Codex/Pinball App/GameRoom_3.1_Master_Plan.md`
- `/Users/pillyliu/Documents/Codex/Pinball App/GameRoom_3.1_Parity_Journal.md`
- `/Users/pillyliu/Documents/Codex/Pinball App/GameRoom_3.1_Android_Parity_Kickoff.md`

## Scope summary

GameRoom is the personal machine-ownership feature for:
- owned machine instances
- machine settings and setup
- archive/history
- maintenance/service logging
- issue logging
- media attachments
- library overlay integration
- Pinside import

## 3.2 focus

- audit 3.1 for structural cleanup
- split oversized screens and helper clusters
- keep product behavior stable unless explicitly changed here
- harden parity expectations against future drift

## Structural baseline

- iOS GameRoom is still a large feature surface, but the home/collection surface now lives outside the main screen file.
- iOS GameRoom settings/import/edit/archive surface now lives in `GameRoomSettingsComponents.swift` instead of staying inline in `GameRoomScreen.swift`.
- Android GameRoom is still a large feature surface, but reusable cards, pills, dropdowns, snapshot helpers, and shared formatting helpers now live outside the main screen file.
- iOS machine-detail route body now lives in `GameRoomMachineView.swift` instead of staying inline in `GameRoomScreen.swift`.
- Android machine-detail route body now lives in `GameRoomMachineRoute.kt` instead of staying inline in `GameRoomScreen.kt`.
- Next cleanup should continue by responsibility cluster:
  - settings import/edit/archive on Android
  - root state and presentation cleanup
  - event/media flows
