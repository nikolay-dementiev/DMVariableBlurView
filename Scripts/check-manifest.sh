#!/bin/bash
#
# Checks what a consumer of the package gets.
#
#   Scripts/check-manifest.sh
#
# Fixtures/Consumer depends on this checkout and uses the released API and the README
# snippets. If it stops building, a consumer's code stops building.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/.build/check-manifest"

mkdir -p "$WORK"

# xcodebuild finds a package only in the current directory.
cd "$ROOT/Fixtures/Consumer"

if ! xcodebuild build \
    -scheme Consumer \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$WORK/DerivedData" \
    -skipPackagePluginValidation \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    > "$WORK/consumer-build.log" 2>&1; then
    echo "check-manifest: Fixtures/Consumer does not build. See $WORK/consumer-build.log" >&2
    grep -E "error:" "$WORK/consumer-build.log" | sort -u | head -20 >&2 || true
    exit 1
fi

echo "check-manifest: Fixtures/Consumer builds against this checkout."
