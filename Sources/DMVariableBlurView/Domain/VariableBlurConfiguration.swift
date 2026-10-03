// The analyzer sees this file compiled in a batch with files that import UIKit, where
// CGFloat is visible without this import. Compiled on its own, the file needs it.
// swiftlint:disable:next unused_import
import CoreGraphics

/// The values a blur view is asked to show.
package struct VariableBlurConfiguration: Equatable {
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
    /// The values are checked in the order of the parameters, and the first rejected one
    /// is reported.
    ///
    /// - Throws: ``DMVariableBlurError/invalidMaxBlurRadius(_:)`` for a radius that is
    ///   negative or not finite, ``DMVariableBlurError/invalidCenterBandProportion(_:)`` for
    ///   a proportion outside `0...1` or not a number, and
    ///   ``DMVariableBlurError/invalidStartOffset(_:)`` for an offset that is not finite,
    ///   in every direction.
    package func maskProfile() throws(DMVariableBlurError) -> BlurMaskProfile {
        guard maxBlurRadius.isFinite, maxBlurRadius >= 0 else {
            throw .invalidMaxBlurRadius(maxBlurRadius)
        }
        if case .blurredCenterClearTopBottom(let centerBandProportion) = direction, !(0...1 ~= centerBandProportion) {
            throw .invalidCenterBandProportion(centerBandProportion)
        }
        guard startOffset.isFinite else {
            throw .invalidStartOffset(startOffset)
        }

        switch direction {
        case .blurredTopClearBottom:
            // From an offset of 1 on, the ramp would end at or above its blurred edge.
            guard startOffset < 1 else {
                return .clear
            }
            return BlurMaskProfile(ramps: [
                .init(start: 0, end: 1 - startOffset, startAlpha: 1, endAlpha: 0)
            ])
        case .blurredBottomClearTop:
            guard startOffset < 1 else {
                return .clear
            }
            return BlurMaskProfile(ramps: [
                .init(start: 1, end: startOffset, startAlpha: 1, endAlpha: 0)
            ])
        case .blurredCenterClearTopBottom(let centerBandProportion):
            // The band is centered: the blur rises from each edge over the same distance.
            let margin = (1 - centerBandProportion) / 2
            // A band of the whole height leaves no edge to rise from: everything is blurred.
            // So does a margin so small that 1 minus it rounds to 1, which would leave the
            // bottom ramp without a length.
            guard margin > 0, 1 - margin < 1 else {
                return BlurMaskProfile(ramps: [])
            }
            return BlurMaskProfile(ramps: [
                .init(start: 0, end: margin, startAlpha: 0, endAlpha: 1),
                .init(start: 1, end: 1 - margin, startAlpha: 0, endAlpha: 1)
            ])
        case .blurredFully:
            return BlurMaskProfile(ramps: [])
        }
    }
}
