#!/bin/bash
#
# Checks what a consumer of the package gets.
#
#   Scripts/check-manifest.sh              run the checks below
#   Scripts/check-manifest.sh --self-test  run the readers of the checks on built-in texts
#
# 1. No manifest file of the package declares a dependency, uses a plugin, declares a plugin
#    target or declares a binary target that is downloaded (one with a url: it is code that
#    arrives when the package is resolved; one with a path is carried by the repository).
#    The files are Package.swift and every Package@swift-*.swift: SwiftPM reads one of the
#    latter in place of Package.swift when the tools of a consumer are newer, so a problem
#    is named after the file it is in. A dependency needs the maintainer's approval and a
#    change of this check in the same pull request. Item 2 sees only a dependency that a
#    target of a product uses: SwiftPM leaves one that nothing uses out of what a consumer
#    resolves, so only the manifest shows it. A dependency by branch or revision is named
#    for its requirement as well: SwiftPM refuses a version requirement on a package that
#    has an unstable dependency. A build plugin of a dependency runs in every consumer's
#    build.
# 2. The installation manifest of README.md works. With only its URL pointed at a
#    throw-away tagged copy of the tracked manifest and sources, it resolves and builds
#    for the iOS simulator: a consumer that depends on the checkout by path cannot show a
#    failure of a version requirement, and only a build shows a wrong product or package
#    name, or a platform below the package's. The Package.resolved of that build pins the
#    copy and nothing else, so a consumer of the package resolves this package only: any
#    other pin is named with its kind, version and location, and a file that cannot be
#    read, that holds no pin or more than one pin of the copy, or that is not of format
#    version 2 or 3 is a failure. The build keeps its own cache, so manifests and
#    repositories cached on the machine of whoever runs this cannot stand in for what the
#    build resolves. The copy is tagged with the version the README names, so the README
#    is compared with what a consumer is told elsewhere: its URL must be the podspec's
#    :git source, character for character, and its version that of the newest dated
#    release heading of CHANGELOG.md.
# 3. Fixtures/Consumer builds. It uses every call shape of the released API and every
#    declaration added since, so if it stops building, a consumer's code stops building.
# 4. The library ships no resource bundle.
# 5. Every Swift block of README.md compiles as written.
#
# --self-test needs no network, no build and no swift. A reader that never fails looks the
# same as a clean tree, so it takes the python blocks of item 1 (marked manifest-rules) and
# of item 2 (marked readme-consumer and resolved-inventory) out of this very file, the text
# that the check runs, and runs them on texts that it carries: a manifest with a dependency
# from a registry, by version, by path, by branch or by revision, a second dependency, a
# plugin, a plugin target, a binary target with a url, or without its list of dependencies or
# of targets, or with a target that has no type or a binary target with neither a url nor a
# path, and several manifest files with a problem in the first, in the second, in both, or in
# a dump that is not JSON; a README with no package manifest, two, exact: for from:, or two
# requirements, a URL that is not the podspec's or differs from it by .git, a version that is
# not the newest release's, a podspec or a changelog that cannot be read or has no source or no
# dated release; a Package.resolved with an extra pin, no pin, the copy twice, a format other
# than 2 and 3, or that is not a resolution at all. A reader that was changed to pass one of
# these fails the self-test. It does not run the shell around the readers: the lines that set
# FAILED, and the ones that find each manifest file, copy it and ask swift to dump it.
#
# Exit codes: 0 every check passed, 1 a check failed, 2 wrong usage, or the self-test could
# not be made (python3 is missing, or a marked block is not where it expects), or the
# search of the build products failed. A command of the setup of item 2 that fails, such as
# git or rsync, ends the script with its own status.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="DMVariableBlurView"

# Takes the python block that follows the line "# <marker>" out of this script into <output file>:
# the very text that the check runs. The marker must appear once, directly under the line that
# opens the heredoc, so that a line added above it or a second marker cannot make the two differ.
extract_block() {  # <marker> <output file>
    local marker="$1" output="$2" found
    found="$(awk -v marker="# $marker" '$0 == marker { count++; opener = prev } { prev = $0 } END { print count + 0 ":" opener }' "${BASH_SOURCE[0]}")"
    case "$found" in
        "1:"*"<<'PY'") ;;
        *)
            echo "check-manifest: self-test: the marker $marker must appear once, under the line that opens the heredoc of its step (found '$found')" >&2
            exit 2
            ;;
    esac
    awk -v marker="# $marker" '$0 == marker { found = 1 } found && /^PY$/ { exit } found' "${BASH_SOURCE[0]}" > "$output"
    if [ ! -s "$output" ]; then
        echo "check-manifest: self-test: the python block marked $marker is not in ${BASH_SOURCE[0]}" >&2
        exit 2
    fi
}

# Runs the readers of step 1 (the manifest) and of step 2 (Package.resolved) on built-in texts, and exits.
SELF_TEST_WORK=""
self_test() {
    local total=0 failures=0 dm plain got output fence app app_two podspec_text changelog_text padded dash clean with_dependency with_plugin
    if ! command -v python3 > /dev/null; then
        echo "check-manifest: self-test: python3 is not installed" >&2
        exit 2
    fi
    SELF_TEST_WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-manifest-self-test.XXXXXX")" || exit 2
    trap 'rm -rf "$SELF_TEST_WORK"' EXIT
    extract_block manifest-rules "$SELF_TEST_WORK/rules.py"
    extract_block readme-consumer "$SELF_TEST_WORK/readme.py"
    extract_block resolved-inventory "$SELF_TEST_WORK/inventory.py"
    pin() {  # <identity> <version>
        printf '{"identity":"%s","kind":"localSourceControl","location":"/x/%s","state":{"revision":"abc","version":"%s"}}' "$1" "$1" "$2"
    }
    judge() {  # <name> <expected status> <expected text> <status the reader gave> <its output>
        total=$((total + 1))
        if [ "$4" -eq "$2" ] && printf '%s\n' "$5" | grep -q -F -- "$3"; then
            echo "check-manifest: self-test ok   $1"
        else
            failures=$((failures + 1))
            echo "check-manifest: self-test FAIL $1: expected status $2 and '$3', got status $4:" >&2
            printf '%s\n' "$5" | head -5 | sed 's/^/    /' >&2
        fi
    }
    expect() {  # <name> <expected status> <expected text>: the reader on Package.resolved as it is
        local got=0 output
        output="$(python3 "$SELF_TEST_WORK/inventory.py" "$SELF_TEST_WORK/Package.resolved" "$MODULE" 2>&1)" || got=$?
        judge "$1" "$2" "$3" "$got" "$output"
    }
    readme_case() {  # <name> <expected status> <expected text> <text of README.md> [<text of the podspec> [<text of CHANGELOG.md>]]
        local got=0 output
        mkdir -p "$SELF_TEST_WORK/probe/consumer"
        printf '%s\n' "$4" > "$SELF_TEST_WORK/README.md"
        printf '%s\n' "${5-$podspec_text}" > "$SELF_TEST_WORK/Package.podspec"
        printf '%s\n' "${6-$changelog_text}" > "$SELF_TEST_WORK/CHANGELOG.md"
        output="$(python3 "$SELF_TEST_WORK/readme.py" "$SELF_TEST_WORK/README.md" "$SELF_TEST_WORK/probe" \
            "$SELF_TEST_WORK/Package.podspec" "$SELF_TEST_WORK/CHANGELOG.md" 2>&1)" || got=$?
        judge "$1" "$2" "$3" "$got" "$output"
    }
    manifest_case() {  # <name> <expected status> <expected text> <text of the manifest>
        local got=0 output
        printf '%s\n' "$4" > "$SELF_TEST_WORK/Package.swift.json"
        output="$(python3 "$SELF_TEST_WORK/rules.py" "$SELF_TEST_WORK/Package.swift.json" 2>&1)" || got=$?
        judge "$1" "$2" "$3" "$got" "$output"
    }
    # The reader is handed the dump of every manifest file of the package, and names a problem after
    # the file whose dump it came from, which is the name of the dump without .json.
    manifests_case() {  # <name> <expected status> <expected text> <manifest file>=<text of its dump>...
        local got=0 output name="$1" status="$2" text="$3" spec dumps=()
        shift 3
        rm -rf "$SELF_TEST_WORK/manifests"
        mkdir -p "$SELF_TEST_WORK/manifests"
        for spec in "$@"; do
            printf '%s\n' "${spec#*=}" > "$SELF_TEST_WORK/manifests/${spec%%=*}.json"
            dumps+=("$SELF_TEST_WORK/manifests/${spec%%=*}.json")
        done
        output="$(python3 "$SELF_TEST_WORK/rules.py" "${dumps[@]}" 2>&1)" || got=$?
        judge "$name" "$status" "$text" "$got" "$output"
    }
    check() {  # <name> <expected status> <expected text> <text of Package.resolved>
        printf '%s\n' "$4" > "$SELF_TEST_WORK/Package.resolved"
        expect "$1" "$2" "$3"
    }
    dm="$(pin dmvariableblurview 1.1.0)"
    check "the copy alone, format 3" 0 "" "{\"version\":3,\"pins\":[$dm]}"
    check "the copy alone, format 2" 0 "" "{\"version\":2,\"pins\":[$dm]}"
    check "an extra pin is named" 1 "second (localSourceControl, 1.0.0, /x/second)" "{\"version\":3,\"pins\":[$(pin second 1.0.0),$dm]}"
    check "an extra pin after the copy is named" 1 "second (localSourceControl, 1.0.0, /x/second)" "{\"version\":3,\"pins\":[$dm,$(pin second 1.0.0)]}"
    check "another pin only" 1 "dmvariableblurview, the tagged copy, is not among the resolved packages" "{\"version\":3,\"pins\":[$(pin second 1.0.0)]}"
    check "no pin at all" 1 "is not among the resolved packages" '{"version":3,"pins":[]}'
    check "format 1" 1 "not of format version 2 or 3" '{"object":{"pins":[{"package":"DMVariableBlurView"}]},"version":1}'
    check "format 4" 1 "not of format version 2 or 3" "{\"version\":4,\"pins\":[$dm]}"
    check "no list of pins" 1 "not of format version 2 or 3" '{"version":3}'
    check "not JSON" 1 "cannot be read" 'not json'
    check "the copy twice" 1 "pinned 2 times" "{\"version\":3,\"pins\":[$dm,$(pin dmvariableblurview 1.2.0)]}"
    check "a pin that is not an object" 1 "not of format version 2 or 3" "{\"version\":3,\"pins\":[$dm,\"text\"]}"
    check "a null state" 1 "second (registry, None, None)" "{\"version\":3,\"pins\":[$dm,{\"identity\":\"second\",\"kind\":\"registry\",\"state\":null}]}"
    rm -f "$SELF_TEST_WORK/Package.resolved"
    expect "a file that is not there" 1 "cannot be read"
    # The manifest as `swift package dump-package` prints it, cut down to the keys the reader looks at.
    plain='{"identity":"swift-log","requirement":{"range":[{"lowerBound":"1.0.0","upperBound":"2.0.0"}]}}'
    manifest_case "no dependency and no plugin" 0 "" '{"dependencies":[],"targets":[{"name":"Library","type":"regular","pluginUsages":null}]}'
    manifest_case "a dependency by version is named" 1 "dependency 'swift-log' is declared: a dependency needs the maintainer's approval" "{\"dependencies\":[{\"sourceControl\":[$plain]}],\"targets\":[]}"
    manifest_case "a dependency by path is named" 1 "dependency 'local' is declared" '{"dependencies":[{"fileSystem":[{"identity":"local","path":"/x"}]}],"targets":[]}'
    manifest_case "a dependency by branch is named for its requirement" 1 "dependency 'swift-log' is required by branch" '{"dependencies":[{"sourceControl":[{"identity":"swift-log","requirement":{"branch":["main"]}}]}],"targets":[]}'
    manifest_case "a dependency by revision is named for its requirement" 1 "dependency 'swift-log' is required by revision" '{"dependencies":[{"sourceControl":[{"identity":"swift-log","requirement":{"revision":["abc"]}}]}],"targets":[]}'
    manifest_case "a dependency from a registry is named" 1 "dependency 'scope.name' is declared" '{"dependencies":[{"registry":[{"identity":"scope.name","requirement":{"range":[{"lowerBound":"1.0.0","upperBound":"2.0.0"}]}}]}],"targets":[]}'
    manifest_case "the second dependency is named" 1 "dependency 'local' is declared" "{\"dependencies\":[{\"sourceControl\":[$plain]},{\"fileSystem\":[{\"identity\":\"local\",\"path\":\"/x\"}]}],\"targets\":[]}"
    manifest_case "the second dependency of a kind is named" 1 "dependency 'swift-metrics' is declared" "{\"dependencies\":[{\"sourceControl\":[$plain,{\"identity\":\"swift-metrics\",\"requirement\":{\"exact\":[\"1.0.0\"]}}]}],\"targets\":[]}"
    manifest_case "a plugin on a target" 1 "target 'Library' uses a plugin" '{"dependencies":[],"targets":[{"name":"Library","type":"regular","pluginUsages":[{"plugin":["Lint",null]}]}]}'
    manifest_case "a plugin on the second target" 1 "target 'Second' uses a plugin" '{"dependencies":[],"targets":[{"name":"First","type":"regular","pluginUsages":null},{"name":"Second","type":"regular","pluginUsages":[{"plugin":["Lint",null]}]}]}'
    manifest_case "the second plugin of a target is named" 1 '"Format"' '{"dependencies":[],"targets":[{"name":"Library","type":"regular","pluginUsages":[{"plugin":["Lint",null]},{"plugin":["Format",null]}]}]}'
    # A plugin is a target of its own, and a binary target with a url is code that is downloaded when the
    # package is resolved. A binary target with a path is a binary the repository carries.
    manifest_case "a plugin target is named" 1 "target 'Lint' is a plugin: a plugin needs the maintainer's approval" '{"dependencies":[],"targets":[{"name":"Lint","type":"plugin"}]}'
    manifest_case "the second target is a plugin" 1 "target 'Second' is a plugin" '{"dependencies":[],"targets":[{"name":"First","type":"regular"},{"name":"Second","type":"plugin"}]}'
    manifest_case "a remote binary target is named" 1 "target 'Remote' is a binary fetched from https://example.invalid/r.zip: " '{"dependencies":[],"targets":[{"name":"Remote","type":"binary","url":"https://example.invalid/r.zip","checksum":"abc"}]}'
    manifest_case "a plugin and a remote binary are named together" 1 "target 'Remote' is a binary fetched from" '{"dependencies":[],"targets":[{"name":"Lint","type":"plugin"},{"name":"Remote","type":"binary","url":"https://example.invalid/r.zip"}]}'
    manifest_case "a local binary target is not named" 0 "" '{"dependencies":[],"targets":[{"name":"Local","type":"binary","path":"Local.xcframework"}]}'
    manifest_case "a target of every other type is not named" 0 "" '{"dependencies":[],"targets":[{"name":"A","type":"regular"},{"name":"B","type":"executable"},{"name":"C","type":"test"},{"name":"D","type":"system"},{"name":"E","type":"macro"}]}'
    manifest_case "a binary target with neither a url nor a path" 1 "the manifest cannot be read" '{"dependencies":[],"targets":[{"name":"Odd","type":"binary"}]}'
    manifest_case "a target without a type" 1 "the manifest cannot be read" '{"dependencies":[],"targets":[{"name":"Library","pluginUsages":null}]}'
    manifest_case "no list of dependencies" 1 "the manifest cannot be read" '{"targets":[]}'
    manifest_case "no list of targets" 1 "the manifest cannot be read" '{"dependencies":[]}'
    manifest_case "an entry that is not an object" 1 "the manifest cannot be read" '{"dependencies":[{"sourceControl":["text"]}],"targets":[]}'
    manifest_case "a dependency without an entry" 1 "the manifest cannot be read" '{"dependencies":[{}],"targets":[]}'
    manifest_case "a kind of dependency without an entry" 1 "the manifest cannot be read" '{"dependencies":[{"sourceControl":[]}],"targets":[]}'
    manifest_case "a requirement that is not an object" 1 "the manifest cannot be read" '{"dependencies":[{"sourceControl":[{"identity":"x","requirement":"main"}]}],"targets":[]}'
    manifest_case "dependencies and targets that are objects, not lists" 1 "the manifest cannot be read" '{"dependencies":{},"targets":{}}'
    manifest_case "dependencies and targets that are strings, not lists" 1 "the manifest cannot be read" '{"dependencies":"","targets":""}'
    manifest_case "not JSON" 1 "the manifest cannot be read" 'not json'
    rm -f "$SELF_TEST_WORK/Package.swift.json"
    got=0
    output="$(python3 "$SELF_TEST_WORK/rules.py" "$SELF_TEST_WORK/Package.swift.json" 2>&1)" || got=$?
    judge "a manifest that is not there" 1 "the manifest cannot be read" "$got" "$output"
    got=0
    output="$(python3 "$SELF_TEST_WORK/rules.py" 2>&1)" || got=$?
    judge "no manifest at all" 1 "no manifest was handed to the reader" "$got" "$output"
    # One dump per manifest file: SwiftPM reads Package@swift-6.0.swift, not Package.swift, when the tools
    # are newer than the tools version of Package.swift, so a consumer's tools may read what this machine's
    # tools do not.
    clean='{"dependencies":[],"targets":[{"name":"Library","type":"regular"}]}'
    with_dependency="{\"dependencies\":[{\"sourceControl\":[$plain]}],\"targets\":[]}"
    with_plugin='{"dependencies":[],"targets":[{"name":"Lint","type":"plugin"}]}'
    manifests_case "two manifests without a problem" 0 "" "Package.swift=$clean" "Package@swift-6.0.swift=$clean"
    manifests_case "a dependency of the second manifest is named after its file" 1 \
        "Package@swift-6.0.swift: dependency 'swift-log' is declared" "Package.swift=$clean" "Package@swift-6.0.swift=$with_dependency"
    manifests_case "a dependency of the first manifest is named after its file" 1 \
        "Package.swift: dependency 'swift-log' is declared" "Package.swift=$with_dependency" "Package@swift-6.0.swift=$clean"
    manifests_case "the problems of two manifests are named together" 1 \
        "Package@swift-6.3.swift: target 'Lint' is a plugin" "Package.swift=$with_dependency" "Package@swift-6.3.swift=$with_plugin"
    manifests_case "a dump that is not JSON is named after its file" 1 \
        "Package@swift-6.0.swift: the manifest cannot be read" "Package.swift=$clean" "Package@swift-6.0.swift=not json"
    # The README as step 2 reads it: one package manifest in a swift fence.
    fence='```'
    swift_block() {  # <text of the block>
        printf '%s\n%s\n%s\n' "${fence}swift" "$1" "$fence"
    }
    app='// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "App",
    dependencies: [
        .package(url: "https://github.com/x/Foo.git", from: "1.2.3")
    ],
    targets: [.target(name: "App", dependencies: [.product(name: "Foo", package: "Foo")])]
)'
    # The podspec and the changelog as the README is compared with them: the source of the pod,
    # and the release headings, newest first, an unreleased section on top of them.
    podspec_text="  s.source = { :git => 'https://github.com/x/Foo.git', :tag => s.version.to_s }"
    changelog_text='# Changelog

## [Unreleased]

## [1.2.3] - 2026-10-03

## [1.0.0] - 2025-10-11'
    readme_case "one manifest: the version and the copy" 0 "1.2.3 Foo" "$(swift_block "$app")"
    got=0
    grep -q -F "url: \"file://$SELF_TEST_WORK/probe/Foo\"" "$SELF_TEST_WORK/probe/consumer/Package.swift" || got=$?
    judge "the consumer points at the copy" 0 "" "$got" ""
    got=0
    grep -q -F "github.com" "$SELF_TEST_WORK/probe/consumer/Package.swift" || got=$?
    judge "the consumer keeps nothing of the real URL" 1 "" "$got" ""
    readme_case "a URL with a trailing slash and no .git" 0 "1.2.3 Foo" "$(swift_block "${app//Foo.git/Foo/}")" \
        "${podspec_text//Foo.git/Foo/}"
    readme_case "a URL of another repository than the podspec's" 1 \
        "README.md installs from https://github.com/x/Foo.git, the podspec's source is https://github.com/y/Foo.git" \
        "$(swift_block "$app")" "${podspec_text//x\/Foo/y/Foo}"
    readme_case "a URL that differs from the podspec's by .git only" 1 \
        "README.md installs from https://github.com/x/Foo, the podspec's source is https://github.com/x/Foo.git" \
        "$(swift_block "${app//Foo.git/Foo}")"
    readme_case "a podspec with no :git source" 1 "the podspec has no source of the form :git => '<url>'" \
        "$(swift_block "$app")" "  s.source = { :http => 'https://example.com/Foo.zip' }"
    readme_case "a version older than the newest release" 1 \
        "README.md asks for version 1.2.3, the newest release heading of CHANGELOG.md is 1.3.0" \
        "$(swift_block "$app")" "$podspec_text" "## [1.3.0] - 2026-11-01

$changelog_text"
    readme_case "a version newer than the newest release" 1 \
        "README.md asks for version 1.2.3, the newest release heading of CHANGELOG.md is 1.0.0" \
        "$(swift_block "$app")" "$podspec_text" "## [1.0.0] - 2025-10-11"
    readme_case "a section with a version and no date is passed over" 0 "1.2.3 Foo" "$(swift_block "$app")" \
        "$podspec_text" "## [1.3.0]

$changelog_text"
    readme_case "a changelog with no dated release" 1 \
        "CHANGELOG.md has no release heading of the form '## [x.y.z] - YYYY-MM-DD'" \
        "$(swift_block "$app")" "$podspec_text" "## [Unreleased]

## [1.2.3]"
    readme_case "the URL and the version are both named: the version" 1 \
        "README.md asks for version 1.2.3, the newest release heading of CHANGELOG.md is 1.3.0" \
        "$(swift_block "$app")" "${podspec_text//x\/Foo/y/Foo}" "## [1.3.0] - 2026-11-01"
    readme_case "the URL and the version are both named: the URL" 1 \
        "README.md installs from https://github.com/x/Foo.git, the podspec's source is https://github.com/y/Foo.git" \
        "$(swift_block "$app")" "${podspec_text//x\/Foo/y/Foo}" "## [1.3.0] - 2026-11-01"
    # A heading with a date part that is not a release date is not passed over like an unreleased section:
    # the newest release is the first one, and a heading skipped here would make an older version pass.
    padded="## [1.3.0] - 2026-11-01 "
    readme_case "a newest heading with a space after the date is named" 1 \
        "the newest release heading of CHANGELOG.md is not of the form '## [x.y.z] - YYYY-MM-DD': '## [1.3.0] - 2026-11-01 '" \
        "$(swift_block "$app")" "$podspec_text" "## [Unreleased]

$padded

$changelog_text"
    readme_case "a newest heading with a date that is not a day form is named" 1 \
        "the newest release heading of CHANGELOG.md is not of the form '## [x.y.z] - YYYY-MM-DD': '## [1.3.0] - 2026-11-1'" \
        "$(swift_block "$app")" "$podspec_text" "## [1.3.0] - 2026-11-1

$changelog_text"
    readme_case "a newest heading with a name for a version is named" 1 \
        "the newest release heading of CHANGELOG.md is not of the form '## [x.y.z] - YYYY-MM-DD': '## [Next] - 2026-11-01'" \
        "$(swift_block "$app")" "$podspec_text" "## [Next] - 2026-11-01

$changelog_text"
    readme_case "a newest heading with a note after the date is named" 1 \
        "the newest release heading of CHANGELOG.md is not of the form '## [x.y.z] - YYYY-MM-DD': '## [1.3.0] - 2026-11-01 [YANKED]'" \
        "$(swift_block "$app")" "$podspec_text" "## [1.3.0] - 2026-11-01 [YANKED]

$changelog_text"
    dash="$(printf '\342\200\223')"
    readme_case "a newest heading with an en dash is named" 1 \
        "the newest release heading of CHANGELOG.md is not of the form '## [x.y.z] - YYYY-MM-DD': '## [1.3.0] $dash 2026-11-01'" \
        "$(swift_block "$app")" "$podspec_text" "## [1.3.0] $dash 2026-11-01

$changelog_text"
    readme_case "an indented newest heading is named" 1 \
        "the newest release heading of CHANGELOG.md is not of the form '## [x.y.z] - YYYY-MM-DD': '   ## [1.3.0] - 2026-11-01'" \
        "$(swift_block "$app")" "$podspec_text" "   ## [1.3.0] - 2026-11-01

$changelog_text"
    # The source of the pod is the one line that is not a comment: an old source that was commented out
    # is neither the pod's source nor a second one.
    readme_case "a source that is commented out is not the source" 0 "1.2.3 Foo" "$(swift_block "$app")" \
        "# s.source = { :git => 'https://github.com/old/Foo.git', :tag => s.version.to_s }
$podspec_text"
    readme_case "a commented-out source that matches does not hide the live one" 1 \
        "README.md installs from https://github.com/x/Foo.git, the podspec's source is https://github.com/y/Foo.git" \
        "$(swift_block "$app")" \
        "  # s.source = { :git => 'https://github.com/x/Foo.git', :tag => s.version.to_s }
${podspec_text//x\/Foo/y/Foo}"
    readme_case "a podspec whose only source is commented out has none" 1 "the podspec has no source of the form :git => '<url>'" \
        "$(swift_block "$app")" "# $podspec_text"
    readme_case "a podspec with two sources is named" 1 "the podspec has 2 sources of the form :git => '<url>'; it must have one" \
        "$(swift_block "$app")" "$podspec_text
${podspec_text//x\/Foo/y/Foo}"
    got=0
    output="$(python3 "$SELF_TEST_WORK/readme.py" "$SELF_TEST_WORK/README.md" "$SELF_TEST_WORK/probe" \
        "$SELF_TEST_WORK/no-such.podspec" "$SELF_TEST_WORK/CHANGELOG.md" 2>&1)" || got=$?
    judge "a podspec that is not there" 1 "no-such.podspec cannot be read" "$got" "$output"
    got=0
    output="$(python3 "$SELF_TEST_WORK/readme.py" "$SELF_TEST_WORK/README.md" "$SELF_TEST_WORK/probe" \
        "$SELF_TEST_WORK/Package.podspec" "$SELF_TEST_WORK/no-such.md" 2>&1)" || got=$?
    judge "a changelog that is not there" 1 "no-such.md cannot be read" "$got" "$output"
    readme_case "no package manifest" 1 "has 0 package manifests" "$(swift_block 'let answer = 42')"
    readme_case "two package manifests" 1 "has 2 package manifests" "$(swift_block "$app")
$(swift_block "$app")"
    readme_case "a manifest in a fence that is not swift" 1 "has 0 package manifests" "~~~swift
$app
~~~"
    readme_case "exact: instead of from:" 1 "does not ask for the package with url: and from:" "$(swift_block "${app//from:/exact:}")"
    app_two='// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "App",
    dependencies: [
        .package(url: "https://github.com/x/Foo.git", from: "1.2.3"),
        .package(url: "https://github.com/x/Bar.git", from: "2.0.0")
    ],
    targets: [.target(name: "App")]
)'
    readme_case "two requirements with url: and from:" 1 "does not ask for the package with url: and from:" "$(swift_block "$app_two")"
    if [ "$failures" -gt 0 ]; then
        echo "check-manifest: self-test: $failures of $total checks failed" >&2
        exit 1
    fi
    echo "check-manifest: self-test: $total checks of the readers of the manifest, of the README and of Package.resolved, all ok."
    exit 0
}

if [ "$#" -gt 0 ]; then
    if [ "$1" = "--self-test" ] && [ "$#" -eq 1 ]; then
        self_test
    fi
    echo "usage: Scripts/check-manifest.sh [--self-test]" >&2
    exit 2
fi

WORK="$ROOT/.build/check-manifest"
FAILED=0

# The version probe and the build folders are throw-away. The logs next to them stay.
PROBE=""
DERIVED=""
SNIPPETS=""
SNIPPETS_DERIVED=""
# shellcheck disable=SC2329  # invoked by the trap below
cleanup() {  # The EXIT trap below calls it. skipcq: SH-2329
    [ -z "$PROBE" ] || rm -rf "$PROBE"
    [ -z "$DERIVED" ] || rm -rf "$DERIVED"
    [ -z "$SNIPPETS" ] || rm -rf "$SNIPPETS"
    [ -z "$SNIPPETS_DERIVED" ] || rm -rf "$SNIPPETS_DERIVED"
}
trap cleanup EXIT

mkdir -p "$WORK"

# 1. Static check of the manifest. The manifest that the tools of this machine choose is dumped for
#    the iOS floor that item 2 builds for. The rules are read on every manifest file of the package,
#    Package.swift and each Package@swift-*.swift: SwiftPM reads a version-specific manifest in place
#    of Package.swift when its version is above the tools version of Package.swift and not above the
#    tools, so the tools of a consumer may read what the tools of whoever runs this do not. Each file
#    is evaluated as the Package.swift of a folder of its own, which needs no sources.
swift package --package-path "$ROOT" dump-package > "$WORK/manifest.json"
rm -rf "$WORK/manifests"
mkdir -p "$WORK/manifests"
MANIFEST_NAMES=()
DUMPS=()
while IFS= read -r MANIFEST_FILE; do
    mkdir -p "$WORK/manifests/$MANIFEST_FILE.d"
    cp "$ROOT/$MANIFEST_FILE" "$WORK/manifests/$MANIFEST_FILE.d/Package.swift"
    # A file that does not evaluate leaves an empty dump, so that the reader names it as one that
    # cannot be read.
    if ! swift package --package-path "$WORK/manifests/$MANIFEST_FILE.d" dump-package \
            > "$WORK/manifests/$MANIFEST_FILE.json" 2> "$WORK/manifests/$MANIFEST_FILE.log"; then
        : > "$WORK/manifests/$MANIFEST_FILE.json"
        echo "check-manifest: $MANIFEST_FILE does not evaluate:" >&2
        head -5 "$WORK/manifests/$MANIFEST_FILE.log" | sed 's/^/  /' >&2
    fi
    MANIFEST_NAMES+=("$MANIFEST_FILE")
    DUMPS+=("$WORK/manifests/$MANIFEST_FILE.json")
done < <(git -C "$ROOT" ls-files -- 'Package*.swift')
if ! python3 - ${DUMPS[@]+"${DUMPS[@]}"} <<'PY'
# manifest-rules
import json
import os
import sys


def problems_of(path):
    try:
        with open(path, encoding="utf-8") as handle:
            manifest = json.load(handle)
        dependencies = manifest["dependencies"]
        targets = manifest["targets"]
        entries = [entry for dependency in dependencies for group in dependency.values() for entry in group]
        if not all(any(dependency.values()) for dependency in dependencies):
            raise TypeError("a dependency has no entry")
        if not all(isinstance(entry, dict) and isinstance(entry.get("requirement", {}), dict) for entry in entries):
            raise TypeError("a dependency is not described by an object")
        usages = [(target["name"], usage) for target in targets for usage in target.get("pluginUsages") or []]
        plugins = [target["name"] for target in targets if target["type"] == "plugin"]
        downloads = []
        for target in targets:
            if target["type"] == "binary":
                if isinstance(target.get("url"), str):
                    downloads.append((target["name"], target["url"]))
                elif not isinstance(target.get("path"), str):
                    raise TypeError(f"binary target '{target['name']}' has neither a url nor a path")
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        return [f"the manifest cannot be read: {error!r}"]
    found = []
    for entry in entries:
        found.append(
            f"dependency '{entry.get('identity')}' is declared: a dependency needs the maintainer's "
            "approval and a change of this check in the same pull request"
        )
        requirement = entry.get("requirement", {})
        for unstable in ("branch", "revision"):
            if unstable in requirement:
                found.append(
                    f"dependency '{entry.get('identity')}' is required by {unstable} "
                    f"{requirement[unstable]}"
                )
    for name, usage in usages:
        found.append(f"target '{name}' uses a plugin: {json.dumps(usage)}")
    for name in plugins:
        found.append(
            f"target '{name}' is a plugin: a plugin needs the maintainer's approval and a change of "
            "this check in the same pull request"
        )
    for name, url in downloads:
        found.append(
            f"target '{name}' is a binary fetched from {url}: code that is downloaded when the package "
            "is resolved needs the maintainer's approval and a change of this check in the same pull request"
        )
    return found


if len(sys.argv) < 2:
    print("check-manifest: the manifest cannot be read: no manifest was handed to the reader", file=sys.stderr)
    sys.exit(1)
problems = []
for path in sys.argv[1:]:
    # A dump is named after the manifest file it came from, with .json after it.
    label = os.path.basename(path)
    if label.endswith(".json"):
        label = label[: -len(".json")]
    problems.extend(f"{label}: {problem}" for problem in problems_of(path))
for problem in problems:
    print(f"check-manifest: {problem}", file=sys.stderr)
sys.exit(1 if problems else 0)
PY
then
    FAILED=1
else
    echo "check-manifest: no dependency, no plugin and no downloaded binary in ${MANIFEST_NAMES[*]}."
fi

# 2. The installation manifest of README.md, built by version against a throw-away tagged copy of
#    the tracked files. The copy is named after the last component of the README's URL, as SwiftPM
#    names the package it fetches from there, so the package name the README uses must match it.
#    A consumer that depends on the checkout by path cannot show a failure of a version
#    requirement, and only a build shows a wrong product or package name. The package is UIKit
#    and SwiftUI, so the consumer is built for the iOS simulator with the SDK of the machine, and
#    the iOS version of the triple is the package's own floor: a README that declares a lower
#    platform fails the build. The cache lies in the folder of the probe, so that manifests and
#    repositories cached on the machine of whoever runs this cannot stand in for what the build
#    resolves.
PROBE="$(mktemp -d "$WORK/version-probe.XXXXXX")"
mkdir -p "$PROBE/consumer"
# The probe repository takes nothing from the git configuration of whoever runs this: no signing,
# no hooks, no identity.
probe_git() {
    git -C "$PROBE/$COPY" \
        -c user.name=probe -c user.email=probe@example.invalid \
        -c commit.gpgsign=false -c tag.gpgSign=false -c core.hooksPath=/dev/null \
        -c core.excludesFile=/dev/null \
        "$@"
}
# Writes the consumer's manifest, and prints the version the README asks for and the name of the copy.
if ! ANSWER="$(python3 - "$ROOT/README.md" "$PROBE" "$ROOT/$MODULE.podspec" "$ROOT/CHANGELOG.md" <<'PY'
# readme-consumer
import re
import sys

readme, probe, podspec, changelog = sys.argv[1:5]
blocks = re.findall(r"^```swift\n(.*?)^```$", open(readme, encoding="utf-8").read(), re.S | re.M)
manifests = [block for block in blocks if "Package(" in block]
if len(manifests) != 1:
    sys.exit(f"check-manifest: README.md has {len(manifests)} package manifests; it must have one")
requirements = re.findall(r'\.package\(url: "([^"]+)", from: "([^"]+)"\)', manifests[0])
if len(requirements) != 1:
    sys.exit("check-manifest: the manifest of README.md does not ask for the package with url: and from:")
url, version = requirements[0]
texts = {}
for path in (podspec, changelog):
    try:
        with open(path, encoding="utf-8") as handle:
            texts[path] = handle.read()
    except (OSError, ValueError) as error:
        sys.exit(f"check-manifest: {path} cannot be read: {error}")
# The source of the pod is the one :git on a line that is not a comment: an old source that was
# commented out after the repository moved says nothing about where the pod is.
spec_lines = [line for line in texts[podspec].splitlines() if not line.lstrip().startswith("#")]
spec_urls = re.findall(r":git\s*=>\s*'([^']+)'", "\n".join(spec_lines))
# The pod is frozen, so the podspec no longer follows the releases. The version is that of the
# newest release heading, '## [x.y.z] - YYYY-MM-DD'. A heading with nothing after its bracket,
# such as Unreleased, is passed over: it is a normal state between two releases, and a tag is not
# there before the release, in a shallow clone, or in a pull request from a fork. Any other
# heading is a release heading and must have that form: one that is passed over for a space or a
# note after its date would let an older release stand in for the newest.
headings = re.findall(r"^ {0,3}## \[[^\]\n]*\][ \t]*[^ \t\n].*$", texts[changelog], re.M)
release = re.fullmatch(r"## \[([0-9]+\.[0-9]+\.[0-9]+)\] - [0-9]{4}-[0-9]{2}-[0-9]{2}", headings[0]) if headings else None
problems = []
if not spec_urls:
    problems.append("the podspec has no source of the form :git => '<url>'")
elif len(spec_urls) > 1:
    problems.append(f"the podspec has {len(spec_urls)} sources of the form :git => '<url>'; it must have one")
elif url != spec_urls[0]:
    problems.append(f"README.md installs from {url}, the podspec's source is {spec_urls[0]}")
if not headings:
    problems.append("CHANGELOG.md has no release heading of the form '## [x.y.z] - YYYY-MM-DD'")
elif not release:
    problems.append(f"the newest release heading of CHANGELOG.md is not of the form '## [x.y.z] - YYYY-MM-DD': '{headings[0]}'")
elif version != release.group(1):
    problems.append(f"README.md asks for version {version}, the newest release heading of CHANGELOG.md is {release.group(1)}")
if problems:
    sys.exit("\n".join(f"check-manifest: {problem}" for problem in problems))
# SwiftPM names a package it fetches after the last component of its URL.
copy = re.sub(r"\.git$", "", url.rstrip("/").split("/")[-1])
with open(f"{probe}/consumer/Package.swift", "w", encoding="utf-8") as consumer:
    consumer.write(manifests[0].replace(f'url: "{url}"', f'url: "file://{probe}/{copy}"'))
print(version, copy)
PY
)"; then
    FAILED=1
else
    read -r VERSION COPY <<< "$ANSWER"
    mkdir -p "$PROBE/$COPY"
    # Without -l, rsync skips a symbolic link and says so only in a warning: the counts below
    # would show it.
    # A manifest for one version of the tools, Package@swift-6.3.swift, is part of the package:
    # SwiftPM reads it in place of Package.swift when it is the newest one the tools can use.
    (cd "$ROOT" && git ls-files -z -- 'Package*.swift' Sources | xargs -0 -I{} rsync -Rl {} "$PROBE/$COPY/")
    COPIED="$(cd "$PROBE/$COPY" && find . \( -type f -o -type l \) | wc -l | tr -d ' ')"
    TRACKED="$(git -C "$ROOT" ls-files -- 'Package*.swift' Sources | wc -l | tr -d ' ')"
    if [ "$COPIED" -eq "$TRACKED" ]; then
        # SwiftPM resolves the copy as soon as it reads the consumer's manifest.
        probe_git init -q
        probe_git add -A
        probe_git commit -q -m probe
        probe_git tag "$VERSION"
        # What the tag holds, not what was copied: a file that git leaves out of the commit would
        # make the build below pass on a package that is not the tracked one.
        COPIED="$(probe_git ls-tree -r --name-only HEAD | wc -l | tr -d ' ')"
    fi
    if [ "$COPIED" -ne "$TRACKED" ]; then
        echo "check-manifest: the tagged copy holds $COPIED of the $TRACKED tracked files of the package" >&2
        FAILED=1
    elif ! IOS_FLOOR="$(python3 -c 'import json, sys; print(next(p["version"] for p in json.load(open(sys.argv[1]))["platforms"] if p["platformName"] == "ios"))' \
            "$WORK/manifest.json" 2> "$WORK/ios-floor.log")"; then
        echo "check-manifest: Package.swift declares no iOS platform, or its platforms cannot be read, so the consumer cannot be built for the simulator:" >&2
        tail -3 "$WORK/ios-floor.log" | sed 's/^/  /' >&2
        FAILED=1
    elif ! SIMULATOR_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"; then
        echo "check-manifest: the SDK of the iOS simulator cannot be found" >&2
        FAILED=1
    elif ! swift package --package-path "$PROBE/consumer" dump-package \
            > "$WORK/readme-manifest.json" 2> "$WORK/readme-manifest.log"; then
        echo "check-manifest: the manifest of README.md does not evaluate:" >&2
        head -10 "$WORK/readme-manifest.log" | sed 's/^/  /' >&2
        FAILED=1
    elif ! TARGETS="$(python3 -c 'import json, sys; print("\n".join(t["name"] for t in json.load(sys.stdin)["targets"]))' \
            < "$WORK/readme-manifest.json")"; then
        echo "check-manifest: the targets of the README's manifest cannot be read" >&2
        FAILED=1
    elif [ -z "$TARGETS" ]; then
        echo "check-manifest: the manifest of README.md has no target to build" >&2
        FAILED=1
    else
        # Every target of the consumer gets a source file that imports the module.
        while IFS= read -r TARGET; do
            mkdir -p "$PROBE/consumer/Sources/$TARGET"
            echo "import $MODULE" > "$PROBE/consumer/Sources/$TARGET/$TARGET.swift"
        done <<< "$TARGETS"
        if swift build --package-path "$PROBE/consumer" --cache-path "$PROBE/cache" \
                --sdk "$SIMULATOR_SDK" --triple "arm64-apple-ios${IOS_FLOOR}-simulator" \
                > "$WORK/version-build.log" 2>&1; then
            # What the build resolved, as SwiftPM pinned it: the tagged copy and nothing else.
            if EXTRA="$(python3 - "$PROBE/consumer/Package.resolved" "$COPY" <<'PY'
# resolved-inventory
import json
import sys

path, copy = sys.argv[1:3]
expected = copy.lower()
try:
    with open(path, encoding="utf-8") as handle:
        resolved = json.load(handle)
except (OSError, ValueError) as error:
    print(f"  Package.resolved cannot be read: {error}")
    sys.exit(1)
readable = isinstance(resolved, dict) and resolved.get("version") in (2, 3) and isinstance(resolved.get("pins"), list)
if not readable or not all(isinstance(pin, dict) for pin in resolved["pins"]):
    print("  Package.resolved is not of format version 2 or 3 with a list of pins, and only those are read")
    sys.exit(1)
identities = [pin.get("identity") for pin in resolved["pins"]]
problems = []
for pin in resolved["pins"]:
    if pin.get("identity") != expected:
        state = pin.get("state")
        if not isinstance(state, dict):
            state = {}
        problems.append(f"  {pin.get('identity')} ({pin.get('kind')}, {state.get('version') or state.get('revision')}, {pin.get('location')})")
if identities.count(expected) == 0:
    problems.append(f"  {expected}, the tagged copy, is not among the resolved packages")
elif identities.count(expected) > 1:
    problems.append(f"  {expected}, the tagged copy, is pinned {identities.count(expected)} times")
print("\n".join(problems))
sys.exit(1 if problems else 0)
PY
)"; then
                echo "check-manifest: the manifest of README.md, pointed at a copy tagged $VERSION, resolves and builds for the iOS $IOS_FLOOR simulator, and the consumer resolves this package only."
            else
                echo "check-manifest: the consumer of README.md's manifest does not resolve this package only:" >&2
                printf '%s\n' "$EXTRA" >&2
                FAILED=1
            fi
        else
            echo "check-manifest: the manifest of README.md does not resolve or build by version:" >&2
            ERRORS="$(grep -E "error:|cannot be used|unstable|unsafe" "$WORK/version-build.log" | cut -c1-300 | head -5 || true)"
            if [ -n "$ERRORS" ]; then
                printf '%s\n' "$ERRORS" >&2
            else
                tail -15 "$WORK/version-build.log" | sed 's/^/  /' >&2
            fi
            FAILED=1
        fi
    fi
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
