---
name: correctness-and-concurrency
description: Review a change to DMVariableBlurView for isolation, for how a failure reaches the host, for the checks before the private filter is used, and for the values it applies. Use it on any change to Sources.
---

# Correctness and concurrency

The question of this lane: does a view still behave as ENGINEERING.md and the README say it does?
The lane applies the rules of the repository and states none of its own. Report each finding in
the format of [Documentation/Review/README.md](../../../Documentation/Review/README.md).

## What it checks

- A view that loses `@MainActor`, a public enum that loses `Sendable`, or a handler of
  `onFailure(_:)` that is no longer `@MainActor @Sendable`.
  (ENGINEERING.md, "Both views are `@MainActor`")
- A report that reaches the handler of `onFailure(_:)` before the update that applied the values
  has ended, or off the main actor: it arrives in a later turn of the main actor.
  (README.md, "a handler receives the reason on the main actor")
  (ENGINEERING.md, "A report reaches the handler of `onFailure(_:)` in a later turn of the main
  actor")
- A failure that does not reach the host. A value that is not valid, a filter that the system does
  not offer and an image that cannot be created leave the plain blur of the system over the whole
  frame, except for a `DMVariableBlurUIView` whose `effect` the host has set to `nil`. The reason
  is recorded as a `DMVariableBlurError`, handed to the handler or held by `failure`, and written
  as one line to the log when no handler is set.
  (ENGINEERING.md, "A failure reaches the host")
- A `detail` handed to `FailureLog` that carries data of the host.
  (ENGINEERING.md, "it is the library's own text and never data of the host")
- A way to end the process that lint does not see, such as `_exit(` or `raise(`.
  (ENGINEERING.md, "The library does not stop its host")
  (ENGINEERING.md, "Another way to end a process, such as `_exit(` or `raise(`, stays with the
  reviewer")
  (AGENTS.md, "Library code never stops its host")
- The private filter reached without the checks that the README lists: the class exists, it
  answers both selectors, the system lists the filter type, a filter is created and the effect has
  a backdrop. No read back after the filter is installed. A key read on a filter that the view did
  not install itself.
  (README.md, "Before it installs the filter, the view checks that the class exists")
  (README.md, "After installing it, the view reads the filter back")
  (README.md, "It reads the keys of a filter only on the filter it installed itself")
- A re-installation that cannot install the blur again and does not leave the plain blur of the
  system, as for any other failure.
  (README.md, "When the view cannot install the blur again after the system rebuilt the effect")
- A validation or a mask profile that differs from the tables of the README: which values are
  applied and which are rejected, and where each direction blurs most.
  (README.md, "### Values")
  (README.md, "### Directions")

## What it ignores

- What a CI script already enforces: `Scripts/lint.sh` (the names `fatalError`,
  `preconditionFailure`, `assertionFailure`, `precondition`, `assert`, `dispatchPrecondition`,
  `abort` and `exit` followed by a parenthesis, force unwraps, implicitly unwrapped optionals,
  `try!` and `as!`), the `thread-sanitizer` job (a race that a test run shows) and the `floor` job
  (a warning of the oldest compiler).
- The layers and the dependencies: that is the lane architecture-and-dependencies.
- The class of a change and its documentation: that is the lane public-api-and-documentation.
- The quality of a test: that is the lane test-discrimination.
- Touches, accessibility and how a host uses a view: that is the lane
  accessibility-and-ui-integration.
