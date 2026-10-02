import Foundation

/// The reason a blur view could not be set up.
package enum DMVariableBlurError: Error, LocalizedError {
    case outputImageFromCIGradientFilter
    case createImageFromContext
    case findFilterFromVariableBlur
    case findVariableBlurFromFilter
    case centerBandProportionOutOfRange(currentValue: CGFloat)

    var errorDescription: String {
        let errorDescriptionString: String
        switch self {
        case .outputImageFromCIGradientFilter:
            errorDescriptionString = "failed to get output image from CIGradientFilter"
        case .createImageFromContext:
            errorDescriptionString = "failed to create CGImage from CIContext"
        case .findFilterFromVariableBlur:
            errorDescriptionString = "can't find CAFilter class"
        case .findVariableBlurFromFilter:
            errorDescriptionString = "CAFilter can't create filterWithType: variableBlur"
        case .centerBandProportionOutOfRange(let actual):
            errorDescriptionString = "centerBandProportion must be in range 0...1; but it is `\(actual)` instead"
        }

        // The prefix is the text the metatype of the SwiftUI view prints. It is spelled out,
        // because the domain names no view type.
        return "[DMVariableBlurView.Type] Error: \(errorDescriptionString)"
    }
}
