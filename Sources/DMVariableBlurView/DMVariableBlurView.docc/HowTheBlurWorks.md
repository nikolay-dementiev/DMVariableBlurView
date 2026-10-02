# How the blur works

What the view puts on the screen, which private parts of the system it relies on, and
what it does when they are missing.

## Overview

The view is a `UIVisualEffectView` with the standard blur effect of the system. The
backdrop of that effect draws the content behind the view through a list of filters. The
view replaces the list with one filter of the type `variableBlur`, which blurs every row
of pixels with its own radius. The radius follows the alpha of a mask image: the full
radius where the mask is opaque, no blur where it is clear. The view draws the mask from
the ``DMVariableBlurDirection`` you choose, and hides the tint of the effect, so that no
hard line marks where the blur ends.

### The private parts

The filter is not public. The view reaches it through these names, which appear as plain
strings in the binary:

- the class `CAFilter`, its class method `filterWithType:` and its class property
  `filterTypes`;
- the filter type `variableBlur` and its keys `inputRadius`, `inputMaskImage` and
  `inputNormalizeEdges`;
- the key `scale` of the backdrop's layer, set to the scale of the screen so that the
  clear edge stays sharp.

App Review Guideline 2.5.1 asks that apps use only public APIs. A user of VariableBlur,
the project this view derives from, reported an App Store rejection that named two of
these strings. Weigh that risk for your app before you ship the view.

### When the private parts are missing

Before it installs the filter, the view checks that the class exists, that it answers
both selectors, that the system lists the filter type, that a filter is created, and that
the effect has a backdrop. After installing it, the view reads the filter back. When a
step fails, the view keeps the plain blur of the system and reports
``DMVariableBlurError/effectUnavailable``.

These checks contain the risk of a system that changed; they cannot remove it. An
exception raised inside the private code cannot be caught from Swift.

### When the system rebuilds the effect

UIKit puts the standard filters and the tint back when the appearance changes between
light and dark, and when the `effect` of the view is assigned. The view puts the
variable blur back in the same layout pass, before the frame reaches the screen. While
the `effect` is `nil`, the view waits, and the blur returns with the effect.
