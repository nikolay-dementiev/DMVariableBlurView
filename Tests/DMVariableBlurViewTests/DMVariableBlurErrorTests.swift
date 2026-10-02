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
        let errors: [DMVariableBlurError] = [makeSUT(1.5), .effectUnavailable, .maskCreationFailed]

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
        let errors: [DMVariableBlurError] = [makeSUT(1.5), .effectUnavailable, .maskCreationFailed]

        for (index, error) in errors.enumerated() {
            for (otherIndex, other) in errors.enumerated() where otherIndex != index {
                XCTAssertNotEqual(error, other, "\(error) and \(other) are different reasons")
            }
        }
    }

    // MARK: - Helpers

    private func makeSUT(_ centerBandProportion: CGFloat) -> DMVariableBlurError {
        .invalidCenterBandProportion(centerBandProportion)
    }
}
