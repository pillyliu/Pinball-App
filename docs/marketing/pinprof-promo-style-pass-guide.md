# PinProf Promo Style Pass Guide

Last updated: `2026-04-05`

This guide is the handoff for taking the current rough cut and layering in the approved visual assets.

Current state:

- Rough cut already exists in Premiere.
- It includes A-roll, app footage, and simple placeholder title cards.
- It does not yet include the style-kit assets, watermark, phone frames, intro logo system, or outro end card.

Primary reference docs:

- Timing master: [pinprof-promo-aroll-remapped-beat-map.md](/Users/pillyliu/Documents/Codex/Pinball%20App/docs/marketing/pinprof-promo-aroll-remapped-beat-map.md)
- Asset inventory: [pinprof-promo-asset-tracker.md](/Users/pillyliu/Documents/Codex/Pinball%20App/docs/marketing/pinprof-promo-asset-tracker.md)
- Style kit manifest: [style_kit_manifest.json](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/style_kit_manifest.json)
- Source selects: [pinprof-promo-primary-source-selects.md](/Users/pillyliu/Documents/Codex/Pinball%20App/docs/marketing/pinprof-promo-primary-source-selects.md)

## Goal

Build a first real style pass on top of the rough cut using the approved assets.

For this pass:

- keep the existing cut structure
- keep hard cuts unless an asset explicitly requires otherwise
- do not invent new graphics
- do not redesign layout on the fly
- focus on getting the approved visual language into the sequence

## Sequence To Build

Duplicate the current rough cut and work in a new sequence:

- Source rough cut: `PinProf Promo Rough Cut v2`
- New sequence name: `PinProf Promo Style Pass v1`

## Assets To Use

### Backgrounds

- Main background: [background_plate_master_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/background_plate_master_4k.png)
- League-accent background, optional: [background_plate_league_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/background_plate_league_4k.png)

### App Frame System

- Full-height phone frame overlay: [phone_frame_overlay_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/phone_frame_overlay_4k.png)
- Full-height phone frame matte: [phone_frame_window_matte_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/phone_frame_window_matte_4k.png)
- Focus-crop phone frame overlay: [phone_focus_frame_overlay_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/phone_focus_frame_overlay_4k.png)
- Focus-crop phone frame matte: [phone_focus_frame_window_matte_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/phone_focus_frame_window_matte_4k.png)

### Presenter / Logo

- Presenter feather matte: [presenter_feather_matte_left_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/presenter_feather_matte_left_4k.png)
- Intro logo glow: [intro_logo_glow_plate_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/intro_logo_glow_plate_4k.png)
- Intro logo frame overlay: [logo_square_frame_overlay_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/logo_square_frame_overlay_4k.png)
- Intro logo frame matte: [logo_square_frame_window_matte_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/logo_square_frame_window_matte_4k.png)
- Outro end card: [end_card_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/end_card_4k.png)
- Outro logo glow, optional if outro is rebuilt from layers: [outro_logo_glow_plate_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/outro_logo_glow_plate_4k.png)
- Outro logo frame overlay, optional: [outro_logo_square_frame_overlay_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/outro_logo_square_frame_overlay_4k.png)
- Outro logo frame matte, optional: [outro_logo_square_frame_window_matte_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/outro_logo_square_frame_window_matte_4k.png)
- Source logo art: `/Users/pillyliu/Library/CloudStorage/Dropbox/Pinball/PinProf Logo/PinProf Logo Upscaled.png`

### Watermark

- Soft watermark overlay: [watermark_logo_soft_overlay_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/watermark_logo_soft_overlay_4k.png)

### Title Cards

- Library: [title_card_library_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/title_card_library_4k.png)
- Practice: [title_card_practice_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/title_card_practice_4k.png)
- GameRoom: [title_card_gameroom_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/title_card_gameroom_4k.png)
- Settings: [title_card_settings_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/title_card_settings_4k.png)
- League: [title_card_league_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/title_card_league_4k.png)

## Suggested Track Layout

This is only a suggested stack. Equivalent organization is fine.

- `V1`: background plates
- `V2`: title cards and end card
- `V3`: A-roll video
- `V4`: presenter matte helper or logo glow helper
- `V5`: app footage
- `V6`: app mattes
- `V7`: app frame overlays
- `V8`: intro logo layers and other overlays
- `V9`: watermark
- `A1-A2`: A-roll audio only

All app-clip audio should stay muted.

## Build Order

### 1. Duplicate and protect the existing rough cut

- Duplicate `PinProf Promo Rough Cut v2`
- Rename the duplicate `PinProf Promo Style Pass v1`
- Do all styling in the duplicate

### 2. Import the style-kit assets

Import the assets listed above from:

- `/Users/pillyliu/Documents/Codex/Pinball App/output/promo-style-kit-4k/assets`

Also import the high-res original logo from Dropbox:

- `/Users/pillyliu/Library/CloudStorage/Dropbox/Pinball/PinProf Logo/PinProf Logo Upscaled.png`

### 3. Lay down the background first

- Put [background_plate_master_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/background_plate_master_4k.png) on `V1` under the full promo length
- If needed, use [background_plate_league_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/background_plate_league_4k.png) only under the League title card or League beat

Do not animate the background in this pass.

### 4. Replace the placeholder title cards

The rough cut already has 2-second title cards before the five app sections.

Replace those placeholder cards with:

- Library title card
- Practice title card
- GameRoom title card
- Settings title card
- League title card

Keep them at the same duration for now unless they obviously feel wrong.

### 5. Add the intro layout

Use the intro timing from the beat map:

- Intro section: `0.00-8.58`
- Logo hit happens around `7.06-7.68`

Build it like this:

- Keep the intro A-roll on `V3`
- If Peter footage does not naturally fill and blend well, apply [presenter_feather_matte_left_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/presenter_feather_matte_left_4k.png) as the matte for the A-roll
- Add [intro_logo_glow_plate_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/intro_logo_glow_plate_4k.png) on the right side starting shortly before `PinProf`
- Add the original logo art inside the rounded-square frame
- Use [logo_square_frame_window_matte_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/logo_square_frame_window_matte_4k.png) to clip the logo
- Add [logo_square_frame_overlay_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/logo_square_frame_overlay_4k.png) above it

For this pass, a simple appearance timed to `PinProf` is enough. Do not build the final spring animation yet unless it is trivial.

### 6. Apply the app frame system section by section

Use the app frame system everywhere the app is visible.

Default rule:

- use the full-height phone frame for most app beats
- use the focus-crop frame only when the readable crop is the point of the shot

Implementation pattern:

1. Put app footage on `V5`
2. Put the matching matte on `V6`
3. Apply Track Matte Key or Set Matte to the app clip so the footage is clipped by the matte
4. Put the matching frame overlay on `V7`

This should create:

- transparent screen window for the footage
- visible branded frame on top

### 7. Section-by-section app treatment

#### Library

Section range: `8.58-25.86`

Recommended treatment:

- `APP001-APP002`: full-height phone frame
- `APP003-APP008`: focus-crop phone frame

This is the section where the crop treatment actually matters, so let the rules and later proof beats live in the focus frame.

Do not build a 2-up layout for now.

#### Practice

Section range: `25.86-40.44`

Recommended treatment:

- use the full-height phone frame by default
- only switch to focus-crop if one of these beats is unreadable:
  - scan score recognition
  - practice notes

If readability is acceptable, keep the whole section in the full-height frame for simplicity.

#### GameRoom

Section range: `40.44-50.02`

Recommended treatment:

- keep the full-height phone frame throughout

#### Settings

Section range: `50.02-63.66`

Recommended treatment:

- keep the full-height phone frame throughout

#### League

Section range: `63.66-69.70`

Recommended treatment:

- keep the single League app shot in the full-height phone frame

### 8. Add the watermark

Use [watermark_logo_soft_overlay_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/watermark_logo_soft_overlay_4k.png) on the top overlay track.

Recommended watermark timing:

- start after the intro logo beat is finished
- keep it on through the app sections
- remove it before or at the start of the outro end-card treatment

Safe default:

- in: `8.58`
- out: `69.70`

That keeps it out of the intro reveal and out of the outro logo ending.

### 9. Add the outro end card

Use the outro timing from the beat map:

- Outro section: `69.70-80.35`
- Fade can begin around `79.57`

For this pass:

- keep the A-roll visible through the spoken outro
- hard cut or quick dissolve to [end_card_4k.png](/Users/pillyliu/Documents/Codex/Pinball%20App/output/promo-style-kit-4k/assets/end_card_4k.png) at the fade point
- hold the end card to the end of the sequence

Do not build the full reverse-pop animation yet unless it is very easy.

### 10. Final cleanup for this pass

- verify all app clips are muted
- verify no raw app footage is showing outside the phone frame
- verify watermark does not collide with the app frame
- verify title cards are the styled ones, not the placeholders
- save the sequence

## What Not To Do In This Pass

- no transition design pass
- no spring animation polish pass
- no label/callout system unless something is unreadable
- no 2-up Library experimentation
- no global color grading pass
- no extra graphics beyond the approved style-kit assets

## Expected Result

At the end of this pass, the sequence should have:

- real backgrounds
- real title cards
- framed app footage
- intro logo layout
- watermark
- outro end card

But it should still feel like a structured rough cut, not the final motion-design polish pass.
