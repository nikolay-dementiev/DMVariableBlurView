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
    func test_maskProfile_centreBandThirtyPercent_matchesTheRecordedProfile() throws {
        let sut = try makeSUT(direction: .blurredCenterClearTopBottom(centerBandProportion: 0.3))
        defer { sut.hide() }

        assertMaskProfile(of: sut, matches: MaskProfileFixtures.centreThirtyPercent)
    }

    /// The configuration the DMUnLoader package uses for its HUD background.
    @MainActor
    func test_maskProfile_centreBandFortyPercentWithRadiusFour_matchesTheRecordedProfile() throws {
        let sut = try makeSUT(
            radius: 4,
            direction: .blurredCenterClearTopBottom(centerBandProportion: 0.4)
        )
        defer { sut.hide() }

        assertMaskProfile(of: sut, matches: MaskProfileFixtures.centreFortyPercent)
    }

    @MainActor
    func test_maskProfile_blurredFully_isOpaqueInEveryRow() throws {
        let sut = try makeSUT(direction: .blurredFully)
        defer { sut.hide() }

        assertMaskProfile(of: sut, matches: MaskProfileFixtures.fully)
    }

    // MARK: - Boundaries, pinned as release 1.0.0 behaves

    /// A band that covers the whole height gives a mask that is clear everywhere: both
    /// ramps collapse to a point. This is a known defect, pinned here so that restructuring
    /// cannot change it by accident. The fix changes this test.
    @MainActor
    func test_maskProfile_centreBandProportionOne_isClearInEveryRow() throws {
        let sut = try makeSUT(direction: .blurredCenterClearTopBottom(centerBandProportion: 1))
        defer { sut.hide() }

        assertMaskProfile(of: sut, matches: [UInt8](repeating: 0, count: 100), tolerance: 0)
    }

    /// At `startOffset: 1` the ramp collapses to a point and the mask is opaque everywhere.
    @MainActor
    func test_maskProfile_blurredTopClearBottom_startOffsetOne_isOpaqueInEveryRow() throws {
        let sut = try makeSUT(direction: .blurredTopClearBottom, startOffset: 1)
        defer { sut.hide() }

        assertMaskProfile(of: sut, matches: [UInt8](repeating: 255, count: 100), tolerance: 0)
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
