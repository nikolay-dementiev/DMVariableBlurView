// The analyzer sees this file compiled in a batch with files that import UIKit, where
// CGFloat is visible without this import. Compiled on its own, the file needs it.
// swiftlint:disable:next unused_import
import CoreGraphics

/// How strongly each height of a blur view is blurred.
///
/// A position is a fraction of the height: 0 is the top edge and 1 is the bottom edge.
/// An alpha of 1 gives the full blur radius and an alpha of 0 gives no blur.
package struct BlurMaskProfile: Equatable, Sendable {
    /// A linear change of the alpha between two positions.
    ///
    /// Beyond either position the alpha keeps the value it has there.
    package struct Ramp: Equatable, Sendable {
        package let start: CGFloat
        package let end: CGFloat
        package let startAlpha: CGFloat
        package let endAlpha: CGFloat

        package init(start: CGFloat, end: CGFloat, startAlpha: CGFloat, endAlpha: CGFloat) {
            self.start = start
            self.end = end
            self.startAlpha = startAlpha
            self.endAlpha = endAlpha
        }

        package func alpha(at position: CGFloat) -> CGFloat {
            // A ramp whose two positions coincide has no direction. It keeps the alpha of
            // its start everywhere, as the gradient of release 1.0.0 does.
            guard start != end else { return startAlpha }
            let progress = min(max((position - start) / (end - start), 0), 1)
            return startAlpha + (endAlpha - startAlpha) * progress
        }
    }

    /// The profile takes the lowest alpha of its ramps. Without a ramp it is opaque.
    package let ramps: [Ramp]

    package init(ramps: [Ramp]) {
        self.ramps = ramps
    }

    package func alpha(at position: CGFloat) -> CGFloat {
        ramps.map { $0.alpha(at: position) }.min() ?? 1
    }
}
