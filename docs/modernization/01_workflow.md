# Workflow

## Mandatory sequence

Every substantial change follows this order:

1. Update `spec.md`.
2. Update `parity.md`.
3. Update `checklist.md` if acceptance changes.
4. Implement canonical behavior.
5. Port the other platform against the written contract.
6. Record outcome, drift, bugs, and follow-ups in `ledger.md`.
7. Verify against the checklist.

## Canonical implementation rule

- Use written docs as the source of truth.
- Do not rely on earlier chat context for labels, order, behavior, or exceptions.
- If implementation reveals a missing detail, add it to docs before continuing.

## Task unit size

Preferred unit of work:
- one feature area
- one screen
- or one cross-platform component family

Avoid:
- app-wide unfocused "cleanup"
- broad parity work with no checklist

## Change categories

- `Doc-only`
- `Refactor`
- `Selective rewrite`
- `Parity port`
- `Design-system change`
- `Branding change`
- `Bug fix`

Record the category in the feature ledger for each meaningful work session.

## Before starting Android parity

Confirm all of the following:
- the screen flow is written
- section order is written
- copy is written
- interactive states are written
- empty/loading/error states are written
- allowed platform differences are written

## Before marking complete

Confirm all of the following:
- both platforms compile
- checklist reviewed on both platforms
- known drift is recorded explicitly
- deferred work is recorded explicitly
- naming and copy match the spec

## Commit guidance

- Keep commits scoped to one coherent unit when practical.
- Prefer commits that map to docs updates plus implementation for one target behavior.
- Avoid mixing unrelated web/app/docs work in a single commit.
