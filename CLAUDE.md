# Conventions for agents

- Never change `main` directly. For every change: create a branch, make the change, open a PR, then merge the PR into `main`.
- This repo is a submodule of `game-studio` (`apps/{name}`). After every merge into `main`, update this repo's pin in `game-studio` (branch + PR there). See `game-studio/CLAUDE.md`.
- Never commit secrets (keystores, `key.properties`, service-account JSON, real AdMob IDs). See `game-factory/CLAUDE.md` for the full factory rules.
