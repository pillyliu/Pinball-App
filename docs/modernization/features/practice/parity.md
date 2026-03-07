# Practice Parity

## Must match

- route structure
- top bar behavior
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
- iOS currently delivers some of these surfaces through sheets/boolean destinations rather than one explicit route enum.
- Android currently models most of them as explicit routes.
- That implementation difference is acceptable only temporarily; the product-surface contract must still match.

## High-risk parity areas

- selected game persistence and resume behavior
- quick-entry launch behavior from home vs game view
- journal filter behavior and mixed library/app activity timeline rules
- rulesheet/playfield/video launch behavior from game detail
- Game route section order and subview composition
- Game-switcher behavior and library-source filtering from the Game route
- group editing flows and date editor behavior
- top-bar actions and back behavior by route
- sheet-vs-route presentation drift for settings and group editor

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

## Known risk

Practice is large enough that parity may drift through small changes unless every behavior change is written first.

## Allowed native differences

- native sheet/dialog presentation
- native date/time picker presentation
