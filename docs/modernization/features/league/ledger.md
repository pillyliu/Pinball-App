# League Ledger

## 2026-03-06

- Root About tab removal and nested League About flow are part of the shipped 3.1 baseline.

## 2026-03-07

- Android League home was split into a shell file plus explicit preview loader, preview model, and preview card files.
- The home screen still behaves the same, but preview loading and card rendering are no longer concentrated in `LeagueScreen.kt`.
- Android rotating preview timers and display-toggle state now live in `LeaguePreviewRotationState.kt` instead of staying inline in `LeagueScreen.kt`.
- iOS League home now splits into a small root navigation shell in `LeagueScreen.swift` plus `LeagueShellContent.swift` for the responsive card layout, destination links, and About footer.
- Android League home now also splits the responsive card layout, destination links, and About footer into `LeagueShellContent.kt`, leaving `LeagueScreen.kt` focused on shell orchestration and preview-state loading.
- iOS League preview loading/parsing/shaping now lives behind `LeaguePreviewLoader.swift` and `LeaguePreviewParsing.swift`, leaving `LeaguePreviewModel.swift` as a thin published-state facade.
- Android League preview loading now mirrors that shape more closely: `LeaguePreviewLoader.kt` focuses on fetch/snapshot assembly, while `LeaguePreviewParsing.kt` owns CSV parsing and preview-shaping rules.
- iOS League preview-card shell and timer-driven state stay in `LeagueCardPreviews.swift`, while the `Targets`, `Standings`, and `Stats` preview bodies now live in `LeaguePreviewSections.swift`.
- Android League now mirrors that rendering split more closely: `LeaguePreviewCards.kt` owns the preview-card shell, while `LeagueMiniPreviews.kt` owns the `Targets`, `Standings`, and `Stats` preview bodies.
- iOS League timer-driven preview rotation state now lives in `LeaguePreviewRotationState.swift`, bringing that ownership seam in line with Android’s existing `LeaguePreviewRotationState.kt`.
- League nested route ownership is now explicit on both platforms: iOS routes through `LeagueDestinationView.swift`, Android routes through `LeagueDestinationHost.kt`, and `About Lansing Pinball League` is now part of the same League destination contract instead of a hidden special case on iOS.

## Next audit targets

- confirm exact card content parity
- verify nested destination behavior on both platforms
- review whether destination contracts and nested route ownership should move into a dedicated shell/router seam next
