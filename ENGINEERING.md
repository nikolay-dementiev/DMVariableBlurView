# Engineering standard

This is the standard DMVariableBlurView is built by: what a change to its public interface and
behaviour costs, what the package is made of, and which toolchains and platforms it promises.
[CONTRIBUTING.md](CONTRIBUTING.md) has the commands, the checks CI runs, the rules for tests and
the release steps. This file does not repeat them.

## Public API and behaviour

DMVariableBlurView is a published library, so what a consumer can see is a contract: every
`public` declaration and every observable behaviour. The public declarations are the SwiftUI view
`DMVariableBlurView`, the UIKit class `DMVariableBlurUIView` and the enums `DMVariableBlurDirection`
and `DMVariableBlurError`; `Fixtures/API/public-interface.txt` lists every line of them. Each change
belongs to one of three classes:

- **none**: no declaration and no observable behaviour changes.
- **additive**: new declarations only, with `Fixtures/API/public-interface.txt` updated in the same
  commit, and nothing a consumer must do. A raised minimum version of a dependency can be additive
  under the conditions below the table.
- **breaking**: anything else.

The rule is strict and has no carve-out: every change of observable behaviour is breaking. That
includes a crash that stops happening and a behaviour brought back in line with the documentation.
A breaking change needs the maintainer's decision, an entry in `CHANGELOG.md`, with a change of
behaviour declared in a `### Breaking changes` subsection, and a major version. This is stricter
than a reading of semantic versioning that allows a patch release for a fix of a bug.

| Change | Class | Release |
|---|---|---|
| A changed default value, such as the 20 of `maxBlurRadius` or the 0.3 of `centerBandProportion` | breaking | major |
| A new case in a public enum that a consumer can switch over (`DMVariableBlurDirection` and `DMVariableBlurError` are two) | breaking | major |
| A value that was applied and is now rejected, or a failure that was dropped and is now reported | breaking | major |
| A new protocol requirement without a default implementation (the package declares no public protocol today) | breaking | major |
| A new protocol requirement with a default implementation | additive or breaking, see below | minor or major |
| An added overload | additive, or breaking if an existing call now resolves to it or becomes ambiguous | minor or major |
| Depending on a new major version of a dependency (the package has none) | breaking | major |
| Raising the minimum version of a dependency within the same major | additive or breaking, see below | minor or major |
| A CI or tool pin that leaves the compiler of the `api` job alone, such as a runner image or the SwiftLint version | none | patch, or no release |
| A pure refactor | none | patch, or no release |
| A crash that stops happening | breaking | major |

A new protocol requirement with a default implementation is additive only when its name is new to
the protocol and to its extensions, and a review finds no member of a conformer that the
requirement would capture. A name that a protocol extension already declares changes how a call is
dispatched: the extension method was called statically and the requirement is called dynamically,
so a conformer's own member of that name starts to be called. That is a change of behaviour, so it
is breaking.

Raising the minimum version of a dependency within the same major version is additive only when it
moves no platform floor, changes no behaviour and asks nothing of a consumer. It then needs a minor
release and its own line in the changelog. A raise that does any of these is breaking.

The package has no dependency today. `Tools/Package.swift` depends on DMDevKit, the development
tooling that the wrappers listed by `WRAPPERS` in `devkit.conf` forward to, but it is a package of
its own: SwiftPM reads the manifest at the root of a dependency only, so a consumer of this package
does not fetch DMDevKit, and the root manifest that this policy and `Scripts/check-manifest.sh`
govern does not change.

Who checks. The `api` job of CI runs `Scripts/check-api.sh --self-test` and `Scripts/check-api.sh`
on every pull request and fails it when the public interface differs from the baseline; on a pull
request it also writes to the job summary the delta against the base of the pull request.
`Scripts/check-release.sh` runs on the version tag, and before it by whoever releases. The previous
release comes from the tags: it is the highest release tag below the version that the commit
reaches, and the heading right below the newest one in `CHANGELOG.md` has to name it. A heading of
another form, one that is not lower than the version, one that skips a reachable release tag, and
no heading below although a release tag is reachable are each a problem. The script refuses a
version that keeps the major version of the previous release when the baseline lost or changed a
line since that release, when the notes of the version have a breaking-changes heading (a heading
of any level, or a line in bold, whose first word is "breaking", in any letter case; `No breaking
changes` does not count), or when the digester reports a break where there is one. The digester,
`Scripts/check-api-digester.sh <previous>`, ends with status 0 for no break and with status 1 and a
line `N breaking change(s) detected in <module>` for a break, which the script prints; status 1
without that line, or any other status, is a comparison that could not be made, exit 2. The script
also refuses a release whose previous release is not an ancestor of the commit being released.
Where the history cannot say which release is below the version, as in a shallow clone, it stops
with exit 2 when the newest heading is for the version, so a run before the tag needs the whole
history and the tags (`git fetch --unshallow --tags`). A clone with no tags and a changelog with a
single release heading is read as the first release, and the script says so. A heading below the
newest one that looks like a release and is not of a form the script reads, a version with a group
of ten digits or more, and a `CHANGELOG.md` that is not there (exit 2) are refused too. The lines
show an added case of a public enum, an added protocol requirement or an added overload only as an
added line, which passes the script with a reminder to review it. The reminder is also a warning
annotation in the log of a run under GitHub Actions, which is the release run. It names an added
case of a public enum, a protocol requirement added without a default implementation and an
overload that makes an existing call ambiguous as breaking, and says that a requirement with a
default implementation is additive only when its name is new to the protocol and to its
extensions; it cannot see which of them an added line is, and the review above decides.
`Scripts/check-release.sh --self-test`, which the `api` job runs, tries the decisions of the script
(DMDevKit's, since the script forwards to it) on scratch repositories. The script cannot tell a line that a new compiler reworded
from a line that the code changed, so both count. It does not see the order of the cases of an enum
or the statements in the body of an inlinable function (the package has no inlinable function
today), and it cannot see behaviour. The pull request template asks for the class, the changes of
observable behaviour and the release the change needs. The reviewer applies the rest: that the
baseline changes in the same commit as the declaration; that an added case of a public enum gets a
major version, as the table says; whether an added line adds a requirement or an overload that
makes an existing call ambiguous; the order of the cases of an enum, where a raw value or
`allCases` depends on it; and every change of observable behaviour that the notes do not declare,
which a test catches only where a test pins the behaviour.

## Deprecation

No compiler deprecation attribute ships in a 1.x release. Its warning appears at every use of the
symbol and fails a consumer that builds with warnings as errors, so it would turn a notice into a
breaking change. A symbol is retired in the documentation instead: the replacement and a
migration example say what to use. The next major version removes it. `Scripts/check-release.sh`
counts a deprecation attribute on a declaration that already exists as a changed line and refuses
it in a release that keeps the major version; a declaration added already deprecated is only an
added line, and the reviewer applies this rule to it.

## History

Version 1.1.0 changed behaviour under a minor version (`CHANGELOG.md`, 1.1.0, "Changed": the rules
for `startOffset` and for rejected values, and the way the mask is drawn). Under the rules above it
would have needed a major version. The rules apply from the release after 1.1.0. A fix of behaviour
is a breaking change too, and needs a major version.

## The package as it is

- **Three layers, by folder.** `Sources/DMVariableBlurView/Domain` holds the values and the
  decisions that need no UI framework: `DMVariableBlurDirection`, `DMVariableBlurError`,
  `VariableBlurConfiguration` and `BlurMaskProfile`, which says how strongly each height of the view
  is blurred. The folder imports Foundation and CoreGraphics only, and `Scripts/lint.sh` enforces
  that: the custom rule `domain_imports` reports any other import in it. `Adapters` wraps the
  system: four `package` protocols, `FailureLog`, `MaskImageRenderer`, `ReduceTransparencySetting`
  and `VariableBlurInstaller`, and the implementations that touch UIKit, CoreGraphics, `os` and the
  private filter. `UI` holds the two public views and `VariableBlurCollaborators`, the set of
  collaborators they use. The dependencies point inward: `Domain` names no
  type of the other two folders, and `Adapters` names no type of `UI`. No tool checks that, because
  an import restricts nothing inside one module; the reviewer applies it. There is no further
  layer, no view model and no coordinator.
- **Collaborators and the composition root.** The four protocols have `package` access, so a test
  inside the package replaces a collaborator and a consumer cannot. The concrete implementations
  are created in one place, `VariableBlurCollaborators.system`
  (`UI/VariableBlurCollaborators.swift`), and the two public views take them from there; the
  reviewer applies that no other file of the library creates one.
- **A private system API.** The view reaches a filter of the system that is not public. The README,
  "Private API", lists its names, the checks made before the filter is installed and the risk that
  remains; this file does not restate them. A new private name of the system is a decision for the
  maintainer (CONTRIBUTING.md, "Commits and pull requests").
- **A failure reaches the host.** When a value is not valid, the system does not offer the filter
  or the image that shapes the blur cannot be created, the view shows the plain blur of the system
  over its whole frame. The one exception is a `DMVariableBlurUIView` whose `effect` the host has
  set to `nil`, which shows no blur until it gets an effect back. The view records the reason as a
  `DMVariableBlurError`. In SwiftUI a handler passed to `onFailure(_:)` receives it, and in UIKit
  the handler of the initializer that takes `onFailure:` does; the unified log gets one line when
  no handler is set. In UIKit the `failure` property holds it as well. The README, "Failures", and the DocC article Handling failures
  (`Sources/DMVariableBlurView/DMVariableBlurView.docc/HandlingFailures.md`) have the details.
- **The library does not stop its host.** Its sources contain no `fatalError`,
  `preconditionFailure`, `assertionFailure`, `precondition`, `assert`, `dispatchPrecondition`,
  `abort` or `exit`, no force unwrap, no `try!`, no `as!` and no implicitly unwrapped optional.
  `Scripts/lint.sh` rejects, over `Sources`, one of those names followed by an opening parenthesis,
  also when a module name or a receiver stands before it (the custom rule `no_process_termination`),
  and SwiftLint's `force_unwrapping`, `implicitly_unwrapped_optional`, `force_try` and `force_cast`
  reject force
  unwraps, implicitly unwrapped optionals, `try!` and `as!`. The force unwrap rule has no exemption
  for a call with a literal argument, so `URL(string: "...")!` is rejected too. Another way to end
  a process, such as `_exit(` or `raise(`, stays with the reviewer. One thing stays outside the
  library's own code: an exception raised inside the private code of the system cannot be caught
  from Swift and ends the app (README, "Private API").
- **The rules are tested.** A rule that never matches reports nothing, so
  `Scripts/check-lint-contract.sh` lints the fixtures of `Fixtures/Lint` and checks that the rules
  in the `RULES` of `devkit.conf` (`domain_imports`, `no_process_termination`, `force_unwrapping`,
  `force_cast`, `force_try` and `implicitly_unwrapped_optional`) fire on the lines that expect them
  and on no other line. A fixture is linted where its folder says: one in the root of `Fixtures/Lint` as a
  file of the library, one in `Domain`, `UI` or `Adapters` in that folder of the library, and one
  under `Outside` outside the library, where it expects nothing. So the contract shows where a
  rule reaches. `domain_imports` fires in `Domain` and its subfolders and in no other folder of the
  library, and not in the `Domain` folder of another module. `no_process_termination` reaches
  `Domain`, `UI`, `Adapters` and the root of the library, and not another module, the consumer
  fixture, the tests or the example app. A rule that is widened to another folder, module or the
  tests, narrowed to some of the folders it names, or aimed at a module whose name starts like the
  library's fails it. It does not notice that `Domain` was renamed while the include of
  `domain_imports` was left alone, so the reviewer applies that. `domain_imports` does not see an
  import that has a comment inside it, that follows a block comment on its line, or that names the
  module in backticks. The helper that fetches SwiftLint, the `swiftlint-tool.sh` of DMDevKit, is
  tested too: `Scripts/check-lint-tool.sh` proves, with a fake archive and no network, that two
  runs on one checkout at once do not break each other and that a failed fetch leaves nothing
  behind. The wrappers that `WRAPPERS` in `devkit.conf` lists are tested as well:
  `devkit check-wrappers`, which CI runs directly and `Scripts/check-wrappers.sh` forwards to,
  proves that each hands its command, arguments, directory, status and streams over unchanged.
- **Isolation.** The package builds in the Swift 6 language mode. Both views are `@MainActor`, the
  two public enums are `Sendable` and the handler of `onFailure(_:)` is `@MainActor @Sendable`.
- **Tests do not wait a fixed time.** A report reaches the handler of `onFailure(_:)` in a later
  turn of the main actor, so a test that expects one waits for it with `FailureReportRecorder`
  (`Tests/DMVariableBlurViewTests/Support`): until the number of reports is reached, within 5
  seconds, so that a slow runner does not fail it, and, only where the contract is that nothing
  arrives, for a quiet interval of 100 milliseconds. The recorder counts the reports itself,
  because an expectation that asserts on over-fulfilment aborts the whole test process and does
  not name the test. A `Task.sleep` in a test is a finding.
- **Documented limits.** What the library enforces and what it cannot promise are in the README,
  "Behaviour your app must know", and in the DocC catalog. This file points to them and does not
  restate them. A change of one of those limits is a change of behaviour.

## Toolchain and platforms

- The manifest declares `swift-tools-version: 6.0` and the Swift 6 language mode, so the package
  needs Xcode 16.0 or later. `ExistentialAny` is on in both targets.
- The supported platform is iOS 17.0 and later. The manifest declares no other platform, and the
  deployment target of the podspec is iOS 17.0. Raising the platform floor, or the
  `swift-tools-version`, is a breaking change.
- `.github/workflows/ci.yml` is the place that says what CI runs; this file does not restate it.
  The policy needs three facts. The oldest iOS runtime that CI runs is iOS 18.5. iOS 17.5 runs
  locally before a release (CONTRIBUTING.md, "Releases"). The `floor` job compiles the library with
  Swift 6.0, the oldest compiler line the manifest allows, with warnings as errors, and runs no
  test.
- The gates below were tried with the failure each advertises, on Xcode 26.6 and iOS 26.5 (the
  older cell of the `test` job on iOS 18.6, the nearest runtime installed). The `test` job counts
  the test methods of `Tests` and fails unless every one ran and passed and none skipped: a lost
  class and a test that skips itself passed the coverage floor alone. A race fails the
  `thread-sanitizer` job with `halt_on_error=1` and without it: the sanitizer aborts the test
  process and the run fails. A snapshot reference that is missing in the newest cell of the
  `example` job fails the test and is not written. A warning in code that only a Release build
  compiles fails three routes, the Release step of the `test` job, the `floor` job and the
  `podspec` job, and none of the Debug routes sees it.
- "Oldest tested runtime" and "oldest supported version" are different statements. The supported
  version is a promise: the platform the manifest declares. The tested runtime is evidence: the
  oldest runtime a test has run on. That is iOS 17.5 against a promise of iOS 17.0.
- No third-party dependency without the maintainer's approval. `Scripts/check-manifest.sh` fails on
  any dependency, on a plugin used by any target, on a plugin target and on a binary target with a
  url (code that is downloaded when the package is resolved), in `Package.swift` and in every
  `Package@swift-*.swift`, which SwiftPM reads in place of it when a consumer's tools are newer,
  and names the problem after its file: it keeps failing until the maintainer approves the
  dependency and the check changes in the same pull request. A binary target with a path is
  carried by the repository and is not refused. The script also checks that the installation
  manifest of the README, with its URL pointed at a tagged copy of the tracked manifest and
  sources, resolves and builds for the iOS simulator and that its consumer resolves this package
  only, that `Fixtures/Consumer` builds, that no resource bundle ships and that every Swift block
  of the README compiles, a manifest block being evaluated. The URL the README names must be the
  `:git` source of the podspec, character for character, and its version that of the newest dated
  release heading of `CHANGELOG.md`: the podspec is frozen, and a tag is not there before a
  release, in a shallow clone or in a pull request from a fork. Its `--self-test` runs the readers
  of the manifest, of the README and of `Package.resolved` on built-in texts, and not the shell
  around them. The approval itself is a rule the reviewer applies.
- XCTest is the test framework. A test goes through the public API and through the `package`
  declarations of the module, the four protocols, their implementations and the domain values; it
  never uses `@testable import`, and the reviewer applies that. Another framework comes only by the
  maintainer's decision.
- The manifest sets no `defaultIsolation`: it would change the inferred isolation of public
  declarations, which is observable behaviour.
- The CocoaPods channel is frozen at 1.1.0 (README, "CocoaPods").

## Where the rest lives

- [CONTRIBUTING.md](CONTRIBUTING.md): how to build and test, the checks CI runs, the rules for
  tests, commits and releases.
- `Sources/DMVariableBlurView/DMVariableBlurView.docc`: what each symbol does, how a failure is
  reported and how the blur works.
- [CHANGELOG.md](CHANGELOG.md): the history of every release.
- [README.md](README.md): installation and usage.
