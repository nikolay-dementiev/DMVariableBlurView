#!/bin/bash
#
#   Scripts/ci-changes.sh <event> < <changed paths, one per line>
#   Scripts/ci-changes.sh --self-test
#
# Tells the CI workflow which jobs a change can affect, so that a pull request that changes
# documents only does not use the macOS runners of the simulator jobs and of the toolchain floor.
# It prints one line per job that can be skipped, `<job>=run` or `<job>=skip`, in the form that
# $GITHUB_OUTPUT takes. The other jobs (lint, api, consumer, podspec and docs) never skip: the
# consumer check reads the README and the changelog, and the rest read the sources or the scripts.
#
# Only a pull request is filtered. Any other event (push, schedule, workflow_dispatch and
# workflow_call, which is how a release runs CI) runs every job, and so does a list with no path.
#
# A path is a document when it is a Markdown file, a file under Documentation/ or the LICENSE,
# and no directory of code holds it. Everything else is code, a path that no rule lists included,
# so a new kind of file runs every job until this file says otherwise. A change is skipped only
# when every path in it is a document. --self-test proves the rules on fixture lists.

GATED_JOBS=(test example thread-sanitizer floor)

# A directory of code wins over the extension: a Markdown file under Sources is a DocC article, and
# .github holds the workflows, so it stays whole.
is_document() {
  case "$1" in
    Sources/* | Tests/* | Examples/* | Fixtures/* | Tools/* | Scripts/* | .github/*) return 1 ;;
    Documentation/* | LICENSE | *.md) return 0 ;;
    *) return 1 ;;
  esac
}

# decide <event>, with the changed paths on standard input.
decide() {
  local event="$1" path count=0 documents=0 verdict=run job
  if [ "$event" = pull_request ]; then
    while IFS= read -r path || [ -n "$path" ]; do
      [ -n "$path" ] || continue
      count=$((count + 1))
      if is_document "$path"; then
        documents=$((documents + 1))
      fi
    done
    if [ "$count" -gt 0 ] && [ "$count" -eq "$documents" ]; then
      verdict=skip
    fi
  fi
  for job in "${GATED_JOBS[@]}"; do
    echo "$job=$verdict"
  done
}

self_test() {
  local failures=0 total=0 path event
  local all_run=$'test=run\nexample=run\nthread-sanitizer=run\nfloor=run'
  local all_skip=$'test=skip\nexample=skip\nthread-sanitizer=skip\nfloor=skip'

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
    check "$path alone runs every job" "$all_run" pull_request "$path"
  done
  for path in \
    README.md \
    CHANGELOG.md \
    LICENSE \
    Documentation/Review/README.md \
    .agents/skills/x/SKILL.md; do
    check "$path alone skips the jobs that can be skipped" "$all_skip" pull_request "$path"
  done
  check "a document and a Swift file run every job" "$all_run" pull_request \
    README.md Sources/DMVariableBlurView/DMVariableBlurView.swift
  check "a path that no rule lists runs every job" "$all_run" pull_request new/dir/x.bin
  check "a document and a path that no rule lists run every job" "$all_run" pull_request \
    README.md new/dir/x.bin
  check "a DocC article under Sources runs every job" "$all_run" pull_request \
    Sources/DMVariableBlurView/DMVariableBlurView.docc/Article.md
  for event in push schedule workflow_dispatch workflow_call; do
    check "$event with README.md alone runs every job" "$all_run" "$event" README.md
  done
  check "a list with no path runs every job" "$all_run" pull_request

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
