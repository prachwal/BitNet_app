# Contributing

This repository is a fork of `microsoft/BitNet` with additional Docker, runtime, and publishing fixes.

## Branching

- Keep local changes on a feature branch.
- Rebase or merge from `upstream/main` before opening a PR or pushing a release branch.
- Use `scripts/sync-upstream.sh` to sync with upstream when the working tree is clean.

## Change Scope

- Prefer small, focused commits.
- Keep documentation changes in existing Markdown files unless a new file adds clear value.
- Update `README.md` when user-facing behavior changes.

## Validation

- Run `docker compose config` after Compose changes.
- Rebuild the image after Dockerfile or entrypoint changes.
- Update the changelog for user-visible changes.
