#!/usr/bin/env bash
set -euo pipefail

upstream_ref="${UPSTREAM_REF:-upstream/main}"
target_dir="${TARGET_DIR:-bitnet-src}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Run this script from inside a git repository." >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree must be clean before syncing with upstream." >&2
  exit 1
fi

git fetch upstream

rm -rf "$target_dir"
mkdir -p "$target_dir"
git archive "$upstream_ref" | tar -x -C "$target_dir"

echo "Imported $upstream_ref into $target_dir/"
