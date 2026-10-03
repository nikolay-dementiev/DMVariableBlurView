import DMVariableBlurView
import XCTest

/// `DMVariableBlurDirection` as a value: equality and the guarantee that it can cross
/// concurrency domains.
final class DirectionValueTests: XCTestCase {
    func test_direction_sameCaseAndProportion_isEqual() {
        XCTAssertEqual(makeSUT(0.4), makeSUT(0.4))
    }

    func test_direction_differentProportion_isNotEqual() {
        XCTAssertNotEqual(makeSUT(0.4), makeSUT(0.5))
    }

    func test_direction_differentCases_areNotEqual() {
        let directions: [DMVariableBlurDirection] = [
            .blurredTopClearBottom, .blurredBottomClearTop, makeSUT(0.3), .blurredFully
        ]

        for (index, direction) in directions.enumerated() {
            for (otherIndex, other) in directions.enumerated() where otherIndex != index {
                XCTAssertNotEqual(direction, other, "\(direction) and \(other) are different directions")
            }
        }
    }

    /// The synthesized equality compares the proportion as a `CGFloat`: a value that is
    /// not a number is not equal to itself.
    func test_direction_proportionThatIsNotANumber_isNotEqualToItself() {
        XCTAssertNotEqual(makeSUT(.nan), makeSUT(.nan))
    }

    /// Compiles only when the type conforms to `Sendable`.
    func test_direction_conformsToSendable() {
        XCTAssertTrue(requireSendable(DMVariableBlurDirection.self))
    }

    // MARK: - Helpers

    private func makeSUT(_ centerBandProportion: CGFloat) -> DMVariableBlurDirection {
        .blurredCenterClearTopBottom(centerBandProportion: centerBandProportion)
    }

    private func requireSendable<Value: Sendable>(_ type: Value.Type) -> Bool {
        true
    }
}
