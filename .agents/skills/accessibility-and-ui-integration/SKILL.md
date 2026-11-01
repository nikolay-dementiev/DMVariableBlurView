---
name: accessibility-and-ui-integration
description: Review a change to DMVariableBlurView for accessibility, Reduce Transparency, touches, the way SwiftUI and UIKit hosts use the views, and the private API where a change to a view touches it. Use it on any change to the views, to the way they install the blur, or to the README parts on behaviour.
---

# Accessibility and UI integration

The question of this lane: does a person who uses assistive technology, or an app that hosts a
view, still get what the README says? The lane applies the rules of the repository and states none
of its own. The parts of the README it cites describe observable behaviour, which is part of the
contract of a published library (ENGINEERING.md, "every `public` declaration and every observable
behaviour"), so a change of what they promise is a change of behaviour. Report each finding in the
format of
[Documentation/Review/README.md](../../../Documentation/Review/README.md).

## What it checks

- A view of the blur that becomes an accessibility element, or content added to the `contentView`
  of a `DMVariableBlurUIView` that loses its own accessibility.
  (README.md, "### Accessibility and Reduce Transparency")
  (README.md, "The views of the blur itself are no accessibility elements")
- The Reduce Transparency setting. A view ignores it by default. A view that follows it shows the
  standard effect of the system while the setting is on, and that is not a failure, so nothing is
  reported.
  (README.md, "the view ignores the Reduce Transparency setting")
  (README.md, "A view that follows the setting shows the standard effect of the system while the
  setting is on")
  (README.md, "That is not a failure: nothing is reported")
- Touches. The blur takes the touches in its frame by default. In SwiftUI
  `.allowsHitTesting(false)` lets them through, and in UIKit `isUserInteractionEnabled` set to
  `false` does. The default stays as it is.
  (README.md, "### Touches")
  (README.md, "The blur takes the touches in its frame")
  (README.md, "The default stays as it is")
- A SwiftUI host. New values reach a view that is already on the screen. `onFailure(_:)` and
  `respectsReduceTransparency(_:)` are methods of `DMVariableBlurView`, to be called before other
  modifiers.
  (README.md, "SwiftUI hands new values to the view that is already on the screen")
  (README.md, "are methods of `DMVariableBlurView`")
- A UIKit host. Content added to the `contentView` stays visible over the blur. Valid values given
  while the host has set `effect` to `nil` wait for the effect.
  (README.md, "Content you add to the `contentView` of the view stays visible over the blur")
  (README.md, "valid values given meanwhile wait for the effect")
- Appearance and display scale. The blur keeps its shape when the appearance changes between light
  and dark and when `effect` is assigned, and the view puts it back in the same layout pass. The
  layer key `scale` is set to the display scale of the traits of the view.
  (README.md, "### Threads, appearance and cost")
  (README.md, "the view puts the variable blur back in the same layout pass")
  (README.md, "a key of the backdrop's layer, set to the display scale of the view's traits")
- The private API where a change to a view touches it. The backdrop is the first subview whose
  layer carries filters, and the other subviews, except `contentView`, are the tint, which the view
  hides. The view finds its own filter by identity, and installs the blur again at its next layout
  pass when the backdrop carries another filter in its place. A new private name of the system goes
  to the lane architecture-and-dependencies.
  (README.md, "The view also relies on how the effect view is built")
  (README.md, "the view finds its own filter by that identity")
  (README.md, "the view installs the blur again at its next layout pass")
  (ENGINEERING.md, "A private system API")
- A change that can affect what the blur draws, in a pull request that does not say that the tests
  of the example app ran.
  (PR template, "`xcodebuild test` of the example app, if the change can affect what the blur
  draws")
  (CONTRIBUTING.md, "The example app")

## What it ignores

- What a CI script already enforces: `Scripts/lint.sh`, `Scripts/check-api.sh` (the declarations,
  not what a view does) and `Scripts/count-tests.sh`.
- The rendering, snapshot and UI tests of the example app, and the cells of the `example` job: each
  checks what it pins. The lane asks that they ran, and does not re-read what they compare. A
  snapshot reference that is recorded again: that is the lane test-discrimination.
- A missing accessibility label on a view of the blur: the README says the views of the blur are no
  accessibility elements, so a label that is added is the finding, and none that is missing.
- Dynamic Type, target sizes and contrast of the controls and the text of an app: the blur has
  none, and the host owns its own.
- The layers, the dependencies and the private names of the system: that is the lane
  architecture-and-dependencies.
- How a view decides and reports a failure, and the checks before the private filter is used,
  including a re-installation that fails: that is the lane correctness-and-concurrency.
- The class of a change and its documentation: that is the lane public-api-and-documentation.
- The quality of a test: that is the lane test-discrimination.
