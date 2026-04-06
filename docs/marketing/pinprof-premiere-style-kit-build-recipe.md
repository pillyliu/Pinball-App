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
- Preferred full-height app chrome is now a neutral phone-like frame with a transparent center.
- It should read like a branded vessel, not a literal iPhone bezel mockup.
- The older filled pane assets are still useful for focus-crop or alternate layouts, but they are no longer the default full-height treatment.

## Asset Set

Backgrounds:

- `background_plate_master_4k.png`
- `background_plate_league_4k.png`

Reusable pane bases:

- `full_app_pane_base_4k.png`
- `focus_crop_pane_base_4k.png`

Preferred phone-frame assets:

- `phone_frame_overlay_4k.png`
- `phone_frame_window_matte_4k.png`
- `phone_focus_frame_overlay_4k.png`
- `phone_focus_frame_window_matte_4k.png`

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
- `outro_logo_glow_plate_4k.png`
- `outro_logo_square_frame_overlay_4k.png`

Watermark:

- `watermark_logo_soft_overlay_4k.png`

Preview boards:

- `preview_phone_frame_layout_library_4k.png`
- `preview_phone_focus_frame_layout_library_4k.png`
- `preview_intro_logo_reveal_4k.png`
- `preview_outro_logo_endcard_4k.png`
- `preview_watermark_logo_4k.png`
- `preview_full_app_layout_library_4k.png`
- `preview_focus_crop_layout_league_4k.png`
- `preview_style_kit_overview_4k.png`

## Premiere Use

### Preferred Full Portrait View

Use when the point is a normal full-height app shot that should still feel device-adjacent.

Stack:

1. `background_plate_master_4k.png`
2. presenter footage on the left
3. app footage, sized to the `media_rect` for `phone_frame_view` from `style_kit_manifest.json`
4. `phone_frame_overlay_4k.png` above the app footage
5. optional helper label if needed

If you need the app footage clipped by a still matte:

1. use `phone_frame_window_matte_4k.png` as the matte source
2. or crop/mask directly to the same `media_rect`

Current placement from the manifest:

- frame rect: `2706,74,3660,2086`
- app media rect: `2732,100,3634,2060`
- frame radius: `120`
- media radius: `96`

This is the current preferred full-height treatment.

### Preferred Focus Crop View

Use when the point is readability and the crop should keep the full captured app width while trimming height only.

Current crop rule:

- source width stays at the full capture width
- source crop becomes `1320 x 1980`
- aspect ratio is `3:2` in height:width terms

Stack:

1. `background_plate_master_4k.png`
2. presenter footage on the left
3. cropped app footage, sized to the `media_rect` for `phone_focus_frame_view`
4. `phone_focus_frame_overlay_4k.png` above the app footage
5. optional helper text below or beside it if needed

Current placement from the manifest:

- frame rect: `2706,377,3660,1782`
- app media rect: `2732,403,3634,1756`
- frame radius: `120`
- media radius: `96`

This is the current preferred cropped-detail treatment because it preserves full app width and only removes top/bottom content.

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
