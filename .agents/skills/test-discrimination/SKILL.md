---
name: test-discrimination
description: Review a change to DMVariableBlurView for tests that could not fail, tests that go around the public interface, tests that wait for a fixed time and snapshot references that are recorded again. Use it on any change to Tests, Examples or a snapshot reference.
---

# Test discrimination

The question of this lane: would the tests catch the defect they claim to catch? The lane applies
the rules of the repository and states none of its own. Report each finding in the format of
[Documentation/Review/README.md](../../../Documentation/Review/README.md).

## What it checks

- A new test with no named change of the code that it fails on.
  (AGENTS.md, "Every new test must be able to fail")
  (CONTRIBUTING.md, "A test must be able to fail")
  (PR template, "For each new test, the change to the code that it fails on")
  (PR template, "Every new test fails without the change")
- An `@testable import`, or a test that reaches an internal declaration instead of the public
  interface and the `package` declarations of the module.
  (AGENTS.md, "with no `@testable import`")
  (CONTRIBUTING.md, "XCTest, through the public API")
  (ENGINEERING.md, "XCTest is the test framework")
- A test class with no `makeSUT()` factory, or a double that asserts inside itself where a spy
  that records calls would do. (CONTRIBUTING.md, "One `makeSUT()` factory per test class")
- A test name that does not say the subject, the condition and the expected result, and a test
  with two or more assertions of which one carries no message.
  (CONTRIBUTING.md, "Names say the subject, the condition and the expected result")
  (CONTRIBUTING.md, "In a test with two or more assertions, every assertion carries a message")
- A fix without a test that reproduces the defect, or a commit with the failing test that does not
  come before the commit that makes it pass.
  (CONTRIBUTING.md, "A fix starts with a test that reproduces the defect")
  (CONTRIBUTING.md, "The commit with a failing test comes before the commit that makes it pass")
- A change of behaviour that no test pins. The notes may leave it undeclared, and a test catches it
  only where it pins the behaviour.
  (ENGINEERING.md, "which a test catches only where a test pins the behaviour")
- A wait for a fixed time: a `Task.sleep`, a test that expects a report without waiting for it with
  `FailureReportRecorder`, or an expectation that asserts on over-fulfilment.
  (ENGINEERING.md, "Tests do not wait a fixed time")
  (ENGINEERING.md, "A `Task.sleep` in a test is a finding")
- A snapshot reference that is recorded again in a commit that does not name the device, the iOS
  version and the reason.
  (CONTRIBUTING.md, "commit it with the device, the iOS version and the reason")

## What it ignores

- What a CI script already enforces: `Scripts/count-tests.sh` (a test class that a run lost, a
  test that skipped or failed), `Scripts/coverage-gate.sh` (the coverage floor), the `example` job
  (the `passed` and `skipped` numbers of each cell) and `Scripts/check-lint-contract.sh` (the
  fixtures of the lint rules).
- The layers and the dependencies: that is the lane architecture-and-dependencies.
- How a view behaves: that is the lane correctness-and-concurrency.
- The class of a change and its documentation: that is the lane public-api-and-documentation.
- What a snapshot shows, touches and accessibility: that is the lane
  accessibility-and-ui-integration.
