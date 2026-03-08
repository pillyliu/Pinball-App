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

- iOS League remains a compact shell and navigation surface.
- Android League home now splits into:
  - `LeagueScreen.kt` for shell/layout/orchestrated rotating state
  - `LeaguePreviewLoader.kt` for preview data assembly
  - `LeaguePreviewModels.kt` for preview view models
  - `LeaguePreviewCards.kt` for card and mini-preview rendering
- Remaining Android follow-up should focus on state ownership and exact contract parity, not putting the preview rendering back into one file.
