import DMVariableBlurView
import XCTest

/// A SwiftUI update hands the view new values: the same UIKit view shows them.
final class BlurViewUpdateTests: XCTestCase {
    @MainActor
    func test_blurView_updatedWithANewRadiusAndDirection_showsThemOnTheSameView() throws {
        let sut = try makeSUT(DMVariableBlurView(maxBlurRadius: 5, direction: .blurredTopClearBottom))
        defer { sut.hide() }

        let updated = try sut.update(DMVariableBlurView(maxBlurRadius: 9, direction: .blurredBottomClearTop))

        XCTAssertTrue(updated === sut.blurView, "SwiftUI keeps the UIKit view and updates it")
        XCTAssertEqual(sut.radius, 9, "the new radius is installed")
        XCTAssertEqual(
            sut.backdropScale,
            sut.blurView.traitCollection.displayScale,
            "the backdrop keeps the display scale of its traits"
        )
        assertMaskProfile(of: sut, matches: MaskProfileFixtures.bottomZeroOffset)
    }

    /// The mask does not depend on the radius, so a new radius alone must still reach the
    /// filter, even though the mask could be kept.
    @MainActor
    func test_blurView_updatedWithANewRadiusOnly_showsTheNewRadius() throws {
        let sut = try makeSUT(DMVariableBlurView(maxBlurRadius: 5, direction: .blurredTopClearBottom))
        defer { sut.hide() }

        _ = try sut.update(DMVariableBlurView(maxBlurRadius: 9, direction: .blurredTopClearBottom))

        XCTAssertEqual(sut.radius, 9, "the new radius is installed")
        XCTAssertNil(sut.blurView.failure, "nothing failed")
    }

    /// A radius of 0 is valid: the system takes the filter, and nothing is blurred.
    @MainActor
    func test_blurView_withARadiusOfZero_installsTheVariableBlurWithoutAFailure() throws {
        let sut = try makeSUT(DMVariableBlurView(maxBlurRadius: 0, direction: .blurredTopClearBottom))
        defer { sut.hide() }

        XCTAssertEqual(sut.filterTypes, ["variableBlur"], "the backdrop carries the variable blur")
        XCTAssertEqual(sut.radius, 0, "with a radius of 0")
        XCTAssertNil(sut.blurView.failure, "nothing failed")
    }

    @MainActor
    func test_blurView_updatedToARejectedValue_showsThePlainSystemBlur() throws {
        let sut = try makeSUT(DMVariableBlurView(maxBlurRadius: 5, direction: .blurredTopClearBottom))
        defer { sut.hide() }

        _ = try sut.update(DMVariableBlurView(direction: .blurredCenterClearTopBottom(centerBandProportion: 1.5)))

        XCTAssertFalse(sut.filterTypes.contains("variableBlur"), "the variable blur is gone")
        XCTAssertFalse(sut.filterTypes.isEmpty, "the backdrop carries the filters of the system blur")
        XCTAssertEqual(sut.tintAlphas, [1], "the tint of the system blur is visible")
    }

    @MainActor
    func test_blurView_updatedFromARejectedValueToAValidOne_showsTheVariableBlur() throws {
        let sut = try makeSUT(DMVariableBlurView(direction: .blurredCenterClearTopBottom(centerBandProportion: 1.5)))
        defer { sut.hide() }

        _ = try sut.update(DMVariableBlurView(maxBlurRadius: 9, direction: .blurredBottomClearTop))

        XCTAssertEqual(sut.filterTypes, ["variableBlur"], "the variable blur replaces the system blur")
        XCTAssertEqual(sut.tintAlphas, [0], "the tint is hidden again")
        assertMaskProfile(of: sut, matches: MaskProfileFixtures.bottomZeroOffset)
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT(
        _ view: DMVariableBlurView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> HostedBlurView {
        try HostedBlurView(view, file: file, line: line)
    }
}
