// The analyzer sees this file compiled in a batch with files that import UIKit, where
// CGFloat is visible without this import. Compiled on its own, the file needs it.
// swiftlint:disable:next unused_import
import CoreGraphics
import DMVariableBlurView

/// A configuration together with the mask that release 1.0.0 drew for it, every row.
struct RecordedMask {
    let name: String
    let direction: DMVariableBlurDirection
    let startOffset: CGFloat
    let rows: [UInt8]

    /// The seven configurations of `MaskProfileFixtures`.
    static let all = [
        RecordedMask("top, no offset", .blurredTopClearBottom, 0, MaskProfileFixtures.topZeroOffset),
        RecordedMask("top, offset -0.1", .blurredTopClearBottom, -0.1, MaskProfileFixtures.topNegativeOffset),
        RecordedMask("bottom, no offset", .blurredBottomClearTop, 0, MaskProfileFixtures.bottomZeroOffset),
        RecordedMask("bottom, offset -0.1", .blurredBottomClearTop, -0.1, MaskProfileFixtures.bottomNegativeOffset),
        RecordedMask(
            "center 0.3",
            .blurredCenterClearTopBottom(centerBandProportion: 0.3),
            0,
            MaskProfileFixtures.centerThirtyPercent
        ),
        RecordedMask(
            "center 0.4",
            .blurredCenterClearTopBottom(centerBandProportion: 0.4),
            0,
            MaskProfileFixtures.centerFortyPercent
        ),
        RecordedMask("full", .blurredFully, 0, MaskProfileFixtures.fully)
    ]

    init(_ name: String, _ direction: DMVariableBlurDirection, _ startOffset: CGFloat, _ rows: [UInt8]) {
        self.name = name
        self.direction = direction
        self.startOffset = startOffset
        self.rows = rows
    }

    /// The profile the library computes for the configuration.
    func profile() throws -> BlurMaskProfile {
        try VariableBlurConfiguration(maxBlurRadius: 20, direction: direction, startOffset: startOffset).maskProfile()
    }
}
