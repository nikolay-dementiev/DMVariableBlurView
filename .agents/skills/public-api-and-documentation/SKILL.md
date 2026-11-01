---
name: public-api-and-documentation
description: Review a change to DMVariableBlurView for the class of the change, the baseline of the public interface, the changelog and the documented limits. Use it on any change that touches a public declaration, an observable behaviour or a document that people using the package read.
---

# Public API and documentation

The question of this lane: is the change classified as ENGINEERING.md classifies it, and does
everything that people using the package read say so? The lane applies the rules of the
repository and states none of its own. Report each finding in the format of
[Documentation/Review/README.md](../../../Documentation/Review/README.md).

## What it checks

- The class of the change, none, additive or breaking, is stated and is right. Every change of
  observable behaviour is breaking, including a crash that stops happening.
  (AGENTS.md, "The public interface is a contract")
  (ENGINEERING.md, "The rule is strict and has no carve-out")
  (PR template, "Class of the change")
- `Fixtures/API/public-interface.txt` changes in the same commit as the declaration.
  (ENGINEERING.md, "updated in the same commit")
  (ENGINEERING.md, "that the baseline changes in the same commit as the declaration")
- An added case of a public enum. A protocol requirement with a default implementation whose name
  is already declared by the protocol or by an extension of it. An added overload that makes an
  existing call ambiguous. The order of the cases of an enum, where a raw value or `allCases`
  depends on it. The script reports each of these as an added line at most, and a review decides.
  (ENGINEERING.md, "A new case in a public enum that a consumer can switch over")
  (ENGINEERING.md, "A new protocol requirement with a default implementation is additive only
  when")
  (ENGINEERING.md, "An added overload")
  (ENGINEERING.md, "where a raw value or `allCases` depends on it")
- A breaking change without the maintainer's decision, an entry in `CHANGELOG.md` and a major
  version. For a change of behaviour the notes declare it in a `### Breaking changes` subsection,
  because no script sees behaviour.
  (ENGINEERING.md, "A breaking change needs the maintainer's decision")
  (CONTRIBUTING.md, "Every breaking change, as ENGINEERING.md defines it, needs a new major
  version")
  (CONTRIBUTING.md, "A change listed under `### Changed` alone does not count")
  (PR template, "Observable behaviour changes, each one listed")
- A change that people using the package can notice, with no entry in `CHANGELOG.md`.
  (CONTRIBUTING.md, "A change that people using the package can notice gets an entry in
  `CHANGELOG.md`")
  (PR template, "Every change that people using the package can notice is in `CHANGELOG.md`")
- A change of observable behaviour that the notes of the release do not declare. No script sees
  behaviour, and a test catches the change only where a test pins the behaviour.
  (ENGINEERING.md, "every change of observable behaviour that the notes do not declare")
  (ENGINEERING.md, "which a test catches only where a test pins the behaviour")
- A change of a documented limit, after which the README, "Behaviour your app must know", or the
  DocC catalog no longer matches it. A change of how a failure is reported, after which the
  README, "Failures", or the article Handling failures no longer matches it.
  (ENGINEERING.md, "Documented limits")
  (ENGINEERING.md, "A failure reaches the host")
- The release the change needs is stated, and it is the one the table gives.
  (PR template, "The release it needs")
  (ENGINEERING.md, "| Change | Class | Release |")

## What it ignores

- What a CI script already enforces: `Scripts/lint.sh` (including the rule that every public symbol
  is documented), `Scripts/check-api.sh` against the baseline, `Scripts/check-release.sh` (the
  heading and its date, the previous release, a breaking-changes heading, the major version, the
  digester), `Scripts/check-manifest.sh` (the install manifest of the README, its URL and version,
  and that every Swift block of the README compiles), `Scripts/check-podspec.sh` and the `docs`
  job (the DocC build).
- How the implementation is built: that is the lane architecture-and-dependencies.
- How a view behaves: that is the lane correctness-and-concurrency.
- The quality of a test: that is the lane test-discrimination.
- Touches, accessibility and how a host uses a view: that is the lane
  accessibility-and-ui-integration.
