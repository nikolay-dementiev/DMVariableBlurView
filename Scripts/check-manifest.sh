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
# 3. Fixtures/Consumer builds. It uses every call shape of the released API and every
#    declaration added since, so if it stops building, a consumer's code stops building.
# 4. The library ships no resource bundle.
# 5. Every Swift block of README.md compiles as written.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/.build/check-manifest"
FAILED=0

# The version probe and the build folders are throw-away. The logs next to them stay.
PROBE=""
DERIVED=""
SNIPPETS=""
SNIPPETS_DERIVED=""
cleanup() {
    [ -z "$PROBE" ] || rm -rf "$PROBE"
    [ -z "$DERIVED" ] || rm -rf "$DERIVED"
    [ -z "$SNIPPETS" ] || rm -rf "$SNIPPETS"
    [ -z "$SNIPPETS_DERIVED" ] || rm -rf "$SNIPPETS_DERIVED"
}
trap cleanup EXIT

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
#    The probe repository must not depend on the git configuration of the machine: a
#    signing requirement or a hook of the user would stop the commit.
PROBE="$(mktemp -d "$WORK/version-probe.XXXXXX")"
mkdir -p "$PROBE/package" "$PROBE/consumer/Sources/Probe"
(cd "$ROOT" && git ls-files -z -- Package.swift Sources | xargs -0 -I{} rsync -R {} "$PROBE/package/")
git -C "$PROBE/package" init -q
git -C "$PROBE/package" add -A
git -C "$PROBE/package" -c user.name=probe -c user.email=probe@example.invalid \
    -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m probe
git -C "$PROBE/package" -c tag.gpgsign=false tag 99.0.0
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
#    A fresh build folder every run: step 4 must not see the products of an older build.
DERIVED="$(mktemp -d "$WORK/DerivedData.XXXXXX")"
CONSUMER_BUILT=0
cd "$ROOT/Fixtures/Consumer"
if xcodebuild build \
    -scheme Consumer \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    > "$WORK/consumer-build.log" 2>&1; then
    CONSUMER_BUILT=1
    # A warning in the fixture is what a consumer of the released API would see, for
    # example a deprecation. The build cannot turn warnings into errors as a whole:
    # Xcode compiles a package dependency with its warnings suppressed.
    WARNINGS="$(grep -E "/Fixtures/Consumer/[^:]*:[0-9]+:[0-9]+: warning:" "$WORK/consumer-build.log" | sort -u || true)"
    if [ -n "$WARNINGS" ]; then
        echo "check-manifest: Fixtures/Consumer builds with warnings:" >&2
        echo "$WARNINGS" | head -20 >&2
        FAILED=1
    else
        echo "check-manifest: Fixtures/Consumer builds against this checkout."
    fi
else
    echo "check-manifest: Fixtures/Consumer does not build. See ${WORK#"$ROOT"/}/consumer-build.log" >&2
    grep -E "error:" "$WORK/consumer-build.log" | sort -u | head -20 >&2 || true
    FAILED=1
fi

# 4. The library gives a consumer code only. A resource bundle means that an asset under
#    the target path is shipped inside every app that uses the package. Only the products
#    of a finished build say so, and a search that fails is not a search that found nothing.
if [ "$CONSUMER_BUILT" -eq 0 ]; then
    echo "check-manifest: resource bundles not checked: Fixtures/Consumer did not build." >&2
elif ! BUNDLES="$(find "$DERIVED/Build/Products" -maxdepth 2 -name 'DMVariableBlurView_*.bundle')"; then
    echo "check-manifest: cannot search the products of the consumer build for a resource bundle." >&2
    exit 2
elif [ -n "$BUNDLES" ]; then
    echo "check-manifest: the library ships a resource bundle to its consumers:" >&2
    echo "$BUNDLES" | while IFS= read -r bundle; do
        echo "  ${bundle#"$DERIVED"/} ($(du -sh "$bundle" | cut -f1))" >&2
    done
    FAILED=1
else
    echo "check-manifest: the library ships no resource bundle."
fi

# 5. The Swift blocks of README.md, each compiled in a context of its own, so that a block
#    cannot use a name another block declares and one broken block cannot hide another.
#    A block that contains `Package(` is a complete package manifest, and SwiftPM
#    evaluates it. Every other block is a target of its own in a generated package for
#    iOS that depends on this checkout by path, the way Fixtures/Consumer does. A warning
#    in a block fails the check too.
SNIPPETS="$(mktemp -d "$WORK/readme.XXXXXX")"
SNIPPETS_DERIVED="$(mktemp -d "$WORK/readme-DerivedData.XXXXXX")"
README_FAILED=0
if ! python3 - "$ROOT/README.md" "$SNIPPETS" > "$WORK/readme-blocks.txt" <<'PY'
import os
import re
import sys

readme, work = sys.argv[1], sys.argv[2]
lines = open(readme, encoding="utf-8").read().split("\n")
block, start, number = None, 0, 0
for index, line in enumerate(lines, start=1):
    if block is None:
        if line.strip() == "```swift":
            block, start = [], index + 1
        elif re.match(r"^\s*(```|~~~)", line) and "swift" in line.lower():
            sys.exit(f"README.md:{index}: write the fence of a Swift block as ```swift, so that it is compiled")
    elif line.strip() == "```":
        number += 1
        text = "\n".join(block) + "\n"
        kind = "manifest" if "Package(" in text else "ios"
        name = f"Snippet{number:02d}"
        os.makedirs(os.path.join(work, "blocks"), exist_ok=True)
        with open(os.path.join(work, "blocks", f"{name}.swift"), "w", encoding="utf-8") as out:
            out.write(text)
        print(kind, name, start)
        block = None
    else:
        block.append(line)
if block is not None:
    sys.exit(f"README.md: the Swift block that starts on line {start} is not closed")
PY
then
    README_FAILED=1
elif [ ! -s "$WORK/readme-blocks.txt" ]; then
    echo "check-manifest: README.md has no Swift block." >&2
    README_FAILED=1
else
    IOS_BLOCKS=()
    while read -r KIND NAME LINE; do
        if [ "$KIND" = "manifest" ]; then
            mkdir -p "$SNIPPETS/$NAME"
            cp "$SNIPPETS/blocks/$NAME.swift" "$SNIPPETS/$NAME/Package.swift"
            if ! swift package dump-package --package-path "$SNIPPETS/$NAME" > "$WORK/readme-$NAME.log" 2>&1; then
                echo "check-manifest: the manifest at README.md:$LINE does not evaluate:" >&2
                grep -E "error:" "$WORK/readme-$NAME.log" | head -10 >&2 || true
                README_FAILED=1
            fi
        else
            mkdir -p "$SNIPPETS/ios/Sources/$NAME"
            cp "$SNIPPETS/blocks/$NAME.swift" "$SNIPPETS/ios/Sources/$NAME/$NAME.swift"
            IOS_BLOCKS+=("$NAME")
        fi
    done < "$WORK/readme-blocks.txt"

    if [ "${#IOS_BLOCKS[@]}" -gt 0 ]; then
        {
            echo "// swift-tools-version: 6.0"
            echo "import PackageDescription"
            echo "let package = Package("
            echo "    name: \"ReadmeSnippets\","
            echo "    platforms: [.iOS(.v17)],"
            echo "    products: [.library(name: \"ReadmeSnippets\", targets: [$(printf '"%s", ' "${IOS_BLOCKS[@]}")])],"
            echo "    dependencies: [.package(name: \"DMVariableBlurView\", path: \"$ROOT\")],"
            echo "    targets: ["
            for NAME in "${IOS_BLOCKS[@]}"; do
                echo "        .target(name: \"$NAME\", dependencies: [.product(name: \"DMVariableBlurView\", package: \"DMVariableBlurView\")]),"
            done
            echo "    ]"
            echo ")"
        } > "$SNIPPETS/ios/Package.swift"
        if (cd "$SNIPPETS/ios" && xcodebuild build \
                -scheme ReadmeSnippets \
                -sdk iphonesimulator \
                -destination 'generic/platform=iOS Simulator' \
                -derivedDataPath "$SNIPPETS_DERIVED" \
                ARCHS=arm64 ONLY_ACTIVE_ARCH=NO) > "$WORK/readme-build.log" 2>&1; then
            # A block counts only when the log shows it compiled in this run.
            for NAME in "${IOS_BLOCKS[@]}"; do
                if ! grep -qE "^SwiftCompile .*/Sources/$NAME/$NAME\.swift" "$WORK/readme-build.log"; then
                    echo "check-manifest: the block at README.md:$(grep " $NAME " "$WORK/readme-blocks.txt" | cut -d ' ' -f 3) was not compiled" >&2
                    README_FAILED=1
                fi
            done
            WARNINGS="$(grep -E "/Sources/Snippet[0-9]+/[^:]+:[0-9]+:[0-9]+: warning:" "$WORK/readme-build.log" | sort -u || true)"
            if [ -n "$WARNINGS" ]; then
                echo "check-manifest: a Swift block of README.md compiles with warnings:" >&2
                echo "$WARNINGS" | head -20 >&2
                echo "  The block numbers map to README lines in ${WORK#"$ROOT"/}/readme-blocks.txt" >&2
                README_FAILED=1
            fi
        else
            echo "check-manifest: a Swift block of README.md does not compile:" >&2
            grep -E "error:" "$WORK/readme-build.log" | sort -u | head -20 >&2 || true
            echo "  The block numbers map to README lines in ${WORK#"$ROOT"/}/readme-blocks.txt" >&2
            README_FAILED=1
        fi
    fi
    if [ "$README_FAILED" -eq 0 ]; then
        echo "check-manifest: the $(wc -l < "$WORK/readme-blocks.txt" | tr -d ' ') Swift blocks of README.md compile."
    fi
fi
if [ "$README_FAILED" -ne 0 ]; then
    FAILED=1
fi

exit "$FAILED"
