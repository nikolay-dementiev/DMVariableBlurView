#!/bin/bash
#
# Checks a release version against the changelog, and that the podspec names the frozen version.
#
#   Scripts/check-release.sh <version>           check; exit 1 if not ready, 2 if it cannot compare
#   Scripts/check-release.sh --notes <version>   print the changelog section of that version
#   Scripts/check-release.sh --self-test         run the decisions of this script in scratch repositories
#
# A release starts from a tag that is the version itself, such as 1.1.0. The newest heading of
# CHANGELOG.md must be `## [1.1.0] - YYYY-MM-DD`, with the date of the release. The release notes
# are the section under that heading. The pod is frozen: the podspec stays at the last version
# published to the trunk, FROZEN_POD_VERSION below, whatever the release version is. The release
# workflow runs this script on the tag; run it before you push one.
#
# The release is also compared with the one before it, the heading below the newest. It must raise
# the major version when the baseline lost or changed a line since the tag of that release
# (Scripts/check-api.sh --since), or when its notes have a `### Breaking changes` subsection, where
# a change of behaviour is declared because no script can see one. Lines that were only added pass
# with a reminder to review them. The first release has none before it and is not compared, and
# neither is a release that holds no baseline; the script says so. A tag that is not in the
# repository, or a comparison that cannot run, is exit 2, never a pass. Run Scripts/check-api.sh
# first: the baseline is the interface of the library only while that check passes. The heading of
# the subsection is matched in any letter case.
#
# Exit codes: 0 ready, 1 not ready, 2 wrong usage or the comparison could not run.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG="$ROOT/CHANGELOG.md"
PODSPEC="$ROOT/DMVariableBlurView.podspec"
# The CocoaPods channel ended with 1.1.0 (README, "CocoaPods"). The podspec stays at that
# version; the release version is checked against the changelog alone.
FROZEN_POD_VERSION="1.1.0"

# Runs the decisions of this script in scratch repositories, and exits. A case builds a repository
# with a changelog, a podspec, tags and baselines, runs a copy of this script in it, and compares
# the exit status and a line of the output with what the case expects. The comparison of the
# interface is the real Scripts/check-api.sh --since on baselines committed at the tags, which needs
# git and python3 and no compiler; a stub takes its place only for a status that the real script
# cannot be made to give.
SELF_TEST_WORK=""
self_test() {
    local total=0 failures=0 number=0 variable absent_note tool tool_path no_python broken_python
    local git_local=()
    if ! command -v python3 > /dev/null 2>&1 || ! python3 -c 'import datetime' > /dev/null 2>&1; then
        echo "check-release: self-test: python3 is needed, and it does not run on this machine" >&2
        exit 2
    fi
    SELF_TEST_WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-release-self-test.XXXXXX")" || exit 2
    trap 'rm -rf "$SELF_TEST_WORK"' EXIT
    # The scratch repositories are kept apart from the environment of the caller: GIT_DIR and the
    # other variables that git lists with rev-parse --local-env-vars would point git at the
    # repository of the caller, and a global setting of hooks or signing would stop the commits.
    for variable in $(git rev-parse --local-env-vars); do
        git_local+=(-u "$variable")
    done
    # Two interpreters that are not the one of the machine: a PATH that holds the tools of the script
    # and no python3, and a python3 that starts and then fails at everything but the import that is
    # tried first.
    no_python="$SELF_TEST_WORK/no-python"
    broken_python="$SELF_TEST_WORK/broken-python"
    mkdir -p "$no_python" "$broken_python"
    for tool in git sed awk grep head tail tr cut wc cat dirname basename mktemp rm mkdir env date sort uniq xargs find; do
        tool_path="$(command -v "$tool")" || continue
        ln -s "$tool_path" "$no_python/$tool"
    done
    cat > "$broken_python/python3" <<'SHIM'
#!/bin/sh
if [ "$2" = "import datetime" ]; then
    exit 0
fi
echo "python3: cannot run this program" >&2
exit 1
SHIM
    chmod +x "$broken_python/python3"
    scratch_git() {  # <directory> <git arguments>
        local directory="$1"
        shift
        env ${git_local[@]+"${git_local[@]}"} GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
            git -C "$directory" -c init.defaultBranch=main -c user.name=check-release \
            -c user.email=check-release@example.invalid -c commit.gpgsign=false -c tag.gpgSign=false \
            -c core.hooksPath=/dev/null "$@"
    }
    baseline_text() {  # <name>: the text of a baseline
        case "$1" in
            keep) printf 'public struct First {\n  public func keep()\n}\n' ;;
            added) printf 'public struct First {\n  public func keep()\n  public func more()\n}\n' ;;
            removed) printf 'public struct First {\n}\n' ;;
            *)
                echo "check-release: self-test: no baseline named '$1'" >&2
                exit 2
                ;;
        esac
    }
    reset_case() {
        S_VERSION="1.1.0" S_NEWEST="" S_PREVIOUS="1.0.0" S_DATE="2026-10-03" S_SUBSECTION=""
        S_PODSPEC="$FROZEN_POD_VERSION" S_OLD="keep" S_NEW="keep" S_TAG="main" S_TAG_BASELINE="yes"
        S_API="real" S_STUB_STATUS="" S_STUB_TEXT="" S_NOTES="no" S_ABSENT="" S_PYTHON="real" S_DIGESTER="none"
    }
    apply() {  # <setting>=<value> ...
        local setting
        for setting in "$@"; do
            case "$setting" in
                version=*) S_VERSION="${setting#version=}" ;;
                newest=*) S_NEWEST="${setting#newest=}" ;;
                previous=*) S_PREVIOUS="${setting#previous=}" ;;
                date=*) S_DATE="${setting#date=}" ;;
                subsection=*) S_SUBSECTION="${setting#subsection=}" ;;
                podspec=*) S_PODSPEC="${setting#podspec=}" ;;
                old=*) S_OLD="${setting#old=}" ;;
                new=*) S_NEW="${setting#new=}" ;;
                tag=*) S_TAG="${setting#tag=}" ;;
                tagbaseline=*) S_TAG_BASELINE="${setting#tagbaseline=}" ;;
                api=*) S_API="${setting#api=}" ;;
                status=*) S_STUB_STATUS="${setting#status=}" ;;
                text=*) S_STUB_TEXT="${setting#text=}" ;;
                notes=*) S_NOTES="${setting#notes=}" ;;
                absent=*) S_ABSENT="${setting#absent=}" ;;
                python=*) S_PYTHON="${setting#python=}" ;;
                digester=*) S_DIGESTER="${setting#digester=}" ;;
                *)
                    echo "check-release: self-test: unknown setting '$setting'" >&2
                    exit 2
                    ;;
            esac
        done
    }
    # The repository a case describes. The release before this one is committed, with its baseline,
    # and tagged: on the line of main, on a side branch that main does not contain, or not at all.
    build_repo() {  # <directory>
        local directory="$1" podspec_name
        podspec_name="$(basename "$PODSPEC")"
        mkdir -p "$directory/Scripts" "$directory/Fixtures/API"
        scratch_git "$directory" init -q
        printf 'base\n' > "$directory/README"
        scratch_git "$directory" add README
        scratch_git "$directory" commit -q -m base
        if [ -n "$S_PREVIOUS" ]; then
            if [ "$S_TAG" = "side" ]; then
                scratch_git "$directory" switch -q -c side
            fi
            if [ "$S_TAG_BASELINE" = "yes" ]; then
                baseline_text "$S_OLD" > "$directory/Fixtures/API/public-interface.txt"
                scratch_git "$directory" add -f Fixtures/API/public-interface.txt
            else
                printf 'earlier\n' > "$directory/earlier"
                scratch_git "$directory" add earlier
            fi
            scratch_git "$directory" commit -q -m "the previous release"
            if [ "$S_TAG" != "missing" ]; then
                scratch_git "$directory" tag "$S_PREVIOUS"
            fi
            if [ "$S_TAG" = "side" ]; then
                scratch_git "$directory" switch -q main
            fi
        fi
        {
            printf '## [%s] - %s\n\n' "${S_NEWEST:-$S_VERSION}" "$S_DATE"
            if [ -n "$S_SUBSECTION" ]; then
                printf '%s\n\n- a behaviour changed\n\n' "$S_SUBSECTION"
            fi
            printf -- '- a change\n'
            if [ -n "$S_PREVIOUS" ]; then
                printf '\n## [%s] - 2025-10-11\n\n- earlier\n' "$S_PREVIOUS"
            fi
        } > "$directory/CHANGELOG.md"
        printf "Pod::Spec.new do |s|\n  s.version = '%s'\nend\n" "$S_PODSPEC" > "$directory/$podspec_name"
        baseline_text "$S_NEW" > "$directory/Fixtures/API/public-interface.txt"
        scratch_git "$directory" add -f CHANGELOG.md "$podspec_name" Fixtures/API/public-interface.txt
        scratch_git "$directory" commit -q -m "the release"
        cp "${BASH_SOURCE[0]}" "$directory/Scripts/check-release.sh"
        if [ "$S_API" = "stub" ]; then
            printf '#!/bin/bash\necho "%s"\nexit %s\n' "$S_STUB_TEXT" "$S_STUB_STATUS" > "$directory/Scripts/check-api.sh"
        else
            cp "$ROOT/Scripts/check-api.sh" "$directory/Scripts/check-api.sh"
        fi
        chmod +x "$directory/Scripts/check-release.sh" "$directory/Scripts/check-api.sh"
        if [ "$S_DIGESTER" != "none" ]; then
            case "$S_DIGESTER" in
                ok) printf '#!/bin/bash\necho "no break"\nexit 0\n' ;;
                break) printf '#!/bin/bash\necho "a break"\nexit 1\n' ;;
                fail) printf '#!/bin/bash\necho "cannot run"\nexit 3\n' ;;
                *)
                    echo "check-release: self-test: no digester named '$S_DIGESTER'" >&2
                    exit 2
                    ;;
            esac > "$directory/Scripts/check-api-digester.sh"
            chmod +x "$directory/Scripts/check-api-digester.sh"
        fi
    }
    judge() {  # <name> <expected status> <expected text> <status> <output> <text that must be absent>
        total=$((total + 1))
        if [ "$4" -eq "$2" ] && grep -q -F -- "$3" <<< "$5" && { [ -z "$6" ] || ! grep -q -F -- "$6" <<< "$5"; }; then
            echo "check-release: self-test ok   $1"
        else
            failures=$((failures + 1))
            absent_note=""
            if [ -n "$6" ]; then
                absent_note=" without \"$6\""
            fi
            echo "check-release: self-test FAIL $1: expected status $2 and \"$3\"$absent_note, got status $4:" >&2
            sed -n '1,6p' <<< "$5" | sed 's/^/    /' >&2
        fi
    }
    run_case() {  # <name> <expected status> <expected text> [<setting>=<value> ...]
        local name="$1" expected_status="$2" expected_text="$3" directory output status=0 run_path="$PATH"
        local arguments=()
        shift 3
        number=$((number + 1))
        reset_case
        apply "$@"
        case "$S_PYTHON" in
            real) ;;
            none) run_path="$no_python" ;;
            broken) run_path="$broken_python:$PATH" ;;
            *)
                echo "check-release: self-test: no python named '$S_PYTHON'" >&2
                exit 2
                ;;
        esac
        directory="$SELF_TEST_WORK/case-$number"
        build_repo "$directory"
        if [ "$S_NOTES" = "yes" ]; then
            arguments=(--notes "$S_VERSION")
        else
            arguments=("$S_VERSION")
        fi
        output="$(env ${git_local[@]+"${git_local[@]}"} PATH="$run_path" /bin/bash "$directory/Scripts/check-release.sh" "${arguments[@]}" 2>&1)" || status=$?
        judge "$name" "$expected_status" "$expected_text" "$status" "$output" "$S_ABSENT"
    }

    run_case "an additive release passes with the reminder" 0 "lines were added to the interface" new=added
    run_case "a removed line under the same major fails" 1 "needs a new major version" new=removed
    run_case "a removed line under a new major passes" 0 "agrees on 2.0.0" version=2.0.0 new=removed
    run_case "a breaking subsection in lower case under the same major fails" 1 "'### Breaking changes' subsection" "subsection=### breaking changes"
    run_case "a breaking subsection in title case under the same major fails" 1 "'### Breaking changes' subsection" "subsection=### Breaking Changes"
    run_case "a breaking subsection in upper case under the same major fails" 1 "'### Breaking changes' subsection" "subsection=### BREAKING CHANGES"
    run_case "a breaking subsection under a new major passes" 0 "agrees on 2.0.0" version=2.0.0 "subsection=### Breaking changes"
    run_case "the first release is not compared" 0 "no release below" previous=
    run_case "the newest heading is for another version" 1 "the newest changelog heading is for 1.2.0, not 1.1.0" newest=1.2.0
    run_case "an impossible date" 1 "not a day of the calendar" date=2026-02-30
    run_case "a date of the wrong form" 1 "where the release date belongs" date=soon
    run_case "a podspec at another version" 1 "the pod is frozen at" podspec=1.0.0
    run_case "the heading below is not a release version" 1 "is not a release version" previous=Unreleased
    run_case "the tag of the previous release is missing" 2 "is not in this repository" tag=missing
    run_case "a previous release that holds no baseline" 0 "holds no baseline" tagbaseline=no
    run_case "a status of the comparison that is not known" 2 "could not be compared" api=stub status=5 text=boom
    run_case "a crash of the comparison" 2 "could not be compared" api=stub status=1 text=boom
    run_case "the notes of a version" 0 "a change" notes=yes
    run_case "the notes of a version that has none" 1 "has no notes under a heading for 9.9.9" notes=yes newest=1.1.0 version=9.9.9
    run_case "no digester script: nothing is said about it" 0 "agrees on 1.1.0" absent=digester
    run_case "no python3: the problems found so far are listed" 2 "the pod is frozen at" python=none podspec=1.0.0 "absent=not a day of the calendar"
    run_case "no python3: the script says that it needs it" 2 "python3 is needed to read the release date" python=none
    run_case "a python3 that fails: the problems found so far are listed" 2 "the pod is frozen at" python=broken podspec=1.0.0 "absent=not a day of the calendar"
    run_case "a python3 that fails: the script says what it said" 2 "python3 could not check the release date" python=broken
    run_case "the digester finds a break under the same major" 1 "the digester reports a break" digester=break
    run_case "the digester finds no break" 0 "the digester finds no break" digester=ok
    run_case "the digester is not asked under a new major" 0 "agrees on 2.0.0" version=2.0.0 digester=break absent=digester
    run_case "the digester cannot compare" 2 "the digester could not compare" digester=fail
    run_case "the digester is not asked after a comparison that could not run" 2 "could not be compared" api=stub status=5 text=boom digester=break absent=digester
    run_case "the digester is told that the previous release holds no baseline" 0 "the digester was not run against 1.0.0" tagbaseline=no digester=ok

    if [ "$total" -eq 0 ]; then
        echo "check-release: self-test: no case ran" >&2
        exit 2
    fi
    if [ "$failures" -gt 0 ]; then
        echo "check-release: self-test: $failures of $total cases failed" >&2
        exit 1
    fi
    echo "check-release: self-test: $total cases of the decisions of this script, all ok."
    exit 0
}

if [ "${1:-}" = "--self-test" ]; then
    if [ "$#" -ne 1 ]; then
        echo "usage: Scripts/check-release.sh --self-test" >&2
        exit 2
    fi
    self_test
fi

NOTES=0
if [ "${1:-}" = "--notes" ]; then
    NOTES=1
    shift
fi
VERSION="${1:-}"

# The checks of this script are case patterns, because a regular-expression match is undefined
# in POSIX sh. A version is three groups of digits joined by dots, such as 1.1.0: nothing but
# digits and dots, no leading, trailing or doubled dot, and exactly two dots.
valid_version() {
    case "$1" in
        '' | .* | *. | *..* | *[!0123456789.]* | *.*.*.*) return 1 ;;
        *.*.*) return 0 ;;
    esac
    return 1
}

if ! valid_version "$VERSION"; then
    echo "usage: Scripts/check-release.sh [--notes] <version>, a version such as 1.1.0" >&2
    exit 2
fi

# The lines between the version's heading and the next release heading, without the blank lines
# at either end. Empty when the version has no heading or nothing under it.
notes() {
    awk -v heading="## [$VERSION]" '
        index($0, heading) == 1 { inside = 1; next }
        inside && /^## \[/ { exit }
        inside { lines[++count] = $0 }
        END {
            first = 1; while (first <= count && lines[first] == "") first++
            last = count; while (last >= first && lines[last] == "") last--
            for (line = first; line <= last; line++) print lines[line]
        }
    ' "$CHANGELOG"
}

if [ "$NOTES" -eq 1 ]; then
    TEXT="$(notes)"
    if [ -z "$TEXT" ]; then
        echo "check-release: CHANGELOG.md has no notes under a heading for $VERSION" >&2
        exit 1
    fi
    printf '%s\n' "$TEXT"
    exit 0
fi

PROBLEMS=()

if [ -z "$(notes)" ]; then
    PROBLEMS+=("CHANGELOG.md has no notes under a heading for $VERSION")
fi

PODSPEC_VERSION="$(sed -n "s/^ *s\.version *= *'\([^']*\)'.*/\1/p" "$PODSPEC")"
if [ "$PODSPEC_VERSION" != "$FROZEN_POD_VERSION" ]; then
    PROBLEMS+=("the podspec names version '$PODSPEC_VERSION'; the pod is frozen at $FROZEN_POD_VERSION")
fi

# A release date is four digits, a dash, two digits, a dash and two digits, such as 2026-10-03.
# Whether that day exists is asked of python3 below.
valid_date_form() {
    case "$1" in
        [0123456789][0123456789][0123456789][0123456789]-[0123456789][0123456789]-[0123456789][0123456789]) return 0 ;;
    esac
    return 1
}

# The version and the date of the newest release heading, '## [version] - date'. sed prints them
# only when the whole heading has that form, and it reads the heading as bytes, so that no locale
# stops it on a character of the heading. A heading with an empty version does not have the form.
NEWEST="$(grep -m 1 -E '^## \[' "$CHANGELOG" || true)"
HEADING_VERSION="$(printf '%s\n' "$NEWEST" | LC_ALL=C sed -n 's/^## \[\([^]]*\)\] - \(.*\)$/\1/p')"
HEADING_DATE="$(printf '%s\n' "$NEWEST" | LC_ALL=C sed -n 's/^## \[\([^]]*\)\] - \(.*\)$/\2/p')"
if [ -n "$HEADING_VERSION" ]; then
    if [ "$HEADING_VERSION" != "$VERSION" ]; then
        PROBLEMS+=("the newest changelog heading is for $HEADING_VERSION, not $VERSION")
    elif ! valid_date_form "$HEADING_DATE"; then
        PROBLEMS+=("the changelog heading of $VERSION has '$HEADING_DATE' where the release date belongs")
    elif ! python3 -c 'import datetime, sys; datetime.date.fromisoformat(sys.argv[1])' "$HEADING_DATE" 2> /dev/null; then
        PROBLEMS+=("the changelog heading of $VERSION has '$HEADING_DATE', which is not a day of the calendar")
    fi
else
    PROBLEMS+=("CHANGELOG.md has no heading of the form '## [version] - date'")
fi

# The release before this one is the version of the second release heading. It has no meaning when
# the newest heading is for another version, which is a problem already.
COULD_NOT_COMPARE=0
if [ "$HEADING_VERSION" = "$VERSION" ]; then
    PREVIOUS_HEADING="$(LC_ALL=C awk '/^## \[/ { count++ } count == 2 { print; exit }' "$CHANGELOG")"
    if [ -z "$PREVIOUS_HEADING" ]; then
        echo "check-release: CHANGELOG.md has no release below $VERSION, so the interface was not compared."
    else
        PREVIOUS="$(printf '%s\n' "$PREVIOUS_HEADING" | LC_ALL=C sed -n 's/^## \[\([^]]*\)\].*$/\1/p')"
        if ! valid_version "$PREVIOUS"; then
            PROBLEMS+=("the changelog heading below $VERSION is not a release version: '$PREVIOUS_HEADING'")
        else
            RAISES_MAJOR=0
            if [ "${VERSION%%.*}" -gt "${PREVIOUS%%.*}" ]; then
                RAISES_MAJOR=1
            fi
            BREAKING="$(notes | grep -c -i -E '^### Breaking changes[[:space:]]*$' || true)"
            if [ "$BREAKING" -gt 0 ] && [ "$RAISES_MAJOR" -eq 0 ]; then
                PROBLEMS+=("the notes of $VERSION have a '### Breaking changes' subsection: that needs a new major version, and $VERSION does not raise the major version of $PREVIOUS")
            fi
            if ! git -C "$ROOT" rev-parse --verify --quiet "refs/tags/$PREVIOUS^{commit}" > /dev/null; then
                PROBLEMS+=("the tag $PREVIOUS of the release below $VERSION is not in this repository, so the interface cannot be compared: git fetch --tags")
                COULD_NOT_COMPARE=1
            else
                DELTA_STATUS=0
                DELTA="$("$ROOT/Scripts/check-api.sh" --since "$PREVIOUS" 2>&1)" || DELTA_STATUS=$?
                case "$DELTA_STATUS" in
                    0) ;;
                    1)
                        # A script that stops on an error exits with 1 as well, so the exit code
                        # counts only with the heading of the lines that were removed or changed.
                        case "$DELTA" in
                            *"Removed or changed"*)
                                if [ "$RAISES_MAJOR" -eq 0 ]; then
                                    PROBLEMS+=("the interface lost or changed lines since $PREVIOUS (Scripts/check-api.sh --since $PREVIOUS lists them): that needs a new major version, and $VERSION does not raise the major version of $PREVIOUS")
                                fi
                                ;;
                            *)
                                PROBLEMS+=("the interface could not be compared with $PREVIOUS: $(printf '%s\n' "$DELTA" | sed -n '1p')")
                                COULD_NOT_COMPARE=1
                                ;;
                        esac
                        ;;
                    3)
                        echo "check-release: lines were added to the interface since $PREVIOUS. Review that none adds a protocol requirement or an overload that makes a call ambiguous: either needs a new major version."
                        ;;
                    4)
                        echo "check-release: the interface was not compared with $PREVIOUS: that release holds no baseline."
                        ;;
                    *)
                        PROBLEMS+=("the interface could not be compared with $PREVIOUS: $(printf '%s\n' "$DELTA" | sed -n '1p')")
                        COULD_NOT_COMPARE=1
                        ;;
                esac
            fi
        fi
    fi
fi

if [ "${#PROBLEMS[@]}" -gt 0 ]; then
    echo "check-release: $VERSION is not ready to release:" >&2
    printf '  - %s\n' "${PROBLEMS[@]}" >&2
    if [ "$COULD_NOT_COMPARE" -eq 1 ]; then
        exit 2
    fi
    exit 1
fi
echo "check-release: the changelog agrees on $VERSION, released $HEADING_DATE; the pod stays at $FROZEN_POD_VERSION."
