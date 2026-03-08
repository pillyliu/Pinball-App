# Practice Parity

## Must match

- route structure
- top bar behavior
- state ownership contract
- game/resource behavior
- group lifecycle behavior
- journal editing behavior
- insights logic and terminology

## Current route contract to verify

Practice routes that must exist and be documented on both platforms:
- `Home`
- `Game`
- `Rulesheet`
- `Playfield`
- `IfpaProfile`
- `GroupDashboard`
- `GroupEditor`
- `Journal`
- `Insights`
- `Mechanics`
- `Settings`

Implementation note:
- iOS now uses explicit `PracticeRoute` and `PracticeSheet` enums for the main pushed and modal surfaces.
- Android models the same primary surfaces as explicit routes.
- `GroupEditor`, `Rulesheet`, and `Playfield` are now normalized as pushed routes on both platforms; remaining route-vs-sheet differences should be limited to true modal editors.

## High-risk parity areas

- selected game persistence and resume behavior
- quick-entry launch behavior from home vs game view
- journal filter behavior and mixed library/app activity timeline rules
- rulesheet/playfield/video launch behavior from game detail
- Game route section order and subview composition
- Game-switcher behavior and library-source filtering from the Game route
- group editing flows and date editor behavior
- top-bar actions and back behavior by route
- remaining route-vs-local-drill-in drift for settings and any future Practice sub-surface additions

## Game route contract

For the selected game workspace, both platforms must match in:
- subview set: `Summary`, `Input`, `Log`
- summary content blocks
- input shortcut set and meaning
- log editing/deletion capabilities
- note save behavior
- resource fallback behavior
- video launch-panel behavior

Allowed temporary differences:
- where the game-switcher control sits in the top chrome
- exact card boundaries and inner headings

## Ownership parity target

Both platforms should converge on the same conceptual state split:
- route state
- dialog/presentation state
- route-local draft state
- persisted domain/store state

Implementation note:
- file names and UI framework primitives may differ
- ownership categories should not differ
- if a behavior exists in one category on iOS and another on Android, that is modernization debt and should be written in `ledger.md`

## Known risk

Practice is large enough that parity may drift through small changes unless every behavior change is written first.

## Allowed native differences

- native sheet/dialog presentation
- native date/time picker presentation
