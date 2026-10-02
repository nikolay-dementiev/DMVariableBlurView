import DMVariableBlurView
import SwiftUI
import XCTest

/// What the library draws, measured on pixels inside the host app.
///
/// Thresholds are relative to the reference strip of `RenderingHarness`. Measured on
/// iOS 17.5, 18.6 and 26.5 with radius 6 over two-point stripes:
/// - a blurred band measures 0.00 to 0.03; the tests accept up to 0.10;
/// - the clear edge of the top and bottom modes measures 0.93 (0.85 on iOS 26.5); the
///   tests ask for 0.60;
/// - the clear edges around a 0.3 center band measure 0.52 to 0.53; the tests ask for 0.25;
/// - the bare stripes measure 1.00; the control asks for 0.90.
///
/// Every test attaches its measured band values, so a result bundle shows them for a
/// passing run too.
final class BlurRenderingTests: XCTestCase {
    private let blurredAtMost = 0.10

    @MainActor
    func test_stripedScene_withoutBlur_isSharpInEveryBand() throws {
        let scene = try render(EmptyView())

        expect(scene, bands: 0...19, atLeast: 0.90, "bare stripes are sharp")
    }

    @MainActor
    func test_blurView_blurredTopClearBottom_blursTheTopAndKeepsTheBottomEdgeSharp() throws {
        let scene = try render(makeSUT(direction: .blurredTopClearBottom))

        expect(scene, bands: 0...13, atMost: blurredAtMost, "the top 70 % is blurred")
        expect(scene, bands: 19...19, atLeast: 0.60, "the bottom edge stays sharp")
    }

    @MainActor
    func test_blurView_blurredBottomClearTop_blursTheBottomAndKeepsTheTopEdgeSharp() throws {
        let scene = try render(makeSUT(direction: .blurredBottomClearTop))

        expect(scene, bands: 6...19, atMost: blurredAtMost, "the bottom 70 % is blurred")
        expect(scene, bands: 0...0, atLeast: 0.60, "the top edge stays sharp")
    }

    @MainActor
    func test_blurView_centerBand_blursTheMiddleAndKeepsBothEdgesSharp() throws {
        let direction = DMVariableBlurDirection.blurredCenterClearTopBottom(centerBandProportion: 0.3)
        let scene = try render(makeSUT(direction: direction))

        expect(scene, bands: 2...17, atMost: blurredAtMost, "the middle is blurred")
        expect(scene, bands: 0...0, atLeast: 0.25, "the top edge stays sharp")
        expect(scene, bands: 19...19, atLeast: 0.25, "the bottom edge stays sharp")
    }

    /// A uniform system blur gives the same picture, so this test cannot tell the variable
    /// blur from the substitute the library shows when its set-up fails. The tests of the
    /// other three modes can. The gap closes when the library reports its failures.
    @MainActor
    func test_blurView_blurredFully_blursEveryBand() throws {
        let scene = try render(makeSUT(direction: .blurredFully))

        expect(scene, bands: 0...19, atMost: blurredAtMost, "the whole overlay is blurred")
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT(direction: DMVariableBlurDirection) -> DMVariableBlurView {
        DMVariableBlurView(maxBlurRadius: 6, direction: direction)
    }

    /// Renders the overlay and keeps the measured band values in the result bundle, so a
    /// passing run also shows how far it was from its thresholds.
    @MainActor
    private func render(_ overlay: some View) throws -> RenderedScene {
        let scene = try RenderingHarness.render(overlay)
        let values = XCTAttachment(string: scene.summary)
        values.name = "band values"
        values.lifetime = .keepAlways
        add(values)
        return scene
    }

    private func expect(
        _ scene: RenderedScene,
        bands range: ClosedRange<Int>,
        atMost limit: Double,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let worst = scene.bands[range].max() ?? 0
        guard worst > limit else { return }
        attachImage(of: scene)
        XCTFail("\(message): at most \(limit) expected, found \(worst). \(scene.summary)", file: file, line: line)
    }

    private func expect(
        _ scene: RenderedScene,
        bands range: ClosedRange<Int>,
        atLeast limit: Double,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let worst = scene.bands[range].min() ?? 0
        guard worst < limit else { return }
        attachImage(of: scene)
        XCTFail("\(message): at least \(limit) expected, found \(worst). \(scene.summary)", file: file, line: line)
    }

    private func attachImage(of scene: RenderedScene) {
        let image = XCTAttachment(image: scene.image)
        image.name = "captured scene"
        image.lifetime = .keepAlways
        add(image)
    }
}
