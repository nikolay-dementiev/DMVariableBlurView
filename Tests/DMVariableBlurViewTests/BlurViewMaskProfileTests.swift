import DMVariableBlurView
import XCTest

/// The mask the library builds for each direction, compared row by row with the profiles
/// recorded from release 1.0.0.
final class BlurViewMaskProfileTests: XCTestCase {
    @MainActor
    func test_maskProfile_blurredTopClearBottom_zeroOffset_matchesTheRecordedProfile() throws {
        let sut = try makeSUT(direction: .blurredTopClearBottom)
        defer { sut.hide() }

        assertMaskProfile(of: sut, matches: MaskProfileFixtures.topZeroOffset)
    }

    @MainActor
    func test_maskProfile_blurredTopClearBottom_negativeOffset_keepsBlurAtTheClearEdge() throws {
        let sut = try makeSUT(direction: .blurredTopClearBottom, startOffset: -0.1)
        defer { sut.hide() }

        assertMaskProfile(of: sut, matches: MaskProfileFixtures.topNegativeOffset)
    }

    @MainActor
    func test_maskProfile_blurredBottomClearTop_zeroOffset_matchesTheRecordedProfile() throws {
        let sut = try makeSUT(direction: .blurredBottomClearTop)
        defer { sut.hide() }

        assertMaskProfile(of: sut, matches: MaskProfileFixtures.bottomZeroOffset)
    }

    @MainActor
    func test_maskProfile_blurredBottomClearTop_negativeOffset_keepsBlurAtTheClearEdge() throws {
        let sut = try makeSUT(direction: .blurredBottomClearTop, startOffset: -0.1)
        defer { sut.hide() }

        assertMaskProfile(of: sut, matches: MaskProfileFixtures.bottomNegativeOffset)
    }

    @MainActor
    func test_maskProfile_centerBandThirtyPercent_matchesTheRecordedProfile() throws {
        let sut = try makeSUT(direction: .blurredCenterClearTopBottom(centerBandProportion: 0.3))
        defer { sut.hide() }

        assertMaskProfile(of: sut, matches: MaskProfileFixtures.centerThirtyPercent)
    }

    /// The configuration the DMUnLoader package uses for its HUD background.
    @MainActor
    func test_maskProfile_centerBandFortyPercentWithRadiusFour_matchesTheRecordedProfile() throws {
        let sut = try makeSUT(
            radius: 4,
            direction: .blurredCenterClearTopBottom(centerBandProportion: 0.4)
        )
        defer { sut.hide() }

        assertMaskProfile(of: sut, matches: MaskProfileFixtures.centerFortyPercent)
    }

    @MainActor
    func test_maskProfile_blurredFully_isOpaqueInEveryRow() throws {
        let sut = try makeSUT(direction: .blurredFully)
        defer { sut.hide() }

        assertMaskProfile(of: sut, matches: MaskProfileFixtures.fully)
    }

    // MARK: - Boundaries, pinned as release 1.0.0 behaves

    /// A band that covers the whole height blurs every row. Release 1.0.0 left every row
    /// clear.
    @MainActor
    func test_maskProfile_centerBandProportionOne_isOpaqueInEveryRow() throws {
        let sut = try makeSUT(direction: .blurredCenterClearTopBottom(centerBandProportion: 1))
        defer { sut.hide() }

        assertMaskProfile(of: sut, matches: [UInt8](repeating: 255, count: 100), tolerance: 0)
    }

    /// From `startOffset: 1` on nothing is blurred. Release 1.0.0 blurred every row.
    @MainActor
    func test_maskProfile_topAndBottomModes_startOffsetOne_areClearInEveryRow() throws {
        for direction in [DMVariableBlurDirection.blurredTopClearBottom, .blurredBottomClearTop] {
            let sut = try makeSUT(direction: direction, startOffset: 1)
            defer { sut.hide() }

            assertMaskProfile(of: sut, matches: [UInt8](repeating: 0, count: 100), tolerance: 0)
        }
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT(
        radius: CGFloat = 20,
        direction: DMVariableBlurDirection,
        startOffset: CGFloat = 0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> HostedBlurView {
        let view = DMVariableBlurView(maxBlurRadius: radius, direction: direction, startOffset: startOffset)
        return try HostedBlurView(view, file: file, line: line)
    }
}
