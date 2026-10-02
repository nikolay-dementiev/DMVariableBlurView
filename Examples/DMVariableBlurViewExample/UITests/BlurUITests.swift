import XCTest

/// The example app driven as a user drives it: the blur after the app switches to dark,
/// and touches on a button under the blur, with and without the pass-through recipe.
final class BlurUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// The label appears after the switch, which only proves that the app got there; the
    /// pixels of the screenshot prove the blur.
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

    /// The recipe of the README: `.allowsHitTesting(false)` on the blur.
    @MainActor
    func test_passThroughScene_tapOnTheButtonUnderTheBlur_reachesTheButton() throws {
        let app = makeSUT(scene: "passThrough")

        tap(app.buttons["tap-target"])

        XCTAssertTrue(waitForLabel("Taps: 1", of: app.staticTexts["tap-count"]), "the button received the tap")
    }

    /// Without the recipe the blur takes the touches, as release 1.0.0 does.
    @MainActor
    func test_blockingScene_tapOnTheButtonUnderTheBlur_isTakenByTheBlur() throws {
        let app = makeSUT(scene: "blocking")

        tap(app.buttons["tap-target"])

        XCTAssertFalse(waitForLabel("Taps: 1", of: app.staticTexts["tap-count"]), "the button received no tap")
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

    @MainActor
    private func waitForLabel(_ label: String, of element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 3) == .completed
    }

    /// The contrast of twenty bands of the blurred area, relative to the bare stripes from
    /// 74 % to 84 % of the height, from the first two screenshots in a row that agree.
    @MainActor
    private func stableBands() throws -> [Double] {
        var previous: [Double]?
        for _ in 0..<20 {
            let image = try XCTUnwrap(XCUIScreen.main.screenshot().image.cgImage, "the screenshot has pixels")
            let rows = BandAnalysis.rowContrast(of: image)
            let height = Double(rows.count)
            let reference = BandAnalysis.mean(of: rows, from: Int(height * 0.74), to: Int(height * 0.84))
            let bands = BandAnalysis.bands(of: rows, from: 0, to: Int(height * 0.7), count: 20, reference: reference)
            if let previous, zip(previous, bands).allSatisfy({ abs($0 - $1) <= 0.02 }) {
                let summary = bands.map { String(format: "%.2f", $0) }.joined(separator: " ")
                let attachment = XCTAttachment(string: "bands top to bottom: \(summary) | reference \(reference)")
                attachment.lifetime = .keepAlways
                add(attachment)
                return bands
            }
            previous = bands
        }
        throw XCTSkip("the screen never became stable")
    }
}
