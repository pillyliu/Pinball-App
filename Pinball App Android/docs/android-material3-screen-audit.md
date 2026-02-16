# Android Material 3 Screen Audit

## Migration status

- Theme and app shell: in progress
- About: in progress
- Stats: in progress
- Standings: in progress
- Targets: in progress
- Library list: in progress
- Library detail/rulesheet/playfield: in progress

## Global foundation

Completed:
- Added a dedicated `PinballTheme` with Material 3 light and dark schemes.
- Enabled dynamic color on Android 12+ with fallback palettes.
- Switched app shell to theme-driven colors instead of hardcoded dark values.
- Removed tab bar gradient treatment and moved to Material navigation surfaces.
- Migrated shared screen/card helpers to Material surface and outline roles.
- Rebuilt shared dropdown controls to Material exposed dropdown text fields.

Next:
- Extract reusable semantic colors (for high/low stats and target tiers) into one UI token file.
- Add screenshot tests for light/dark per top-level tab.

## About screen

Completed:
- Converted text and button colors to Material token roles.
- Replaced custom dark button styling with filled tonal buttons.

Next:
- Convert source caption to supporting text style.
- Add large-screen spacing adjustments.

## Stats screen

Completed:
- Converted most hardcoded neutrals to Material color roles.
- Updated row striping to use theme surfaces.
- Updated refresh timestamp/icon tint to `onSurfaceVariant`.

Next:
- Move positive/negative/accent stat colors to centralized semantic tokens.
- Use stronger hierarchy for table header and selected filter states.
- Add empty/error states with Material icons.

## Standings screen

Completed:
- Converted neutral hardcoded colors to Material color roles.
- Updated alternating row surfaces and refresh metadata styling.

Next:
- Replace medal colors with theme-aware accents that preserve contrast in light mode.
- Improve selected season control prominence.

## Targets screen

Completed:
- Converted error/help text and row striping to Material theme roles.

Next:
- Unify target tier colors (2nd/4th/8th) with semantic token set.
- Improve filter affordance contrast in light mode.
- Increase readability of explanatory footer copy on small screens.

## Library list screen

Completed:
- Migrated search/filter controls and card colors away from hardcoded dark values.
- Updated card metadata text to theme-based contrast colors.

Next:
- Replace custom dropdown button with shared exposed dropdown control.
- Reduce shadow usage and align elevation with Material tonal elevation.
- Add clear active filter chips for sort/bank state.

## Library detail / rulesheet / playfield

Completed:
- Migrated most card/chrome colors to Material theme roles.
- Updated video tile surface/border states to theme roles.

Next:
- Rename/remove glass-specific components and apply Material top app bar/back patterns.
- Make markdown WebView CSS light/dark aware instead of forcing white text.
- Evaluate fullscreen playfield chrome behavior for edge-to-edge and accessibility.

## QA checklist

- Verify all tabs in both light and dark mode.
- Verify Android 12+ dynamic color and pre-12 fallback palettes.
- Validate text contrast on search fields, table headers, metadata text, and links.
- Validate dropdown menu width, anchor behavior, and touch targets.
- Verify system bar icon contrast with edge-to-edge.
