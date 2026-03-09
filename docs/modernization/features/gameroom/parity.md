# GameRoom Parity

## Current baseline

`3.1` is the baseline parity contract for GameRoom.

## Must match

- root tab name: `GameRoom`
- settings segments
- machine view segments
- collection selection behavior
- archive behavior
- import review behavior
- library integration behavior
- variant badge behavior
- status/attention semantics

## Allowed native differences

- liquid-glass rendering on iOS
- Material rendering on Android
- platform-native back gesture behavior
- media picker presentation style

## Drift rule

Any GameRoom drift found during 3.2 must be logged in `ledger.md` and either:
- fixed to match the written contract
- or approved here as an intentional difference
