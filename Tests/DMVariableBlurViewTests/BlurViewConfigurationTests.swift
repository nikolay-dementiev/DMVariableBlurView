import DMVariableBlurView
import SwiftUI
import XCTest

/// What the SwiftUI view installs on the system views for a valid configuration.
final class BlurViewConfigurationTests: XCTestCase {
    @MainActor
    func test_blurView_validConfiguration_installsOnlyTheVariableBlurFilterWithTheRequestedRadius() throws {
        let sut = try makeSUT(DMVariableBlurView(maxBlurRadius: 7, direction: .blurredTopClearBottom))
        defer { sut.hide() }

        XCTAssertEqual(
            sut.filterTypes,
            ["variableBlur"],
            "the backdrop layer holds the variable blur filter and nothing else"
        )
        XCTAssertEqual(sut.radius, 7, "the filter carries the requested maximum radius")
    }

    @MainActor
    func test_blurView_validConfiguration_hidesTheTintOfTheEffectView() throws {
        let sut = try makeSUT(DMVariableBlurView(maxBlurRadius: 7, direction: .blurredTopClearBottom))
        defer { sut.hide() }

        XCTAssertEqual(sut.tintAlphas, [0])
    }

    @MainActor
    func test_blurView_attachedToWindow_setsTheBackdropScaleToTheDisplayScale() throws {
        let sut = try makeSUT(DMVariableBlurView(maxBlurRadius: 7, direction: .blurredTopClearBottom))
        defer { sut.hide() }

        XCTAssertEqual(sut.backdropScale, sut.window.screen.scale)
    }

    @MainActor
    func test_blurView_defaultArguments_useRadiusTwentyAndAThirtyPercentCentreBand() throws {
        let sut = try makeSUT(DMVariableBlurView())
        defer { sut.hide() }

        XCTAssertEqual(sut.radius, 20, "the default maximum radius is 20")
        assertMaskProfile(of: sut, matches: MaskProfileFixtures.centreThirtyPercent)
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
