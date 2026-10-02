// The analyzer sees this file compiled in a batch with files that import UIKit, where
// CGFloat is visible without this import. Compiled on its own, the file needs it.
// swiftlint:disable:next unused_import
import CoreGraphics

public enum DMVariableBlurDirection {
    case blurredTopClearBottom
    case blurredBottomClearTop
    case blurredCenterClearTopBottom(centerBandProportion: CGFloat = 0.3) // centerBandProportion: 0...1
    case blurredFully
}
