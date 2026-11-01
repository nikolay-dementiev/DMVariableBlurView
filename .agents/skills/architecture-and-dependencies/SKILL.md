---
name: architecture-and-dependencies
description: Review a change to DMVariableBlurView for its layers, its collaborators, its private names of the system, its dependencies and its platform floors. Use it on any change to Sources, Package.swift, Tools, devkit.conf or the lint fixtures.
---

# Architecture and dependencies

The question of this lane: does the change keep the package what ENGINEERING.md says it is? The
lane applies the rules of the repository and states none of its own. Report each finding in the
format of [Documentation/Review/README.md](../../../Documentation/Review/README.md).

## What it checks

- A type of `Domain` that names a type of `Adapters` or `UI`, or a type of `Adapters` that names a
  type of `UI`. The dependencies point inward, and no tool checks that.
  (ENGINEERING.md, "Three layers, by folder")
- A use in `Domain` of a CoreGraphics object or a CoreGraphics function. The folder takes
  CoreGraphics for its scalar types, such as `CGFloat`, and the rule looks at the import only.
  (ENGINEERING.md, "the folder uses no CoreGraphics object and no CoreGraphics function")
- A `Domain` import that `domain_imports` does not see: one with a comment inside it, one that
  follows a block comment on its line, one that names the module in backticks.
  (ENGINEERING.md, "The rules are tested")
- A `Domain` folder that is renamed while the include of `domain_imports` stays as it was.
  (ENGINEERING.md, "was renamed while the include of `domain_imports` was left alone")
- A further layer, such as a view model or a coordinator.
  (ENGINEERING.md, "There is no further layer, no view model and no coordinator")
- A collaborator protocol that is not `package`, or a concrete collaborator created in a file other
  than `UI/VariableBlurCollaborators.swift`, where `VariableBlurCollaborators.system` creates them.
  (ENGINEERING.md, "Collaborators and the composition root")
- A new private name of the system, such as a class, a selector, a filter type or a key, that the
  pull request does not name as the maintainer's decision, or that the README, "Private API", and
  the article How the blur works do not list.
  (AGENTS.md, "A new private name of the system is the maintainer's decision")
  (CONTRIBUTING.md, "A new private name of the system in the library is a decision for the
  maintainer")
  (ENGINEERING.md, "A private system API")
  (PR template, "No new private name of the system")
- A dependency, a plugin, a plugin target or a binary target with a url that the maintainer has not
  approved. The check rejects each by name; the approval itself is for the reviewer.
  (ENGINEERING.md, "No third-party dependency without the maintainer's approval")
  (ENGINEERING.md, "The approval itself is a rule the reviewer applies")
  (AGENTS.md, "Add no dependency without the maintainer's approval")
- A raised platform floor or `swift-tools-version`, a `defaultIsolation` in the manifest, or a test
  framework other than XCTest.
  (ENGINEERING.md, "Raising the platform floor")
  (ENGINEERING.md, "The manifest sets no `defaultIsolation`")
  (ENGINEERING.md, "XCTest is the test framework")

## What it ignores

- What a CI script already enforces: `Scripts/lint.sh` (the rule `domain_imports` reports every
  other import of `Domain`, and SwiftLint's own rules), `Scripts/check-lint-contract.sh` (that each
  rule of `devkit.conf` fires on the lines of its fixtures that expect it and on no other line),
  `Scripts/check-manifest.sh` (a dependency, a plugin, a plugin target or a binary target with a
  url in a manifest).
- How a view behaves: that is the lane correctness-and-concurrency.
- The class of a change and its documentation: that is the lane public-api-and-documentation.
- The quality of a test: that is the lane test-discrimination.
- Touches, accessibility and how a host uses a view: that is the lane
  accessibility-and-ui-integration.
