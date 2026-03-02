# Android OPDB v3 Adaptation

## Current iOS data contract

- `pinball_library_v3.json`
  - curated built-in sources
  - local override metadata
  - existing local tutorial/video rows
- `opdb_catalog_v1.json`
  - authenticated OPDB machine/manufacturer catalog
  - Match Play tutorial links
  - external rulesheet links
- Imported source state
  - persisted locally
  - manufacturers and Pinball Map venues are saved as source records
- Source preference state
  - enabled source ids
  - pinned source ids
  - selected source id
  - selected sort/bank by source

## iOS behavior implemented

- Settings is a new fifth tab.
- Settings -> Library supports:
  - Add Manufacturer
  - Add Venue
  - enable/disable imported sources
  - pin/unpin sources for the Library filter
  - venue refresh
  - imported source removal
- Library and Practice reload when source state changes.
- Built-in RLM/Avenue rows are enriched with:
  - OPDB primary backglass/translite image
  - OPDB playfield fallback when curated playfield is absent
  - external rulesheet fallback when curated rulesheet is absent
  - Match Play tutorial fallback when curated videos are absent
- Imported manufacturer and venue rows are built from OPDB catalog rows and local curated overrides.

## Android parity work still needed

- Add `SETTINGS` tab to root navigation.
- Port imported source persistence:
  - `PinballImportedSourceRecord`
  - source state store
- Port merged loader logic:
  - load `pinball_library_v3.json`
  - load `opdb_catalog_v1.json`
  - enrich built-in games with OPDB/Match Play fallback
  - generate imported manufacturer rows
  - generate imported venue rows
- Port Pinball Map client:
  - closest-by-address search
  - location machine details fetch
- Port Settings screens:
  - Library management list
  - Add Manufacturer list
  - Add Venue search/import flow
- Update Android Library filter to use pinned sources first.
- Update Android Practice source dropdowns to use enabled imported sources.

## Shared follow-up

- Move imported source persistence from UserDefaults/shared prefs into SQLite on both platforms.
- Bundle a normalized SQLite seed once the iOS schema is finalized.
- Publish a shared manifest from `pillyliu.com` for snapshot version checking and background refresh.

## Shared UI notes

- Library cards keep a fixed card size across all sources.
- Card art should:
  - fill the full card width
  - start at the top edge of the card
  - preserve image aspect ratio
  - crop the bottom when the fitted-width image is taller than the card
  - end naturally when the fitted-width image is shorter than the card
- Library card text sits directly over the image, not below it.
- Use a darker transparent bottom scrim plus text shadow for readability instead of material blur.
- Any screenshot or resource-button behavior change in the Library game view must also be mirrored in the Practice game view.
