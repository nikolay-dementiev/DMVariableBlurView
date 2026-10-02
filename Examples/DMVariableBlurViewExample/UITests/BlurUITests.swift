import XCTest

/// The example app driven as a user drives it: the blur after the app switches to dark,
/// and touches on a button under the blur, with and without the pass-through recipe.
final class BlurUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// The label appears once the views have the dark appearance, which proves that the
    /// change reached them; the pixels of the screenshot prove the blur.
    @MainActor
    func test_appearanceScene_appSwitchesToDark_keepsTheClearEdgeSharp() throws {
        let app = makeSUT(scene: "appearance")
        XCTAssertTrue(app.buttons["switch-to-dark"].waitForExistence(timeout: 10), "the scene is on screen")
        app.buttons["switch-to-dark"].tap()
        XCTAssertTrue(app.staticTexts["appearance-dark"].waitForExistence(timeout: 10), "the app is dark")

        let bands = try stableBands()

        XCTAssertLessThanOrEqual(bands[0...13].max() ?? 1, 0.10, "the top 70 % of the blurred area is blurred: \(bands)")
        XCTAssertGreaterThanOrEqual(bands[19], 0.60, "the clear edge stays sharp: \(bands)")
    }

    /// The pass-through recipe: `.allowsHitTesting(false)` on the blur.
    @MainActor
    func test_passThroughScene_tapOnTheButtonUnderTheBlur_reachesTheButton() throws {
        let app = makeSUT(scene: "passThrough")

        tap(app.buttons["tap-target"])

        XCTAssertTrue(
            waitForLabel("Taps: 1", of: app.staticTexts["tap-count"], timeout: 10),
            "the button received the tap"
        )
    }

    /// Without the recipe the blur takes the touches: SwiftUI gives a hosted UIKit view the
    /// touches in its frame. The test pins that behaviour of the platform, so a change of
    /// it in a new iOS version shows up here.
    @MainActor
    func test_blockingScene_tapOnTheButtonUnderTheBlur_isTakenByTheBlur() throws {
        let app = makeSUT(scene: "blocking")
        let count = app.staticTexts["tap-count"]

        tap(app.buttons["tap-target"])

        XCTAssertFalse(waitForLabel("Taps: 1", of: count, timeout: 3), "the button received no tap")
        XCTAssertEqual(count.label, "Taps: 0", "the counter is on screen and still at zero")
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT(scene: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestScene", scene]
        app.launch()
        return app
    }

    /// Taps the screen where the element is: a coordinate tap reaches whatever view is on
    /// top there, which is what the tests are about.
    @MainActor
    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "the scene is on screen")
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// A wait for a label that should appear is long; a wait that proves a label does not
    /// change is short, because it always runs to its end.
    @MainActor
    private func waitForLabel(_ label: String, of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// The contrast of twenty bands of the blurred area, relative to the bare stripes from
    /// 74 % to 84 % of the height, from the first two screenshots in a row that agree.
    ///
    /// A screen that never settles fails the test: a blur that keeps changing is a defect
    /// the test must report, not a reason to skip it.
    @MainActor
    private func stableBands() throws -> [Double] {
        var previous: [Double]?
        var summary = "no screenshot"
        for _ in 0..<20 {
            let image = try XCTUnwrap(XCUIScreen.main.screenshot().image.cgImage, "the screenshot has pixels")
            let rows = try BandAnalysis.rowContrast(of: image)
            let height = Double(rows.count)
            let reference = BandAnalysis.mean(of: rows, from: Int(height * 0.74), to: Int(height * 0.84))
            let bands = BandAnalysis.bands(of: rows, from: 0, to: Int(height * 0.7), count: 20, reference: reference)
            summary = "bands top to bottom: "
                + bands.map { String(format: "%.2f", $0) }.joined(separator: " ")
                + " | reference \(reference)"
            if let previous, zip(previous, bands).allSatisfy({ abs($0 - $1) <= 0.02 }) {
                attach(summary, named: "band values")
                return bands
            }
            previous = bands
        }
        attach(summary, named: "band values of the last screenshot")
        throw UnstableScreen(summary: summary)
    }

    @MainActor
    private func attach(_ text: String, named name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// No two screenshots in a row agreed within twenty attempts.
private struct UnstableScreen: Error, CustomStringConvertible {
    let summary: String

    var description: String {
        "the screen never became stable; last \(summary)"
    }
}
