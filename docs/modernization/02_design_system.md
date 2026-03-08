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
- Android search-plus-filter header chrome is now standardized through `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppSearchFilterBar.kt`, with Library now using the same token-driven search field and filter trigger instead of keeping a feature-local top control row.
- Android practice menu dropdowns now route through the shared dropdown chrome in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/SharedComponents.kt`, with Practice wrappers reduced to thin adapters instead of owning their own menu styling.
- Android GameRoom manufacturer filtering now also routes through the same shared dropdown chrome in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/SharedComponents.kt`, using a shared grouped dropdown seam instead of a feature-local exposed text-field menu.
- Android stats-family refresh/status rows now route through `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt`, with Stats and Standings sharing one token-driven updated-at / refresh control instead of duplicating inline row chrome.
- Android Targets benchmark copy now also routes through `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt`, with the screen using a shared three-column legend header instead of owning separate portrait and landscape header-row markup inline.
- Android Settings manufacturer-bucket and venue-distance selectors now also route through the shared dropdown chrome in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/SharedComponents.kt`, with add/import flows moving off feature-local segmented selectors and onto the same card-plus-dropdown treatment used elsewhere.
- Android compact row-action chips now live in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt`, with Settings source rows using the shared refresh/delete chip treatment instead of local button styling.
- Android Settings home section headings now also use the shared `SectionTitle` seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt` instead of feature-local semibold text styling.
- Android Practice settings/profile surfaces now also use the shared `SectionTitle` seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt` instead of feature-local semibold section labels.
- Android Practice home, insights, mechanics, and group-dashboard section headings now also use the shared `SectionTitle` seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt` instead of feature-local semibold card headings.
- Android Library detail sections now also use the shared `SectionTitle` seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt`, with the remaining `Sources` block moved onto the same heading chrome as `Video References` and `Game Info`.
- Android centered back-button plus title rows now also use the shared `AppScreenHeader` seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt`, replacing feature-local header composition in Library detail, playfield/rulesheet screens, Settings add/import flows, and GameRoom machine/settings routes.
- Android inline error messaging in Stats, Standings, and Targets now also routes through `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/CommonUi.kt`, with those screens using one shared status-message seam instead of raw red `Text` blocks.
- Android fullscreen viewer loading and missing/error overlays now also route through `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/SharedFullscreenChrome.kt`, with Library playfield and rulesheet viewers using one shared centered overlay seam instead of local state blocks.
- iOS filter-toolbar triggers and dropdown menu labels are now standardized through `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`, which is used by Stats, Standings, and Targets.
- iOS toolbar icon triggers now share the same chrome in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`, with Library now using shared search and filter trigger labels instead of raw toolbar images.
- iOS compact dropdown menu labels now also share the same chrome in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`, with Practice dropdown pickers using one shared chevron-and-label control instead of per-screen copies.
- iOS compact text-plus-filter labels now also share the same chrome in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`, with GameRoom settings using a shared filter label instead of a feature-local text-plus-symbol menu label.
- iOS compact icon menu labels now also share the same chrome in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`, with GameRoom machine, area, import-match, and import-variant selectors using shared control styling instead of feature-local `Label` menu buttons.
- iOS stacked compact menu labels now also share the same chrome in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`, with Practice Home resume/source selectors using one shared title-plus-value control instead of a feature-local dropdown label implementation.
- iOS selectable menu rows now also share the same chrome in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`, with Library and Practice menus using one shared checked-row pattern instead of mixing `✓ ` string prefixes and feature-local `Label(..., checkmark)` branches.
- iOS Practice journal league-import selection now also uses shared compact dropdown chrome in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppFilterControls.swift` instead of keeping a feature-local chevron-and-text control.
- iOS Settings manufacturer-bucket and venue-distance selectors now also use shared compact menu chrome in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`, with the add/import flows moving off segmented pickers and onto the same compact dropdown and selectable-row patterns already used elsewhere.
- iOS compact row-action chips now also live in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`, with Settings source rows using the shared refresh/delete chip treatment instead of feature-local row-button styling.
- iOS Settings home section headings now also use the shared section-title seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/SharedTableUi.swift` instead of feature-local headline styling.
- iOS Practice settings/profile surfaces now also use the shared section-title seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/SharedTableUi.swift` instead of feature-local headline section labels.
- iOS Practice home, insights, mechanics, and group-dashboard section headings now also use the shared section-title seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/SharedTableUi.swift` instead of feature-local headline or semibold card headings.
- iOS Library detail card headings now also use the shared section-title seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/SharedTableUi.swift`, replacing feature-local headline titles in the `Video References`, `Game Info`, and `Sources` cards.
- iOS inline error messaging and table-empty placeholders in Stats, Standings, and Targets now also route through `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/SharedTableUi.swift`, replacing feature-local red footnotes and empty-row copy while also fixing first-load placeholder drift in Stats and Standings.
- iOS Library fullscreen viewer back-button chrome now also uses a shared seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/SharedFullscreenChrome.swift`, replacing duplicated floating back-button overlays in the playfield and rulesheet viewers.
- iOS Library fullscreen viewer loading and missing/error overlays now also use the shared seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/SharedFullscreenChrome.swift`, replacing feature-local status blocks in fullscreen playfield and rulesheet presentation.
- iOS editor-toolbar text actions now share the same chrome in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppToolbarActions.swift`, with Practice entry and editor flows using shared cancel / save / create / done actions instead of hand-rolled toolbar buttons.
- Android confirm-alert and date-picker chrome now has shared seams in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App Android/app/src/main/java/com/pillyliu/pinprofandroid/ui/AppDialogs.kt`, with Practice delete/date flows moved onto them.
- iOS sheet detent, drag-indicator, background, and keyboard-dismiss behavior now has a shared seam in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppPresentationChrome.swift`, with Practice and GameRoom sheet styles routing through it.
- iOS toolbar summary labels now have shared chrome in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`, with Stats, Standings, and Targets using the same summary-label treatment.
- iOS refresh/status rows now also use the same shared seam in `AppFilterControls.swift`, with Stats and Standings using one shared “updated / refresh” strip instead of duplicating it.
- iOS now exposes semantic color, spacing, and shape token groups in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/ui/AppTheme.swift` instead of only flat globals.
- iOS now exposes typography roles in the same theme file so dropdown and shell text sizing can stop drifting from ad hoc font choices.
- iOS root tabs in `/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/app/ContentView.swift` now use one metadata-driven tab contract instead of repeating screen/title/icon wiring inline.

## Next design-system steps

1. Move more shared component families onto semantic spacing, typography, and shape tokens instead of ad hoc local constants.
2. Normalize remaining top-bar, header, sheet, and dialog chrome across shared UI helpers on both platforms.
3. Start documenting motion roles before broader visual restyling.
