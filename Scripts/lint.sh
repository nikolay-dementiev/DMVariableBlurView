#!/bin/bash
#
# Lints the repository with the SwiftLint version pinned in .swiftlint.yml.
#
#   Scripts/lint.sh                         lint; a warning fails the run
#   Scripts/lint.sh --analyze <build log>   also run the analyzer rules, which need the
#                                           compiler invocations of an xcodebuild log
#
# The tool is fetched once into .build/tools and checked against the pinned checksum before
# it is unpacked. Nothing is installed or upgraded on the machine.

set -euo pipefail

# A mistyped option would otherwise run the plain lint and pass without the analysis.
case "${1:-}" in
    "") ;;
    --analyze)
        if [ "$#" -lt 2 ]; then
            echo "lint: --analyze needs the path of an xcodebuild log." >&2
            exit 2
        fi
        ;;
    *)
        echo "lint: unknown argument '$1'. Run it without one, or with --analyze <xcodebuild log>." >&2
        exit 2
        ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=SCRIPTDIR/swiftlint-tool.sh
. "$ROOT/Scripts/swiftlint-tool.sh"
VERSION="$(swiftlint_version "$ROOT" lint)"
SWIFTLINT="$(swiftlint_fetch "$ROOT" "$VERSION" lint)"

cd "$ROOT"
"$SWIFTLINT" lint --strict --quiet

if [ "${1:-}" = "--analyze" ]; then
    LOG="$2"
    if [ ! -r "$LOG" ]; then
        echo "lint: cannot read $LOG" >&2
        exit 2
    fi
    # The analyzer reads the lines that call swiftc with -module-name. A log without one,
    # such as the log of an incremental build, would pass without a file being analyzed.
    if ! grep -qE 'swiftc( .*)? -module-name ' "$LOG"; then
        echo "lint: $LOG holds no compiler invocation; analyze the log of a clean build." >&2
        exit 2
    fi
    # The analyzer looks only at the files of this repository that the log compiled, and its
    # summary says how many: none means that the log is of another project.
    REPORT="$ROOT/.build/lint-analyze.log"
    STATUS=0
    "$SWIFTLINT" analyze --strict --compiler-log-path "$LOG" 2> "$REPORT" || STATUS=$?
    if [ "$STATUS" -ne 0 ]; then
        cat "$REPORT" >&2
        exit "$STATUS"
    fi
    if ! grep -qE ' in [1-9][0-9]* files?\.$' "$REPORT"; then
        echo "lint: $LOG compiled no file of this repository, so nothing was analyzed." >&2
        exit 2
    fi
fi

echo "lint: no violations (SwiftLint $("$SWIFTLINT" version))."
