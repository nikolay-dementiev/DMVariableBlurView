import Foundation

/// The reason a blur view could not show the variable blur it was asked for.
///
/// While a view has a reason, it shows the plain blur of the system over its whole frame,
/// as release 1.0.0 did.
package enum DMVariableBlurError: Error, Sendable {
    /// `maxBlurRadius` is negative or is not a finite number. Carries the value.
    case invalidMaxBlurRadius(CGFloat)

    /// `centerBandProportion` is outside `0...1` or is not a number. Carries the value.
    case invalidCenterBandProportion(CGFloat)

    /// `startOffset` is not a finite number. Carries the value.
    case invalidStartOffset(CGFloat)

    /// The system on this device does not offer the variable blur effect, or did not
    /// accept it. The configuration is valid.
    case effectUnavailable

    /// The image that shapes the blur could not be created. The configuration is valid.
    case maskCreationFailed
}

extension DMVariableBlurError: Equatable {
    /// Two reasons are equal when they are the same case and their values compare equal or
    /// are both not a number, so a reason is always equal to itself.
    package static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.invalidMaxBlurRadius(left), .invalidMaxBlurRadius(right)),
             let (.invalidCenterBandProportion(left), .invalidCenterBandProportion(right)),
             let (.invalidStartOffset(left), .invalidStartOffset(right)):
            left == right || (left.isNaN && right.isNaN)
        case (.effectUnavailable, .effectUnavailable), (.maskCreationFailed, .maskCreationFailed):
            true
        case (.invalidMaxBlurRadius, _), (.invalidCenterBandProportion, _), (.invalidStartOffset, _),
             (.effectUnavailable, _), (.maskCreationFailed, _):
            false
        }
    }
}

extension DMVariableBlurError: LocalizedError {
    /// A description in English that names the parameter, its valid range and the value,
    /// or what the system did not do.
    package var errorDescription: String? {
        switch self {
        case .invalidMaxBlurRadius(let value):
            "maxBlurRadius must be a finite number, 0 or greater, but it is \(value)"
        case .invalidCenterBandProportion(let value):
            "centerBandProportion must be in the range 0...1, but it is \(value)"
        case .invalidStartOffset(let value):
            "startOffset must be a finite number, but it is \(value)"
        case .effectUnavailable:
            "The system does not offer the variable blur effect, or did not accept it"
        case .maskCreationFailed:
            "The image that shapes the blur could not be created"
        }
    }
}
