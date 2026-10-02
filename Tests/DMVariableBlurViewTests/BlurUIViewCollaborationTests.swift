import DMVariableBlurView
import UIKit
import XCTest

/// What the UIKit view asks of its two collaborators, seen through spies.
final class BlurUIViewCollaborationTests: XCTestCase {
    private struct RenderingFailure: Error {}

    @MainActor
    func test_blurUIView_validConfiguration_installsTheRenderedMaskWithTheRequestedRadiusOnItself() throws {
        let mask = try makeMaskImage()
        let renderer = MaskImageRendererSpy(result: .success(mask))
        let installer = VariableBlurInstallerSpy()

        let sut = try makeSUT(
            VariableBlurConfiguration(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0.25),
            renderer: renderer,
            installer: installer
        )

        XCTAssertEqual(
            renderer.profiles,
            [BlurMaskProfile(ramps: [.init(start: 0, end: 0.75, startAlpha: 1, endAlpha: 0)])],
            "the renderer draws the profile of the configuration, once"
        )
        XCTAssertEqual(installer.installations.count, 1, "the view installs once")
        XCTAssertEqual(installer.installations.first?.maxBlurRadius, 7, "the installer gets the requested radius")
        XCTAssertTrue(installer.installations.first?.mask === mask, "the installer gets the image the renderer drew")
        XCTAssertEqual(
            installer.installations.first?.effectView,
            ObjectIdentifier(sut),
            "the view is installed on itself"
        )
    }

    @MainActor
    func test_blurUIView_installerReportsThatTheEffectIsUnavailable_throws() throws {
        let reasons: [VariableBlurInstallation.Reason] = [
            .filterClassMissing, .filterFactoryMissing, .filterTypeMissing,
            .filterCreationFailed, .backdropMissing, .notApplied
        ]

        for reason in reasons {
            let installer = VariableBlurInstallerSpy()
            installer.outcome = .unavailable(reason)

            XCTAssertThrowsError(
                try makeSUT(installer: installer),
                "the view does not pretend to show the variable blur when the installer reports \(reason)"
            )
        }
    }

    @MainActor
    func test_blurUIView_rendererFails_throwsTheErrorOfTheRendererAndInstallsNothing() throws {
        let renderer = MaskImageRendererSpy(result: .failure(RenderingFailure()))
        let installer = VariableBlurInstallerSpy()

        XCTAssertThrowsError(
            try makeSUT(renderer: renderer, installer: installer),
            "a mask that cannot be drawn stops the set-up"
        ) { error in
            XCTAssertTrue(error is RenderingFailure, "the error of the renderer reaches the caller, not \(error)")
        }
        XCTAssertEqual(installer.installations.count, 0, "nothing is installed without a mask")
    }

    @MainActor
    func test_blurUIView_centerBandProportionOutOfRange_throwsBeforeItRendersOrInstalls() throws {
        let renderer = MaskImageRendererSpy(result: .success(try makeMaskImage()))
        let installer = VariableBlurInstallerSpy()
        let configuration = VariableBlurConfiguration(
            maxBlurRadius: 7,
            direction: .blurredCenterClearTopBottom(centerBandProportion: 1.25),
            startOffset: 0
        )

        XCTAssertThrowsError(
            try makeSUT(configuration, renderer: renderer, installer: installer),
            "values that are not valid stop the set-up"
        )
        XCTAssertEqual(renderer.profiles.count, 0, "nothing is drawn for values that are not valid")
        XCTAssertEqual(installer.installations.count, 0, "nothing is installed for values that are not valid")
    }

    @MainActor
    func test_blurUIView_movedToAWindow_tellsTheInstallerTheScaleOfTheScreen() throws {
        let installer = VariableBlurInstallerSpy()
        let sut = try makeSUT(installer: installer)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 400))

        window.addSubview(sut)
        sut.removeFromSuperview()

        XCTAssertEqual(
            installer.scaleUpdates,
            [.init(scale: window.screen.scale, effectView: ObjectIdentifier(sut))]
        )
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT(
        _ configuration: VariableBlurConfiguration = VariableBlurConfiguration(
            maxBlurRadius: 7,
            direction: .blurredTopClearBottom,
            startOffset: 0
        ),
        renderer: MaskImageRendererSpy? = nil,
        installer: VariableBlurInstallerSpy
    ) throws -> DMVariableBlurUIView {
        try DMVariableBlurUIView(
            configuration: configuration,
            maskRenderer: renderer ?? MaskImageRendererSpy(result: .success(makeMaskImage())),
            installer: installer
        )
    }
}
