# Changelog

All notable changes to DMVariableBlurView are recorded in this file. The format follows Keep a
Changelog 1.1.0, and versions follow Semantic Versioning 2.0.0.

## [Unreleased]

### Breaking changes

- The view finds its own filter on the backdrop by identity and reads the radius and the mask
  from that filter only. When the backdrop carries another filter in the place of the one the
  view installed, put there by a host or by a later system, the view counts the effect as
  rebuilt: while it shows the variable blur, it installs the blur again at the next layout
  pass, and the other filter is gone. In 1.1.0 the view asked any single filter for
  `inputMaskImage` and `inputRadius`, and an object that does not define those keys raised an
  exception that Swift cannot catch and ended the app. Migration: an app that puts its own
  filter on the backdrop layer of the view has to move it to a view of its own, since the view
  replaces it. Nothing else changes: the filter that the view installed is found as before.
- A SwiftUI update is applied as one request. When one update turned the Reduce Transparency
  option off and changed the values together, the option reached the view first, so the view
  installed the previous values, which it had never shown while it followed the setting. If
  the system rejected them, the failure went to the new `onFailure(_:)` handler, and the plain
  blur was rebuilt twice when the option went on. Now the view shows the new values under the
  new option once, and the handler hears only about them. Migration: nothing to change; a
  handler that counted on the failure of the values an update replaced no longer receives it.
- A layout pass that cannot install the blur again leaves the plain blur of the system, with
  its tint, and reports the failure once, as before. The plain blur is the regular style, as
  for every other failure, also when the host had given the view another effect. In 1.1.0
  the view could keep the standard filters with the tint that the earlier installation had
  hidden, until the host assigned `effect` again. Migration: nothing to change; a view that
  showed no tint after such a failure now shows the plain blur.

## [1.1.0] - 2026-10-03

### Added

- `DMVariableBlurError`, the reason a view cannot show the variable blur, with five cases:
  `invalidMaxBlurRadius(_:)`, `invalidCenterBandProportion(_:)`, `invalidStartOffset(_:)`,
  `effectUnavailable` and `maskCreationFailed`. It is `Equatable`, a payload that is not a
  number counts as equal to itself, and its `localizedDescription` names the value and the
  valid range.
- `DMVariableBlurView.onFailure(_:)`: a handler that receives each failure on the main actor,
  after the update that applied the values.
- `DMVariableBlurView.respectsReduceTransparency(_:)` and
  `DMVariableBlurUIView.respectsReduceTransparency`: a view that follows the Reduce
  Transparency setting shows the standard effect of the system while the setting is on. Off by
  default.
- `DMVariableBlurUIView.init(maxBlurRadius:direction:startOffset:)`,
  `update(maxBlurRadius:direction:startOffset:)` and `failure`: the UIKit view can be created
  with values, updated, and asked why it shows no variable blur. Content in its `contentView`
  stays visible over the blur. Valid values given while a host has set `effect` to `nil` wait
  for the effect; a value that is not valid is reported at once.
- `DMVariableBlurDirection` is `Sendable` and `Equatable`.
- Documentation for every public symbol, and a documentation catalog with the articles How the
  blur works, which lists every private name the view uses, and Handling failures.
- `THIRD_PARTY_NOTICES.md` with the notices of VariableBlur and VariableBlurView, the two
  projects the view derives from.

### Fixed

- The package can be added by version, for example `.package(url: ..., from: "1.1.0")`. The
  manifest of 1.0.0 required a lint plugin by branch, and Swift Package Manager refuses a
  version requirement on a package that does that.
- Nothing but the library reaches an app that uses the package. The demo photo, 3.5 MB, and
  a screenshot helper lived in the library target and shipped in a resource bundle.
- The pod no longer makes the apps that use it link XCTest.
- The blur keeps its shape when the appearance changes between light and dark, and when the
  `effect` of the view is assigned. In 1.0.0 the standard blur of the system replaced it.
- The backdrop scale follows the display scale after a fade-in and after a trait change, so
  the clear edge stays sharp. The backdrop takes the display scale of the view's traits when
  the view enters a window, when the blur is installed, and when the display scale changes.
  A host that sets `effect` to `nil` before the view enters a window, to fade it in, gets the
  scale with the blur. In 1.0.0 the backdrop took the scale of the screen when the view
  entered a window.
- SwiftUI applies new values to a view that is already on the screen. In 1.0.0 they were
  ignored.
- `centerBandProportion: 1`, and a value so close to 1 that the clear margins vanish in the
  arithmetic, blur the whole height. In 1.0.0 a proportion of 1 blurred nothing.
- `localizedDescription` of an error carries its description. In 1.0.0 it was a generic text.
- Decoding `DMVariableBlurUIView` from an archive or a storyboard returns `nil`. In 1.0.0 it
  stopped the app.
- A failure is reported to the handler of `onFailure(_:)`, or written as one line to the
  unified log under the subsystem `DMVariableBlurView`. In 1.0.0 it was dropped.
- The private interfaces of the system are guarded: a missing class, a missing method, a
  missing filter type and an empty result each end in the plain blur of the system and a
  reported reason. These guards contain the risk of the private interfaces; they cannot
  remove it.

### Changed

Behaviour changes. None of them removes a declaration; each one is pinned by a test.

- A `startOffset` of 1 or more blurs nothing in the top and bottom modes. In 1.0.0 it blurred
  everything. Any finite negative offset is allowed.
- A negative or non-finite `maxBlurRadius`, and a non-finite `startOffset`, are rejected: the
  view shows the plain blur of the system and reports the reason. In 1.0.0 they were applied.
- The image that shapes the blur is drawn with CoreGraphics instead of Core Image, once for
  each configuration. Against the masks of 1.0.0 it is equal in six of seven recorded
  configurations and differs by one step of 255 in 3 of 100 rows of the seventh.
- `DMVariableBlurUIView` is `final`. It was not `open` before either, so no subclass outside
  the package was possible.

### Removed

- The README no longer suggests copying a source file into an app.

## [1.0.0] - 2025-10-11

- First release: `DMVariableBlurView` for SwiftUI and `DMVariableBlurUIView` for UIKit, with
  four blur directions.

[1.1.0]: https://github.com/nikolay-dementiev/DMVariableBlurView/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/nikolay-dementiev/DMVariableBlurView/tree/1.0.0
