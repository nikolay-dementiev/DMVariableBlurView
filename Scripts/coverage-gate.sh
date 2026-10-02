#!/bin/bash
#
# Fails when the line coverage of the library in a result bundle falls below its floor.
#
#   Scripts/coverage-gate.sh <result bundle>
#
# The bundle comes from a test run with coverage on (-enableCodeCoverage YES). The floor
# is the coverage the tests reached when it was set, rounded down, and never below 90 %.
# Coverage is a net, not the proof that a test can fail: that proof is the red run or the
# mutation recorded with each test.
#
# Exit codes: 0 at or above the floor, 1 below it, 2 when the bundle has no coverage of
# the library target.

set -euo pipefail

# ==== Settings of this repository =======================================================
# The packages DMAction, DMVariableBlurView and DMUnLoader share this script. Only this
# block differs between them. Everything below the end marker is identical in the three:
# a change there is made in the copy of DMVariableBlurView and synced to the other two.

# The target whose line coverage is checked, as the coverage report names it.
TARGET="DMVariableBlurView"
# The lowest accepted line coverage of that target, in percent. Never below 90.
FLOOR_PERCENT=99

# ==== End of the settings ===============================================================

if [ "$#" -ne 1 ]; then
    echo "usage: Scripts/coverage-gate.sh <result bundle>" >&2
    exit 2
fi
BUNDLE="$1"
if [ ! -d "$BUNDLE" ]; then
    echo "coverage-gate: no result bundle at $BUNDLE" >&2
    exit 2
fi

REPORT="$(mktemp)"
trap 'rm -f "$REPORT"' EXIT

if ! xcrun xccov view --report --json "$BUNDLE" > "$REPORT" 2> /dev/null; then
    echo "coverage-gate: $BUNDLE has no coverage report. Run the tests with -enableCodeCoverage YES." >&2
    exit 2
fi

python3 - "$REPORT" "$TARGET" "$FLOOR_PERCENT" <<'PY'
import json
import sys

report_path, target, floor = sys.argv[1], sys.argv[2], float(sys.argv[3])
if floor < 90:
    print(f"coverage-gate: the floor {floor:g} % is below 90 %. Check FLOOR_PERCENT.", file=sys.stderr)
    sys.exit(2)

with open(report_path) as report:
    targets = [entry for entry in json.load(report).get("targets", []) if entry.get("name") == target]
if len(targets) != 1:
    print(f"coverage-gate: the report has {len(targets)} targets named {target}, not one.", file=sys.stderr)
    sys.exit(2)

covered, executable = targets[0]["coveredLines"], targets[0]["executableLines"]
if executable == 0:
    print(f"coverage-gate: {target} has no executable lines in the report.", file=sys.stderr)
    sys.exit(2)

percent = 100 * covered / executable
print(f"coverage-gate: {target} {percent:.2f} % of lines ({covered} of {executable}), floor {floor:g} %.")
for file in sorted(targets[0].get("files", []), key=lambda entry: entry["name"]):
    missed = file["executableLines"] - file["coveredLines"]
    if missed > 0:
        print(f"  {file['name']}: {missed} of {file['executableLines']} lines not covered")
if percent < floor:
    sys.stdout.flush()
    print(f"coverage-gate: below the floor of {floor:g} %.", file=sys.stderr)
    sys.exit(1)
PY
