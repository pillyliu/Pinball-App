# Practice Ledger

## 2026-03-06

- Marked as a priority modernization target due to size and drift risk.

## 2026-03-07

- Category: `Doc-only`
- Established the first real Practice audit baseline.
- Recorded that Practice is currently a feature family with at least 11 route surfaces, not one screen.
- Recorded that iOS route and modal state remains heavily centralized in `PracticeScreen.swift`.
- Recorded that Android route structure is cleaner at the screen layer, but `PracticeStore.kt` is still a large responsibility center.
- Set Practice as the first feature-level modernization audit target.
- Wrote the first route-by-route Practice contract for Home, Game, Rulesheet, Playfield, IFPA Profile, Group Dashboard, Group Editor, Journal, Insights, Mechanics, and Settings.
- Recorded the current structural divergence: iOS uses a mixed route-plus-sheet model while Android models most primary surfaces as explicit routes.
- Wrote the first Game-route section contract: image preview, segmented workspace panel, game note, then resources.
- Recorded that `Summary`, `Input`, and `Log` are already functionally close across platforms, but component boundaries and ownership are still inconsistent.
- Recorded the current state-ownership split:
  - iOS root screen owns too much ephemeral route/UI state
  - Android screen-state layer is cleaner, but `PracticeStore.kt` still owns too much runtime/domain state
- Identified the first refactor seam as state ownership normalization before visual redesign.

## Next audit targets

- exact route-to-screen contract
- top-bar behavior per route
- game workspace state dependencies and component boundaries
- state ownership split between screen, route model, and store
- repeated resource/video/rulesheet UI patterns
