#!/bin/bash
#
# Compares the public interface of the library with the committed baseline.
#
#   Scripts/check-api.sh            compare, exit 1 on any difference
#   Scripts/check-api.sh --update   rewrite the baseline from the current sources
#
# Any difference fails. A removed or changed line is a break of the public contract.
# An added line is new public API: run with --update and commit the baseline together
# with the change, so the whole API delta is readable in the diff of one file.
#
# The interface text depends on the compiler and the SDK. CI runs this check on one
# pinned Xcode; after a toolchain change the baseline may need --update with no API change.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="DMVariableBlurView"
BASELINE="$ROOT/Fixtures/API/public-interface.txt"
WORK="$ROOT/.build/check-api"
INTERFACE="$WORK/$MODULE.swiftinterface"
CURRENT="$WORK/public-interface.txt"

mkdir -p "$WORK"

SOURCES=()
while IFS= read -r file; do
    SOURCES+=("$file")
done < <(find "$ROOT/Sources/$MODULE" -name '*.swift' | sort)

# The package cannot be built for the host, so the compiler is called for the simulator.
# It is called directly, because the module and its main type share a name: qualified
# names in the emitted interface are ambiguous to the interface verifier, which a build
# through xcodebuild always runs. The emitted text is still the complete interface.
if ! xcrun --sdk iphonesimulator swiftc \
    -target arm64-apple-ios17.0-simulator \
    -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
    -module-name "$MODULE" \
    -package-name "$MODULE" \
    -swift-version 6 \
    -enable-upcoming-feature ExistentialAny \
    -enable-library-evolution \
    -emit-module -emit-module-path "$WORK/$MODULE.swiftmodule" \
    -emit-module-interface-path "$INTERFACE" \
    -no-verify-emitted-module-interface \
    "${SOURCES[@]}" \
    > "$WORK/swiftc.log" 2>&1; then
    echo "check-api: the library does not compile. See ${WORK#"$ROOT"/}/swiftc.log" >&2
    grep -E "error:" "$WORK/swiftc.log" | sort -u | head -20 >&2 || true
    exit 2
fi

# Header comments carry the compiler version and flags; imports are not API. The compiler
# emits declarations in the order of the source files, so the top-level declarations are
# sorted: moving a type to another file must not look like an API change. An attribute
# that the compiler prints on a line of its own, such as @available, stays with the
# declaration below it: moving it to another declaration is an API change.
grep -v -E '^(//|import )' "$INTERFACE" | python3 -c '
import sys

def attributes_only(line):
    position, end = 0, len(line)
    while position < end:
        if line[position].isspace():
            position += 1
            continue
        if line[position] != "@":
            return False
        position += 1
        while position < end and (line[position].isalnum() or line[position] in "_."):
            position += 1
        if position < end and line[position] == "(":
            depth = 0
            while position < end:
                depth += {"(": 1, ")": -1}.get(line[position], 0)
                position += 1
                if depth == 0:
                    break
    return True

blocks, current = [], []
for line in sys.stdin.read().splitlines():
    starts_declaration = bool(line) and not line[0].isspace() and line != "}"
    if starts_declaration and current and not all(attributes_only(held) for held in current):
        blocks.append("\n".join(current))
        current = []
    current.append(line)
if current:
    blocks.append("\n".join(current))
print("\n".join(sorted(blocks)))
' > "$CURRENT"

if [ "${1:-}" = "--update" ]; then
    mkdir -p "$(dirname "$BASELINE")"
    cp "$CURRENT" "$BASELINE"
    echo "check-api: baseline updated: ${BASELINE#"$ROOT"/}"
    exit 0
fi

if [ ! -f "$BASELINE" ]; then
    echo "check-api: no baseline at ${BASELINE#"$ROOT"/}. Run with --update." >&2
    exit 2
fi

if diff -u "$BASELINE" "$CURRENT" > "$WORK/api.diff"; then
    echo "check-api: the public interface matches the baseline."
    exit 0
fi

echo "check-api: the public interface differs from the baseline." >&2
echo "  '-' lines were removed or changed: that breaks the public contract." >&2
echo "  '+' lines are new public API: run Scripts/check-api.sh --update and commit the baseline." >&2
cat "$WORK/api.diff" >&2
exit 1
