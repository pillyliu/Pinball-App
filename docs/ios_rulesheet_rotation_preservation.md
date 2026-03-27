# iOS Rulesheet Rotation Preservation

## Summary

This document explains the iOS rulesheet rotation bug in the `WKWebView`-based rulesheet reader, the debugging process used to isolate it, and the final restore strategy that made portrait/landscape rotation preserve the reader's position reliably.

The fix applies to the iOS rulesheet web renderer in:

- `Pinball App 2/Pinball App 2/library/RulesheetScreen.swift`

Android was not part of this work. Android rotation behavior was already acceptable.

## User-Facing Problem

Long rulesheets, especially `Avengers: Infinity Quest`, would jump to the wrong place when rotating between portrait and landscape.

Observed failure patterns included:

- Mid-document headings like `Reality Gem`, `Power Gem`, and `Battle Thanos` jumping to later unrelated content in landscape.
- Near-end headings like `Trophy Mania` and `FAQ` jumping even more severely, often close to the end of the document.
- Some earlier attempts would seem to "fix themselves" only after the user started scrolling.
- Quick back-and-forth rotation could produce bounce behavior where the view briefly went to the right place and then the wrong place.

## Why This Was Hard

Safari does not have this issue because Safari owns the full browser viewport, scroll anchoring, and relayout pipeline.

In the app we are embedding a `WKWebView` inside a SwiftUI/UIKit hierarchy and trying to preserve reading position from outside WebKit. That means:

- SwiftUI updates view geometry.
- UIKit updates the `WKWebView`.
- WebKit performs its own relayout and scroll remapping.
- The rulesheet HTML itself reflows substantially between portrait and landscape.

`WKWebView` has no public API that says "keep this exact semantic reading position under rotation."

## What The Debugging Proved

Extensive instrumentation was added to the iOS rulesheet web renderer to log:

- native view size
- scroll view size
- native content height
- native content offset
- DOM viewport width/height
- DOM content height
- DOM scroll position
- the DOM block/text under a fixed reading line below the top chrome

The key findings were:

### 1. Default `WKWebView` behavior preserves or remaps raw scroll position, not reading position

In many mid-document cases, `scrollY` stayed numerically the same after rotation, but the document became much shorter in landscape. The same raw offset then mapped to later semantic content.

Example pattern:

- portrait anchor was on `Reality Gem`
- landscape kept the same raw scroll offset
- the visible content became `Right ramp`

### 2. Near the end of long rulesheets, WebKit can clamp to the new max scroll

Late-document sections such as `Trophy Mania` and `FAQ` showed a second failure mode:

- landscape relayout reduced the maximum scroll range
- WebKit remapped/clamped to the new max scroll
- the view landed near the bottom, often in FAQ content

This is why late-document rotation felt worse than mid-document rotation.

### 3. Some early "rotation events" were fake

Initial attempts tied rotation detection to SwiftUI `updateUIView`, which produced many intermediate size-change events that were not the real `WKWebView` relayout. These fake events made capture and restore timing unreliable.

The breakthrough was moving rotation detection to the actual `WKWebView.layoutSubviews()` path, which let the restore logic observe the real landscape/portrait relayout instead of SwiftUI bookkeeping churn.

### 4. Capturing at rotation start was too late

Even when using text-based anchors, capturing at "rotation start" often sampled content after WebKit had already started transitioning. That produced bad anchors such as `Left ramp` while the user was still visibly on `Reality Gem`.

The final approach uses the last stable pre-rotation anchor captured during normal reading, not a fresh capture during rotation.

## Failed / Rejected Approaches

### Default WebKit rotation only

This was the starting point and was not reliable for long, highly reflowing rulesheets.

### Percentage-based restore

Restoring by overall document percentage worked near the top of long documents but drifted badly later in the rulesheet.

### Native reader prototype

A native renderer was prototyped to avoid `WKWebView`, but it regressed too much of the existing formatting fidelity:

- indentation
- linked subheadings
- mixed markdown/HTML structure
- image behavior

Tables improved, but the overall fidelity tradeoff was not acceptable for the current product.

### Text marker inserted into DOM

A temporary inline marker/bookmark idea had previously caused word-wrapping flicker because it contributed to layout. That approach was rejected.

### Rotation-start recapture

Re-capturing the anchor during the rotation event proved too late and often captured the wrong text or mixed-layout state.

### Content-width cap

Reducing reflow with a tighter content width was considered but explicitly rejected. The goal was to restore the right semantic position, not reduce layout flexibility.

## Final Strategy

The final fix keeps the web renderer and overrides WebKit's wrong landing after rotation.

High-level flow:

1. During normal reading, continuously capture a stable viewport anchor.
2. When rotation begins, freeze the last stable anchor and the last stable coherent layout snapshot.
3. Wait for the actual `WKWebView` relayout to complete in the new orientation.
4. Let WebKit land wherever it wants first.
5. Restore the frozen anchor into the new layout.
6. Ignore stale restore attempts from earlier generations.

## Final Anchor Model

The restore system supports two anchor forms:

- text anchor
- block anchor fallback

### Text anchor

Primary path.

The code captures an exact text position near the reading line using DOM caret/range APIs and stores:

- text node path
- character offset
- nearby text context
- related block anchor

This acts as a virtual bookmark without inserting any DOM element that would affect layout.

### Block anchor

Fallback path.

If a text anchor cannot be resolved safely, the system falls back to a block-level anchor using the nearest visible semantic element and an offset within it.

This fallback turned out to be especially useful on the reverse rotation after the primary restore had already landed near the correct block.

## Final Implementation Details

The implementation lives in the web-view coordinator inside `RulesheetScreen.swift`.

### A. Stable pre-rotation anchor capture

During ordinary scrolling and settled states, the coordinator captures:

- `lastViewportAnchorJSON`
- `lastStableViewportLayoutSnapshot`

Only coherent native/DOM snapshots are promoted to the stable layout baseline. Coherence means native and DOM geometry agree closely enough to represent a real layout state.

### B. Rotation detection on `WKWebView.layoutSubviews()`

This was the critical change.

The web view is now subclassed so `layoutSubviews()` can notify the coordinator when the actual web view geometry changes. This replaced the less reliable trigger from SwiftUI `updateUIView`.

### C. Freeze instead of recapture

On rotation:

- the most recent stable anchor is frozen into `frozenViewportAnchorJSON`
- the most recent stable layout snapshot is frozen into `viewportRestoreBaselineLayoutSnapshot`

No fresh anchor capture is attempted during rotation.

### D. Settled-layout restore

After rotation:

- the coordinator samples the current native+DOM layout
- verifies the layout meaningfully changed from the frozen baseline
- waits until the new layout stops changing enough to be considered settled
- then applies the restore

### E. Generation guard

Each rotation event increments a generation counter. Restore work is only allowed to complete for the latest generation. This prevents fast back-and-forth rotations from replaying stale restore attempts.

## What Success Looks Like In Logs

For a successful rotation, logs typically show:

1. rotation starts on the correct heading
2. sample 1 lands in the wrong place after WebKit relayout
3. `restore-attempt`
4. `restore-succeeded`
5. sample 2 or sample 3 returns to the original heading

This is expected. The final solution does not stop WebKit from landing wrong. It allows that landing and then corrects it.

## Verified Scenarios

The fix was validated in simulator and then spot-checked on device with long Avengers sections including:

- `Reality Gem`
- `Battle Thanos`
- `Extra Balls`
- `Trophy Mania`

These cover:

- mid-document heading restore
- late-document restore
- near-end clamping/remap behavior
- reverse rotation back to portrait

The late-document `Trophy Mania` case was particularly important because it historically demonstrated the worst remap/clamp behavior.

## Known Unrelated Console Noise

The following console messages appeared during testing but were not part of the rotation bug:

- `WEBP ... failed err=-50`
- `nw_connection_copy_connected_local_endpoint...`
- `WebProcess::updateFreezerStatus`
- `Error acquiring assertion`
- `Failed to terminate process`
- `Tracking element window has a non-placeholder input view`

### WEBP warnings

The Avengers rulesheet layout section references remote Stern-hosted `.webp` playfield images. WebKit appears to log failed decode attempts for some internal representation path even when the image still displays successfully. This is unrelated to rotation restoration.

## Future Cleanup

The temporary named debug channels used during this investigation are no longer present in the current codebase.

The restore behavior itself should remain, and any future rotation debugging can be added back in a more targeted form if regressions return.

## Practical Takeaway

The fix worked only after treating rotation as a semantic restore problem rather than a raw scroll-position problem.

The final solution depends on three ideas:

- capture a stable anchor before rotation, not during it
- detect the real WebKit relayout, not just SwiftUI geometry noise
- let WebKit land wrong, then restore the correct reading position
