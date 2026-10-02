// The analyzer sees this file compiled in a batch with files that import UIKit, where
// CGFloat is visible without this import. Compiled on its own, the file needs it.
// swiftlint:disable:next unused_import
import CoreGraphics

/// Where a blur view blurs, and where it fades to clear.
///
/// Two directions are equal when they are the same case with an equal proportion. The
/// proportion is compared as a `CGFloat`, so a proportion that is not a number is not
/// equal to itself.
public enum DMVariableBlurDirection: Sendable, Equatable {
    case blurredTopClearBottom
    case blurredBottomClearTop
    case blurredCenterClearTopBottom(centerBandProportion: CGFloat = 0.3) // centerBandProportion: 0...1
    case blurredFully
}
