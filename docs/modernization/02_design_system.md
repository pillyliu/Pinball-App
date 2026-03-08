# Design System

## Intent

Create one semantic design language with platform-native expression.

The system should support:
- iOS liquid-glass style presentation where appropriate
- modern Android Material expression where appropriate
- shared product identity across both platforms
- a future PinProf visual personality that feels intentional, not pasted on

## Token families

Define and maintain tokens for:
- color roles
- typography roles
- spacing scale
- corner radius scale
- stroke/border roles
- elevation/material roles
- icon sizing
- motion timing and easing

## Component families

Standardize these before large feature rewrites:
- app shell
- top bars and back buttons
- tab bar / navigation bar behavior
- cards and panels
- segmented controls
- list rows
- pills and badges
- text fields
- menus and pickers
- sheets and dialogs
- empty/loading/error states

## Platform adaptation rules

Shared across iOS and Android:
- IA
- naming
- behavior
- state transitions
- information hierarchy
- data semantics

Allowed to differ:
- material rendering
- shadows/elevation style
- control shape details
- gesture affordance style where native conventions differ

## Brand direction

PinProf should evolve toward:
- clear teaching/guide energy
- disciplined but playful pinball identity
- visual confidence, not novelty clutter

Signals from the mascot direction:
- scholarly but energetic
- bold title treatment
- high legibility
- a sense of instruction, strategy, and craft

Do not add mascot styling ad hoc. First establish the system that branding will sit on top of.

## Near-term outputs

1. semantic token inventory
2. shared component inventory
3. native adaptation notes for iOS and Android
4. branded visual direction references

## Current gap to close

- iOS already uses a light custom semantic layer in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppTheme.swift`.
- Android still leans heavily on Material color-scheme defaults in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/PinballTheme.kt`.
- The next design-system step is not a visual overhaul first. It is defining semantic roles that both files can implement consistently.

## 2026-03-07 baseline progress

- Android now has an explicit semantic token layer in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/PinballDesignTokens.kt`.
- `PinballTheme.kt` now provides semantic shell/panel/control/stat/target roles instead of exposing only raw Material scheme usage to the rest of the app.
- Android shell and shared UI now consume those semantic tokens in:
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/PinballShell.kt`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/MainActivity.kt`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt`
  - `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/SharedComponents.kt`
- Android spacing and shell-bar geometry are now part of the same semantic token layer instead of being repeated as raw `dp` constants across root shell and shared UI.
- Android typography roles are now part of the same token layer, and shared UI consumes them for section titles, empty states, filter headers, dropdowns, table cells, and shell labels.
- Android filter-sheet chrome is now standardized through `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppFilterSheet.kt`, which is used by Library, Stats, Standings, and Targets.
- iOS filter-toolbar triggers and dropdown menu labels are now standardized through `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`, which is used by Stats, Standings, and Targets.
- iOS now exposes semantic color, spacing, and shape token groups in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppTheme.swift` instead of only flat globals.
- iOS now exposes typography roles in the same theme file so dropdown and shell text sizing can stop drifting from ad hoc font choices.
- iOS root tabs in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/app/ContentView.swift` now use one metadata-driven tab contract instead of repeating screen/title/icon wiring inline.

## Next design-system steps

1. Move more shared component families onto semantic spacing, typography, and shape tokens instead of ad hoc local constants.
2. Normalize remaining top-bar, sheet, and dialog chrome across shared UI helpers on both platforms.
3. Start documenting motion roles before broader visual restyling.
