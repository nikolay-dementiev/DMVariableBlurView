#!/bin/bash
#
# Lints the podspec in every language mode it declares and checks what a consumer links.
#
#   Scripts/check-podspec.sh
#
# The lint builds a consumer app around the pod. The script then reads the build
# configuration that CocoaPods generated for that app: a test framework in it means that
# the pod makes its consumers link test code.
#
# The script installs nothing. It needs CocoaPods on the machine.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PODSPEC="$ROOT/DMVariableBlurView.podspec"
WORK="$ROOT/.build/check-podspec"
FAILED=0

# CocoaPods stops in a locale that is not UTF-8.
export LANG=en_US.UTF-8

if ! command -v pod > /dev/null; then
    echo "check-podspec: CocoaPods is not installed." >&2
    exit 2
fi

mkdir -p "$WORK"

MODES="$(pod ipc spec "$PODSPEC" | python3 -c '
import json, sys
modes = json.load(sys.stdin).get("swift_versions", [])
print(" ".join([modes] if isinstance(modes, str) else modes))
')"
if [ -z "$MODES" ]; then
    echo "check-podspec: the podspec declares no swift_versions." >&2
    exit 1
fi

for MODE in $MODES; do
    LOG="$WORK/lint-swift$MODE.log"
    if ! pod lib lint "$PODSPEC" --swift-version="$MODE" --no-clean > "$LOG" 2>&1; then
        echo "check-podspec: pod lib lint fails in Swift $MODE mode. See ${LOG#"$ROOT"/}" >&2
        grep -E "ERROR|WARN|error:" "$LOG" | head -20 >&2 || true
        FAILED=1
        continue
    fi

    # --no-clean keeps the consumer app that the lint built, and the log says where.
    WORKSPACE="$(sed -n 's/^Pods workspace available at `\(.*\)` for inspection\.$/\1/p' "$LOG" | tail -1)"
    CONSUMER="$(dirname "$WORKSPACE")"
    if [ -z "$WORKSPACE" ] || [ ! -d "$CONSUMER/Pods/Target Support Files" ]; then
        echo "check-podspec: the consumer app of the Swift $MODE lint was not found." >&2
        FAILED=1
        continue
    fi

    if grep -r -l "XCTest" "$CONSUMER/Pods/Target Support Files" > "$WORK/xctest-swift$MODE.txt"; then
        echo "check-podspec: in Swift $MODE mode a consumer of the pod links XCTest:" >&2
        sed "s#^$CONSUMER/##" "$WORK/xctest-swift$MODE.txt" >&2
        FAILED=1
    else
        echo "check-podspec: the pod passes the lint in Swift $MODE mode and links no test framework."
    fi
    rm -rf "$CONSUMER"
done

exit "$FAILED"
