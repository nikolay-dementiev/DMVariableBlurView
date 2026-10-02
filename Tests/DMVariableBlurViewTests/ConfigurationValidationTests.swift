import DMVariableBlurView
import XCTest

/// The checks of a configuration, value by value: each bound, the values next to it, and
/// the values that are not finite.
final class ConfigurationValidationTests: XCTestCase {
    func test_maxBlurRadius_zeroOrAFinitePositiveValue_isAccepted() {
        for radius in [0, -0.0, .leastNonzeroMagnitude, 0.5, 20, .greatestFiniteMagnitude] as [CGFloat] {
            XCTAssertNoThrow(try makeSUT(maxBlurRadius: radius).maskProfile(), "a radius of \(radius)")
        }
    }

    func test_maxBlurRadius_negativeOrNotFinite_isRejectedWithTheValue() {
        for radius in [-.leastNonzeroMagnitude, -1, -.greatestFiniteMagnitude, .nan, .infinity, -.infinity] as [CGFloat] {
            expect(makeSUT(maxBlurRadius: radius), toBeRejectedWith: .invalidMaxBlurRadius(radius), "a radius of \(radius)")
        }
    }

    func test_centerBandProportion_inZeroToOne_isAccepted() {
        for proportion in [0, CGFloat(0).nextUp, 0.5, CGFloat(1).nextDown, 1] as [CGFloat] {
            XCTAssertNoThrow(
                try makeSUT(direction: .blurredCenterClearTopBottom(centerBandProportion: proportion)).maskProfile(),
                "a proportion of \(proportion)"
            )
        }
    }

    func test_centerBandProportion_outsideZeroToOneOrNotFinite_isRejectedWithTheValue() {
        for proportion in [CGFloat(0).nextDown, CGFloat(1).nextUp, -1, 2, .nan, .infinity, -.infinity] as [CGFloat] {
            expect(
                makeSUT(direction: .blurredCenterClearTopBottom(centerBandProportion: proportion)),
                toBeRejectedWith: .invalidCenterBandProportion(proportion),
                "a proportion of \(proportion)"
            )
        }
    }

    func test_startOffset_anyFiniteValue_isAcceptedInEveryDirection() {
        for direction in allDirections {
            for offset in [-10, -1, 0, 0.99, 1, 1.5, 1e6] as [CGFloat] {
                XCTAssertNoThrow(
                    try makeSUT(direction: direction, startOffset: offset).maskProfile(),
                    "an offset of \(offset) for \(direction)"
                )
            }
        }
    }

    /// The offset does not shape the center band or the full blur, and a value that is not
    /// finite is still a mistake of the caller.
    func test_startOffset_notFinite_isRejectedWithTheValueInEveryDirection() {
        for direction in allDirections {
            for offset in [.nan, .infinity, -.infinity] as [CGFloat] {
                expect(
                    makeSUT(direction: direction, startOffset: offset),
                    toBeRejectedWith: .invalidStartOffset(offset),
                    "an offset of \(offset) for \(direction)"
                )
            }
        }
    }

    /// The values are checked in the order of the parameters, and the first rejection wins.
    func test_validation_severalRejectedValues_reportsTheFirstParameter() {
        let radiusAndBand = makeSUT(maxBlurRadius: -1, direction: .blurredCenterClearTopBottom(centerBandProportion: 2))
        let bandAndOffset = makeSUT(direction: .blurredCenterClearTopBottom(centerBandProportion: 2), startOffset: .nan)

        expect(radiusAndBand, toBeRejectedWith: .invalidMaxBlurRadius(-1), "the radius comes before the band")
        expect(bandAndOffset, toBeRejectedWith: .invalidCenterBandProportion(2), "the band comes before the offset")
    }

    func test_errorDescription_rejectedRadiusAndOffset_nameTheParameterTheRangeAndTheValue() {
        XCTAssertEqual(
            DMVariableBlurError.invalidMaxBlurRadius(-1).errorDescription,
            "maxBlurRadius must be a finite number, 0 or greater, but it is -1.0",
            "the radius"
        )
        XCTAssertEqual(
            DMVariableBlurError.invalidStartOffset(.infinity).errorDescription,
            "startOffset must be a finite number, but it is inf",
            "the offset"
        )
    }

    func test_equality_rejectedRadiusOrOffsetThatIsNotANumber_isEqualToItself() {
        XCTAssertEqual(DMVariableBlurError.invalidMaxBlurRadius(.nan), .invalidMaxBlurRadius(.nan), "the radius")
        XCTAssertEqual(DMVariableBlurError.invalidStartOffset(.nan), .invalidStartOffset(.nan), "the offset")
    }

    // MARK: - Helpers

    private let allDirections: [DMVariableBlurDirection] = [
        .blurredTopClearBottom, .blurredBottomClearTop, .blurredCenterClearTopBottom(), .blurredFully
    ]

    private func makeSUT(
        maxBlurRadius: CGFloat = 20,
        direction: DMVariableBlurDirection = .blurredTopClearBottom,
        startOffset: CGFloat = 0
    ) -> VariableBlurConfiguration {
        VariableBlurConfiguration(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset)
    }

    private func expect(
        _ configuration: VariableBlurConfiguration,
        toBeRejectedWith expected: DMVariableBlurError,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            _ = try configuration.maskProfile()
            XCTFail("\(message) is accepted", file: file, line: line)
        } catch {
            XCTAssertEqual(error, expected, message, file: file, line: line)
        }
    }
}
