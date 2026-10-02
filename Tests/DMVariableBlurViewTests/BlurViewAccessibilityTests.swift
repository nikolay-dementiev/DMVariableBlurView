import DMVariableBlurView
import UIKit
import XCTest

/// The blur is decoration: no view of it is an accessibility element or offers elements
/// of its own, so assistive technologies pass it by.
final class BlurViewAccessibilityTests: XCTestCase {
    @MainActor
    func test_blurView_withTheVariableBlurInstalled_exposesNoAccessibilityElement() throws {
        let sut = try makeSUT()
        defer { sut.hide() }

        let views = [sut.blurView] + descendants(of: sut.blurView)

        XCTAssertGreaterThan(views.count, 1, "the effect view has views inside it to check")
        XCTAssertEqual(
            views.filter(\.isAccessibilityElement).map { "\(type(of: $0))" },
            [],
            "no view of the blur is an element"
        )
        XCTAssertEqual(
            views.filter { ($0.accessibilityElements?.count ?? 0) > 0 }.map { "\(type(of: $0))" },
            [],
            "no view of the blur offers elements of its own"
        )
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT() throws -> HostedBlurView {
        try HostedBlurView(DMVariableBlurView(maxBlurRadius: 7, direction: .blurredTopClearBottom))
    }

    @MainActor
    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
