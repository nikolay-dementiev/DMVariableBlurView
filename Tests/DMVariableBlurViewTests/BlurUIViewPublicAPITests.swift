import DMVariableBlurView
import XCTest

/// The UIKit entry point: the initializer, update and the failure state, through the
/// public API only.
final class BlurUIViewPublicAPITests: XCTestCase {
    @MainActor
    func test_blurUIView_publicInitializer_validValues_installsTheVariableBlur() throws {
        let sut = makeSUT(DMVariableBlurUIView(maxBlurRadius: 7, direction: .blurredTopClearBottom))
        defer { sut.hide() }

        XCTAssertEqual(sut.filterTypes, ["variableBlur"], "the backdrop carries the variable blur")
        XCTAssertEqual(sut.radius, 7, "with the radius of the initializer")
        XCTAssertNil(sut.blurView.failure, "nothing prevents the variable blur")
        assertMaskProfile(of: sut, matches: MaskProfileFixtures.topZeroOffset)
    }

    /// Written as `DMVariableBlurUIView()`: the call a UIKit host makes first.
    @MainActor
    func test_blurUIView_defaultArguments_matchTheSwiftUIDefaults() throws {
        let sut = makeSUT(DMVariableBlurUIView())
        defer { sut.hide() }

        XCTAssertEqual(sut.filterTypes, ["variableBlur"], "the default call shows the variable blur")
        XCTAssertEqual(sut.radius, 20, "the default radius is 20, as in SwiftUI")
        assertMaskProfile(of: sut, matches: MaskProfileFixtures.centerThirtyPercent)
    }

    @MainActor
    func test_blurUIView_publicInitializer_rejectedRadius_showsThePlainBlurAndSetsTheFailure() throws {
        let sut = makeSUT(DMVariableBlurUIView(maxBlurRadius: -1))
        defer { sut.hide() }

        XCTAssertFalse(sut.filterTypes.contains("variableBlur"), "no variable blur")
        XCTAssertEqual(sut.tintAlphas, [1], "the plain blur of the system with its tint")
        XCTAssertEqual(sut.blurView.failure, .invalidMaxBlurRadius(-1), "the reason is readable at once")
    }

    @MainActor
    func test_blurUIView_update_newValues_replacesTheRadiusAndTheMask() throws {
        let sut = makeSUT(DMVariableBlurUIView(maxBlurRadius: 7, direction: .blurredTopClearBottom))
        defer { sut.hide() }

        sut.blurView.update(maxBlurRadius: 9, direction: .blurredBottomClearTop, startOffset: 0)

        XCTAssertEqual(sut.radius, 9, "the new radius is installed")
        assertMaskProfile(of: sut, matches: MaskProfileFixtures.bottomZeroOffset)
    }

    @MainActor
    func test_blurUIView_update_rejectedThenValidThenRejected_tracksTheFailure() throws {
        let sut = makeSUT(DMVariableBlurUIView(maxBlurRadius: 7, direction: .blurredTopClearBottom))
        defer { sut.hide() }

        sut.blurView.update(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: .nan)
        let afterRejection = sut.blurView.failure
        sut.blurView.update(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0)
        let afterRecovery = sut.blurView.failure
        sut.blurView.update(maxBlurRadius: .infinity, direction: .blurredTopClearBottom, startOffset: 0)

        XCTAssertEqual(afterRejection, .invalidStartOffset(.nan), "a rejected offset is recorded at once")
        XCTAssertNil(afterRecovery, "valid values clear the failure")
        XCTAssertEqual(sut.blurView.failure, .invalidMaxBlurRadius(.infinity), "the next rejection is recorded")
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT(_ view: DMVariableBlurUIView) -> HostedBlurView {
        HostedBlurView(placing: view)
    }
}
