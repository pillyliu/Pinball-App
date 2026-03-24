# Android Intro Overlay Parity Spec

## Purpose

This document captures the current iOS intro overlay feature and the hidden Settings double-tap shortcut exactly as implemented and refined in this thread, so Android can reproduce it with 1:1 behavioral and visual parity.

This spec covers:

- the startup intro overlay
- the six intro cards and their assets
- typography, color, spacing, and image treatment
- the `Start Exploring` dismissal behavior
- first-run and next-launch gating
- the hidden Settings double-tap shortcut on the PinProf logo
- the success popup shown after toggling that shortcut

## Current iOS Source Of Truth

- `Pinball App 2/Pinball App 2/app/AppIntroOverlay.swift`
- `Pinball App 2/Pinball App 2/app/ContentView.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsHomeSections.swift`
- `Pinball App 2/Pinball App 2/settings/SettingsScreen.swift`
- `Pinball App 2/Pinball App 2/ui/AppTheme.swift`
- `Pinball App 2/Pinball App 2/ui/AppFilterControls.swift`

## Final Design Decisions From This Thread

- The intro overlay is modeled after the iOS shake danger overlays: theatrical dark backdrop, green atmospheric tint, framed image box, and a premium presentation feel.
- The welcome card uses the main PinProf logo as the hero image.
- The welcome card does not show an icon, title, subtitle, upper-left app label, feature bullets, or professor spotlight. It shows only the logo art and the quote.
- Cards 2-6 are named after the app tabs: `League`, `Library`, `Practice`, `GameRoom`, `Settings`.
- A `League` card was added, bringing the deck to six cards total.
- The screenshots were externally cropped before import so the status bar and Dynamic Island area are already removed.
- Screenshot cards show the full cropped screenshot inside a taller framed art box. The image is fit to the box without extra feature labels or footer text.
- There are no `Skip`, `Back`, or `Next` buttons. Swiping is the primary navigation affordance, with page indicators at the bottom.
- The only action button is `Start Exploring`, and it appears only on the last page.
- Tapping `Start Exploring` fades the overlay out.
- The title and subtitle use a distinguished app-matching font treatment, separate from the Baskerville-style quote.
- The title is currently `26` portrait and `24` landscape.
- There is slightly increased vertical spacing between title and subtitle, but still intentionally tight.
- The quote styling for the welcome card highlights `PinProf` so that `Pin` uses the quote color and `Prof` uses the brand gold from the logo.
- The circular professor headshot appears next to the quote on cards 2-6 only.
- The headshot alternates sides, always facing toward the quote text:
- `League`: left side, mirrored
- `Library`: right side, original
- `Practice`: left side, mirrored
- `GameRoom`: right side, original
- `Settings`: left side, mirrored
- The overlay should respect system display scaling. Do not implement a bypass for Display Zoom on iOS or any Android equivalent for display size or font scaling.

## Runtime Behavior

### Launch Rules

The intro overlay is shown when either of the following is true:

- the app has never shown the current intro version before
- the hidden Settings shortcut has armed the intro for the next cold launch

Current iOS values:

- `AppIntroOverlay.currentVersion = 1`
- `app-intro-seen-version`
- `app-intro-show-on-next-launch`

Current launch calculation:

- At app init, iOS reads both keys from `UserDefaults`.
- `shouldShowIntro = appIntroShowOnNextLaunch || appIntroSeenVersion < AppIntroOverlay.currentVersion`
- That value is snapshotted into launch-local state.
- Toggling the Settings shortcut while the app is already open does not show the overlay immediately. It only affects the next app load.

### Dismiss Rules

When `Start Exploring` is tapped:

- `withAnimation(.easeOut(duration: 0.26))` wraps the dismiss
- the overlay view uses `.transition(.opacity)`
- the dismiss closure sets:
- `isIntroVisible = false`
- `appIntroSeenVersion = AppIntroOverlay.currentVersion`
- `appIntroShowOnNextLaunch = false`

Android parity recommendation:

- use a launch-time snapshot of the gate, not a reactive always-live one
- fade out the overlay over about `260ms`
- clear the next-launch override when the overlay is dismissed

## Card Content

### Card 1: Welcome

- Title: none
- Subtitle: none
- Quote: `Welcome to PinProf, a pinball study app. Go from pinball novice to pinball wizard in no time!`
- Highlighted phrase: `PinProf`
- Art asset: `LaunchLogo`
- Artwork ratio: `1.0`
- Professor spotlight: none

### Card 2: League

- Title: `League`
- Subtitle: `Lansing Pinball League stats`
- Quote: `Among peers, statistics reveal true standing.`
- Art asset: `IntroLeagueScreenshot`
- Artwork ratio: `1206 / 1809`
- Professor spotlight: left side, mirrored
- Accent color: `AppTheme.statsMeanMedian`

### Card 3: Library

- Title: `Library`
- Subtitle: `Rulesheets, playfields, tutorials`
- Quote: `Attend closely; mastery follows diligence.`
- Art asset: `IntroStudyScreenshot`
- Artwork ratio: `1206 / 1809`
- Professor spotlight: right side, original
- Accent color: custom mint green

### Card 4: Practice

- Title: `Practice`
- Subtitle: `Track practice, trends, progress`
- Quote: `A careful record reveals true progress.`
- Art asset: `IntroAssessmentScreenshot`
- Artwork ratio: `1206 / 1809`
- Professor spotlight: left side, mirrored
- Accent color: warm gold

### Card 5: GameRoom

- Title: `GameRoom`
- Subtitle: `Organize machines and upkeep`
- Quote: `Order and care are marks of excellence.`
- Art asset: `IntroCollectionScreenshot`
- Artwork ratio: `1206 / 1809`
- Professor spotlight: right side, original
- Accent color: amber gold

### Card 6: Settings

- Title: `Settings`
- Subtitle: `Sources, venues, tournaments, data`
- Quote: `A well-curated library reflects discernment.`
- Art asset: `IntroCurationScreenshot`
- Artwork ratio: `1206 / 1809`
- Professor spotlight: left side, mirrored
- Accent color: pale green

## Asset Inventory

### Hero And Character Assets

- `LaunchLogo`
- `IntroProfessorHeadshot`

### Screenshot Assets

- `IntroLeagueScreenshot`
- `IntroStudyScreenshot`
- `IntroAssessmentScreenshot`
- `IntroCollectionScreenshot`
- `IntroCurationScreenshot`

### Current Asset Sizes

- `LaunchLogo@3x.png`: `2046 x 2046`
- `IntroProfessorHeadshot.png`: `512 x 512`
- each intro screenshot: `1206 x 1809`

### Source Notes

- The screenshot assets were manually cropped before import to remove the top phone chrome.
- The professor headshot originated as `PinProf Headshot.webp`, then was converted into the app asset catalog as PNG.
- The welcome card uses the main logo art and fills the entire rounded image box edge to edge.

## Visual Spec

### Backdrop

The backdrop is a layered full-screen composition:

- base black scrim: `Color.black.opacity(0.64)`
- green-tinted linear gradient:
- start: `AppIntroTheme.tint.opacity(0.82)`
- end: `Color.black.opacity(0.94)`
- top-left radial glow:
- color: `AppIntroTheme.glow.opacity(0.18)`
- bottom-right gold radial glow:
- color: `AppTheme.brandGold.opacity(0.14)`

Current intro-specific colors:

- `AppIntroTheme.tint = #1F5742`
- `AppIntroTheme.glow = #A3E0BD`
- `AppIntroTheme.text = white at 96%`
- `AppIntroTheme.secondaryText = white at 84%`

### Card Container

The main card uses:

- corner radius: `28`
- portrait layout: vertical stack
- landscape layout: horizontal split
- background fill: `Color.black.opacity(0.76)`
- inner gradient overlay:
- `AppIntroTheme.tint.opacity(0.30)`
- `AppTheme.atmosphereBottom.opacity(0.12)`
- `AppTheme.brandGold.opacity(0.11)`
- border stroke: `Color.white.opacity(0.18)` at `1.1`
- shadow: `AppIntroTheme.tint.opacity(0.32)`, radius `24`, y `12`

The overlay surface was intentionally made less transparent than earlier drafts.

### Artwork Box

The hero artwork box uses:

- corner radius: `24`
- base fill: `AppTheme.atmosphereBottom.opacity(0.99)`
- inner gradient overlay:
- `AppIntroTheme.tint.opacity(0.26)`
- `Color.black.opacity(0.14)`
- `AppTheme.brandGold.opacity(0.10)`
- accent border: `card.accent.opacity(0.72)` at `1.15`
- shadow: `AppIntroTheme.tint.opacity(0.22)`, radius `16`, y `8`

### Screenshot Treatment

Each screenshot card uses:

- full imported image, already cropped externally
- `scaledToFit`
- full-height fit inside the art box
- no extra badges, captions, footer copy, or logo overlays
- radial accent glow behind the screenshot:
- `accent.opacity(0.18)` to clear
- screenshot shadow: `accent.opacity(0.16)`, radius `16`, y `8`

### Professor Headshot Treatment

Cards 2-6 use a circular spotlight treatment next to the quote:

- outer glow circle: `82 x 82`
- inner circle: `72 x 72`
- image frame: `80 x 80`
- headshot clipped to circle
- y offset: `-2`
- mirrored when the headshot is on the left so the face points inward
- original orientation on the right so the face points inward

Spotlight glow colors:

- `AppIntroTheme.glow.opacity(0.34)`
- `AppIntroTheme.tint.opacity(0.20)`
- clear

The welcome card does not show this spotlight at all.

### Page Indicators

- position: bottom overlay area
- count: `6`
- spacing: `8`
- selected pill: width `34`, height `8`, color `AppTheme.brandGold`
- unselected pill: width `18`, height `8`, color `white @ 18%`
- animation: `easeInOut(duration: 0.18)`

### Bottom CTA

- only visible on the last page
- text: `Start Exploring`
- uses the shared `AppPrimaryActionButtonStyle`
- positioned below the page indicators
- the button is intentionally lower on screen to avoid crowding the last card

### Primary CTA Style

The `Start Exploring` button uses the shared gold primary action style:

- shape: rounded rectangle with `AppRadii.control = 10`
- text font: `.subheadline.weight(.semibold)`
- text color: `AppTheme.brandOnGold`
- horizontal padding: `12`
- vertical padding: `10`
- fill: `AppTheme.brandGold.opacity(0.94)` when enabled
- pressed overlay: `AppTheme.brandInk.opacity(0.24)`
- stroke: `AppTheme.brandGold.opacity(0.48)` when enabled

Android parity recommendation:

- do not swap this for a generic Material filled button
- match the warm gold fill and darker pressed overlay
- preserve the rounded rectangle shape and dense sizing

## Typography

### Title Font

Current size:

- portrait: `26`
- landscape: `24`

Current fallback stack:

- `Didot-Bold`
- `BodoniSvtyTwoITCTT-Bold`
- `AvenirNextCondensed-Heavy`
- fallback: system rounded bold

Color:

- `AppTheme.brandGold`

Spacing:

- title/subtitle stack spacing: `2`
- extra title bottom padding: `2`

### Subtitle Font

Current size:

- portrait: `17`
- landscape: `16`

Current fallback stack:

- `Optima-Regular`
- `GillSans-SemiBold`
- `AvenirNext-DemiBold`
- fallback: system rounded semibold

Color:

- `AppTheme.brandChalk`

### Quote Font

Welcome card quote size:

- `22`

Other card quote size:

- `19`

Current fallback stack:

- `Baskerville-SemiBoldItalic`
- `Baskerville-Italic`
- `TimesNewRomanPS-ItalicMT`
- fallback: system serif semibold italic

Highlighted quote fallback stack:

- `Baskerville-BoldItalic`
- `Baskerville-SemiBoldItalic`
- `TimesNewRomanPS-BoldItalicMT`
- fallback: system serif bold italic

Quote formatting details:

- curly quotes are included in the rendered string
- line spacing: `2`
- center aligned in portrait
- left aligned in landscape

Welcome quote special styling:

- `Pin` uses the highlighted quote font and normal quote color
- `Prof` uses the highlighted quote font and `AppTheme.brandGold`

### Android Font Recommendation

For true 1:1 parity, do not rely only on platform defaults. Bundle actual Android font files that mimic the current iOS feel:

- a Didot/Bodoni-style display serif for titles
- a humanist sans in the Optima/GillSans range for subtitles
- a Baskerville italic and bold italic pair for quotes

If licensing blocks exact matches, choose the closest bundled alternatives and keep the role split intact:

- title: premium high-contrast serif
- subtitle: refined humanist sans
- quote: literary italic serif

## Layout Rules

### Portrait

- outer horizontal padding: `22`
- outer vertical padding: `20`
- max card width: `460`
- card content layout: image first, copy second
- card internal horizontal padding: `18`
- card internal vertical padding: `18`
- spacing between artwork and copy: `12`

### Landscape

- outer horizontal padding: `28`
- outer vertical padding: `18`
- max card width: `960`
- card artwork width: `322`
- card content layout: side-by-side
- horizontal spacing between art and copy: `18`
- card internal horizontal padding: `20`
- card internal vertical padding: `20`

### Scroll Behavior

Each page is wrapped in a vertical `ScrollView`, even though the main navigation is horizontal paging.

This is intentional and must be preserved on Android:

- it allows content to remain reachable on smaller screens
- it protects the layout under zoomed or scaled display settings
- it avoids clipping on devices with tighter effective height

Special centering rule:

- the welcome page is vertically centered in its page
- all other pages are top-aligned

## Theme Tokens Used By The Overlay

Shared app theme values used directly:

- `AppTheme.brandGold`
- `AppTheme.brandOnGold`
- `AppTheme.brandChalk`
- `AppTheme.brandInk`
- `AppTheme.atmosphereBottom`
- `AppTheme.statsMeanMedian`

Important current iOS light-mode hex approximations:

- `AppTheme.brandGold`: `#DEB029`
- `AppTheme.brandChalk`: `#5E8778`
- `AppTheme.brandInk`: `#0D1C3B`
- `AppTheme.atmosphereBottom`: `#E6EDFA`
- `AppTheme.statsMeanMedian`: `#1763C7`

Important current iOS dark-mode hex approximations:

- `AppTheme.brandGold`: `#FFD44A`
- `AppTheme.brandChalk`: `#8AB8A8`
- `AppTheme.brandInk`: `#D1E5FF`
- `AppTheme.atmosphereBottom`: `#1A212E`
- `AppTheme.statsMeanMedian`: `#7DD3FC`

## Hidden Settings Double-Tap Shortcut

### Behavior

The Settings About section contains the centered `LaunchLogo` image. Double tapping this logo toggles whether the intro overlay should show on the next app launch.

Current iOS behavior:

- host screen: `Settings`
- panel: `About`
- target view: `Image("LaunchLogo")`
- gesture: double tap only
- action: toggle `app-intro-show-on-next-launch`
- immediate result: show a success banner at the top of Settings

### Current Toggle Messages

- enabled: `Intro enabled for next launch`
- disabled: `Intro disabled for next launch`

### About Panel Host Styling

The hidden gesture lives inside the Settings `About` panel, which uses the shared `appPanelStyle`:

- panel padding: `12`
- panel corner radius: `12`
- background: `.regularMaterial`
- diagonal chalk wash overlay: `AppTheme.brandChalk.opacity(0.06)` to clear
- border: `AppTheme.brandChalk.opacity(0.26)` at `1`

Logo treatment inside the panel:

- asset: `LaunchLogo`
- sizing: `scaledToFit`, width `150`
- alignment: centered
- gesture target enlarged using `contentShape(Rectangle())`
- trigger: double tap only

### Persistence

- key: `app-intro-show-on-next-launch`
- stored in `@AppStorage` on iOS

### Important Parity Rule

This shortcut only arms or disarms the intro for the next app load. It does not pop the intro overlay immediately inside the active app session.

## Success Popup Spec

The success popup is not a full modal. It is the shared top banner style already used elsewhere in the app for save/success feedback.

Current iOS component:

- `AppSuccessBanner`

Current styling:

- shape: capsule
- foreground base color: `AppTheme.statsHigh`
- text font: `.footnote.weight(.semibold)` when not compact
- icon: `checkmark.circle.fill`
- horizontal padding: `12`
- vertical padding: `9`
- non-prominent background opacity: `0.26`
- non-prominent stroke opacity: `0.42`

Settings usage specifics:

- alignment: top overlay
- top padding: `4`
- enter/exit transition: `move(edge: .top)` combined with `opacity`
- animation: `easeInOut(duration: 0.25)`
- auto-dismiss delay: `1.2 seconds`

Android parity recommendation:

- use a top-aligned success banner, not a snackbar anchored at bottom
- keep the checkmark icon
- keep the green success color family
- auto-hide after about `1200ms`
- animate with top slide + fade

## Android Implementation Notes

### Recommended Compose Structure

- full-screen `Box` for the overlay root
- layered gradient backdrop in the root
- `HorizontalPager` for the six intro pages
- each page contains a vertical `Column` wrapped in a `verticalScroll`
- portrait page layout: image above copy
- landscape page layout: row with fixed-width image column and flexible copy column
- last page only: primary CTA under indicators

### State And Persistence

Recommended Android state keys:

- `app_intro_seen_version`
- `app_intro_show_on_next_launch`

Recommended behavior:

- compute `shouldShowIntroThisLaunch` once at cold launch
- do not re-evaluate live during the same process after the Settings double-tap
- on dismiss:
- set `app_intro_seen_version = CURRENT_VERSION`
- set `app_intro_show_on_next_launch = false`

### Settings Double Tap On Android

Recommended implementation:

- place the logo inside the Android Settings `About` card
- use a double-tap gesture handler on the logo only
- on double tap:
- toggle `app_intro_show_on_next_launch`
- show the top success banner

If using Jetpack Compose:

- use `combinedClickable` with `onDoubleClick`

### Overlay Stacking

Current iOS root overlay order in `ContentView` is:

- shake warning overlay first
- intro overlay second

That means the intro overlay visually sits above the shake overlay if both are active.

### Accessibility And Scaling

Do not try to bypass Android display size or font scale.

Parity goal:

- preserve the same graceful behavior as iOS under display scaling
- allow vertical scrolling on each page
- keep content reachable rather than forcing a hard fixed viewport

### Asset Handling On Android

- keep the welcome logo square
- keep the five screenshots at the tall cropped aspect ratio
- keep the professor headshot square and clip it circular in UI
- mirror the bitmap only when the headshot is on the left side

### Animation Notes

- dismiss: fade out around `260ms`
- indicator change: subtle `180ms` ease
- success banner: top slide + fade, around `250ms`

## Parity Acceptance Checklist

- six-card deck matches the current iOS order and copy exactly
- welcome card has no title, subtitle, icon, or professor spotlight
- screenshot cards use the imported tall crops and no extra footer text
- title font role, subtitle font role, and quote font role remain distinct
- `Prof` in the welcome quote is gold
- professor headshot side and mirroring match iOS exactly
- there are no `Skip`, `Back`, or `Next` buttons
- page indicators match count, width treatment, and selected gold styling
- `Start Exploring` appears only on the last page
- overlay fades out on dismiss
- overlay shows on first run
- hidden Settings logo double tap toggles intro for next launch only
- success banner appears at the top with the correct enable/disable message
- Android respects display scaling and font scaling rather than bypassing them

## Suggested Android File Targets

These are recommendations, not current Android source of truth:

- a dedicated intro overlay composable near the Android app root
- root startup gating where the main shell decides whether to overlay intro
- Settings `About` section composable for the hidden double-tap target
- shared success banner component reused from existing Android save/success feedback if available

## Status

This document reflects the current iOS implementation and the latest design decisions from this thread as of `2026-03-24`.
