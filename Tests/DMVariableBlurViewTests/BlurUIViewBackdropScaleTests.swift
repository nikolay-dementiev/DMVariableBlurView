import DMVariableBlurView
import UIKit
import XCTest

/// The scale the backdrop renders at, through the installer port: which display scale the
/// view hands over, and when. A backdrop that keeps the default scale, a fraction of the
/// display scale, shows a pixelated clear edge.
final class BlurUIViewBackdropScaleTests: XCTestCase {
    @MainActor
    func test_blurUIView_movedIntoAWindowAndOut_handsTheInstallerTheDisplayScaleOfItsTraitsOnce() throws {
        let (sut, installer) = try makeSUT()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 400))

        window.addSubview(sut)
        let scaleInTheWindow = sut.traitCollection.displayScale
        sut.removeFromSuperview()

        XCTAssertEqual(
            installer.scaleUpdates,
            [.init(scale: scaleInTheWindow, effectView: ObjectIdentifier(sut))],
            "one update with the display scale of the traits in the window, none when the view leaves it"
        )
    }

    /// The scale the backdrop renders at comes from the traits the view receives, which a
    /// host can override for a part of its hierarchy, not from the screen of the window.
    @MainActor
    func test_movedToWindow_underADisplayScaleOverride_handsTheTraitsScaleToTheInstaller() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 400))
        let controller = UIViewController()
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        let container = UIView(frame: controller.view.bounds)
        controller.view.addSubview(container)
        let overriddenScale: CGFloat = window.screen.scale == 2 ? 3 : 2
        container.traitOverrides.displayScale = overriddenScale
        container.layoutIfNeeded()
        let (sut, installer) = try makeSUT()

        container.addSubview(sut)

        XCTAssertEqual(
            installer.scaleUpdates.map(\.scale),
            [overriddenScale],
            "the installer receives the display scale of the traits, not \(window.screen.scale) of the screen"
        )
    }

    /// A host that fades the view in sets `effect` to `nil`, adds the view to a window and then
    /// sets the effect. Without an effect there is no backdrop, so the scale goes to the
    /// backdrop once the blur is installed on it again.
    @MainActor
    func test_blurUIView_effectSetAfterEnteringTheWindow_handsTheScaleAfterTheBlurIsInstalledAgain() throws {
        let (sut, installer) = try makeSUT()
        sut.apply(VariableBlurConfiguration(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0))
        sut.effect = nil
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 400))
        window.addSubview(sut)
        window.layoutIfNeeded()
        let updatesWithoutAnEffect = installer.scaleUpdates
        let installationsWithoutAnEffect = installer.installations.count

        // UIKit puts the standard filters of the new effect on the backdrop.
        installer.blurIsStillInstalled = false
        sut.effect = UIBlurEffect(style: .regular)
        window.layoutIfNeeded()

        XCTAssertEqual(updatesWithoutAnEffect, [], "without an effect there is no backdrop to take the scale")
        XCTAssertEqual(
            installer.installations.count,
            installationsWithoutAnEffect + 1,
            "precondition: the blur is installed again when the effect is set"
        )
        XCTAssertEqual(
            installer.scaleUpdates,
            [.init(scale: sut.traitCollection.displayScale, effectView: ObjectIdentifier(sut))],
            "the display scale of the traits goes to the backdrop after the installation"
        )
    }

    /// A view whose first values were rejected has no blur to put back when a host fades it
    /// in. The scale goes to the backdrop with the first blur installed afterwards.
    @MainActor
    func test_blurUIView_firstBlurInstalledAfterAFadeIn_handsTheScaleWithIt() throws {
        let (sut, installer) = try makeSUT()
        sut.effect = nil
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 400))
        window.addSubview(sut)
        sut.effect = UIBlurEffect(style: .regular)
        window.layoutIfNeeded()
        let updatesBeforeTheBlur = installer.scaleUpdates

        sut.apply(VariableBlurConfiguration(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0))

        XCTAssertEqual(updatesBeforeTheBlur, [], "nothing is handed over while there is no blur and no backdrop at the move")
        XCTAssertEqual(installer.installations.count, 1, "precondition: the first blur is installed")
        XCTAssertEqual(
            installer.scaleUpdates.map(\.scale),
            [sut.traitCollection.displayScale],
            "the display scale goes to the backdrop with the first blur"
        )
    }

    /// A host may change the display scale of a part of its hierarchy after the view entered
    /// it. The backdrop follows the traits.
    @MainActor
    func test_blurUIView_displayScaleChangedAfterEnteringTheWindow_handsTheNewScale() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 400))
        let controller = UIViewController()
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        let container = UIView(frame: controller.view.bounds)
        controller.view.addSubview(container)
        let (sut, installer) = try makeSUT()
        container.addSubview(sut)
        let scaleInTheWindow = sut.traitCollection.displayScale
        let newScale: CGFloat = scaleInTheWindow == 2 ? 3 : 2

        container.traitOverrides.displayScale = newScale
        window.layoutIfNeeded()

        XCTAssertEqual(
            installer.scaleUpdates.map(\.scale),
            [scaleInTheWindow, newScale],
            "the display scale in the window, then the new display scale of the traits"
        )
    }

    /// The scale goes to the backdrop after every installation, but the installer is not asked
    /// to set a scale the backdrop already has.
    @MainActor
    func test_blurUIView_installedAgainWithAnEqualDisplayScale_doesNotHandTheScaleAgain() throws {
        let (sut, installer) = try makeSUT()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 400))
        window.addSubview(sut)

        sut.apply(VariableBlurConfiguration(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0))
        sut.apply(VariableBlurConfiguration(maxBlurRadius: 9, direction: .blurredTopClearBottom, startOffset: 0))

        XCTAssertEqual(installer.installations.count, 2, "precondition: two installations in the window")
        XCTAssertEqual(
            installer.scaleUpdates.map(\.scale),
            [sut.traitCollection.displayScale],
            "one update: an equal scale is not handed over again"
        )
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT() throws -> (DMVariableBlurUIView, VariableBlurInstallerSpy) {
        let installer = VariableBlurInstallerSpy()
        let sut = DMVariableBlurUIView(
            maskRenderer: MaskImageRendererSpy(result: .success(try makeMaskImage())),
            installer: installer,
            failureLog: FailureLogSpy(),
            reduceTransparency: ReduceTransparencySettingSpy()
        )
        return (sut, installer)
    }
}
