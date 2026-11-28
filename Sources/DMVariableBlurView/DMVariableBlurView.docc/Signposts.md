# Signposts

See what a blur view does, and how long it takes to draw its mask.

## Overview

Every view emits signposts under the subsystem `DMVariableBlurView` and the category `blur`.
A performance tool shows them: profile the app with an instrument that shows signposts, such as
the `os_signpost` instrument of Instruments, and filter by the subsystem. The app configures
nothing, and the package has no public setting for them.

DMCore records the signposts. A recording shows each one with the signpost name `event` or
`interval`: the name in the table below starts its message, followed by a colon and the detail
where there is one. Look for a name in the message.

| Name | Kind | Detail | Emitted when |
|---|---|---|---|
| `apply` | event | `accepted` or `rejected` | the view takes values that differ from the last ones, those of its initializer included |
| `maskRender` | interval | none | the view draws the mask of a blur, also when the drawing fails |
| `install` | event | `installed`, or a reason below | new values, or a change of the Reduce Transparency setting or option, make the view put the blur on |
| `reinstall` | event | none | a layout pass tries to put the blur on: the system had replaced it, or the effect of the view had been removed and is back |
| `failure` | event | none | the view records a reason for not showing the variable blur |

An `install` that does not succeed names one of these reasons: `filterClassMissing`,
`filterFactoryMissing`, `filterTypeMissing`, `filterCreationFailed`, `backdropMissing` or
`notApplied`. A `reinstall` that does not succeed is followed by a `failure`.

While a view follows the Reduce Transparency setting and the setting is on, valid values draw
no mask and install nothing: the view emits `apply` only. A layout pass that finds the blur in
place emits nothing.

Every detail is a constant of the package: a signpost carries no value of the app. The failure
itself, with the value that was rejected, reaches the app as <doc:HandlingFailures> describes.
