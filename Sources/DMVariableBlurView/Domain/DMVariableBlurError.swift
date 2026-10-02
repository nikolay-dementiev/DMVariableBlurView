import Foundation

/// The reason a blur view could not show the variable blur it was asked for.
///
/// While a view has a reason, it shows the plain blur of the system over its whole frame,
/// as release 1.0.0 did.
package enum DMVariableBlurError: Error, Sendable {
    /// `centerBandProportion` is outside `0...1` or is not a number. Carries the value.
    case invalidCenterBandProportion(CGFloat)

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
        case let (.invalidCenterBandProportion(left), .invalidCenterBandProportion(right)):
            left == right || (left.isNaN && right.isNaN)
        case (.effectUnavailable, .effectUnavailable), (.maskCreationFailed, .maskCreationFailed):
            true
        case (.invalidCenterBandProportion, _), (.effectUnavailable, _), (.maskCreationFailed, _):
            false
        }
    }
}

extension DMVariableBlurError: LocalizedError {
    /// A description in English that names the parameter, its valid range and the value,
    /// or what the system did not do.
    package var errorDescription: String? {
        switch self {
        case .invalidCenterBandProportion(let value):
            "centerBandProportion must be in the range 0...1, but it is \(value)"
        case .effectUnavailable:
            "The system does not offer the variable blur effect, or did not accept it"
        case .maskCreationFailed:
            "The image that shapes the blur could not be created"
        }
    }
}
