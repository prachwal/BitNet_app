#!/usr/bin/env bash
set -euo pipefail

mode="${1:-rebase}"
upstream_ref="${UPSTREAM_REF:-upstream/main}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Run this script from inside a git repository." >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree must be clean before syncing with upstream." >&2
  exit 1
fi

git fetch upstream

case "$mode" in
  merge)
    git merge --no-edit "$upstream_ref"
    ;;
  rebase)
    git rebase "$upstream_ref"
    ;;
  *)
    echo "Usage: $0 [rebase|merge]" >&2
    exit 1
    ;;
esac
