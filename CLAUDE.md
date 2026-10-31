# Conventions for agents

- Branch/PR workflow is suspended for now: changes may be committed and pushed directly to `main`.
- This repo is a submodule of `game-studio` (`apps/{name}`). After every change to `main`, update this repo's pin in `game-studio`. See `game-studio/CLAUDE.md`.
- Never commit secrets (keystores, `key.properties`, service-account JSON, real AdMob IDs). See `game-factory/CLAUDE.md` for the full factory rules.
