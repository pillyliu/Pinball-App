# PinProf Premiere Style Kit Build Recipe

This recipe turns the PinProf dark-mode language into reusable Premiere elements rather than one-off timeline tricks.

Generated kit output:

- `output/promo-style-kit-4k/assets/`
- `output/promo-style-kit-4k/previews/`
- `output/promo-style-kit-4k/style_kit_manifest.json`

Generator:

- `scripts/build_promo_style_kit.py`

Run it with the local Pillow-enabled venv:

```bash
source .codex-venv/bin/activate
python scripts/build_promo_style_kit.py
```

## Core Rule

Use the app as content and the style kit as chrome.

- The app footage itself should stay clean and readable.
- The Premiere elements should provide the atmosphere, pane, border, glow, and editorial hierarchy around the app.
- Do not add fake device hardware.

## Asset Set

Backgrounds:

- `background_plate_master_4k.png`
- `background_plate_league_4k.png`

Reusable pane bases:

- `full_app_pane_base_4k.png`
- `focus_crop_pane_base_4k.png`

Reusable label treatments:

- `feature_label_container_blank_4k.png`
- `feature_label_sample_read_rulesheet_4k.png`
- `focus_phrase_container_blank_4k.png`
- `focus_phrase_sample_view_standings_4k.png`

Title cards:

- `title_card_library_4k.png`
- `title_card_practice_4k.png`
- `title_card_gameroom_4k.png`
- `title_card_settings_4k.png`
- `title_card_league_4k.png`

End card:

- `end_card_4k.png`

Preview boards:

- `preview_full_app_layout_library_4k.png`
- `preview_focus_crop_layout_league_4k.png`
- `preview_style_kit_overview_4k.png`

## Premiere Use

### Full App View

Use when the point is browsing, discovery, or broader app context.

Stack:

1. `background_plate_master_4k.png`
2. presenter footage on the left
3. `full_app_pane_base_4k.png`
4. app footage masked to the `media_rect` from `style_kit_manifest.json`
5. optional feature label overlay

Current placement from the manifest:

- pane rect: `1900,420,3660,1740`
- app media rect: `2353,440,3207,1720`
- pane radius: `34`

The app media rect is intentionally narrower than the pane so the surrounding dark chrome can breathe.

### Focus Crop View

Use when the point is text, tables, standings, targets, or other dense information.

Stack:

1. `background_plate_league_4k.png` or `background_plate_master_4k.png`
2. presenter footage on the left
3. `focus_crop_pane_base_4k.png`
4. app crop masked to the `media_rect` from `style_kit_manifest.json`
5. phrase container below it
6. short phrase text centered over the container

Current placement from the manifest:

- pane rect: `1900,552,3660,1608`
- media rect: `1920,572,3640,1588`
- phrase rect: `2260,1656,3300,1788`
- pane radius: `30`

This is the shorter app view intended for the “2-3 word phrase under the crop” layout.

## Motion Defaults

Animate these in Premiere rather than baking motion into the stills.

- Pane or label fade in: `8-10` frames
- Pane settle: `103%` to `100%`
- Title card in/out crossfade: `8-12` frames
- Focus crop phrase fade in after the crop settles: `4-6` frames later

## Style Translation Notes

The app gives us the language:

- dark blue-charcoal atmosphere
- gold, chalk, and blue accents
- rounded continuous cards
- restrained borders
- calm, premium spacing

Premiere should exaggerate those properties slightly for legibility in 4K, but not drift into generic glossy ad graphics.
