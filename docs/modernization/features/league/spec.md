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

## Current focus

- confirm destination contracts
- normalize shell/card patterns
- document exact copy and card order
- keep the feature shell compact while preview loading, rotating preview state, and card rendering live behind explicit seams
- make nested League destination ownership explicit on both platforms, including `About Lansing Pinball League`

## Structural baseline

- iOS League home now splits into:
  - `LeagueScreen.swift` for the root navigation shell
  - `LeagueShellContent.swift` for the responsive card stack/grid, destination links, and About footer
  - `LeaguePreviewLoader.swift` for preview data fetch and snapshot assembly
  - `LeaguePreviewParsing.swift` for CSV parsing and preview-shaping rules
  - `LeagueCardPreviews.swift` for the preview-card shell
  - `LeaguePreviewRotationState.swift` for timer-driven preview rotation state
  - `LeaguePreviewSections.swift` for `Targets`, `Standings`, and `Stats` preview bodies
  - `LeagueDestinationView.swift` for destination-specific nested route content
- Android League home now splits into:
  - `LeagueScreen.kt` for the root feature shell and preview-state loading
  - `LeagueShellContent.kt` for the responsive card stack/grid, destination links, and About footer
  - `LeaguePreviewLoader.kt` for preview data assembly
  - `LeaguePreviewParsing.kt` for CSV parsing and preview-shaping rules
  - `LeaguePreviewModels.kt` for preview view models
  - `LeaguePreviewCards.kt` for the preview-card shell
  - `LeagueMiniPreviews.kt` for `Targets`, `Standings`, and `Stats` preview bodies
  - `LeaguePreviewRotationState.kt` for rotating preview state
  - `LeagueDestinationHost.kt` for destination-specific nested route content
- Remaining follow-up should focus on exact contract parity and nested destination boundaries, not putting preview or shell composition back into one file.
