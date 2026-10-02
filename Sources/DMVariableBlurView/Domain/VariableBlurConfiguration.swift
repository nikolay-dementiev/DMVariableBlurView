// The analyzer sees this file compiled in a batch with files that import UIKit, where
// CGFloat is visible without this import. Compiled on its own, the file needs it.
// swiftlint:disable:next unused_import
import CoreGraphics

/// The values a blur view is asked to show.
package struct VariableBlurConfiguration {
    package let maxBlurRadius: CGFloat
    package let direction: DMVariableBlurDirection
    package let startOffset: CGFloat

    package init(maxBlurRadius: CGFloat, direction: DMVariableBlurDirection, startOffset: CGFloat) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.startOffset = startOffset
    }

    /// The mask the direction and the offset ask for.
    ///
    /// - Throws: ``DMVariableBlurError/centerBandProportionOutOfRange(currentValue:)`` when
    ///   the proportion of the center band is outside `0...1`.
    package func maskProfile() throws -> BlurMaskProfile {
        switch direction {
        case .blurredTopClearBottom:
            return BlurMaskProfile(ramps: [
                .init(start: 0, end: 1 - startOffset, startAlpha: 1, endAlpha: 0)
            ])
        case .blurredBottomClearTop:
            return BlurMaskProfile(ramps: [
                .init(start: 1, end: startOffset, startAlpha: 1, endAlpha: 0)
            ])
        case .blurredCenterClearTopBottom(let centerBandProportion):
            guard 0...1 ~= centerBandProportion else {
                throw DMVariableBlurError.centerBandProportionOutOfRange(currentValue: centerBandProportion)
            }
            // The band is centered: the blur rises from each edge over the same distance.
            let margin = (1 - centerBandProportion) / 2
            return BlurMaskProfile(ramps: [
                .init(start: 0, end: margin, startAlpha: 0, endAlpha: 1),
                .init(start: 1, end: 1 - margin, startAlpha: 0, endAlpha: 1)
            ])
        case .blurredFully:
            return BlurMaskProfile(ramps: [])
        }
    }
}
