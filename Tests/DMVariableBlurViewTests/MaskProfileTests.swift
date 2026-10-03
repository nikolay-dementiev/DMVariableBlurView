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

    // MARK: - Boundaries

    /// A band of the whole height blurs the whole height (release 1.0.0 left it clear).
    func test_alpha_centerBandProportionOne_isOpaqueAtEveryPosition() throws {
        let sut = try makeSUT(.blurredCenterClearTopBottom(centerBandProportion: 1))

        XCTAssertEqual([0, 0.5, 1].map(sut.alpha(at:)), [1, 1, 1])
    }

    /// The offset shapes the top and bottom modes only. From 1 on those blur nothing; the
    /// center band and the full blur stay as they are.
    func test_alpha_centerBandAndFullModesWithAnOffsetOfOneOrMore_ignoreTheOffset() throws {
        let center = try makeSUT(.blurredCenterClearTopBottom(centerBandProportion: 0.3), startOffset: 1.5)
        let centerWithoutOffset = try makeSUT(.blurredCenterClearTopBottom(centerBandProportion: 0.3))
        let fully = try makeSUT(.blurredFully, startOffset: 1.5)

        XCTAssertEqual(center, centerWithoutOffset, "the center band ignores the offset")
        XCTAssertEqual([0, 0.5, 1].map(fully.alpha(at:)), [1, 1, 1], "the full blur ignores the offset")
    }

    /// The largest proportion below 1 leaves margins smaller than the precision of the
    /// arithmetic: the band must blur like a proportion of 1, not turn the view clear.
    func test_alpha_centerBandProportionJustBelowOne_isOpaqueAtTheRowsOfTheMask() throws {
        let sut = try makeSUT(.blurredCenterClearTopBottom(centerBandProportion: CGFloat(1).nextDown))

        XCTAssertEqual([0.005, 0.5, 0.995].map(sut.alpha(at:)), [1, 1, 1])
    }

    /// The offset moves the clear end of the ramp. From 1 on, nothing is blurred (release
    /// 1.0.0 blurred everything); a negative offset leaves blur at the clear edge. The alpha
    /// is read at the blurred edge, in the middle and at the clear edge.
    func test_alpha_topAndBottomModes_followTheOffsetTable() throws {
        let table: [(offset: CGFloat, alphas: [CGFloat])] = [
            (0.99, [1, 0, 0]),
            (1, [0, 0, 0]),
            (1.5, [0, 0, 0]),
            (1e6, [0, 0, 0]),
            (-1, [1, 0.75, 0.5]),
            (-10, [1, 1 - 0.5 / 11, 1 - 1 / 11])
        ]

        for row in table {
            let top = try makeSUT(.blurredTopClearBottom, startOffset: row.offset)
            let bottom = try makeSUT(.blurredBottomClearTop, startOffset: row.offset)
            for (index, (topPosition, bottomPosition)) in [(0.0, 1.0), (0.5, 0.5), (1.0, 0.0)].enumerated() {
                XCTAssertEqual(
                    top.alpha(at: topPosition),
                    row.alphas[index],
                    accuracy: 1e-12,
                    "top mode, offset \(row.offset), position \(topPosition)"
                )
                XCTAssertEqual(
                    bottom.alpha(at: bottomPosition),
                    row.alphas[index],
                    accuracy: 1e-12,
                    "bottom mode, offset \(row.offset), position \(bottomPosition)"
                )
            }
        }
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
                guard case .invalidCenterBandProportion(let value)? = error as? DMVariableBlurError else {
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
        for recorded in RecordedMask.all {
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

    private func makeSUT(
        _ direction: DMVariableBlurDirection,
        startOffset: CGFloat = 0
    ) throws -> BlurMaskProfile {
        try VariableBlurConfiguration(maxBlurRadius: 20, direction: direction, startOffset: startOffset).maskProfile()
    }
}
