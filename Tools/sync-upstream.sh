#!/bin/zsh
# Sync the macOS 13 / Intel port with upstream main, rebuild, and stop.
#
#   Tools/auto-sync-upstream.sh
#   UPSTREAM_REMOTE=upstream Tools/auto-sync-upstream.sh
#
# Exit codes:
#   0  rebased (or already current), build succeeded
#   2  rebase conflict (branch left unchanged)
#   3  build failed (branch restored to its pre-rebase commit)
#
# This script never pushes. Review and push the branch explicitly.
set -euo pipefail
cd "$(dirname "$0")/.."

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-fork}"
BRANCH="${BRANCH:-macos13-intel}"
DEPTH="${SYNC_DEPTH:-100}"

echo "▸ fetch $UPSTREAM_REMOTE/main (depth $DEPTH)"
git fetch --depth="$DEPTH" --no-tags "$UPSTREAM_REMOTE" main

previous=$(git rev-parse "$BRANCH")

if git merge-base --is-ancestor "$UPSTREAM_REMOTE/main" "$BRANCH"; then
    echo "▸ $BRANCH already contains $UPSTREAM_REMOTE/main"
else
    echo "▸ rebase $BRANCH onto $UPSTREAM_REMOTE/main"
    if ! git rebase "$UPSTREAM_REMOTE/main" "$BRANCH"; then
        git rebase --abort 2>/dev/null || true
        echo "✗ rebase conflict; resolve manually" >&2
        exit 2
    fi
fi

echo "▸ build x86_64 / macOS 13.3"
if ! ./build.sh; then
    echo "✗ build failed; restoring $BRANCH to $previous" >&2
    git reset --hard "$previous" >/dev/null
    exit 3
fi

echo "✓ sync and build ok ($BRANCH at $(git rev-parse --short HEAD))"
