# Parity Rules

## Definition

Parity means the two apps match in:
- screen structure
- navigation flow
- labels and copy
- interaction logic
- state behavior
- data handling
- edge-case handling

## Allowed differences

Allowed only when explicitly written:
- native material treatment
- native back behavior details
- native control rendering
- platform-specific accessibility affordances

Not allowed without written approval:
- missing actions
- different labels
- different sort/filter defaults
- different data persistence behavior
- different empty/loading/error behavior
- different route structure for the same feature intent

## Parity checklist rule

Every feature must have:
- a parity doc
- a checklist
- a ledger entry when drift exists

## Canonical source rule

For each feature, define one canonical behavior source.

Current default:
- use the written feature spec, not memory
- if needed, one platform may act as the temporary implementation reference
- GameRoom 3.1 remains the strongest example of a written parity contract

## Drift handling

If Android or iOS diverges:

1. stop
2. record drift in `ledger.md`
3. update `parity.md`
4. fix the drift against the written contract

## Completion language

Do not say:
- "close enough"
- "roughly matches"
- "same idea"

Use:
- `matches spec`
- `intentional native variation`
- `known drift recorded`
