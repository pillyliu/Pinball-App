# PinProf Promo Codex Brief

This brief captures the current promo direction as of `2026-04-04`.

When this brief conflicts with the older long-form promo docs, prefer this brief. The existing storyboard, sequence maps, and capture notes are still useful as source material, but they reflect an earlier, denser cut.

## Goal

Refine the PinProf promo into a shorter, clearer, more polished branded piece that:

- feels modern and premium
- shows fewer things more clearly
- uses motion intentionally instead of constantly
- makes app text easier to read
- stays emotionally warm without over-explaining

## Runtime Target

- Current long read: about `2:25`
- Preferred target: about `1:30`

Working rule:

- if a beat does not materially improve clarity, emotion, or credibility, cut it

## Core Creative Principles

1. Less is more.
2. Readability beats completeness.
3. Motion should feel modern, restrained, and premium.
4. Branding should feel integrated, not pasted on.
5. Build reusable systems, not one-off tricks.
6. Leave breathing room between ideas.
7. Use the signature crop transition sparingly so it keeps its impact.

## Visual System

### App Container

Show app footage inside a neutral branded rounded rectangle:

- phone-like proportions
- not a literal iPhone mockup
- rounded corners consistent with PinProf UI
- optional subtle border and shadow

Treat it as a reusable masked container:

- app video underneath
- rounded-rectangle mask defines the visible region
- optional frame stroke/glow above
- frame and footage grouped so they can animate together

### Two Main App Views

Use two default treatments:

1. Full portrait view
   Use when orientation and overall app context matter.

2. Focus crop view
   Use when text or a specific UI region needs emphasis.

The focus crop is not just a zoom. It is a shorter visible window that becomes more square and more readable.

### Signature Transition

Signature transition definition:

> A branded rounded-rectangle app container transforms from a tall full-screen phone-like view into a shorter cropped detail view while the app video keeps playing, scales up, and repositions to emphasize a chosen UI area, all with smooth spring-eased motion.

Animate these together:

- frame height shrinking from top and bottom
- frame moving to its new position
- app video scaling up
- app video repositioning inside the mask so the chosen UI region stays centered

Use this only for the strongest readability moments.

## Motion System

Motion should feel iOS-adjacent:

- smooth
- light inertia
- small overshoot
- quick settle
- never cartoony

Default motion guidance:

- favor eased transforms over hard linear moves
- allow slight overshoot on hero transitions, logo reveals, and select labels
- keep label motion subtler than logo or hero app transitions

Good candidates for spring treatment:

- the intro logo reveal
- the signature app crop transition
- occasional feature callout entrances

Avoid:

- constant bouncing
- repeated punch-zooms
- using the same showy move on every shot

## Logo And Branding

### Intro Logo Beat

During the line `This is PinProf`:

- Peter starts centered
- during `this is`, he shifts toward the left rule-of-thirds line
- on `Pin`, the logo begins emerging on the right rule-of-thirds line
- by `Prof`, the logo reaches full presence with a small overshoot and settle

Shorthand:

> Peter slides from center to the left third while the PinProf logo springs into the right third from a tiny point and settles into place.

### Watermark Treatment

Keep a small PinProf logo visible for much of the promo, likely bottom-right.

The watermark should feel blended, not sticker-like:

- rounded-rectangle container
- center stays crisp
- edges feather softly into transparency
- video should show through near the perimeter

Think in terms of a feathered rounded-rectangle alpha mask or soft matte.

### Fade In / Fade Out

Prefer:

- fade in from a branded gradient background
- fade out to that same branded gradient

Avoid defaulting to plain black unless the gradient version fails visually.

## Editorial Direction

The promo should no longer try to cover everything.

Working editorial rules:

- show fewer features
- give each important moment more time
- use app proof clips only where the narration needs proof
- do not fill every second with app footage
- preserve short visual pauses where the viewer can absorb what was just shown

Likely structure:

- strong intro beat
- only the most compelling proof moments
- concise emotional close

## Crop Transition Usage Rule

Use the signature crop transition only when one of these is true:

- the text is too small in full portrait view
- a specific region needs emphasis
- the shot gains real clarity from becoming shorter and larger

Default candidates for the crop treatment:

- Library rulesheet detail
- playfield detail callout
- score scan confirmation
- notes or log detail
- League stats or standings detail

If the full app view already reads cleanly, keep it simple.

## Script Direction

The script should be aggressively tightened.

Priorities:

- remove redundancy
- stop explaining every capability
- keep only standout value
- stay warm and conversational
- end sooner than feels necessary, not later

Current preferred outro direction:

> Over the past year and a half, the pinball community has given me so much. PinProf is my way of giving back. Give it a flip, thanks.

## Immediate Next Steps

1. Lock a `~90s` voiceover script before deep motion work.
2. Reduce the feature list to the few beats that most clearly sell PinProf.
3. Build one reusable rounded-rectangle masked app container.
4. Build one version of the tall-to-focus crop transition and test it on a text-heavy app shot.
5. Build the `This is PinProf` talking-head plus logo intro beat.
6. Build the soft-edge watermark treatment.
7. Use the older storyboard and capture docs only as a source library for candidate clips, not as the final pacing plan.

## Suggested Doc Roles

- `docs/marketing/pinprof-promo-video-production-board.md`
  Treat as the old long-form shot inventory.
- `docs/marketing/pinprof-intro-video-script.md`
  Treat as the old script baseline to cut down from.
- `docs/marketing/pinprof-promo-micro-capture-edit-spec.md`
  Keep using for clip-prep and phrase-level editorial timing.
- `docs/marketing/pinprof-promo-visual-style-spec-4k.md`
  Keep using for palette, background plate, and container styling, but update motion assumptions to match this brief.
