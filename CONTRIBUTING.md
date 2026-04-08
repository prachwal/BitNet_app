# Contributing

This repository is a fork of `microsoft/BitNet` with additional Docker, runtime, and publishing fixes.

## Branching

- Keep local changes on a feature branch.
- Keep a local `upstream` remote pointing at `microsoft/BitNet`.
- Use `git fetch upstream` followed by `git merge upstream/main` or `git rebase upstream/main` before opening a PR or pushing a release branch.

## Change Scope

- Prefer small, focused commits.
- Keep documentation changes in existing Markdown files unless a new file adds clear value.
- Update `README.md` when user-facing behavior changes.

## Validation

- Run `docker compose config` after Compose changes.
- Rebuild the image after Dockerfile or entrypoint changes.
- Update the changelog for user-visible changes.
