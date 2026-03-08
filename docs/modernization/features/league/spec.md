# League Spec

## Status

- comparatively smaller feature surface
- still part of app-shell parity

## Scope summary

League includes:
- league home
- stats
- standings
- targets
- nested `About Lansing Pinball League`

## 3.2 focus

- confirm destination contracts
- normalize shell/card patterns
- document exact copy and card order
- keep the feature shell compact while preview loading, rotating preview state, and card rendering live behind explicit seams

## Structural baseline

- iOS League home now splits into:
  - `LeagueScreen.swift` for the root navigation shell
  - `LeagueShellContent.swift` for the responsive card stack/grid, destination links, and About footer
- Android League home now splits into:
  - `LeagueScreen.kt` for the root feature shell and preview-state loading
  - `LeagueShellContent.kt` for the responsive card stack/grid, destination links, and About footer
  - `LeaguePreviewLoader.kt` for preview data assembly
  - `LeaguePreviewModels.kt` for preview view models
  - `LeaguePreviewCards.kt` for card and mini-preview rendering
  - `LeaguePreviewRotationState.kt` for rotating preview state
- Remaining follow-up should focus on exact contract parity and nested destination boundaries, not putting preview or shell composition back into one file.
