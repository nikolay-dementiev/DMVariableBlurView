#!/bin/bash
#
# Checks what a consumer of the package gets.
#
#   Scripts/check-manifest.sh
#
# 1. The manifest has no dependency by branch or revision and uses no plugin. SwiftPM
#    refuses a version requirement on a package that has an unstable dependency, and a
#    build plugin of a dependency runs in every consumer's build.
# 2. A consumer that asks for the package by version resolves it.
# 3. Fixtures/Consumer builds. It uses the released API and the README samples, so if it
#    stops building, a consumer's code stops building.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/.build/check-manifest"
FAILED=0

mkdir -p "$WORK"

# 1. Static check of the manifest.
swift package --package-path "$ROOT" dump-package > "$WORK/manifest.json"
if ! python3 - "$WORK/manifest.json" <<'PY'
import json
import sys

manifest = json.load(open(sys.argv[1]))
problems = []
for dependency in manifest.get("dependencies", []):
    for kind, entries in dependency.items():
        for entry in entries:
            requirement = entry.get("requirement", {})
            for unstable in ("branch", "revision"):
                if unstable in requirement:
                    problems.append(
                        f"dependency '{entry.get('identity')}' is required by {unstable} "
                        f"{requirement[unstable]}"
                    )
for target in manifest.get("targets", []):
    for usage in target.get("pluginUsages") or []:
        problems.append(f"target '{target['name']}' uses a plugin: {json.dumps(usage)}")
for problem in problems:
    print(f"check-manifest: {problem}", file=sys.stderr)
sys.exit(1 if problems else 0)
PY
then
    FAILED=1
else
    echo "check-manifest: no unstable requirement and no plugin in Package.swift."
fi

# 2. Resolution by version, against a throw-away copy of the working tree with a tag.
PROBE="$(mktemp -d "$WORK/version-probe.XXXXXX")"
mkdir -p "$PROBE/package" "$PROBE/consumer/Sources/Probe"
(cd "$ROOT" && git ls-files -z -- Package.swift Sources | xargs -0 -I{} rsync -R {} "$PROBE/package/")
git -C "$PROBE/package" init -q
git -C "$PROBE/package" add -A
git -C "$PROBE/package" -c user.name=probe -c user.email=probe@example.invalid commit -q -m probe
git -C "$PROBE/package" tag 99.0.0
cat > "$PROBE/consumer/Package.swift" <<EOF
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Probe",
    platforms: [.iOS(.v17)],
    dependencies: [.package(url: "file://$PROBE/package", from: "99.0.0")],
    targets: [.target(name: "Probe", dependencies: [.product(name: "DMVariableBlurView", package: "package")])]
)
EOF
echo "import DMVariableBlurView" > "$PROBE/consumer/Sources/Probe/Probe.swift"
if swift package --package-path "$PROBE/consumer" resolve > "$WORK/version-resolution.log" 2>&1; then
    echo "check-manifest: a version requirement on the package resolves."
else
    echo "check-manifest: a version requirement on the package does not resolve:" >&2
    grep -E "error:|cannot be used|unstable" "$WORK/version-resolution.log" | head -5 >&2 || true
    FAILED=1
fi

# 3. The consumer fixture. xcodebuild finds a package only in the current directory.
cd "$ROOT/Fixtures/Consumer"
if xcodebuild build \
    -scheme Consumer \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$WORK/DerivedData" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    > "$WORK/consumer-build.log" 2>&1; then
    echo "check-manifest: Fixtures/Consumer builds against this checkout."
else
    echo "check-manifest: Fixtures/Consumer does not build. See ${WORK#"$ROOT"/}/consumer-build.log" >&2
    grep -E "error:" "$WORK/consumer-build.log" | sort -u | head -20 >&2 || true
    FAILED=1
fi

exit "$FAILED"
