import DMVariableBlurView
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
    func test_blurView_defaultArguments_useRadiusTwentyAndAThirtyPercentCenterBand() throws {
        let sut = try makeSUT(DMVariableBlurView())
        defer { sut.hide() }

        XCTAssertEqual(sut.radius, 20, "the default maximum radius is 20")
        assertMaskProfile(of: sut, matches: MaskProfileFixtures.centerThirtyPercent)
    }

    /// Values the library rejects give the plain blur of the system over the whole view,
    /// as release 1.0.0 does.
    @MainActor
    func test_blurView_centerBandProportionOutOfRange_showsThePlainSystemBlur() throws {
        // A handler keeps the expected failure out of the unified log of the test process.
        let sut = try makeSUT(
            DMVariableBlurView(direction: .blurredCenterClearTopBottom(centerBandProportion: 1.5)).onFailure { _ in }
        )
        defer { sut.hide() }

        XCTAssertFalse(sut.filterTypes.contains("variableBlur"), "no variable blur is installed")
        XCTAssertFalse(sut.filterTypes.isEmpty, "the backdrop keeps the filters of the system blur")
        XCTAssertEqual(sut.tintAlphas, [1], "the tint of the system blur stays visible")
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
