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
| `Scripts/lint.sh` | SwiftLint, at the version pinned in `.swiftlint.yml`. The first run fetches that version into `.build/tools` and checks its checksum. `--analyze <xcodebuild log>` also runs the analyzer rule for unused imports. It needs the log of a clean build: a log without compiler invocations stops the run |
| `Scripts/check-api.sh` | the public interface against `Fixtures/API/public-interface.txt`; `--self-test` runs the cases of its normalisation; `--since <ref>` prints, without a compiler, the lines the baseline lost, changed or gained since a git ref such as a release tag. A deliberate change of the public API updates the baseline in the same commit |
| `Scripts/check-manifest.sh` | the manifest, installation by version, the consumer fixture, that no resource bundle ships, and every Swift block of `README.md`, each on its own: a manifest block is evaluated, every other block compiled. A warning in a block fails it too |
| `Scripts/check-lint-contract.sh` | that each rule in the `RULES` of the script fires on the lines of `Fixtures/Lint` that expect it and on no other line. It lints the fixtures in a scratch copy with the `.swiftlint.yml` of the repository, unchanged |
| `Scripts/check-podspec.sh` | `pod lib lint` in Swift 5.0 and 6.0 mode, and that the pod links no test framework |
| `Scripts/coverage-gate.sh <result bundle>` | the line coverage of the library against its floor |
| `Scripts/check-release.sh <version>` | that the newest heading of `CHANGELOG.md` is that version, with a release date that is a day of the calendar and notes under it, and that the podspec still names 1.1.0, the version the pod is frozen at; it also compares the release with the one below it in the changelog and refuses a version that keeps its major version after a removed or changed line of the interface, or after a `### Breaking changes` subsection |
| `Scripts/check-example-project.sh` | that the Xcode project of the example matches its XcodeGen spec |

The checks run code that the branch contains: `Package.swift` and the manifest blocks of the README
are evaluated by Swift Package Manager, the podspec by CocoaPods, and `project.yml` by XcodeGen.
Before you run them on someone else's branch, read what that branch changes in those files.

## The example app

`Examples/DMVariableBlurViewExample` uses the package from this checkout. Its rendering tests,
snapshot tests and UI tests run with:

```bash
xcodebuild test -project Examples/DMVariableBlurViewExample/DMVariableBlurViewExample.xcodeproj -scheme DMVariableBlurViewExample -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

The snapshot references live in `Examples/DMVariableBlurViewExample/Snapshots`, one set for each
iOS version, named `<name>_ios<major>_<minor>.1.png`. A local run records a missing reference and
fails once; CI never records one. To record a reference again, move the old file away, run the
tests on that iOS version, look at the new picture, and commit it with the reason.

CI checks how many tests each cell of the `example` job ran: the `passed` and `skipped` numbers of
that cell in `.github/workflows/ci.yml` must equal the ones in the result bundle, and no test may
fail. A new test of the example changes them, and so does recording the snapshot references of a
runtime that had none, since its snapshot tests were skipped and now run. Change the numbers in the
same commit.

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
   the pod is frozen.
2. Every breaking change, as ENGINEERING.md defines it, needs a new major version, with no
   exception for a small one. A removed or changed line of the interface is one:
   `Scripts/check-api.sh --since <previous version>` lists them. A change of behaviour is another,
   and the notes of the release declare it in a `### Breaking changes` subsection, in any letter
   case, because no script can see behaviour: a change listed under `### Changed` alone does not
   count.
   `Scripts/check-release.sh` refuses a version that keeps the major version of the previous one
   when it finds either. Lines that were only added pass the script. A new case in a public enum
   is breaking and needs a major version; a requirement added to a protocol or an overload is
   additive only after a review that it makes no existing call ambiguous and asks nothing of a
   conformer, under the conditions of ENGINEERING.md. The script cannot classify an added line, and
   it cannot see the order of the cases of an enum or of the statements in the body of an
   inlinable function.
   It cannot tell a line that a new compiler reworded from a line that the code changed, so both
   count. Run `Scripts/check-api.sh` first, since the baseline is the interface of the library
   only while that check passes.
3. The tests of the package and of the example app pass on an iOS 17 simulator, the oldest version
   the package supports. CI's oldest runtime is iOS 18.5, so this run is local:
   `xcodebuild test -scheme DMVariableBlurView -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'`,
   and the same destination for the example's scheme.

On the tag, the release workflow runs the check, makes sure the tagged commit is on `main`, runs the
whole CI workflow, makes sure the tag still points at the commit CI tested, and drafts a GitHub
release from the changelog section. Publishing the release stays a manual step, and nothing goes to
the CocoaPods trunk.

## Security

Do not report a vulnerability in a public issue. See `SECURITY.md`.
