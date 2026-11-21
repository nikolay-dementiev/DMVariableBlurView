#!/bin/bash
#
#   Scripts/ci-changes.sh <event> < <changed paths, one per line>
#   Scripts/ci-changes.sh --self-test
#
# Tells the CI workflow which jobs a change needs, so that a pull request that changes documents
# only does not use the macOS runners of the simulator jobs and of the toolchain floor, and one that
# changes a file that no job reads uses none. It prints two lines, `light=run|skip` and
# `heavy=run|skip`, in the form that $GITHUB_OUTPUT takes. The jobs of ci.yml are in two groups:
#   light  lint, docs, api, consumer, podspec: they read the sources, the scripts, the README and
#          the changelog.
#   heavy  test, example, thread-sanitizer, floor: they build and test the code on simulators.
#
# A path is inert when no job reads it (.coderabbit.yaml), a document when it is a Markdown file, a
# file under Documentation/ or the LICENSE and no directory of code holds it, and code otherwise: a
# path that no rule lists is code, so a new kind of file runs every job until this file says
# otherwise. A change of inert files alone skips both groups, a change of documents and inert files
# skips the heavy group, and any code runs both.
#
# Only a pull request is filtered. Any other event (push, schedule, workflow_dispatch and
# workflow_call, which is how a release runs CI) runs every job, and so does a list with no path.
# --self-test proves the rules on fixture lists.

set -euo pipefail

# inert, document or code. A directory of code wins over the extension: a Markdown file under
# Sources is a DocC article, and .github holds the workflows, so it stays whole.
classify() {
  case "$1" in
    .coderabbit.yaml) echo inert ;;
    Sources/* | Tests/* | Examples/* | Fixtures/* | Tools/* | Scripts/* | .github/*) echo code ;;
    Documentation/* | LICENSE | *.md) echo document ;;
    *) echo code ;;
  esac
}

# decide <event>, with the changed paths on standard input. A list is read for a pull request only.
decide() {
  local event="$1" path count=0 mode=inert
  if [ "$event" = pull_request ]; then
    while IFS= read -r path || [ -n "$path" ]; do
      [ -n "$path" ] || continue
      count=$((count + 1))
      case "$(classify "$path")" in
        code) mode=code ;;
        document) [ "$mode" = code ] || mode=document ;;
        *) ;;
      esac
    done
  fi
  [ "$count" -gt 0 ] || mode=code
  case "$mode" in
    code) echo "light=run"; echo "heavy=run" ;;
    document) echo "light=run"; echo "heavy=skip" ;;
    *) echo "light=skip"; echo "heavy=skip" ;;
  esac
}

self_test() {
  local failures=0 total=0 path event
  local both=$'light=run\nheavy=run' docs=$'light=run\nheavy=skip' none=$'light=skip\nheavy=skip'

  # check <name> <expected output> <event> [path...]
  check() {
    local name="$1" expected="$2" actual
    local changed_event="$3"
    shift 3
    actual="$(printf '%s\n' "$@" | decide "$changed_event")"
    total=$((total + 1))
    if [ "$actual" = "$expected" ]; then
      echo "ok: $name"
    else
      echo "FAIL: $name" >&2
      echo "  expected: $(echo "$expected" | tr '\n' ' ')" >&2
      echo "  actual:   $(echo "$actual" | tr '\n' ' ')" >&2
      failures=$((failures + 1))
    fi
  }

  for path in \
    Sources/DMVariableBlurView/DMVariableBlurView.swift \
    Tests/DMVariableBlurViewTests/BlurTests.swift \
    Examples/DMVariableBlurViewExample/App.swift \
    Fixtures/API/public-interface.txt \
    Scripts/lint.sh \
    Tools/Package.swift \
    Package.swift \
    .github/workflows/ci.yml \
    .github/PULL_REQUEST_TEMPLATE.md; do
    check "$path alone runs both groups" "$both" pull_request "$path"
  done
  for path in \
    README.md \
    CHANGELOG.md \
    LICENSE \
    Documentation/Review/README.md \
    .agents/skills/x/SKILL.md; do
    check "$path alone skips the heavy group" "$docs" pull_request "$path"
  done
  check "a document and a Swift file run both groups" "$both" pull_request \
    README.md Sources/DMVariableBlurView/DMVariableBlurView.swift
  check "a Swift file and a document run both groups, whatever the order" "$both" pull_request \
    Sources/DMVariableBlurView/DMVariableBlurView.swift README.md
  check "a path that no rule lists runs both groups" "$both" pull_request new/dir/x.bin
  check "a document and a path that no rule lists run both groups" "$both" pull_request \
    README.md new/dir/x.bin
  check "a DocC article under Sources runs both groups" "$both" pull_request \
    Sources/DMVariableBlurView/DMVariableBlurView.docc/Article.md
  # A file that is not Markdown is code with or without the directory rule, so only a Markdown
  # file proves that the rule of a directory is there.
  for path in \
    Tests/NOTES.md \
    Examples/NOTES.md \
    Fixtures/NOTES.md \
    Tools/NOTES.md \
    Scripts/NOTES.md; do
    check "a Markdown file $path under a directory of code runs both groups" "$both" \
      pull_request "$path"
  done
  check "a Markdown file with a space in its path alone skips the heavy group" "$docs" \
    pull_request "My Docs/a b.md"
  check "a Markdown file with a space under Sources runs both groups" "$both" pull_request \
    "Sources/My File.md"
  # git prints a path with a non-ASCII character in quotes, and such a path is not a document.
  check "a path that git quotes runs both groups" "$both" pull_request \
    '"Documentation/caf\303\251.md"'

  check "the inert file alone skips both groups" "$none" pull_request .coderabbit.yaml
  check "the inert file and a document skip the heavy group only" "$docs" pull_request \
    .coderabbit.yaml README.md
  check "a document and the inert file skip the heavy group only, whatever the order" "$docs" \
    pull_request README.md .coderabbit.yaml
  check "the inert file and a Swift file run both groups, whatever the order" "$both" \
    pull_request .coderabbit.yaml Sources/DMVariableBlurView/DMVariableBlurView.swift
  check "a Swift file and the inert file run both groups" "$both" pull_request \
    Sources/DMVariableBlurView/DMVariableBlurView.swift .coderabbit.yaml
  check "the inert file and a path that no rule lists run both groups" "$both" pull_request \
    .coderabbit.yaml new/dir/x.bin
  for path in .coderabbit.yml .coderabbit.yaml.bak docs/.coderabbit.yaml; do
    check "$path is not the inert file, so it runs both groups" "$both" pull_request "$path"
  done

  for event in push schedule workflow_dispatch workflow_call; do
    check "$event with README.md alone runs both groups" "$both" "$event" README.md
    check "$event with the inert file alone runs both groups" "$both" "$event" .coderabbit.yaml
  done
  check "a list with no path runs both groups" "$both" pull_request

  if [ "$failures" -ne 0 ]; then
    echo "ci-changes: $failures of $total cases failed." >&2
    return 1
  fi
  echo "ci-changes: all $total cases passed."
}

case "${1:-}" in
  --self-test) self_test ;;
  "") echo "usage: ci-changes.sh <event> < paths | ci-changes.sh --self-test" >&2; exit 64 ;;
  *) decide "$1" ;;
esac
