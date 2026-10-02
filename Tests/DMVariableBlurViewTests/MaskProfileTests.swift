import DMVariableBlurView
import XCTest

/// The mask profile the domain computes for every direction: the exact ramps, the alpha
/// next to every boundary, and the agreement with the masks recorded from release 1.0.0.
///
/// The positions and offsets are fractions with a power of two below the line, so every
/// expected value is exact and the assertions need no tolerance.
final class MaskProfileTests: XCTestCase {
    private typealias Ramp = BlurMaskProfile.Ramp

    // MARK: - The ramps of each direction

    func test_maskProfile_blurredTopClearBottom_isOneRampFromOpaqueAtTheTopToClearAtOneMinusTheOffset() throws {
        XCTAssertEqual(
            try makeSUT(.blurredTopClearBottom, startOffset: 0).ramps,
            [Ramp(start: 0, end: 1, startAlpha: 1, endAlpha: 0)],
            "without an offset the blur ends at the bottom edge"
        )
        XCTAssertEqual(
            try makeSUT(.blurredTopClearBottom, startOffset: 0.25).ramps,
            [Ramp(start: 0, end: 0.75, startAlpha: 1, endAlpha: 0)],
            "a positive offset ends the blur above the bottom edge"
        )
        XCTAssertEqual(
            try makeSUT(.blurredTopClearBottom, startOffset: -0.25).ramps,
            [Ramp(start: 0, end: 1.25, startAlpha: 1, endAlpha: 0)],
            "a negative offset ends the blur below the bottom edge"
        )
    }

    func test_maskProfile_blurredBottomClearTop_isOneRampFromOpaqueAtTheBottomToClearAtTheOffset() throws {
        XCTAssertEqual(
            try makeSUT(.blurredBottomClearTop, startOffset: 0).ramps,
            [Ramp(start: 1, end: 0, startAlpha: 1, endAlpha: 0)],
            "without an offset the blur ends at the top edge"
        )
        XCTAssertEqual(
            try makeSUT(.blurredBottomClearTop, startOffset: 0.25).ramps,
            [Ramp(start: 1, end: 0.25, startAlpha: 1, endAlpha: 0)],
            "a positive offset ends the blur below the top edge"
        )
        XCTAssertEqual(
            try makeSUT(.blurredBottomClearTop, startOffset: -0.25).ramps,
            [Ramp(start: 1, end: -0.25, startAlpha: 1, endAlpha: 0)],
            "a negative offset ends the blur above the top edge"
        )
    }

    func test_maskProfile_centerBand_isTwoRampsThatRiseFromBothEdgesToTheBand() throws {
        let halfBand = [
            Ramp(start: 0, end: 0.25, startAlpha: 0, endAlpha: 1),
            Ramp(start: 1, end: 0.75, startAlpha: 0, endAlpha: 1)
        ]

        XCTAssertEqual(
            try makeSUT(.blurredCenterClearTopBottom(centerBandProportion: 0.5)).ramps,
            halfBand,
            "a band of half the height starts a quarter below the top and ends a quarter above the bottom"
        )
        XCTAssertEqual(
            try makeSUT(.blurredCenterClearTopBottom(centerBandProportion: 0.5), startOffset: 0.25).ramps,
            halfBand,
            "the offset does not apply to the center band"
        )
    }

    func test_maskProfile_blurredFully_hasNoRamp() throws {
        XCTAssertEqual(try makeSUT(.blurredFully).ramps, [], "the full blur has no ramp")
        XCTAssertEqual(
            try makeSUT(.blurredFully, startOffset: 0.25).ramps,
            [],
            "the offset does not apply to the full blur"
        )
    }

    // MARK: - The alpha next to each boundary

    func test_alpha_blurredTopClearBottom_fallsLinearlyAndStaysClearBeyondTheRamp() throws {
        let sut = try makeSUT(.blurredTopClearBottom, startOffset: 0.5)

        XCTAssertEqual(sut.alpha(at: 0), 1, "the top edge has the full radius")
        XCTAssertEqual(sut.alpha(at: 0.25), 0.5, "halfway down the ramp the alpha is a half")
        XCTAssertEqual(sut.alpha(at: 0.5 - 0.0625), 0.125, "just above the end of the ramp some blur is left")
        XCTAssertEqual(sut.alpha(at: 0.5), 0, "the ramp ends clear at one minus the offset")
        XCTAssertEqual(sut.alpha(at: 0.75), 0, "below the ramp the view stays clear")
        XCTAssertEqual(sut.alpha(at: -0.5), 1, "above the view the alpha keeps the value of the top edge")
    }

    func test_alpha_blurredBottomClearTop_risesLinearlyTowardsTheBottom() throws {
        let sut = try makeSUT(.blurredBottomClearTop, startOffset: 0.5)

        XCTAssertEqual(sut.alpha(at: 1), 1, "the bottom edge has the full radius")
        XCTAssertEqual(sut.alpha(at: 0.75), 0.5, "halfway up the ramp the alpha is a half")
        XCTAssertEqual(sut.alpha(at: 0.5 + 0.0625), 0.125, "just below the end of the ramp some blur is left")
        XCTAssertEqual(sut.alpha(at: 0.5), 0, "the ramp ends clear at the offset")
        XCTAssertEqual(sut.alpha(at: 0.25), 0, "above the ramp the view stays clear")
    }

    func test_alpha_centerBand_isOpaqueInsideTheBandAndFallsOnBothSidesOfIt() throws {
        let sut = try makeSUT(.blurredCenterClearTopBottom(centerBandProportion: 0.5))

        XCTAssertEqual(sut.alpha(at: 0.25), 1, "the upper boundary of the band has the full radius")
        XCTAssertEqual(sut.alpha(at: 0.5), 1, "the middle of the band has the full radius")
        XCTAssertEqual(sut.alpha(at: 0.75), 1, "the lower boundary of the band has the full radius")
        XCTAssertEqual(sut.alpha(at: 0.25 - 0.015625), 0.9375, "just above the band the blur starts to fall")
        XCTAssertEqual(sut.alpha(at: 0.75 + 0.015625), 0.9375, "just below the band the blur starts to fall")
        XCTAssertEqual(sut.alpha(at: 0.125), 0.5, "halfway between the top edge and the band the alpha is a half")
        XCTAssertEqual(sut.alpha(at: 0), 0, "the top edge is clear")
        XCTAssertEqual(sut.alpha(at: 1), 0, "the bottom edge is clear")
    }

    func test_alpha_blurredFully_isOpaqueAtEveryPosition() throws {
        let sut = try makeSUT(.blurredFully)

        XCTAssertEqual([0, 0.5, 1].map(sut.alpha(at:)), [1, 1, 1])
    }

    // MARK: - Boundaries, as release 1.0.0 behaves

    /// A band of the whole height leaves both ramps without length, and a ramp without
    /// length keeps the alpha of its start: clear. A known defect, kept while the code is
    /// only restructured.
    func test_alpha_centerBandProportionOne_isClearAtEveryPosition() throws {
        let sut = try makeSUT(.blurredCenterClearTopBottom(centerBandProportion: 1))

        XCTAssertEqual([0, 0.5, 1].map(sut.alpha(at:)), [0, 0, 0])
    }

    /// An offset of one leaves the ramp without length, and it keeps the alpha of its
    /// start: opaque.
    func test_alpha_blurredTopClearBottom_startOffsetOne_isOpaqueAtEveryPosition() throws {
        let sut = try makeSUT(.blurredTopClearBottom, startOffset: 1)

        XCTAssertEqual([0, 0.5, 1].map(sut.alpha(at:)), [1, 1, 1])
    }

    // MARK: - Validation

    func test_maskProfile_centerBandProportionAtItsBounds_isAccepted() {
        XCTAssertNoThrow(
            try makeSUT(.blurredCenterClearTopBottom(centerBandProportion: 0)),
            "zero is the lower bound"
        )
        XCTAssertNoThrow(
            try makeSUT(.blurredCenterClearTopBottom(centerBandProportion: 1)),
            "one is the upper bound"
        )
    }

    func test_maskProfile_centerBandProportionOutOfRange_throwsWithTheValue() {
        for proportion in [-0.25, 1.25] as [CGFloat] {
            XCTAssertThrowsError(
                try makeSUT(.blurredCenterClearTopBottom(centerBandProportion: proportion)),
                "a proportion of \(proportion) is outside 0...1"
            ) { error in
                guard case .centerBandProportionOutOfRange(let value)? = error as? DMVariableBlurError else {
                    return XCTFail("a proportion of \(proportion) throws \(error)")
                }
                XCTAssertEqual(value, proportion, "the error carries the rejected value")
            }
        }
    }

    // MARK: - Agreement with the recorded masks

    /// The profile and the mask image describe the same thing. Row `n` of a 100-row mask
    /// is the position `(n + 0.5) / 100`.
    func test_alpha_ofEveryRecordedConfiguration_matchesTheRecordedMaskWithinOneStep() throws {
        let recordedMasks = [
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

        for recorded in recordedMasks {
            let sut = try makeSUT(recorded.direction, startOffset: recorded.startOffset)
            let differences = recorded.rows.enumerated().map { row, alpha in
                abs(sut.alpha(at: (CGFloat(row) + 0.5) / CGFloat(recorded.rows.count)) * 255 - CGFloat(alpha))
            }
            XCTAssertLessThanOrEqual(
                differences.max() ?? .infinity,
                1,
                "\(recorded.name): the profile is within one step of 255 of every recorded row"
            )
        }
    }

    // MARK: - Helpers

    private struct RecordedMask {
        let name: String
        let direction: DMVariableBlurDirection
        let startOffset: CGFloat
        let rows: [UInt8]

        init(_ name: String, _ direction: DMVariableBlurDirection, _ startOffset: CGFloat, _ rows: [UInt8]) {
            self.name = name
            self.direction = direction
            self.startOffset = startOffset
            self.rows = rows
        }
    }

    private func makeSUT(
        _ direction: DMVariableBlurDirection,
        startOffset: CGFloat = 0
    ) throws -> BlurMaskProfile {
        try VariableBlurConfiguration(maxBlurRadius: 20, direction: direction, startOffset: startOffset).maskProfile()
    }
}
