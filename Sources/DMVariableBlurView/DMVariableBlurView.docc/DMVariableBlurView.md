# ``DMVariableBlurView``

A blur whose radius changes from row to row, for SwiftUI and UIKit.

## Overview

The views of this package blur what lies behind them. Unlike the materials of the
system, the blur is not uniform: it is strongest where you ask for it and fades linearly
to clear, from the top, from the bottom, from the middle, or not at all.

Place ``DMVariableBlurView/DMVariableBlurView`` over the content to blur in SwiftUI, or
add ``DMVariableBlurUIView`` to a UIKit hierarchy. Both take a radius, a
``DMVariableBlurDirection`` and an offset, and both report when they cannot show the
blur: see <doc:HandlingFailures>.

The blur uses a private filter of the system. Read <doc:HowTheBlurWorks> before you ship
it.

## Topics

### Essentials

- ``DMVariableBlurView/DMVariableBlurView``
- ``DMVariableBlurDirection``
- <doc:HowTheBlurWorks>

### UIKit

- ``DMVariableBlurUIView``

### Failures

- <doc:HandlingFailures>
- ``DMVariableBlurError``
