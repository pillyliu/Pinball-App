# PinProf Promo Micro-Capture Edit Spec

This spec replaces the "long live navigation capture" approach for the promo.

## Decision

- Capture on device, not simulator.
- Keep Peter's on-camera delivery feeling continuous and conversational across the promo.
- Capture only short proof clips.
- Do not record scrolling, back-navigation, loading waits, or setup steps unless the motion itself is the point.
- Rewrite the action list after the voiceover is recorded, using phrase-level timestamps instead of sentence-level guesses.

## Why This Is Better

- Device capture looks smoother than simulator capture.
- Continuous A-roll will feel more natural than a heavily stop-start presenter edit.
- Short clips let us start on the useful state instead of burning time getting there.
- Text-heavy moments will read better if we crop the app intentionally instead of always showing the whole phone screen.
- The promo will feel tighter if each spoken phrase maps to one clear proof moment.

## A-Roll Structure

Peter's delivery should play like one continuous conversation, even if the actual production uses separate takes between sections.

Working rule:

- let the presenter performance feel continuous
- use section title cards as the natural editorial reset between sections
- cut to app proof clips only when the spoken script calls for visual proof
- return to Peter cleanly after each proof beat

This means the edit should not feel like:

- intro clip
- hard stop
- Library clip
- hard stop
- Practice clip

It should feel like:

- Peter speaks naturally
- title card bridges the section change
- Peter continues
- app proof appears when needed
- Peter continues again

The title cards make those section seams feel intentional instead of choppy.

## Current Audio Source

There is already a recorded promo read in Dropbox:

- `/Users/pillyliu/Library/CloudStorage/Dropbox/Pinball/PinProf Promo Video/PinProf Intro Script.m4a`

Duration:

- about `146.02s`

Word-level and segment-level timing exports now exist in:

- `output/transcribe/pinprof_intro_script_verbose_whisper/PinProf Intro Script.verbose.json`
- `output/transcribe/pinprof_intro_script_verbose_whisper/PinProf Intro Script.words.csv`
- `output/transcribe/pinprof_intro_script_verbose_whisper/PinProf Intro Script.segments.csv`

## Timing Workflow

We should cut this promo against the spoken audio, not against the raw app clips.

1. Lock the spoken script version we are actually editing to.
2. Use the existing recorded audio or replace it with the final presenter take later.
3. Generate a word-level transcript with timestamps.
4. Group words into short proof phrases.
5. Assign one prepared app shot to each phrase.
6. Trim the shot to the phrase start/end, plus a small editorial handle.
7. Only use word-level cuts when one sentence contains multiple proof beats.

## Timing Rules

Edit master:

- `24 fps`

Default handles:

- Lead-in before phrase start: `4-6 frames`
- Hold after phrase end: `6-10 frames`

Use phrase timing, not sentence timing, for:

- feature labels
- app crop changes
- cut points between proof moments

Use word timing only when a sentence needs more than one visual proof beat, like:

- `six rescues`
- `right ramp`
- `watch a gameplay video`

## Timing Template Fields

Each timing row should track:

- `section`
- `sentence_id`
- `phrase_id`
- `phrase_text`
- `full_script_line`
- `word_start`
- `word_end`
- `phrase_duration`
- `view_mode`
- `source_crop`
- `source_prep_state`
- `clip_goal`
- `overlay_text`
- `notes`

The companion CSV template lives at:

- `docs/marketing/pinprof-promo-voiceover-phrase-map-template.csv`

## View Modes

We should use two footage treatments.

### 1. Full App Portrait

Use this when the viewer needs orientation or broader context:

- tab landing views
- game detail views
- dashboards
- filter results
- moments where the viewer should feel the whole app screen

Source options:

- Full device screen: `1206x2622`
- Intro-style crop: `1206x1809`

The intro crop is already established in the app intro assets and code:

- `Pinball App 2/Pinball App 2/SharedAppSupport/app-intro/library-screenshot.webp`
- `Pinball App 2/Pinball App 2/app/AppIntroModels.swift`

That crop is effectively `2:3`, which is why it feels cleaner than the full phone height.

Use the intro-style crop whenever:

- the status bar adds noise
- the tab bar is not important
- the interesting content lives in the middle of the screen

### 2. Focus Crop

Use this when the content is text-heavy or when we want the app to read like a card instead of a phone:

- rulesheet lines
- stats tables
- standings rows
- imported lists
- video tiles
- notes and logs

Default source crop:

- full screen width
- crop to about `1206x724`

That gives us a more horizontal proof frame without making the app feel alien.

If the content needs one more text line, expand slightly, but stay in this range:

- `1206x680` to `1206x780`

Layout rule:

- put the `2-3 word` phrase underneath the crop
- do not place the phrase beside the crop in this mode

This is the right treatment for the text-centric beats you called out, and it matches the idea of a vertically shorter app view instead of always showing the full phone height.

## 4K Layout Rules

### Full App Portrait

- Container style: rounded rectangle, PinProf dark chrome
- Default use: centered or right-weighted
- Radius: `34px`
- Use the full portrait only when the UI context matters

Recommended working display sizes in 4K:

- Full device screen mode: around `960x2088`
- Intro-style crop mode: around `1160x1740`

### Focus Crop

- Container style: rounded rectangle
- Radius: `30px`
- Default working display size in 4K: around `1800x1080`
- Phrase label sits below, centered, with generous breathing room

Spacing:

- Gap from crop bottom to phrase: `36-48px`

## Capture Rules

Every capture should begin from a prepared state.

That means:

- correct tab already open
- correct game already visible
- correct filter already chosen
- correct section already scrolled into place
- keyboard already open if typing is the proof

Each clip should prove one thing.

Good clip:

- tap `PinProf`
- show playfield
- hold on the sign

Bad clip:

- open Library
- scroll
- overscroll
- tap game
- wait for load
- tap playfield
- zoom
- try to frame the sign

If setup is required, prep it off-camera and start recording after prep.

Scrolling should be minimized, not fully banned.

Allowed scrolling moments:

- showing off the Library card layout
- showing stats tables
- showing standings tables

Even in those cases:

- keep the scroll short
- start near the useful region
- end as soon as the proof is readable

## Section Rewrite

These should be treated as prepared proof clips, not live walkthroughs.

### Library

- `Library landing` as a short context clip
- `Jurassic Park detail already open`
- `Rulesheet already at Extra Ball anchor`
- `Six rescues` line as its own readable proof beat
- `Right ramp` line as its own readable proof beat
- `Playfield already zoomed near the extra ball sign`
- `Gameplay tile already visible`

Do not capture:

- long list scroll to Jurassic Park
- back-outs between rulesheet and playfield
- long scroll to video references

### Practice

- `Resume Game` card already visible
- `Rulesheet Study logged` result
- `Playfield Review logged` result
- `Score scan freeze` result
- `Study group created` result
- `Medieval Madness note already visible`
- `Game log already visible`

Do not capture:

- long search setup
- full navigation into note/log views

### GameRoom

- `Pinside search result` already visible
- `Pokemon imported` result
- `Area / group / position` final organized state
- `Issue resolved` final state
- `Library filtered to Flynn's Arcade` result

Do not capture:

- full import form entry if the result proves it better
- repeated back navigation

### Settings

- `Venue imported` result
- `Tournament arena list imported` result
- `IFPA profile visible`

Do not capture:

- full settings traversal if the imported state already proves the line

### League

- `League dashboard` context
- `Stats filtered result`
- `Standings row` result
- `Targets for Bank 7` result

Do not capture:

- long filter drilling unless the filter choice itself is the point
- long standings scrolls

## Editorial Rule Of Thumb

If the viewer can understand the capability from the end state, show the end state.

Only show an interaction when it adds one of these:

- clarity
- delight
- proof

## Recommended Next Step

Next pass should be:

1. Treat the current recorded audio as the working timing master.
2. Fill in the phrase map CSV from the exported word timings.
3. Rewrite the shot list around continuous Peter A-roll plus title-card section breaks.
4. Capture only the prepared proof clips that the filled phrase map calls for.
5. Replace the working audio only if a later presenter take changes the spoken timing materially.
