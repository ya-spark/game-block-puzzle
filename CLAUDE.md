# Conventions for agents

- Branch/PR workflow is suspended for now: changes may be committed and pushed directly to `main`.
- This repo is a submodule of `game-studio` (`apps/{name}`). After every change to `main`, update this repo's pin in `game-studio`. See `game-studio/CLAUDE.md`.
- Never commit secrets (keystores, `key.properties`, service-account JSON, real AdMob IDs). See `game-factory/CLAUDE.md` for the full factory rules.
- `docs/SPEC.md` is the single source of truth for how the game behaves (rules, feel, layout, offsets, drag behaviour). When the owner gives a behaviour instruction, update `docs/SPEC.md` (the "Behaviour and feel" section, exact values) in the same commit as the code. There is no copy of the spec in game-factory.
