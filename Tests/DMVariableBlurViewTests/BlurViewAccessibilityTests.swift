import DMVariableBlurView
import XCTest

/// The blur is decoration: assistive technologies do not see it, and the elements of the
/// host underneath stay reachable.
final class BlurViewAccessibilityTests: XCTestCase {
    @MainActor
    func test_blurView_isHiddenFromAccessibility() throws {
        let sut = try makeSUT()
        defer { sut.hide() }

        XCTAssertFalse(sut.blurView.isAccessibilityElement, "the blur view is not an element")
        XCTAssertEqual(sut.blurView.accessibilityElementCount(), 0, "it offers no elements of its own")
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT() throws -> HostedBlurView {
        try HostedBlurView(DMVariableBlurView(maxBlurRadius: 7, direction: .blurredTopClearBottom))
    }
}
