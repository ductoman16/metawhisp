#!/usr/bin/env bash
# Apply the checked-in packaging fix to the resolved dependency, idempotently.
set -euo pipefail
cd "$(dirname "$0")/.."
CHECKOUT="$PWD/.build/checkouts/swift-transformers"
PATCH="$PWD/scripts/hub-app-resources.patch"
test -d "$CHECKOUT/.git"
if git -C "$CHECKOUT" apply --reverse --check "$PATCH" 2>/dev/null; then
    echo 'Hub app resource lookup patch already applied.'
else
    # A dependency update with incompatible source fails here, before building.
    git -C "$CHECKOUT" apply --check "$PATCH"
    git -C "$CHECKOUT" apply "$PATCH"
fi
