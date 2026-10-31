# Handling failures

What the view shows when it cannot show the variable blur, and how you learn why.

## Overview

A value out of range, or a system that does not offer the filter, does not leave the view
empty: the view shows the plain blur of the system over its whole frame. The one exception
is a ``DMVariableBlurUIView`` whose `effect` the host has set to `nil`, for example to fade
it out: it shows no blur until the host gives it an effect again.

The view records the reason as a ``DMVariableBlurError``:

- ``DMVariableBlurError/invalidMaxBlurRadius(_:)``: the radius is negative, infinite or
  not a number.
- ``DMVariableBlurError/invalidCenterBandProportion(_:)``: the proportion of the center
  band is outside `0...1`, or not a number.
- ``DMVariableBlurError/invalidStartOffset(_:)``: the offset is infinite or not a number.
- ``DMVariableBlurError/effectUnavailable``: the system does not offer the variable blur,
  or did not accept it.
- ``DMVariableBlurError/maskCreationFailed``: the image that shapes the blur could not be
  created.

The values are checked in this order, so a configuration with two invalid values reports
the first. The view checks them before it touches the system.

### In SwiftUI

Pass a handler to ``DMVariableBlurView/DMVariableBlurView/onFailure(_:)``. It runs on the
main actor, after the update that applied the configuration, so it may change state. It
runs once for each configuration that fails, and again when a failure returns after a
valid configuration. A configuration rejected for the same reason as the one before it,
the same case and value, counts as unchanged: nothing is reported again, also when its
other values differ. One update is one request: when it changes the values and the
Reduce Transparency option together, the handler hears only about the new values, never
about the values that the update replaced.

Without a handler, the view writes one line for each failure to the unified log, under
the subsystem `DMVariableBlurView` and the category `failure`. With a handler, it writes
none.

### In UIKit

Pass a handler to ``DMVariableBlurUIView/init(maxBlurRadius:direction:startOffset:onFailure:)``.
It follows the rules of the SwiftUI handler above: it runs on the main actor, in a later turn
than the one that recorded the failure, once for each configuration that fails, and again
when a failure returns after a valid configuration, also for the failure of a re-application
after the system rebuilt the effect. It is in place before the first values are applied, so a
failure of those is reported too, after the initializer has returned. One thing differs: nothing
replaces the handler, which stays for the life of the view. The view keeps it, so capture the
view weakly. With a handler the view writes nothing to the log.

Without a handler, read ``DMVariableBlurUIView/failure`` after you create the view, after
``DMVariableBlurUIView/update(maxBlurRadius:direction:startOffset:)``, and after a change
of appearance: it holds the reason, or `nil` when nothing prevents the blur. Each
recorded reason also writes one line to the unified log. When the view cannot install the
blur again after the system rebuilt the effect, it shows the plain blur of the system, as
for any other failure: the regular style, also when the host had given the view another
one.

### Reduce Transparency

A view can follow the Reduce Transparency setting of the device:
``DMVariableBlurView/DMVariableBlurView/respectsReduceTransparency(_:)`` in SwiftUI,
``DMVariableBlurUIView/respectsReduceTransparency`` in UIKit. While the setting is on, such a
view shows the standard effect of the system, which the system then draws without
transparency. That is not a failure: nothing is reported. The option is off by default.
