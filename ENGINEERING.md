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

The package has no dependency today.

Who checks. The `api` job of CI runs `Scripts/check-api.sh --self-test` and `Scripts/check-api.sh`
on every pull request and fails it when the public interface differs from the baseline; on a pull
request it also writes to the job summary the delta against the base of the pull request.
`Scripts/check-release.sh` runs on the version tag, and before it by whoever releases: it refuses a
version that keeps the major version of the previous release when the baseline lost or changed a
line since that release, or when the notes of the version have a `### Breaking changes`
subsection, in any letter case. It also refuses a release whose previous release is not an ancestor
of the commit being released, and stops with exit 2 where that cannot be asked, as in a shallow
clone. The lines show an added case of a public enum, an added protocol requirement or an added
overload only as an added line, which passes the script with a reminder to review it. The reminder
names an added case of a public enum, a protocol requirement added without a default
implementation and an overload that makes an existing call ambiguous as breaking, and says that a
requirement with a default implementation is additive only when its name is new to the protocol
and to its extensions; it cannot see which of them an added line is, and the review above decides.
`Scripts/check-release.sh --self-test`, which the `api` job runs, tries the decisions of the script
on scratch repositories. The script cannot tell a line that a new compiler reworded
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
  private filter. `UI` holds the two public views. The dependencies point inward: `Domain` names no
  type of the other two folders, and `Adapters` names no type of `UI`. No tool checks that, because
  an import restricts nothing inside one module; the reviewer applies it. There is no further
  layer, no view model and no coordinator.
- **Collaborators and the composition root.** The four protocols have `package` access, so a test
  inside the package replaces a collaborator and a consumer cannot. The two public views create the
  concrete implementations, in `UI/DMVariableBlurView.swift` and `UI/DMVariableBlurUIView.swift`;
  the reviewer applies that no other file of the library does.
- **A private system API.** The view reaches a filter of the system that is not public. The README,
  "Private API", lists its names, the checks made before the filter is installed and the risk that
  remains; this file does not restate them. A new private name of the system is a decision for the
  maintainer (CONTRIBUTING.md, "Commits and pull requests").
- **A failure reaches the host.** When a value is not valid, the system does not offer the filter
  or the image that shapes the blur cannot be created, the view shows the plain blur of the system
  over its whole frame. The one exception is a `DMVariableBlurUIView` whose `effect` the host has
  set to `nil`, which shows no blur until it gets an effect back. The view records the reason as a
  `DMVariableBlurError`. In SwiftUI a handler passed to `onFailure(_:)` receives it, and the
  unified log gets one line when no handler is set. In UIKit the `failure` property holds it and
  the unified log gets a line. The README, "Failures", and the DocC article Handling failures
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
  in its `RULES` (`domain_imports`, `no_process_termination`, `force_unwrapping`, `force_cast`,
  `force_try` and `implicitly_unwrapped_optional`) fire on the lines that expect them and on no
  other line. The fixtures sit in the `Domain` folder of a scratch copy, where every one of those
  rules applies. They cannot show two things. That `domain_imports` stays off in `UI` and
  `Adapters`, which import UIKit, is shown by `Scripts/lint.sh` on the real tree. That
  `no_process_termination` reaches `Adapters` and `UI` is shown by nothing, since the library has
  no such call there, so the reviewer applies it. `domain_imports` does not see an import that has
  a comment inside it, that follows a block comment on its line, or that names the module in
  backticks.
- **Isolation.** The package builds in the Swift 6 language mode. Both views are `@MainActor`, the
  two public enums are `Sendable` and the handler of `onFailure(_:)` is `@MainActor @Sendable`.
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
- "Oldest tested runtime" and "oldest supported version" are different statements. The supported
  version is a promise: the platform the manifest declares. The tested runtime is evidence: the
  oldest runtime a test has run on. That is iOS 17.5 against a promise of iOS 17.0.
- No third-party dependency without the maintainer's approval. `Scripts/check-manifest.sh` rejects
  a dependency required by branch or revision and a plugin on any target, and checks that a
  consumer resolves the package by version, that `Fixtures/Consumer` builds, that no resource
  bundle ships and that every Swift block of the README compiles, a manifest block being
  evaluated. The approval itself is a rule the reviewer applies.
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
