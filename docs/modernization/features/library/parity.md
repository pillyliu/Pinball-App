# Library Parity

## Must match

- source ordering rules
- filtering behavior
- detail layout intent
- rulesheet fallback behavior
- playfield fallback behavior
- GameRoom overlay behavior
- v3 starter-pack resource naming contract

## Allowed native differences

- reader rendering details
- image viewer gesture feel
- back button material treatment

## Current parity baseline

- Both platforms now resolve local Library assets against the same v3-only names and should not reintroduce local slug-based rulesheet or game-info fallbacks.
- Both platforms now route imported-game and rulesheet/video resolution through dedicated catalog-resolution helper files rather than leaving that behavior embedded in the main loader/store file.
- Both platforms now route seed-db imported-source resolution through the same catalog-resolution seam rather than maintaining a second imported-game assembly path.
