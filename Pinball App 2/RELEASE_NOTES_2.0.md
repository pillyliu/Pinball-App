# Pinball App iOS 2.0 - Major Update Notes

This document summarizes the major iOS changes completed for version 2.0, with focus on:

- League mini-views
- Rulesheet progress behavior
- Practice tab structure and functionality

## 1) League Mini-Views (League Hub)

### Layout and presentation
- League mini-view cards are now the primary summary entry point into:
  - Stats
  - Standings
  - Targets
- Mini-views were tuned for tighter spacing and better fit on phone screens.
- iOS landscape behavior was updated so league mini-view cards render in two columns.
- Mini-view typography was increased for readability, with icon + title alignment tightened.
- Right-most numeric columns in mini tables were aligned for cleaner scanning.

### Stats mini-view behavior
- Stats mini-view shows most-recent bank context inline (season, bank, player).
- Stat values support alternating display behavior (score/points style transitions) for compact live context.
- Header and row alignment were updated to match Android parity where requested.

### Standings mini-view behavior
- Place header/abbreviation standardized (`#` where requested).
- Column spacing and alignment were tuned to better balance place/name/points.
- Podium coloring adjusted to improve first-place contrast.
- Bold styling constrained to top placements only (1st-3rd).

### Targets mini-view behavior
- Next-bank targeting logic now resolves to the lowest missing bank (not simply next sequential after last played).
- Target cycling behavior supports multiple benchmark bands (2nd/4th/8th style target tiers).
- Small-view truncation/compact handling improved for long game names.

## 2) Rulesheet Progress and Navigation

### Progress pill behavior
- Rulesheet progress is controlled by a pill-based percentage action.
- Tapping the pill saves the current scroll-based progress value.
- Unsaved progress state is visually indicated (pulse behavior), with saved state shown in solid success styling.

### Resume flow
- Resume logic was rebuilt to avoid prior scroll lock conditions.
- Resume prompt behavior is explicit and tied to saved progress state.
- The rulesheet renderer path was simplified to avoid repeated/looping scroll requests.

### Navigation behavior
- Rulesheet back navigation now returns to the correct origin game view context:
  - Library game view origin -> back to Library game view
  - Practice game view origin -> back to Practice game view
- Edge-back behavior was aligned with existing full-screen playfield interaction patterns.

## 3) Practice Tab - Full 2.0 Structure/Functionality

Practice is now organized as a full workflow instead of disconnected forms.

### Home
- Home includes:
  - Resume area (return to last relevant game)
  - Quick Entry shortcuts
  - Active Groups panel
- First-run onboarding uses an in-context overlay prompt for player name and feature guidance.

### Group Dashboard
- Group management supports create/edit/reorder and schedule dates.
- Group cards provide:
  - Completion summary
  - Priority indicators
  - Suggested next game focus
- Group editor now includes `Active` status controls before `Priority`.
- Inactive groups are excluded from the Practice Home "Active Groups" panel.

### Journal Timeline
- Timeline combines Practice events and Library activity events into one chronological feed.
- Filter selector supports All/Study/Practice/Scores/Notes/League slices.
- Journal rows only navigate on deliberate tap (no accidental open during scroll).
- Timeline log is constrained to a dedicated panel with internal scrolling behavior.

### Insights
- Insights include score summary and trend context:
  - Average
  - Median
  - Floor
  - IQR
  - Consistency framing
- Head-to-head comparison is integrated with refresh and scoped game-level deltas.
- Chart/table height behavior was adjusted to avoid clipping and preserve readability.

### Mechanics
- Mechanics is consolidated around skill-tagged logging and trend/history review.
- Skill naming/order was aligned to requested tutorial taxonomy.
- Mechanics history is panelized with internal scroll and trend sparkline.
- External tutorial link support added for quick reference.

### Game View (Practice)
- Practice game workspace remains segmented (Summary/Input/Log) with tightened behavior:
  - Summary includes score stats and target-score context
  - Input aligns with shared entry templates
  - Log supports constrained panel scrolling
- Rulesheet/playfield/video resources are directly linked in-game.

### Quick Entry
- Quick Entry mirrors the full entry forms while preserving fast input flow.
- Category-specific defaults and selected game memory behaviors were improved.
- Mechanics quick entry now supports "None" game selection default when appropriate.

### Settings and data controls
- Settings streamlined to remove non-functional placeholders.
- Reset flow now supports full Practice-state reset with explicit confirmation.
- League import flow remains integrated with player selection and import summary behavior.

## 4) Stability and Data Handling Improvements Included in 2.0

- Score log decoding made backward-compatible for older local state payloads.
- League CSV parsing hardened for header alias variations and row-width differences.
- Hidden one-off cleanup logic that could silently remove league-imported scores was removed.
- Deprecated iOS API usage (`UIScreen.main`) in Practice sizing paths was replaced with context-based sizing.

## 5) Intended 2.0 Outcome

Version 2.0 is intended to deliver:

- A stronger "Command Center" workflow through league mini-views.
- Reliable and intuitive rulesheet progress/resume behavior.
- A complete, cohesive Practice system (home -> groups -> game work -> journal -> insights -> mechanics -> settings) with fewer dead paths and less UI/data friction.
