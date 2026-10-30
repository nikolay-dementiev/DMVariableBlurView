# Contributing to DMVariableBlurView

Thank you for helping. This guide says how to build and test the package, what a test must do, and
how to propose a change. [ENGINEERING.md](ENGINEERING.md) has the architecture and the
compatibility and release policy.

## Build and test

You need Xcode 16.0 or later (Swift 6.0) and an iOS simulator. CI tests with Xcode 16.4 and 26.6,
and compiles the library with Xcode 16.0. The
library is for iOS only, so its tests run on a simulator, with warnings as errors:

```bash
xcodebuild test -scheme DMVariableBlurView -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -enableCodeCoverage YES SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
```

## The checks CI runs

The checks below are scripts in `Scripts/`, and CI runs them as you do, except
`check-example-project.sh`, which needs XcodeGen.

| Script | What it checks |
|---|---|
| `Scripts/lint.sh` | SwiftLint, at the version pinned in `.swiftlint.yml`. The first run fetches that version into `.build/tools` and checks its checksum, and two runs that fetch at once on one checkout do not break each other. `--analyze <xcodebuild log>` also runs the analyzer rule for unused imports. It needs the log of a clean build whose DerivedData is still on disk: a log without compiler invocations, or one whose files are gone, stops the run with status 2, and `--analyze` with no log or with one that cannot be read ends with status 1 |
| `Scripts/check-api.sh` | the public interface against `Fixtures/API/public-interface.txt`; `--self-test` runs the cases of its normalisation; `--since <ref>` prints, without a compiler, the lines the baseline lost, changed or gained since a git ref such as a release tag. A deliberate change of the public API updates the baseline in the same commit |
| `Scripts/check-manifest.sh` | that no manifest file (`Package.swift` and every `Package@swift-*.swift`) declares a dependency, uses a plugin, declares a plugin target or declares a binary target with a url; that the installation manifest of `README.md`, with its URL pointed at a tagged copy of the tracked manifest and sources, resolves and builds for the iOS simulator and that its consumer resolves this package only, and that the URL it names is the `:git` source of the podspec, character for character, and its version that of the newest dated release heading of `CHANGELOG.md`; the consumer fixture; that no resource bundle ships; and every Swift block of `README.md`, each on its own: a manifest block is evaluated, every other block compiled. A warning in a block fails it too. `--self-test` runs the readers of the manifest, of the README and of `Package.resolved` on built-in texts, with no build |
| `Scripts/check-lint-contract.sh` | that each rule in the `RULES` of `devkit.conf` fires on the lines of `Fixtures/Lint` that expect it and on no other line. It lints the fixtures in a scratch copy with the `.swiftlint.yml` of the repository, unchanged, each where its folder says: one in the root as a file of the library, one in `Domain`, `UI` or `Adapters`, or in a subfolder of one, in that folder, one under `Outside` outside the library, where it expects nothing |
| `Scripts/check-lint-tool.sh` | that the helper which fetches SwiftLint (the `swiftlint-tool.sh` of DMDevKit) does so safely when two runs overlap: the tool stays whole while another run unpacks, two first-time runs both succeed, a wrong checksum never reaches the unpack, and a failed fetch leaves nothing behind. It needs no network and no SwiftLint |
| `Scripts/check-wrappers.sh` | that the four scripts which forward to `devkit` forward faithfully: with a shim in place of `swift` it checks the command and the arguments that reach `devkit`, the directory, the exit status and both standard streams, and that each script works from any directory |
| `Scripts/check-podspec.sh` | `pod lib lint` in Swift 5.0 and 6.0 mode, and that the pod links no test framework |
| `Scripts/coverage-gate.sh <result bundle>` | the line coverage of the library against its floor |
| `Scripts/check-release.sh <version>` | that the newest heading of `CHANGELOG.md` is that version, with a release date that is a day of the calendar and notes under it, and that the podspec still names 1.1.0, the version the pod is frozen at; it also takes the previous release from the tags (the highest release tag below the version that the commit reaches) and refuses a changelog whose heading below the newest does not name it, is not lower than the version or skips a reachable tag; it compares the release with it and refuses a version that keeps its major version after a removed or changed line of the interface, a breaking-changes heading in the notes (a heading of any level, or a bold line, whose first word is "breaking") or a break reported by the digester where there is one; it refuses a release whose previous release is not an ancestor of the commit, and stops with exit 2 in a shallow clone. Under GitHub Actions the reminder for added lines is also a warning annotation. `--self-test` runs these decisions on scratch repositories |
| `Scripts/check-example-project.sh` | that the Xcode project of the example matches its XcodeGen spec |

The checks run code that the branch contains: `Package.swift`, every `Package@swift-*.swift` and the
manifest blocks of the README are evaluated by Swift Package Manager, the podspec by CocoaPods, and `project.yml` by XcodeGen.
`Tools/Package.swift` and `devkit.conf` are code of the same kind: `devkit.conf` is shell code that
runs with your rights. Before you run the checks on someone else's branch, read what that branch
changes in those files.

## The tools

`Scripts/lint.sh`, `Scripts/check-lint-contract.sh`, `Scripts/check-lint-tool.sh` and
`Scripts/prepare-simulator.sh` are wrappers of
[DMDevKit](https://github.com/nikolay-dementiev/DMDevKit), the tooling that DMAction,
DMVariableBlurView and DMUnLoader are to share. Each goes to the repository root, which `devkit`
finds with git, so run them in a clone, and runs
`swift run --quiet --package-path Tools devkit <command>` with the arguments it was given, so the
paths that CI and this file name stay as they were. The other scripts of `Scripts/` have not moved.

- `Tools/Package.swift` is a package of its own. It pins a release of DMDevKit, and
  `Tools/Package.resolved` pins its commit; Dependabot proposes the newer releases. SwiftPM reads
  only the manifest at the root of a dependency, so a package that depends on this one does not
  fetch DMDevKit.
- `devkit.conf` holds the settings of this repository that the commands read: the library folder,
  the lint rules and the folder of their fixtures. A change to a command is a change to DMDevKit.
- The first run builds `devkit`, takes several seconds and prints the lines that SwiftPM writes
  while it fetches DMDevKit; each next run adds about a second to the script. If `swift run`
  itself fails, a fetch or a build, the script ends with its status, which can be 1, the status
  that the scripts also use for findings.
- A clean checkout gets SwiftLint, at the version that `.swiftlint.yml` pins, by running
  `Scripts/lint.sh`, or alone with
  `swift run --quiet --package-path Tools devkit swiftlint-fetch 0.65.1`.
  Both need `curl`, `unzip` and `shasum`. `.swiftlint.yml` can pin only a version that DMDevKit
  has a checksum for: for another one `Scripts/lint.sh` ends with status 2 and says so, so a
  bump of SwiftLint waits for a DMDevKit release that knows the version.
- `swift run --quiet --package-path Tools devkit --help` lists the commands.

## The example app

`Examples/DMVariableBlurViewExample` uses the package from this checkout. Its rendering tests,
snapshot tests and UI tests run with:

```bash
xcodebuild test -project Examples/DMVariableBlurViewExample/DMVariableBlurViewExample.xcodeproj -scheme DMVariableBlurViewExample -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

The snapshot references live in `Examples/DMVariableBlurViewExample/Snapshots`, one set for each
device and iOS version, named `<name>_<device>_ios<major>_<minor>.1.png`, for example
`blurredFully_iPhone17_ios26_5.1.png`. The device is the name the simulator gives the test process
in `SIMULATOR_DEVICE_NAME`, reduced to its letters and digits; a run that has none fails and does
not guess. A local run records a missing reference and fails once; CI never records one. The cell
of the `example` job that runs iPhone 17 on iOS 26.5 compares the set of that device and requires
it. A reference that another device recorded is not one of this run, even on the same iOS version.
To record a reference again, move the old file away, run the tests on that device and iOS version,
look at the new picture, and commit it with the device, the iOS version and the reason.

CI checks how many tests each cell of the `example` job ran: the `passed` and `skipped` numbers of
that cell in `.github/workflows/ci.yml` must equal the ones in the result bundle, and no test may
fail. A new test of the example changes them, and so does recording the snapshot references of a
device and iOS version that had none, since its snapshot tests were skipped and now run. Change the
numbers in the same commit.

CI checks the tests of the package in the same way in every cell of the `test` job: the step "Check
the test count" counts the test methods of `Tests` (a `func test...()` on one line, with attributes
and the modifiers `public`, `open`, `internal`, `final`, `override` and `nonisolated` allowed
before `func`) and fails unless the result bundle holds exactly that many tests passed, none failed
and none skipped. A test that you add needs no number to change, but it has to be written in a
shape the pattern in `.github/workflows/ci.yml` counts: one that it does not count makes the step
fail, which is how you find out. A class that a run leaves out, and a test that skips itself, fail
it; the coverage floor does not see either. Two tests of `ReduceTransparencyTests` skip themselves
when Reduce Transparency is on, so a simulator that has it on fails the step by design.

The Xcode project is generated with XcodeGen 2.45.3 from `Examples/DMVariableBlurViewExample/project.yml`,
and both are committed. Change the spec, not the project:
`Scripts/check-example-project.sh --update` regenerates the project, and
`Scripts/check-example-project.sh` checks that the two agree. Both stop when the machine has another
version of XcodeGen. CI does not install XcodeGen, so this check is yours to run before you commit a
change to the example's project.

## Tests

- XCTest, through the public API: no `@testable import`. A collaborator that a test must replace
  is declared `package`, and the test imports the module plainly.
- One `makeSUT()` factory per test class, and hand-written spies that record calls.
- Names say the subject, the condition and the expected result:
  `test_<subject>_<condition>_<expected>`.
- In a test with two or more assertions, every assertion carries a message.
- A test must be able to fail. Show it red against the code before your change, or, for a test of
  behaviour that already holds, with a temporary change of the code it covers.
- A fix starts with a test that reproduces the defect.

## Commits and pull requests

- One topic per commit, with a conventional prefix: `test:`, `fix:`, `feat:`, `refactor:`, `docs:`,
  `chore:`, `ci:` or `perf:`.
- The commit with a failing test comes before the commit that makes it pass.
- Pull requests go to `main` and are merged with a merge commit, so the test and fix pairs stay
  visible.
- A change that people using the package can notice gets an entry in `CHANGELOG.md`.
- A new private name of the system in the library is a decision for the maintainer: say so in the
  pull request, and add it to the lists in the README and in the article How the blur works.

## Releases

A release starts from a tag that is the version itself, such as `1.1.0`, on a commit of `main`:
merge first, then tag. Before the tag is pushed:

1. The newest heading of `CHANGELOG.md` is `## [<version>] -` with the release date and the notes
   under it. `Scripts/check-release.sh <version>` checks it. The podspec stays at 1.1.0 because
   the pod is frozen. The installation manifest in the README asks for `from: "<version>"` in the
   same change as the heading: `Scripts/check-manifest.sh` compares it with the newest dated
   heading.
2. Every breaking change, as ENGINEERING.md defines it, needs a new major version, with no
   exception for a small one. A removed or changed line of the interface is one:
   `Scripts/check-api.sh --since <previous version>` lists them. A change of behaviour is another,
   and the notes of the release declare it in a `### Breaking changes` heading, because no script
   can see behaviour: a heading of any level, or a line in bold, in any letter case, whose first
   word is "breaking" (`#### Breaking changes (API)` counts, `### No breaking changes` does not). A
   change listed under `### Changed` alone does not count.
   `Scripts/check-release.sh` takes the previous release from the tags, not from the changelog: the
   heading below the newest one has to name the highest release tag below the version that the
   commit reaches, so a release that the changelog skips is named. A run before the tag needs the
   whole history and the tags: in a shallow clone it stops (`git fetch --unshallow --tags`). The
   script refuses a version that keeps the major version of the previous one when the baseline
   lost or changed a line, when the notes have a heading of breaking changes, or when the digester
   reports a break. Lines that were only added pass the script, with a reminder that is also a
   warning annotation in the log of the release run. A new case in a public enum is breaking and
   needs a major version; a requirement added to a protocol or an overload is additive only after
   a review that it makes no existing call ambiguous and asks nothing of a
   conformer, under the conditions of ENGINEERING.md. The script cannot classify an added line, and
   it cannot see the order of the cases of an enum or of the statements in the body of an
   inlinable function.
   It cannot tell a line that a new compiler reworded from a line that the code changed, so both
   count. Run `Scripts/check-api.sh` first, since the baseline is the interface of the library
   only while that check passes.
3. The tests of the package and of the example app pass on an iOS 17 simulator, the oldest version
   the package supports. CI's oldest runtime is iOS 18.5, so this run is local:
   `xcodebuild test -scheme DMVariableBlurView -destination 'platform=iOS Simulator,name=iPhone 14,OS=17.5'`,
   and the same destination for the example's scheme. The snapshot references of iOS 17.5 were
   recorded on that iPhone 14 and only this local run compares them: CI compares the set of the
   iPhone 17 on iOS 26.5, and its iOS 18.5 cell, an iPhone 16, has no set and skips the snapshot
   tests. The references of iOS 18.6 were recorded on an iPhone 16 and are local too: the same
   command with `name=iPhone 16,OS=18.6` compares them. Another device records a set of its own
   on its first run and fails once.

On the tag, the release workflow runs the check, makes sure the tagged commit is on `main`, runs the
whole CI workflow, makes sure the tag still points at the commit CI tested, and drafts a GitHub
release from the changelog section. Publishing the release stays a manual step, and nothing goes to
the CocoaPods trunk.

## Security

Do not report a vulnerability in a public issue. See `SECURITY.md`.
