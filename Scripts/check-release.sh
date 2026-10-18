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
# The release is also compared with the one before it. That release comes from the tags: it is the
# highest release tag (three groups of digits) below the version that the commit reaches, and the
# heading right below the newest one in the changelog has to name it. A heading of another form, one
# that is not lower than the version, one that skips a reachable release tag, and a changelog with
# no heading below although a release tag is reachable are each a problem. The release must raise
# the major version when the baseline lost or changed a line since the tag of that release
# (Scripts/check-api.sh --since), or when its notes have a heading of breaking changes, where a
# change of behaviour is declared because no script can see one: a heading of any level, or a line
# that opens with bold text, whose first word is "breaking", in any letter case, with blanks,
# punctuation or an emoji in front of it. A heading that says there are none ("No breaking
# changes") does not count. Lines that were only added pass with a reminder to review them, which is
# also a warning annotation under GitHub Actions. The first release has none before it and is not
# compared, and neither is a release that holds no baseline; the script says so. A clone with no
# tags and a changelog with a single release heading is read as the first release. A tag that is
# not in the repository, or a comparison that cannot run, is exit 2, never a pass. Run
# Scripts/check-api.sh first: the baseline is the interface of the library only while that check
# passes. The tag of the release before it must also be an ancestor of the commit being released: a
# tag on a side branch is a problem. A shallow clone cannot say which release is below the version,
# so it is exit 2 in every case. The reminder for added lines names an added case of a public enum,
# a protocol requirement without a default implementation and an overload that makes an existing
# call ambiguous as breaking; it cannot see which of them an added line is.
#
# --self-test builds a scratch repository for each decision and runs a copy of this script in it,
# with the real Scripts/check-api.sh --since, a python3 that is missing or fails, and a digester
# that finds a break or cannot run. It needs git and python3, and no compiler.
#
# Where Scripts/check-api-digester.sh exists, a release that keeps its major version is also
# compared with the previous one by swift-api-digester, which classifies what lines cannot, such as
# a protocol requirement added without a default: a break it reports needs a new major version too.
# The script is called with the previous version. It ends with status 0 for no break; with status 1
# for a break, and then prints a line of the form 'N breaking change(s) detected in <module>' (behind
# the name of the script or not) and what broke, which is printed here; any other status, or
# status 1 without that line, is a comparison that could not be made and is exit 2.
# In a repository without that script this does nothing.
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
    local real_git no_merge_base old_git
    local git_local=()
    # The cases run copies of this script, which carry the same PODSPEC line: a name that is wrong
    # would be wrong in every copy and pass. The file it names has to be in this repository.
    if [ ! -f "$PODSPEC" ]; then
        echo "check-release: self-test: the podspec ${PODSPEC#"$ROOT"/} does not exist; PODSPEC at the top of this script names it" >&2
        exit 2
    fi
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
    # Two gits that answer wrongly where the script asks them something: one cannot tell whether a
    # commit is an ancestor (status 128), the other is older than the flag that tells a shallow clone
    # (git before 2.15 prints the flag back and succeeds).
    real_git="$(command -v git)"
    no_merge_base="$SELF_TEST_WORK/git-without-merge-base"
    old_git="$SELF_TEST_WORK/git-before-2-15"
    mkdir -p "$no_merge_base" "$old_git"
    # The single quotes write the shims as they are; their $@ and $argument are for the shim.
    # shellcheck disable=SC2016
    printf '#!/bin/sh\nfor argument in "$@"; do\n    if [ "$argument" = merge-base ]; then\n        echo "fatal: merge-base is out of order" >&2\n        exit 128\n    fi\ndone\nexec "%s" "$@"\n' "$real_git" > "$no_merge_base/git"
    # shellcheck disable=SC2016
    printf '#!/bin/sh\nfor argument in "$@"; do\n    if [ "$argument" = --is-shallow-repository ]; then\n        echo "--is-shallow-repository"\n        exit 0\n    fi\ndone\nexec "%s" "$@"\n' "$real_git" > "$old_git/git"
    chmod +x "$no_merge_base/git" "$old_git/git"
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
            gone) printf 'public struct Other {\n}\n' ;;
            *)
                echo "check-release: self-test: no baseline named '$1'" >&2
                exit 2
                ;;
        esac
    }
    reset_case() {
        S_VERSION="1.1.0" S_NEWEST="" S_PREVIOUS="1.0.0" S_DATE="2026-10-03" S_SUBSECTION=""
        S_PODSPEC="$FROZEN_POD_VERSION" S_OLD="keep" S_NEW="keep" S_TAG="main" S_TAG_BASELINE="yes"
        S_API="real" S_STUB_STATUS="" S_STUB_TEXT="" S_NOTES="no" S_ABSENT="" S_PYTHON="real" S_DIGESTER="none" S_SHALLOW="no" S_GIT="real"
        S_NODATE="no" S_EMPTY="no" S_NOPODSPEC="no" S_TAGS="" S_BELOW="" S_HEADTAG="no" S_ACTIONS="no"
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
                shallow=*) S_SHALLOW="${setting#shallow=}" ;;
                git=*) S_GIT="${setting#git=}" ;;
                nodate=*) S_NODATE="${setting#nodate=}" ;;
                empty=*) S_EMPTY="${setting#empty=}" ;;
                nopodspec=*) S_NOPODSPEC="${setting#nopodspec=}" ;;
                tags=*) S_TAGS="${setting#tags=}" ;;
                below=*) S_BELOW="${setting#below=}" ;;
                headtag=*) S_HEADTAG="${setting#headtag=}" ;;
                actions=*) S_ACTIONS="${setting#actions=}" ;;
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
        local directory="$1" podspec_name tag_spec tag_name tag_baseline
        local tag_specs=()
        podspec_name="$(basename "$PODSPEC")"
        mkdir -p "$directory/Scripts" "$directory/Fixtures/API"
        scratch_git "$directory" init -q
        printf 'base\n' > "$directory/README"
        scratch_git "$directory" add README
        scratch_git "$directory" commit -q -m base
        # Several release tags in order, each with its baseline: tags=1.0.0:keep,2.0.0:removed. They take
        # the place of the one tag of the previous release below.
        if [ -n "$S_TAGS" ]; then
            IFS=, read -r -a tag_specs <<< "$S_TAGS"
            for tag_spec in "${tag_specs[@]}"; do
                tag_name="${tag_spec%%:*}"
                tag_baseline="${tag_spec#*:}"
                baseline_text "$tag_baseline" > "$directory/Fixtures/API/public-interface.txt"
                scratch_git "$directory" add -f Fixtures/API/public-interface.txt
                printf '%s\n' "$tag_name" > "$directory/marker"
                scratch_git "$directory" add marker
                scratch_git "$directory" commit -q -m "release $tag_name"
                scratch_git "$directory" tag "$tag_name"
            done
        fi
        if [ -n "$S_PREVIOUS" ] && [ -z "$S_TAGS" ]; then
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
            if [ "$S_NODATE" = "yes" ]; then
                printf '## [%s]\n\n' "${S_NEWEST:-$S_VERSION}"
            else
                printf '## [%s] - %s\n\n' "${S_NEWEST:-$S_VERSION}" "$S_DATE"
            fi
            if [ -n "$S_SUBSECTION" ]; then
                printf '%s\n\n- a behaviour changed\n\n' "$S_SUBSECTION"
            fi
            if [ "$S_EMPTY" != "yes" ]; then
                printf -- '- a change\n'
            fi
            # What lies below the newest section: the heading of the previous release, the text of the
            # case with its escapes (below=), or nothing at all (below=none).
            if [ "$S_BELOW" = "none" ]; then
                :
            elif [ -n "$S_BELOW" ]; then
                printf '\n%b\n' "$S_BELOW"
            elif [ -n "$S_PREVIOUS" ]; then
                printf '\n## [%s] - 2025-10-11\n\n- earlier\n' "$S_PREVIOUS"
            fi
        } > "$directory/CHANGELOG.md"
        printf "Pod::Spec.new do |s|\n  s.version = '%s'\nend\n" "$S_PODSPEC" > "$directory/$podspec_name"
        mkdir -p "$directory/Fixtures/API"
        baseline_text "$S_NEW" > "$directory/Fixtures/API/public-interface.txt"
        scratch_git "$directory" add -f CHANGELOG.md "$podspec_name" Fixtures/API/public-interface.txt
        scratch_git "$directory" commit -q -m "the release"
        # The release job runs on the tag of the release itself.
        if [ "$S_HEADTAG" = "yes" ]; then
            scratch_git "$directory" tag "$S_VERSION"
        fi
        if [ "$S_NOPODSPEC" = "yes" ]; then
            rm -f "$directory/$podspec_name"
        fi
        cp "${BASH_SOURCE[0]}" "$directory/Scripts/check-release.sh"
        if [ "$S_API" = "stub" ]; then
            printf '#!/bin/bash\necho "%s"\nexit %s\n' "$S_STUB_TEXT" "$S_STUB_STATUS" > "$directory/Scripts/check-api.sh"
        else
            cp "$ROOT/Scripts/check-api.sh" "$directory/Scripts/check-api.sh"
        fi
        chmod +x "$directory/Scripts/check-release.sh" "$directory/Scripts/check-api.sh"
        if [ "$S_DIGESTER" != "none" ]; then
            # shellcheck disable=SC2016
            case "$S_DIGESTER" in
                ok) printf '#!/bin/bash\necho "no break"\nexit 0\n' ;;
                break) printf '#!/bin/bash\necho "check-api-digester: 1 breaking change detected in Lib since $1"\necho "  - removed func keep()"\nexit 1\n' ;;
                breaksingular) printf '#!/bin/bash\necho "1 breaking change detected in Lib:"\necho "  - removed func keep()"\nexit 1\n' ;;
                breakplural) printf '#!/bin/bash\necho "2 breaking changes detected in Lib:"\necho "  - removed func keep()"\nexit 1\n' ;;
                breakbare) printf '#!/bin/bash\necho "swift: command not found"\nexit 1\n' ;;
                fail) printf '#!/bin/bash\necho "cannot run for $1"\nexit 3\n' ;;
                noexec) printf '#!/bin/bash\necho "a break"\nexit 1\n' ;;
                *)
                    echo "check-release: self-test: no digester named '$S_DIGESTER'" >&2
                    exit 2
                    ;;
            esac > "$directory/Scripts/check-api-digester.sh"
            if [ "$S_DIGESTER" != "noexec" ]; then
                chmod +x "$directory/Scripts/check-api-digester.sh"
            fi
        fi
        # A clone that holds the last commit and the tag of the previous release, and nothing between.
        if [ "$S_SHALLOW" = "yes" ]; then
            env ${git_local[@]+"${git_local[@]}"} GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
                git clone -q --depth 1 --no-tags "file://$directory" "$directory-shallow"
            if [ -n "$S_PREVIOUS" ]; then
                scratch_git "$directory-shallow" fetch -q --depth 1 origin "refs/tags/$S_PREVIOUS:refs/tags/$S_PREVIOUS"
            fi
            cp -R "$directory/Scripts" "$directory-shallow/Scripts"
        fi
    }
    judge() {  # <name> <expected status> <expected text> <status> <output> <text that must be absent>
        if [ -z "$3" ]; then
            echo "check-release: self-test: the case '$1' names no text to look for, and every output holds the empty text" >&2
            exit 2
        fi
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
        local arguments=() actions_env=()
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
        case "$S_GIT" in
            real) ;;
            nomergebase) run_path="$no_merge_base:$run_path" ;;
            oldgit) run_path="$old_git:$run_path" ;;
            *)
                echo "check-release: self-test: no git named '$S_GIT'" >&2
                exit 2
                ;;
        esac
        directory="$SELF_TEST_WORK/case-$number"
        build_repo "$directory"
        if [ "$S_SHALLOW" = "yes" ]; then
            directory="$directory-shallow"
        fi
        if [ "$S_NOTES" = "yes" ]; then
            arguments=(--notes "$S_VERSION")
        else
            arguments=("$S_VERSION")
        fi
        # The self-test may itself run under GitHub Actions, and a case that does not ask for the
        # annotations must not get them.
        if [ "$S_ACTIONS" = "yes" ]; then
            actions_env=(GITHUB_ACTIONS=true)
        fi
        output="$(env ${git_local[@]+"${git_local[@]}"} -u GITHUB_ACTIONS ${actions_env[@]+"${actions_env[@]}"} \
            PATH="$run_path" /bin/bash "$directory/Scripts/check-release.sh" "${arguments[@]}" 2>&1)" || status=$?
        judge "$name" "$expected_status" "$expected_text" "$status" "$output" "$S_ABSENT"
    }

    run_case "an additive release passes with the reminder" 0 "lines were added to the interface" new=added
    run_case "the reminder is also an annotation under GitHub Actions" 0 "::warning::check-release: lines were added to the interface" new=added actions=yes
    run_case "the reminder is no annotation outside GitHub Actions" 0 "lines were added to the interface" new=added absent=::warning::
    run_case "no annotation is made under GitHub Actions when no line was added" 0 "agrees on 1.1.0" actions=yes absent=::warning::
    run_case "the reminder names an added case of a public enum" 0 "Review each one: a new case of a public enum" new=added
    run_case "the reminder names a protocol requirement added without a default" 0 "without a default implementation" new=added
    run_case "the reminder says when a requirement with a default is additive" 0 "its name is new to the protocol" new=added
    run_case "a removed line under the same major fails" 1 "needs a new major version" new=removed
    run_case "a removed line under a new major passes" 0 "agrees on 2.0.0" version=2.0.0 new=removed
    run_case "a breaking subsection in lower case under the same major fails" 1 "'### Breaking changes' subsection" "subsection=### breaking changes"
    run_case "a breaking subsection in title case under the same major fails" 1 "'### Breaking changes' subsection" "subsection=### Breaking Changes"
    run_case "a breaking subsection in upper case under the same major fails" 1 "'### Breaking changes' subsection" "subsection=### BREAKING CHANGES"
    run_case "a breaking subsection with blanks after it still fails" 1 "'### Breaking changes' subsection" "subsection=### Breaking changes   "
    run_case "a breaking subsection under a new major passes" 0 "agrees on 2.0.0" version=2.0.0 "subsection=### Breaking changes"
    # A declaration of breaking changes is a heading of any level, or a line that opens with bold text,
    # whose first word is "breaking": the rule refuses more than the one literal heading.
    run_case "a breaking heading with a colon fails and is quoted" 1 "the heading found: '### Breaking Changes:'" "subsection=### Breaking Changes:"
    run_case "a singular breaking heading fails" 1 "'### Breaking changes' subsection" "subsection=### Breaking change"
    run_case "a bare breaking heading fails" 1 "'### Breaking changes' subsection" "subsection=### Breaking"
    run_case "a deeper breaking heading fails" 1 "'### Breaking changes' subsection" "subsection=#### Breaking changes"
    run_case "a shallower breaking heading fails" 1 "'### Breaking changes' subsection" "subsection=## Breaking changes"
    run_case "a bold breaking line fails" 1 "'### Breaking changes' subsection" "subsection=**Breaking changes**"
    run_case "a breaking heading with a note fails" 1 "'### Breaking changes' subsection" "subsection=### Breaking changes (API)"
    run_case "a breaking heading with two blanks after the hashes fails" 1 "'### Breaking changes' subsection" "subsection=###  Breaking changes"
    run_case "a breaking heading with two blanks inside fails" 1 "'### Breaking changes' subsection" "subsection=### Breaking  changes"
    run_case "a breaking heading with an emoji in front fails" 1 "'### Breaking changes' subsection" "subsection=### $(printf '\360\237\222\245') Breaking changes"
    run_case "a heading that says there are no breaking changes passes" 0 "agrees on 1.1.0" "subsection=### No breaking changes"
    run_case "a heading about changes that do not break passes" 0 "agrees on 1.1.0" "subsection=### Non-breaking changes"
    run_case "a list item that names breaking changes passes" 0 "agrees on 1.1.0" "subsection=- Breaking changes"
    run_case "a heading with no date" 1 "has no heading of the form" nodate=yes
    run_case "a heading with nothing under it" 1 "has no notes under a heading for 1.1.0" empty=yes
    run_case "a version with two groups of digits" 2 "usage: Scripts/check-release.sh" version=1.1
    run_case "a version with four groups of digits" 2 "usage: Scripts/check-release.sh" version=1.1.0.1
    run_case "a version that starts with a dot" 2 "usage: Scripts/check-release.sh" version=.1.0
    run_case "a podspec that is not there is exit 2, not a release that is not ready" 2 "does not exist" nopodspec=yes
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
    # The digester is believed on status 1 only with the line that reports a break, which the tool
    # prints in the singular and in the plural, with the name of the script in front of it or not.
    run_case "the break line of the tool in the singular is a break" 1 "the digester reports a break" digester=breaksingular
    run_case "the break line of the tool in the plural is a break" 1 "the digester reports a break" digester=breakplural
    run_case "the output of the digester is printed with a break" 1 "removed func keep()" digester=break
    run_case "a digester that ends with status 1 and no break line could not compare" 2 "the digester could not compare with 1.0.0" digester=breakbare "absent=reports a break"
    run_case "the output of a digester that could not compare is quoted" 2 "swift: command not found" digester=breakbare
    run_case "the digester is not asked under a new major" 0 "agrees on 2.0.0" version=2.0.0 digester=break absent=digester
    run_case "the digester cannot compare, and is told the previous release" 2 "cannot run for 1.0.0" digester=fail
    run_case "a digester that is there and is not executable" 2 "is not executable" digester=noexec
    run_case "the digester is not asked after a comparison that could not run" 2 "could not be compared" api=stub status=5 text=boom digester=break absent=digester
    run_case "the digester is told that the previous release holds no baseline" 0 "the digester was not run against 1.0.0" tagbaseline=no digester=ok
    run_case "the previous release on a side branch is not an ancestor" 1 "is not an ancestor of the commit being released" tag=side
    run_case "the previous release on a side branch fails under a new major too" 1 "is not an ancestor of the commit being released" tag=side version=2.0.0
    run_case "a shallow clone cannot be checked" 2 "git fetch --unshallow" shallow=yes
    run_case "a git that cannot say whether the tag is an ancestor" 2 "it could not be checked whether the tag 1.0.0 is an ancestor" git=nomergebase
    run_case "a git that does not know whether the clone is shallow" 2 "whether this clone is shallow" git=oldgit
    # The release before this one comes from the tags: the highest release tag below the version that
    # this commit reaches, and the heading below the newest one has to name it.
    run_case "a heading below that is not a release heading is named" 1 "is not a release version" "below=## 1.0.0 - 2025-10-11\n\n- earlier" new=removed
    run_case "a heading below with a v in front is named" 1 "is not a release version" "below=## v1.0.0 - 2025-10-11\n\n- earlier" new=removed
    run_case "a release tag that the changelog skips is named" 1 "the changelog skips 2.0.0" version=2.1.0 tags=1.0.0:keep,2.0.0:removed "below=## [1.0.0] - 2025-10-11\n\n- earlier" new=gone
    run_case "a duplicate heading is not lower than the version" 1 "which is not lower than 1.1.0" headtag=yes "below=## [1.1.0] - 2026-10-03\n\n- a change\n\n## [1.0.0] - 2025-10-11\n\n- earlier" new=removed
    run_case "a heading below that is higher than the version" 1 "which is not lower than 1.1.0" "below=## [1.2.0] - 2026-11-01\n\n- later"
    run_case "a reachable release tag and no heading below" 1 "has no heading below 1.1.0, and the release tag 1.0.0 is reachable" below=none
    run_case "a shallow clone of the first release cannot be checked" 2 "git fetch --unshallow" previous= shallow=yes
    run_case "a release tag above the version is not the previous release" 0 "agrees on 1.1.0" tags=1.0.0:keep,1.5.0:keep
    run_case "the tags are compared as numbers" 0 "agrees on 1.11.0" version=1.11.0 tags=1.2.0:keep,1.10.0:keep "below=## [1.10.0] - 2025-10-11\n\n- earlier"

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

# The one line of this script that differs between the repositories that share it names the
# podspec. A name that is wrong makes the script read a file that is not there, which is not a
# release that is not ready.
if [ ! -f "$PODSPEC" ]; then
    echo "check-release: the podspec ${PODSPEC#"$ROOT"/} does not exist; PODSPEC at the top of this script names it" >&2
    exit 2
fi

PROBLEMS=()

# The problems found so far, as the final report prints them. A script that has to stop before the
# end prints them first, so that the reason it stops is not the only thing the releaser learns.
report_problems() {
    if [ "${#PROBLEMS[@]}" -gt 0 ]; then
        echo "check-release: $VERSION is not ready to release:" >&2
        printf '  - %s\n' "${PROBLEMS[@]}" >&2
    fi
    # What the digester printed when it found a break, so that the break is read here and not looked
    # up in another run.
    if [ -n "${DIGEST_DETAIL:-}" ]; then
        echo "check-release: the digester said:" >&2
        printf '%s\n' "$DIGEST_DETAIL" | sed -n '1,20p' | sed 's/^/    /' >&2
    fi
}

if [ -z "$(notes)" ]; then
    PROBLEMS+=("CHANGELOG.md has no notes under a heading for $VERSION")
fi

PODSPEC_VERSION="$(sed -n "s/^ *s\.version *= *'\([^']*\)'.*/\1/p" "$PODSPEC")"
if [ "$PODSPEC_VERSION" != "$FROZEN_POD_VERSION" ]; then
    PROBLEMS+=("the podspec names version '$PODSPEC_VERSION'; the pod is frozen at $FROZEN_POD_VERSION")
fi

# Whether a day exists is asked of python3, and a machine without it must say so: a missing
# interpreter is not a bad date.
if ! python3 -c 'import datetime' > /dev/null 2>&1; then
    report_problems
    echo "check-release: python3 is needed to read the release date, and it does not run on this machine" >&2
    exit 2
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
    elif ! DATE_CHECK="$(python3 -c 'import datetime, sys; datetime.date.fromisoformat(sys.argv[1])' "$HEADING_DATE" 2>&1)"; then
        case "$DATE_CHECK" in
            *ValueError*)
                PROBLEMS+=("the changelog heading of $VERSION has '$HEADING_DATE', which is not a day of the calendar")
                ;;
            *)
                report_problems
                echo "check-release: python3 could not check the release date: $DATE_CHECK" >&2
                exit 2
                ;;
        esac
    fi
else
    PROBLEMS+=("CHANGELOG.md has no heading of the form '## [version] - date'")
fi

# The release before this one. It has no meaning when the newest heading is for another version,
# which is a problem already. It comes from the tags: the highest release tag below the version that
# this commit reaches, and the heading below the newest one has to name it. A history that is cut
# short cannot say which tags are below the version, so a shallow clone is never a pass.
version_less() {  # <a> <b>: whether version a is lower than version b, group by group
    local a_major a_minor a_patch b_major b_minor b_patch
    IFS=. read -r a_major a_minor a_patch <<< "$1"
    IFS=. read -r b_major b_minor b_patch <<< "$2"
    [ "$a_major" -lt "$b_major" ] && return 0
    [ "$a_major" -gt "$b_major" ] && return 1
    [ "$a_minor" -lt "$b_minor" ] && return 0
    [ "$a_minor" -gt "$b_minor" ] && return 1
    [ "$a_patch" -lt "$b_patch" ]
}

COULD_NOT_COMPARE=0
PREVIOUS=""
if [ "$HEADING_VERSION" = "$VERSION" ]; then
    # Only true and false are answers. Whatever else git prints, its error included, is kept for
    # the message below, so the status of the command is not needed. A git before 2.15 does not
    # know the flag and prints it back: that is no answer.
    SHALLOW="$(git -C "$ROOT" rev-parse --is-shallow-repository 2>&1)" || true
    if [ "$SHALLOW" = "true" ]; then
        PROBLEMS+=("this clone is shallow, so it cannot be told from the tags which release is below $VERSION, nor checked that it is an ancestor of the commit being released: git fetch --unshallow --tags")
        COULD_NOT_COMPARE=1
    elif [ "$SHALLOW" != "false" ]; then
        PROBLEMS+=("it could not be asked whether this clone is shallow, so it cannot be told from the tags which release is below $VERSION (git said '$SHALLOW'; git 2.15 or later is needed)")
        COULD_NOT_COMPARE=1
    elif ! MERGED_TAGS="$(git -C "$ROOT" tag --merged HEAD 2>&1)"; then
        PROBLEMS+=("the tags that this commit reaches could not be listed (git said '$(printf '%s\n' "$MERGED_TAGS" | sed -n '1p')')")
        COULD_NOT_COMPARE=1
    else
        TAG_BELOW=""
        while IFS= read -r TAG; do
            if valid_version "$TAG" && version_less "$TAG" "$VERSION"; then
                if [ -z "$TAG_BELOW" ] || version_less "$TAG_BELOW" "$TAG"; then
                    TAG_BELOW="$TAG"
                fi
            fi
        done <<< "$MERGED_TAGS"
        # The heading right below the newest release heading. A release heading opens with a version
        # in brackets or without them, with or without a v; another level-2 heading is part of the notes.
        PREVIOUS_HEADING="$(LC_ALL=C awk '/^## \[/ && !seen { seen = 1; next } seen && /^## (\[|v?[0-9])/ { print; exit }' "$CHANGELOG")"
        if [ -z "$PREVIOUS_HEADING" ]; then
            if [ -z "$TAG_BELOW" ]; then
                echo "check-release: CHANGELOG.md has no release below $VERSION, so the interface was not compared."
            else
                PROBLEMS+=("CHANGELOG.md has no heading below $VERSION, and the release tag $TAG_BELOW is reachable: the changelog skips $TAG_BELOW")
            fi
        else
            HEADING_BELOW="$(printf '%s\n' "$PREVIOUS_HEADING" | LC_ALL=C sed -n 's/^## \[\([^]]*\)\].*$/\1/p')"
            if ! valid_version "$HEADING_BELOW"; then
                PROBLEMS+=("the changelog heading below $VERSION is not a release version: '$PREVIOUS_HEADING'")
            elif ! version_less "$HEADING_BELOW" "$VERSION"; then
                PROBLEMS+=("the changelog heading below $VERSION is for $HEADING_BELOW, which is not lower than $VERSION")
            elif [ -n "$TAG_BELOW" ] && version_less "$HEADING_BELOW" "$TAG_BELOW"; then
                PROBLEMS+=("the highest release tag below $VERSION that this commit reaches is $TAG_BELOW, but the heading below is for $HEADING_BELOW: the changelog skips $TAG_BELOW")
            else
                PREVIOUS="$HEADING_BELOW"
            fi
        fi
    fi
fi

if [ -n "$PREVIOUS" ]; then
    RAISES_MAJOR=0
    if [ "${VERSION%%.*}" -gt "${PREVIOUS%%.*}" ]; then
        RAISES_MAJOR=1
    fi
    # A declaration of breaking changes is a heading of any level, or a line that opens with bold text,
    # whose first word is "breaking": blanks, punctuation and an emoji may stand before it, and
    # whatever follows is free. A heading that says there are none, such as "No breaking changes", and
    # a list item do not open with that word. A rule that refuses more is the safe direction here.
    BREAKING_LINE="$(notes | LC_ALL=C grep -i -E -m 1 '^ {0,3}(#{1,6}|\*\*|__)[^[:alnum:]]*breaking([^[:alnum:]]|$)' || true)"
    if [ -n "$BREAKING_LINE" ] && [ "$RAISES_MAJOR" -eq 0 ]; then
        PROBLEMS+=("the notes of $VERSION have a '### Breaking changes' subsection (the heading found: '$BREAKING_LINE'): that needs a new major version, and $VERSION does not raise the major version of $PREVIOUS")
    fi
    if ! git -C "$ROOT" rev-parse --verify --quiet "refs/tags/$PREVIOUS^{commit}" > /dev/null; then
        PROBLEMS+=("the tag $PREVIOUS of the release below $VERSION is not in this repository, so the interface cannot be compared: git fetch --tags")
        COULD_NOT_COMPARE=1
    else
        # The release before this one has to be part of the history of this one. A tag on a side
        # branch compares the interface with a release that this commit does not follow. The clone is
        # known to be whole at this point, which git merge-base --is-ancestor needs: in a shallow clone
        # it says no for a tag that is an ancestor.
        ANCESTOR_STATUS=0
        git -C "$ROOT" merge-base --is-ancestor "refs/tags/$PREVIOUS^{commit}" HEAD || ANCESTOR_STATUS=$?
        case "$ANCESTOR_STATUS" in
            0) ;;
            1)
                PROBLEMS+=("the tag $PREVIOUS of the release below $VERSION is not an ancestor of the commit being released: $VERSION does not follow $PREVIOUS, so the comparison of the interface does not say what changed since it")
                ;;
            *)
                PROBLEMS+=("it could not be checked whether the tag $PREVIOUS is an ancestor of the commit being released (git merge-base exit status $ANCESTOR_STATUS)")
                COULD_NOT_COMPARE=1
                ;;
        esac
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
                # The reminder is a line of the log that nobody may read. Under GitHub Actions it is
                # also a warning annotation, which a pull request shows.
                REMINDER="check-release: lines were added to the interface since $PREVIOUS. Review each one: a new case of a public enum, a protocol requirement added without a default implementation and an overload that makes an existing call ambiguous are breaking and need a new major version; a requirement with a default implementation is additive only when its name is new to the protocol and to its extensions."
                echo "$REMINDER"
                if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
                    echo "::warning::$REMINDER"
                fi
                ;;
            4)
                echo "check-release: the interface was not compared with $PREVIOUS: that release holds no baseline."
                ;;
            *)
                PROBLEMS+=("the interface could not be compared with $PREVIOUS: $(printf '%s\n' "$DELTA" | sed -n '1p')")
                COULD_NOT_COMPARE=1
                ;;
        esac
        if [ -e "$ROOT/Scripts/check-api-digester.sh" ] && [ ! -x "$ROOT/Scripts/check-api-digester.sh" ]; then
            # A digester that cannot start is not a reason to pass: the hook would be dead and
            # the release would say nothing about it.
            PROBLEMS+=("Scripts/check-api-digester.sh is there and is not executable, so the digester did not run: chmod +x Scripts/check-api-digester.sh")
            COULD_NOT_COMPARE=1
        elif [ -x "$ROOT/Scripts/check-api-digester.sh" ]; then
            if [ "$DELTA_STATUS" -eq 4 ]; then
                echo "check-release: the digester was not run against $PREVIOUS: that release holds no baseline."
            elif [ "$RAISES_MAJOR" -eq 0 ] && [ "$COULD_NOT_COMPARE" -eq 0 ]; then
                DIGEST_STATUS=0
                DIGEST="$("$ROOT/Scripts/check-api-digester.sh" "$PREVIOUS" 2>&1)" || DIGEST_STATUS=$?
                # The contract of the digester: status 0 is no break, and status 1 is a break only with a
                # line 'N breaking change(s) detected in <module>', which the wrapper in DMAction prints
                # behind the name of the script and the tool prints without it. Anything else, such as a
                # tool that is missing and ends with status 1 too, is a comparison that could not be made.
                DIGEST_BREAK="$(printf '%s\n' "$DIGEST" | LC_ALL=C grep -E -m 1 '^(check-api-digester: )?[0-9]+ breaking changes? detected in ' || true)"
                if [ "$DIGEST_STATUS" -eq 0 ]; then
                    echo "check-release: the digester finds no break since $PREVIOUS."
                elif [ "$DIGEST_STATUS" -eq 1 ] && [ -n "$DIGEST_BREAK" ]; then
                    PROBLEMS+=("the digester reports a break since $PREVIOUS (Scripts/check-api-digester.sh $PREVIOUS lists it): that needs a new major version, and $VERSION does not raise the major version of $PREVIOUS")
                    DIGEST_DETAIL="$DIGEST"
                else
                    PROBLEMS+=("the digester could not compare with $PREVIOUS (it ended with status $DIGEST_STATUS; a break is status 1 and a line 'N breaking changes detected in <module>'): $(printf '%s\n' "$DIGEST" | sed -n '1,2p' | tr '\n' ' ')")
                    COULD_NOT_COMPARE=1
                fi
            fi
        fi
    fi
fi

if [ "${#PROBLEMS[@]}" -gt 0 ]; then
    report_problems
    if [ "$COULD_NOT_COMPARE" -eq 1 ]; then
        exit 2
    fi
    exit 1
fi
echo "check-release: the changelog agrees on $VERSION, released $HEADING_DATE; the pod stays at $FROZEN_POD_VERSION."
