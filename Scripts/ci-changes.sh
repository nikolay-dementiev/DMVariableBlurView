#!/bin/bash
#
#   Scripts/ci-changes.sh <event> <base> <ref>
#   Scripts/ci-changes.sh --classify <event> <ref> < <changed paths, one per line>
#   Scripts/ci-changes.sh --self-test
#
# Tells the CI workflow which jobs a change needs, so that a pull request that changes documents
# only does not use the macOS runners of the simulator jobs and of the toolchain floor, and one that
# changes a file that no job reads uses none. It prints two lines, `light=run|skip` and
# `heavy=run|skip`, in the form that $GITHUB_OUTPUT takes. The jobs of ci.yml are in two groups:
#   light  lint, docs, api, consumer: they read the sources, the scripts, the README and the
#          changelog.
#   heavy  test, example, thread-sanitizer, floor: they build and test the code on simulators.
#
# A path is inert when no job reads it (.coderabbit.yaml), a document when it is a Markdown file, a
# file under Documentation/ or the LICENSE and no directory of code holds it, and code otherwise: a
# path that no rule lists is code, so a new kind of file runs every job until this file says
# otherwise. A change of inert files alone skips both groups, a change of documents and inert files
# skips the heavy group, and any code runs both.
#
# A pull request and a push to refs/heads/main are filtered: the first form lists what HEAD changes
# against <base>, the commit the pull request is based on or the one main was at before the push,
# and decides from the paths. --classify decides for the paths on standard input. Any other event
# runs every job: a push to another branch, a push of a tag (which is how the release reaches this
# script: a workflow that ci.yml calls sees the event of its caller), schedule and
# workflow_dispatch. So does a list with no path, and a base that is not a commit of this clone (a
# new branch, a forced push): a path that no rule lists stands for the change that could not be
# listed. --self-test proves the rules on fixture lists and on a scratch repository, and that every
# job of ci.yml is in a group and asks for the answer of its group.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly LIGHT_JOBS="lint docs api consumer"
readonly HEAVY_JOBS="test example thread-sanitizer floor"

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

# is_filtered <event> <ref>. A scheduled run is on refs/heads/main too, so the event decides first.
is_filtered() {
  [ "$1" = pull_request ] || { [ "$1" = push ] && [ "$2" = refs/heads/main ]; }
}

# decide <event> <ref>, with the changed paths on standard input. A list is read when the event is
# filtered. Only an answer of inert or document, spelt as classify spells it, lowers the answer: any
# other word stands for code, so that a mistake in classify cannot skip a job.
decide() {
  local event="$1" ref="$2" path count=0 mode=inert
  if is_filtered "$event" "$ref"; then
    while IFS= read -r path || [ -n "$path" ]; do
      [ -n "$path" ] || continue
      count=$((count + 1))
      case "$(classify "$path")" in
        inert) ;;
        document) [ "$mode" = code ] || mode=document ;;
        *) mode=code ;;
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

# is_commit_name <text>: a full commit name, 40 hex digits (SHA-1) or 64 (SHA-256), in lower case.
# Anything else is not handed to git: a base that starts with a dash is read as an option
# (--output=file writes a file), and a branch name is not the commit the change is based on. The
# digits are listed and not given as a range, because the order of a range depends on the locale;
# case and not a regular expression, because =~ and == in [[ ]] are not defined in POSIX sh, which
# is how a linter reads this file.
is_commit_name() {
  case "$1" in
    *[!0123456789abcdef]*) return 1 ;;
  esac
  case "${#1}" in
    40 | 64) return 0 ;;
    *) return 1 ;;
  esac
}

# run_diff <event> <base> <ref> [<repository>]. The repository is a parameter so that the self-test
# can run the real diff on a scratch one. The answer is the only thing on standard output. The log
# shows the paths, each after a bar: the runner reads a workflow command after the blanks at the
# start of a line, so that a file name that starts with :: would be one.
run_diff() {
  local event="$1" base="$2" ref="$3" repo="${4-$ROOT}" paths
  if ! is_filtered "$event" "$ref"; then
    decide "$event" "$ref" < /dev/null
    return
  fi
  # Two dots compare the tree of the base with the one of HEAD, which lists the change whether or
  # not the base is an ancestor of HEAD: three dots list less after a forced push of main, and fail
  # when there is no merge base. --no-renames lists both paths of a moved file, so a source file
  # moved into Documentation is still a source change; core.quotePath=false keeps a non-ASCII path
  # as it is, not in quotes.
  if ! is_commit_name "$base" ||
    ! git -C "$repo" rev-parse --verify --quiet "$base^{commit}" > /dev/null ||
    ! paths="$(git -C "$repo" -c core.quotePath=false diff --no-renames --name-only "$base..HEAD")"; then
    echo "::warning title=Change filter::The diff against the base failed, so every job runs." >&2
    paths="unlisted/unknown-change"
  elif [ -z "$paths" ]; then
    echo "::warning title=Change filter::The change lists no path, so every job runs." >&2
  fi
  echo "Changed paths:" >&2
  printf '%s\n' "$paths" | sed 's/^/  | /' >&2
  decide "$event" "$ref" <<<"$paths"
}

# job_table_faults <ci.yml>: one line for each way that the file lets a job run unfiltered, skip
# without a reason or read the wrong group. Every job of ci.yml but `changes` is in exactly one group
# and asks for the answer of its group, so that a job added later cannot run unfiltered, or skip, by
# accident. A line is matched whole and at its own indent, so that a comment, a step that carries the
# same condition, or the same words inside another key does not pass for the key of the job.
job_table_faults() {
  local workflow="$1" job group block names want
  names="$(awk '/^jobs:/ { in_jobs = 1; next } in_jobs && /^  [A-Za-z_][A-Za-z0-9_-]*:$/ { sub(/^  /, ""); sub(/:$/, ""); print }' "$workflow" | tr '\n' ' ')"
  # job_block <job>: the lines under the key of the job, up to the key of the next one.
  job_block() {
    awk -v job="$1" '$0 == "  " job ":" { on = 1; next } on && /^  [A-Za-z_][A-Za-z0-9_-]*:$/ { exit } on { print }' "$workflow"
  }
  for job in $names; do
    [ "$job" = changes ] && continue
    group=""
    case " $LIGHT_JOBS " in *" $job "*) group=light ;; esac
    case " $HEAVY_JOBS " in *" $job "*) group=heavy ;; esac
    if [ -z "$group" ]; then
      echo "the job '$job' is in neither group"
      continue
    fi
    block="$(job_block "$job")"
    for want in "    needs: changes" "    if: \${{ !cancelled() && needs.changes.outputs.$group != 'skip' }}"; do
      grep -qxF "$want" <<<"$block" || echo "the job '$job' does not carry the line \"$want\""
    done
  done
  for job in $LIGHT_JOBS $HEAVY_JOBS; do
    case " $names " in *" $job "*) ;; *) echo "'$job' is in a group but is not a job" ;; esac
  done
  block="$(job_block changes)"
  for want in "      light: \${{ steps.filter.outputs.light }}" "      heavy: \${{ steps.filter.outputs.heavy }}" \
    "        id: filter"; do
    grep -qxF "$want" <<<"$block" || echo "the job 'changes' does not carry the line \"$want\""
  done
}

# contains <text> <part>: the text holds the part, which is read as it is and not as a pattern.
# case and not [[ == ]], because == in [[ ]] is not defined in POSIX sh.
contains() {
  case "$1" in
    *"$2"*) return 0 ;;
    *) return 1 ;;
  esac
}

# check_job_table: ci.yml has no fault, and each fault that job_table_faults is for is found in a
# copy of ci.yml that has it. It counts into the `failures` and `total` of self_test.
check_job_table() {
  local workflow="$ROOT/.github/workflows/ci.yml" faults fault dir job_range
  total=$((total + 1))
  faults="$(job_table_faults "$workflow")"
  if [ -z "$faults" ]; then
    echo "ok: every job of ci.yml is in one group and asks for the answer of its group"
  else
    while IFS= read -r fault; do echo "FAIL: ci.yml: $fault" >&2; done <<<"$faults"
    failures=$((failures + 1))
  fi

  dir="$(mktemp -d)"
  job_range='/^  lint:$/,/^  [A-Za-z_][A-Za-z0-9_-]*:$/'
  # check_fault <name> <sed script> <the fault that the copy must show>
  check_fault() {
    local copy="$dir/ci.yml"
    sed -e "$2" "$workflow" > "$copy"
    total=$((total + 1))
    if cmp -s "$workflow" "$copy"; then
      echo "FAIL: $1: the change did not apply to the copy of ci.yml" >&2
      failures=$((failures + 1))
    elif contains "$(job_table_faults "$copy")" "$3"; then
      echo "ok: $1"
    else
      echo "FAIL: $1" >&2
      failures=$((failures + 1))
    fi
  }
  check_fault "a job without its needs line is found" \
    "$job_range { /^    needs: changes\$/ d; }" \
    "the job 'lint' does not carry the line \"    needs: changes\""
  check_fault "a job with its condition commented out is found" \
    "$job_range s/^    if: /    # if: /" \
    "the job 'lint' does not carry the line \"    if: "
  check_fault "a job with its condition at the indent of a step is found" \
    "$job_range s/^    if: /        if: /" \
    "the job 'lint' does not carry the line \"    if: "
  check_fault "a job that asks for the answer of the other group is found" \
    "$job_range s/outputs\\.light != /outputs.heavy != /" \
    "the job 'lint' does not carry the line \"    if: \${{ !cancelled() && needs.changes.outputs.light != 'skip' }}\""
  check_fault "an output of the changes job under a wrong name is found" \
    "s/^      light: /      lite: /" \
    "the job 'changes' does not carry the line \"      light: "
  check_fault "a changes step without its id is found" \
    "/^        id: filter\$/ d" \
    "the job 'changes' does not carry the line \"        id: filter\""
  check_fault "a job of a group that ci.yml does not have is found" \
    "s/^  docs:\$/  documents:/" \
    "'docs' is in a group but is not a job"
  check_fault "a job that is in no group is found" \
    "\$ a\\
\\
  stranger:\\
    needs: changes" \
    "the job 'stranger' is in neither group"
  rm -rf "$dir"
}

# Runs the real diff on a scratch repository: the base and the head are commits of it. It counts
# into the `failures` and `total` of self_test.
check_real_diff() {
  local dir base zero tree old_tip log
  dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" config user.name scratch
  git -C "$dir" config user.email scratch@example.com
  mkdir -p "$dir/Sources" "$dir/Documentation"
  echo "let a = 1" > "$dir/Sources/A.swift"
  echo "text" > "$dir/README.md"
  echo "text" > "$dir/.coderabbit.yaml"
  git -C "$dir" add -A
  git -C "$dir" commit -q -m base
  base="$(git -C "$dir" rev-parse HEAD)"
  zero="0000000000000000000000000000000000000000"
  tree="$(git -C "$dir" rev-parse 'HEAD^{tree}')"

  # scratch_change <file> <content>: HEAD becomes one commit on top of the base that writes the file.
  scratch_change() {
    git -C "$dir" checkout -q -B scratch "$base"
    mkdir -p "$(dirname "$dir/$1")"
    echo "$2" > "$dir/$1"
    git -C "$dir" add -A
    git -C "$dir" commit -q -m change
  }
  # scratch_try <label> <expected output> <event> <base> <ref>
  scratch_try() {
    local actual
    actual="$(run_diff "$3" "$4" "$5" "$dir" 2>/dev/null | tr '\n' ' ')"
    actual="${actual% }"
    total=$((total + 1))
    if [ "$actual" = "$2" ]; then
      echo "ok: $1"
    else
      echo "FAIL: $1" >&2
      echo "  expected: $2" >&2
      echo "  actual:   $actual" >&2
      failures=$((failures + 1))
    fi
  }
  # scratch_warns <label> <event> <base> <ref>: the log holds a ::warning.
  scratch_warns() {
    total=$((total + 1))
    log="$(run_diff "$2" "$3" "$4" "$dir" 2>&1 >/dev/null)"
    if grep -q '^::warning' <<<"$log"; then
      echo "ok: $1"
    else
      echo "FAIL: $1" >&2
      failures=$((failures + 1))
    fi
  }

  local both="light=run heavy=run" docs="light=run heavy=skip" none="light=skip heavy=skip"
  scratch_change README.md changed
  scratch_try "a pull request that changes a document skips the heavy group" "$docs" \
    pull_request "$base" refs/pull/1/merge
  scratch_try "a push to main that changes a document skips the heavy group" "$docs" \
    push "$base" refs/heads/main
  scratch_try "a push to another branch that changes a document runs both groups" "$both" \
    push "$base" refs/heads/feature/x
  scratch_try "a push of a tag that changes a document runs both groups" "$both" \
    push "$base" refs/tags/v1.0.0
  scratch_try "a scheduled run on main runs both groups" "$both" schedule "$base" refs/heads/main
  scratch_try "a base that is not in the clone runs both groups" "$both" \
    push 1111111111111111111111111111111111111111 refs/heads/main
  scratch_try "a base of zeros, a new branch, runs both groups" "$both" \
    push "$zero" refs/heads/main
  scratch_try "a base that is a tree and not a commit runs both groups" "$both" \
    push "$tree" refs/heads/main
  scratch_try "a base that is a branch name runs both groups" "$both" push main refs/heads/main
  scratch_try "an empty base runs both groups" "$both" push "" refs/heads/main
  scratch_try "a base that is an option runs both groups" "$both" \
    push "--output=$dir/written" refs/heads/main
  total=$((total + 1))
  if [ -e "$dir/written..HEAD" ] || [ -e "$dir/written" ]; then
    echo "FAIL: a base that is an option was handed to git, and it wrote a file" >&2
    failures=$((failures + 1))
  else
    echo "ok: a base that is an option is not handed to git"
  fi
  scratch_warns "a diff that fails is a warning" push "$zero" refs/heads/main
  scratch_warns "a change that lists no path is a warning" push "$(git -C "$dir" rev-parse HEAD)" \
    refs/heads/main
  scratch_try "a change that lists no path runs both groups" "$both" \
    push "$(git -C "$dir" rev-parse HEAD)" refs/heads/main
  scratch_change .coderabbit.yaml changed
  scratch_try "a push to main that changes the inert file alone skips both groups" "$none" \
    push "$base" refs/heads/main
  scratch_change Sources/A.swift "let a = 2"
  old_tip="$(git -C "$dir" rev-parse HEAD)"
  scratch_try "a push to main that changes a source file runs both groups" "$both" \
    push "$base" refs/heads/main
  # The old tip of main had a source change that the new one does not: the trees differ in it.
  scratch_change README.md changed
  scratch_try "a forced push of main that drops a source change runs both groups" "$both" \
    push "$old_tip" refs/heads/main
  git -C "$dir" checkout -q -B scratch "$base"
  git -C "$dir" mv Sources/A.swift Documentation/A.md
  git -C "$dir" commit -q -m moved
  scratch_try "a source file moved to Documentation/*.md runs both groups" "$both" \
    push "$base" refs/heads/main
  scratch_change "Documentation/R$(printf '\303\251')sum$(printf '\303\251').md" text
  scratch_try "a document with a non-ASCII name skips the heavy group" "$docs" \
    push "$base" refs/heads/main
  # The runner reads a workflow command after the blanks at the start of a line.
  scratch_change "::notice::x.md" text
  scratch_try "a document whose name starts with :: skips the heavy group" "$docs" \
    push "$base" refs/heads/main
  total=$((total + 1))
  log="$(run_diff push "$base" refs/heads/main "$dir" 2>&1 >/dev/null)"
  if grep -qF '::notice::x.md' <<<"$log" && ! grep -qE '^[[:space:]]*::' <<<"$log"; then
    echo "ok: a file name that starts with :: is not a workflow command in the log"
  else
    echo "FAIL: a file name that starts with :: is a workflow command in the log, or is not listed" >&2
    failures=$((failures + 1))
  fi
  rm -rf "$dir"
}

# check_commit_names: is_commit_name takes the two lengths of a commit name and the lower case hex
# digits, and nothing next to them: each neighbour of a length and of the digit set is listed, so
# that a limit that is one too wide or one too narrow is found. It counts into the `failures` and
# `total` of self_test, through `verdict`.
check_commit_names() {
  local forty sixtyfour upper newline name expected
  forty="0123456789abcdef0123456789abcdef01234567"
  sixtyfour="${forty}89abcdef0123456789abcdef"
  upper="$(printf '%s' "$forty" | tr 'a-f' 'A-F')"
  newline='
'
  # name_case <label> <expected: yes or no> <text>
  name_case() {
    if is_commit_name "$3"; then expected=yes; else expected=no; fi
    verdict "$1" "$2" "$expected"
  }
  name_case "a commit name of 40 digits is a name" yes "$forty"
  name_case "a commit name of 64 digits is a name" yes "$sixtyfour"
  name_case "a name of 40 zeros is a name" yes "0000000000000000000000000000000000000000"
  name_case "a text of 32 digits is not a name" no "${forty%????????}"
  name_case "a text of 39 digits is not a name" no "${forty%?}"
  name_case "a text of 41 digits is not a name" no "${forty}0"
  name_case "a text of 63 digits is not a name" no "${sixtyfour%?}"
  name_case "a text of 65 digits is not a name" no "${sixtyfour}0"
  name_case "an empty text is not a name" no ""
  name_case "a name in upper case is not a name" no "$upper"
  # The characters next to the digits: each upper case digit, the letters after f, and the two that
  # stand next to 0 and 9 in the character set.
  for name in A B C D E F g G / :; do
    name_case "a text of 40 characters with a $name in place of a digit is not a name" no \
      "${name}${forty#?}"
  done
  name_case "a text of 40 characters that starts with a dash is not a name" no "-${forty#?}"
  name_case "a text of 40 characters with a space is not a name" no "${forty%?} "
  name_case "a text of 40 characters with a line break is not a name" no "${forty%?}$newline"
  name_case "a branch name is not a name" no "main"
  name="${forty}${newline}${forty}"
  name_case "two names on two lines are not a name" no "$name"
}

# check_contains: contains finds the part wherever it is, takes it as it is and not as a pattern,
# and says no when it is not there. It counts into the `failures` and `total` of self_test, through
# `verdict`.
check_contains() {
  local newline expected
  newline='
'
  # contains_case <label> <expected: yes or no> <text> <part>
  contains_case() {
    if contains "$3" "$4"; then expected=yes; else expected=no; fi
    verdict "$1" "$2" "$expected"
  }
  contains_case "a part in the middle is found" yes "abc" "b"
  contains_case "a part at the start is found" yes "abc" "a"
  contains_case "a part at the end is found" yes "abc" "c"
  contains_case "the whole text is found" yes "abc" "abc"
  contains_case "a part on a later line is found" yes "one${newline}two" "two"
  contains_case "a part that is not there is not found" no "abc" "d"
  contains_case "a part that is longer than the text is not found" no "a" "ab"
  contains_case "an empty part is found" yes "abc" ""
  contains_case "a star in the part is a star" yes "a*b" "*"
  contains_case "a star in the part is not a pattern" no "ab" "a*b"
  contains_case "a star alone is not found in a text that has none" no "ab" "*"
}

self_test() {
  local failures=0 total=0 path event ref actual stub
  local both=$'light=run\nheavy=run' docs=$'light=run\nheavy=skip' none=$'light=skip\nheavy=skip'

  # verdict <name> <expected output> <actual output>
  verdict() {
    total=$((total + 1))
    if [ "$3" = "$2" ]; then
      echo "ok: $1"
    else
      echo "FAIL: $1" >&2
      echo "  expected: $(echo "$2" | tr '\n' ' ')" >&2
      echo "  actual:   $(echo "$3" | tr '\n' ' ')" >&2
      failures=$((failures + 1))
    fi
  }

  # check_ref <name> <expected output> <event> <ref> [path...]
  check_ref() {
    local name="$1" expected="$2" actual
    local changed_event="$3" changed_ref="$4"
    shift 4
    # The list goes in by process substitution: an event that is not filtered reads none, and a
    # pipe to it would make printf fail, and the script with it, under pipefail.
    actual="$(decide "$changed_event" "$changed_ref" < <(printf '%s\n' "$@"))"
    verdict "$name" "$expected" "$actual"
  }

  # check_text <name> <expected output> <list as text, with \n for a line break>, on a pull request:
  # a list that check_ref cannot write, because it ends every path with a line break.
  check_text() {
    verdict "$1" "$2" "$(decide pull_request refs/pull/1/merge < <(printf '%b' "$3"))"
  }

  # check <name> <expected output> <event> [path...], on the ref of a pull request.
  check() {
    local name="$1" expected="$2" changed_event="$3"
    shift 3
    check_ref "$name" "$expected" "$changed_event" refs/pull/1/merge "$@"
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
    Documentation/Images/blur-modes.jpeg \
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
  check_text "a last path with no line break after it is read" "$docs" 'README.md'
  check_text "a blank line is not a path" "$docs" '\nREADME.md\n\n'

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
  check "a list with no path runs both groups" "$both" pull_request

  # A class that decide does not know stands for code, so a mistake in classify skips no job.
  unknown_class() { echo bogus; }
  no_class() { :; }
  for stub in unknown_class no_class; do
    total=$((total + 1))
    actual="$(classify() { "$stub"; }; decide pull_request refs/pull/1/merge <<<"Sources/X.swift")"
    if [ "$actual" = "$both" ]; then
      echo "ok: $stub for a source file runs both groups"
    else
      echo "FAIL: $stub for a source file does not run both groups" >&2
      failures=$((failures + 1))
    fi
  done

  # A scheduled run is on refs/heads/main as well, so the event decides before the ref does.
  # workflow_call is listed for a caller that passes it on: the release does not, it passes on a
  # push of a tag.
  for event in schedule workflow_dispatch workflow_call; do
    check_ref "$event on main with README.md alone runs both groups" "$both" "$event" \
      refs/heads/main README.md
    check_ref "$event on main with the inert file alone runs both groups" "$both" "$event" \
      refs/heads/main .coderabbit.yaml
  done
  check_ref "a push to main with README.md alone skips the heavy group" "$docs" push \
    refs/heads/main README.md
  check_ref "a push to main with the inert file alone skips both groups" "$none" push \
    refs/heads/main .coderabbit.yaml
  check_ref "a push to main with a Swift file runs both groups" "$both" push refs/heads/main \
    Sources/DMVariableBlurView/DMVariableBlurView.swift
  check_ref "a push to main with a list of no path runs both groups" "$both" push refs/heads/main
  for ref in refs/heads/feature/x refs/heads/feature/main refs/heads/main2 refs/heads/mainline \
    refs/tags/v1.2.3 refs/tags/main main ""; do
    check_ref "a push to '$ref' with README.md alone runs both groups" "$both" push "$ref" \
      README.md
  done

  check_commit_names
  check_contains
  check_job_table
  check_real_diff
  if [ "$failures" -ne 0 ]; then
    echo "ci-changes: $failures of $total cases failed." >&2
    return 1
  fi
  echo "ci-changes: all $total cases passed."
}

usage() {
  echo "usage: ci-changes.sh <event> <base> <ref> | --classify <event> <ref> < paths | --self-test" >&2
  exit 64
}

case "${1:-}" in
  --self-test) self_test ;;
  --classify) [ "$#" -eq 3 ] || usage; decide "$2" "$3" ;;
  "" | -*) usage ;;
  *) [ "$#" -eq 3 ] || usage; run_diff "$1" "$2" "$3" ;;
esac
