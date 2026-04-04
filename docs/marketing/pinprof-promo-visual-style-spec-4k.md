# PinProf Promo Visual Style Spec (4K)

This spec translates the shipped PinProf dark-mode appearance into a 4K video asset system for the promo edit.

Render target:

- `3840x2160`
- `16:9`
- Master export in UHD 4K

Design intent:

- Feel like PinProf dark mode expanded into a cinematic frame
- Keep the app footage inside the same visual language as the app chrome
- Avoid generic ad graphics, fake device frames, or bright glossy UI

## Source Style Cues

Primary style references in the app code:

- `Pinball App 2/Pinball App 2/ui/AppTheme.swift`
- `Pinball App 2/Pinball App 2/ui/AppSurfaceModifiers.swift`
- `Pinball App 2/Pinball App 2/app/AppIntroModels.swift`
- `Pinball App 2/Pinball App 2/app/AppIntroViewSupport.swift`
- `Pinball App 2/Pinball App 2/practice/PracticeEntryGlassStyle.swift`

Core visual takeaways:

- Dark atmosphere is blue-charcoal, not plain black
- Gold is the primary premium accent
- Chalky green is the secondary brand accent
- Blue is used for analytical and league-heavy moments
- Cards are rounded, dense, and lightly glassed
- Borders are thin and soft, not neon

## 4K Canvas

Use these working guides for all shots:

- Outer action safe margin: `160px`
- Inner text-safe margin: `220px`
- Baseline grid: `20px`

Default split-screen balance:

- Left presenter zone: `1360px` wide
- Right app zone: `1880px` wide
- Center gutter between presenter and app pane: `120px`

This leaves room for edge padding and prevents the layout from feeling cramped in 4K.

## Color System

Base palette derived from the app:

- Launch black: `#060609`
- Atmosphere top: `#121724`
- Atmosphere bottom: `#1A212E`
- Brand gold: `#FFD44A`
- Brand chalk: `#8AB8A8`
- Brand ink dark-mode text tint: `#D1E6FF`
- League blue: `#7DD3FC`
- High/success green: `#6EE7B7`
- Low/warning red: `#FCA5A5`
- Neutral line: `rgba(255,255,255,0.18)`

Video usage rules:

- Use launch black only at the deepest edges or fade-to-black moments
- Use the atmosphere colors for all main backgrounds
- Use gold for active emphasis, key titles, active pills, and end-card focus
- Use chalk for secondary text, soft glow, and scholarly tone
- Use blue only where the content is stats/league/data driven

## Background Plate

Every title card and most promo layouts should sit on a reusable 4K background plate.

Build:

1. Base fill: `#060609`
2. Large diagonal gradient from `#121724` at top-left to `#1A212E` at bottom-right
3. Gold radial glow in top-left:
   - size: `900px`
   - opacity: `14%`
4. Chalk-green radial glow in bottom-right:
   - size: `820px`
   - opacity: `10%`
5. Optional soft vignette:
   - black at `18%`

Texture:

- Add very subtle smoky noise or film grain at `3-5%`
- Keep it soft and clean; no gritty grunge overlays

## App Footage Frame

Do not place the app inside a fake phone frame.

Use a premium pane treatment:

- Frame size: `1760x1320`
- Corner radius: `34px`
- Fill behind footage: dark graphite at `#121417` around `88%`
- Border: `2px` soft white at `18%`
- Secondary inner edge glow: `1px` gold or section accent at `10-14%`
- Shadow:
  - y offset: `24px`
  - blur: `60px`
  - opacity: `22%`

Inset padding for footage inside frame:

- `20px` on all sides if using a container
- If masking footage directly, keep the mask flush and let the border sit outside the clip

Recommended split-screen app pane placement:

- X position: right aligned inside safe area
- Y position: vertically centered
- Default visible area anchor: center-right weighted, not hugging the edge

## Rounded Rectangle System

Use the same family of radii across all promo assets:

- Hero app pane: `34px`
- Section title card panel: `36px`
- Feature label pill container: `24px`
- Secondary stat/info chip: `20px`
- Micro pill: `999px` capsule

Rule:

- Never mix sharp rectangles with rounded system surfaces in the same shot
- All overlays should use continuous corners, not geometric hard-corner rounding

## Section Title Cards

Each section card should feel like the app intro overlay scaled up for video.

Card panel:

- Size: `2460x1180`
- Centered on screen
- Radius: `36px`
- Fill: near-black at `76-82%`
- Overlay wash: subtle top-left to bottom-right tint using the section accent at `10-16%`
- Border: `2px` white at `18%`
- Outer glow: section accent at `20-24%`, blur `70px`

Title typography:

- Font style: high-contrast editorial serif
- Preferred look: Didot/Bodoni-style
- Size: `152-176px`
- Tracking: `-1 to 0`
- Color: gold for most sections

Subtitle or descriptor:

- Font style: clean humanist or SF Pro Display/Semibold
- Size: `44-52px`
- Color: chalk or brand-ink tint
- Max width: `1800px`

Layout:

- Title baseline around vertical center
- Optional accent line or pill above title
- Keep lots of negative space

Section accents:

- `Library`: `#8FDBC7`
- `Practice`: `#FFDB66`
- `GameRoom`: `#F5C75C`
- `Settings`: `#B8E6C2`
- `League`: `#7DD3FC`

## Feature Labels

Feature labels should look like PinProf UI chrome, not broadcast lower thirds.

Container:

- Height: `112px`
- Horizontal padding: `40px`
- Corner radius: `24px`
- Fill: dark panel `#1A1F25` at `86%`
- Border: `2px` gold or section accent at `22%`
- Soft highlight wash from top-left at `8%`

Text:

- Font: SF Pro Display or close equivalent
- Weight: Semibold
- Size: `46px`
- Color: `#F3F6FB`

Optional accent bar:

- Width: `10px`
- Height: `52px`
- Radius: `999px`
- Color: gold or section accent

Default placement:

- Bottom-left of app pane, inset `48px`
- If it covers important UI, move to upper-left of pane with the same inset

Animation:

- Fade + rise `18px`
- Duration `8-10` frames at 24fps
- No bounce

## Presenter + App Split Screen

For presenter sections, use this layout:

- Presenter stays left of frame center
- App pane sits to the right
- Presenter should never overlap the app pane border

Recommended app pane placement in 4K:

- Pane width: `1760px`
- Pane height: `1320px`
- Right margin: `180px`
- Vertical center: `1080px`

Recommended presenter block:

- Keep face/torso inside left `1280px`
- Head top should stay below top text-safe line
- Shoulder line should not visually collide with app pane corners

## End Card

Use the same master background plate with less interface chrome.

Layout:

- Centered PinProf logo
- Logo max height: `820px`
- Optional soft gold underglow behind logo:
  - width: `1100px`
  - opacity: `12%`

Optional close:

- One short line under logo in SF Pro Semibold, `44px`, chalk color
- If used, keep it restrained

## Motion Rules

Motion should feel calm and premium.

Use:

- Crossfades
- Gentle position shifts
- Small scale settles from `103%` to `100%`
- Soft masked reveals
- Tasteful spring-eased hero moves with slight overshoot and quick settle

Avoid:

- Fast whip pans
- Big zoom punches
- Flash frames
- Glitch transitions
- Heavy motion blur gimmicks

Default timings:

- Section card in/out crossfade: `8-12` frames
- Feature label fade in: `8-10` frames
- App pane fade or slide: `10-14` frames
- End card fade to black: `18-24` frames

Guidance:

- Reserve spring motion for the logo reveal, the signature app crop transition, and a few hero moments.
- Keep label motion subtler than hero transitions.
- Do not use spring behavior on every move or the promo will feel busy.

## Asset Inventory

Build these reusable assets before final polish:

1. `4K master background plate`
2. `Library title card`
3. `Practice title card`
4. `GameRoom title card`
5. `Settings title card`
6. `League title card`
7. `4K app pane frame`
8. `Feature label template`
9. `End card background`
10. `End card logo treatment`

## Premiere Notes

For Premiere or any NLE:

- Build the app pane as a reusable mogrt or nested comp
- Build one feature label template with swap-able text and accent color
- Build section cards from one master comp with editable title, subtitle, and accent glow
- Keep all titles and labels vector or shape-based where possible so they stay crisp in 4K

## Practical Rule Of Thumb

If a graphic element would not plausibly belong inside PinProf dark mode, it should not appear in the promo.

The promo should feel like:

- PinProf dark mode
- plus larger spatial atmosphere
- plus cleaner editorial typography
- plus cinematic timing

Not like:

- a generic startup ad
- a glossy YouTube template
- or a fake iPhone commercial
