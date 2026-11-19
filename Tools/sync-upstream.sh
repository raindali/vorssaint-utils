#!/bin/zsh
# Rebase the macOS 13 / Intel port onto the latest upstream main, then build.
#
# Usage:
#   Tools/sync-upstream.sh
#   UPSTREAM_REMOTE=upstream Tools/sync-upstream.sh
#
# The script does not push. After a clean build, push the branch explicitly:
#   git push --force-with-lease <fork-remote> macos13-intel
set -euo pipefail
cd "$(dirname "$0")/.."

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-origin}"
BRANCH="${BRANCH:-macos13-intel}"

echo "▸ fetching $UPSTREAM_REMOTE/main"
git fetch "$UPSTREAM_REMOTE" main

echo "▸ rebasing $BRANCH onto $UPSTREAM_REMOTE/main"
git rebase "$UPSTREAM_REMOTE/main" "$BRANCH"

echo "▸ building x86_64 / macOS 13.3"
./build.sh

cat <<EOF
✓ rebase and build finished.
  Review the diff, then push with:
    git push --force-with-lease <fork-remote> $BRANCH
EOF
