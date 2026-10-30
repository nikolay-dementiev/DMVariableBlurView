import DMVariableBlurView
import XCTest

/// The reason the library records when a view shows the plain blur of the system instead
/// of the variable blur.
final class DMVariableBlurErrorTests: XCTestCase {
    func test_errorDescription_invalidCenterBandProportion_namesTheParameterTheRangeAndTheValue() {
        XCTAssertEqual(
            makeSUT(1.5).errorDescription,
            "centerBandProportion must be in the range 0...1, but it is 1.5"
        )
    }

    func test_errorDescription_effectUnavailable_saysThatTheSystemDoesNotOfferTheEffect() {
        XCTAssertEqual(
            DMVariableBlurError.effectUnavailable.errorDescription,
            "The system does not offer the variable blur effect, or did not accept it"
        )
    }

    func test_errorDescription_maskCreationFailed_saysThatTheMaskCouldNotBeCreated() {
        XCTAssertEqual(
            DMVariableBlurError.maskCreationFailed.errorDescription,
            "The image that shapes the blur could not be created"
        )
    }

    /// Release 1.0.0 declared `errorDescription` as a non-optional `String`, which does not
    /// satisfy `LocalizedError`, so `localizedDescription` showed a generic text.
    func test_localizedDescription_ofEveryError_isItsDescription() {
        let errors: [DMVariableBlurError] = [
            .invalidMaxBlurRadius(-1), makeSUT(1.5), .invalidStartOffset(.nan), .effectUnavailable, .maskCreationFailed
        ]

        for error in errors {
            XCTAssertEqual(
                (error as any Error).localizedDescription,
                error.errorDescription,
                "\(error) reaches a host that only sees an Error"
            )
        }
    }

    func test_equality_sameCaseAndValue_isEqual() {
        XCTAssertEqual(makeSUT(1.5), makeSUT(1.5))
    }

    func test_equality_differentValues_isNotEqual() {
        XCTAssertNotEqual(makeSUT(1.5), makeSUT(2))
    }

    /// An error is always equal to itself, also when the rejected value is not a number.
    func test_equality_bothValuesNotANumber_isEqual() {
        XCTAssertEqual(makeSUT(.nan), makeSUT(.nan))
    }

    func test_equality_differentCases_isNotEqual() {
        let errors: [DMVariableBlurError] = [
            .invalidMaxBlurRadius(-1), makeSUT(1.5), .invalidStartOffset(.nan), .effectUnavailable, .maskCreationFailed
        ]

        for (index, error) in errors.enumerated() {
            for (otherIndex, other) in errors.enumerated() where otherIndex != index {
                XCTAssertNotEqual(error, other, "\(error) and \(other) are different reasons")
            }
        }
    }

    /// The three reasons that carry a value compare it by the same rules: equal values are equal,
    /// two values that are not a number are equal, and nothing else is.
    func test_equality_reasonsThatCarryAValue_compareTheValueByTheSameRules() {
        let reasons: [(name: String, make: (CGFloat) -> DMVariableBlurError)] = [
            ("invalidMaxBlurRadius", { .invalidMaxBlurRadius($0) }),
            ("invalidCenterBandProportion", { .invalidCenterBandProportion($0) }),
            ("invalidStartOffset", { .invalidStartOffset($0) })
        ]
        let pairs = [
            ValuePair(1.5, 1.5, isEqual: true, "the same value"),
            ValuePair(1.5, 2, isEqual: false, "different values"),
            ValuePair(.nan, .nan, isEqual: true, "two values that are not a number"),
            ValuePair(.nan, 1.5, isEqual: false, "a value that is not a number against a number"),
            ValuePair(1.5, .nan, isEqual: false, "a number against a value that is not a number"),
            ValuePair(.infinity, .infinity, isEqual: true, "the same infinity"),
            ValuePair(.infinity, -.infinity, isEqual: false, "opposite infinities")
        ]

        for reason in reasons {
            for pair in pairs {
                XCTAssertEqual(
                    reason.make(pair.left) == reason.make(pair.right),
                    pair.isEqual,
                    "\(reason.name), \(pair.comparison)"
                )
            }
        }
    }

    /// A reason is never equal to another reason, also when both carry the same value.
    func test_equality_differentReasonsWithTheSameValue_isNotEqual() {
        for value in [0, 1.5, .nan, .infinity] as [CGFloat] {
            let reasons: [DMVariableBlurError] = [
                .invalidMaxBlurRadius(value), .invalidCenterBandProportion(value), .invalidStartOffset(value)
            ]
            for (index, reason) in reasons.enumerated() {
                for (otherIndex, other) in reasons.enumerated() where otherIndex != index {
                    XCTAssertNotEqual(reason, other, "\(reason) and \(other) carry the same value and are different reasons")
                }
            }
        }
    }

    // MARK: - Helpers

    /// Two values and whether two reasons that carry them are equal.
    private struct ValuePair {
        let left: CGFloat
        let right: CGFloat
        let isEqual: Bool
        let comparison: String

        init(_ left: CGFloat, _ right: CGFloat, isEqual: Bool, _ comparison: String) {
            self.left = left
            self.right = right
            self.isEqual = isEqual
            self.comparison = comparison
        }
    }

    private func makeSUT(_ centerBandProportion: CGFloat) -> DMVariableBlurError {
        .invalidCenterBandProportion(centerBandProportion)
    }
}
