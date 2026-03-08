# League Ledger

## 2026-03-06

- Root About tab removal and nested League About flow are part of the shipped 3.1 baseline.

## 2026-03-07

- Android League home was split into a shell file plus explicit preview loader, preview model, and preview card files.
- The home screen still behaves the same, but preview loading and card rendering are no longer concentrated in `LeagueScreen.kt`.

## Next audit targets

- confirm exact card content parity
- verify nested destination behavior on both platforms
- review whether Android rotating preview timers belong in a dedicated state seam rather than the shell file
