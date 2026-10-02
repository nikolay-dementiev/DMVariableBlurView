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
    /// The strongest blur at the top edge, fading linearly to clear at the bottom edge.
    case blurredTopClearBottom

    /// The strongest blur at the bottom edge, fading linearly to clear at the top edge.
    case blurredBottomClearTop

    /// The strongest blur in a band across the middle, fading linearly to clear at the
    /// top and bottom edges.
    ///
    /// `centerBandProportion` is the height of the band, as a share of the view's height,
    /// in `0...1`: 0.3 by default. With 1 the whole height is blurred; with 0 the strongest
    /// blur is only the middle row. A value outside the range is rejected with
    /// ``DMVariableBlurError/invalidCenterBandProportion(_:)``.
    case blurredCenterClearTopBottom(centerBandProportion: CGFloat = 0.3)

    /// The strongest blur over the whole view.
    case blurredFully
}
