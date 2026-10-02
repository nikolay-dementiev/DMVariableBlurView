import DMVariableBlurView
import UIKit
import XCTest

/// What the UIKit view asks of its collaborators, and what it records and logs when one
/// of them fails, seen through spies.
final class BlurUIViewCollaborationTests: XCTestCase {
    private struct RenderingFailure: Error {}

    private struct Collaborators {
        let renderer: MaskImageRendererSpy
        let installer: VariableBlurInstallerSpy
        let log: FailureLogSpy
    }

    @MainActor
    func test_apply_validConfiguration_installsTheRenderedMaskWithTheRequestedRadiusOnItself() throws {
        let mask = try makeMaskImage()
        let (sut, collaborators) = try makeSUT(renderer: MaskImageRendererSpy(result: .success(mask)))

        sut.apply(VariableBlurConfiguration(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0.25))

        let installations = collaborators.installer.installations
        XCTAssertEqual(
            collaborators.renderer.profiles,
            [BlurMaskProfile(ramps: [.init(start: 0, end: 0.75, startAlpha: 1, endAlpha: 0)])],
            "the renderer draws the profile of the configuration, once"
        )
        XCTAssertEqual(installations.count, 1, "the view installs once")
        XCTAssertEqual(installations.first?.maxBlurRadius, 7, "the installer gets the requested radius")
        XCTAssertTrue(installations.first?.mask === mask, "the installer gets the image the renderer drew")
        XCTAssertEqual(installations.first?.effectView, ObjectIdentifier(sut), "the view is installed on itself")
        XCTAssertNil(sut.failure, "a configuration that is shown records no failure")
        XCTAssertEqual(collaborators.log.entries, [], "nothing is written to the log")
    }

    @MainActor
    func test_apply_installerReportsTheEffectUnavailable_recordsItAndLogsTheReasonOnce() throws {
        let reasons: [VariableBlurInstallation.Reason] = [
            .filterClassMissing, .filterFactoryMissing, .filterTypeMissing,
            .filterCreationFailed, .backdropMissing, .notApplied
        ]

        for reason in reasons {
            let (sut, collaborators) = try makeSUT()
            collaborators.installer.outcome = .unavailable(reason)

            sut.apply(validConfiguration)

            XCTAssertEqual(sut.failure, .effectUnavailable, "\(reason) is recorded as the effect being unavailable")
            XCTAssertEqual(
                collaborators.log.entries,
                [.init(error: .effectUnavailable, detail: "\(reason)")],
                "\(reason) is logged once, with the reason as the detail"
            )
        }
    }

    @MainActor
    func test_apply_rendererFails_recordsMaskCreationFailedLogsTheRendererErrorAndInstallsNothing() throws {
        let (sut, collaborators) = try makeSUT(renderer: MaskImageRendererSpy(result: .failure(RenderingFailure())))

        sut.apply(validConfiguration)

        XCTAssertEqual(sut.failure, .maskCreationFailed, "a mask that cannot be drawn is recorded")
        XCTAssertEqual(
            collaborators.log.entries,
            [.init(error: .maskCreationFailed, detail: "RenderingFailure()")],
            "the failure is logged once, with the error of the renderer as the detail"
        )
        XCTAssertEqual(collaborators.installer.installations.count, 0, "nothing is installed without a mask")
    }

    @MainActor
    func test_apply_centerBandProportionOutOfRange_recordsAndLogsItBeforeAnyCollaboratorRuns() throws {
        let (sut, collaborators) = try makeSUT()
        let configuration = VariableBlurConfiguration(
            maxBlurRadius: 7,
            direction: .blurredCenterClearTopBottom(centerBandProportion: 1.25),
            startOffset: 0
        )

        sut.apply(configuration)

        XCTAssertEqual(sut.failure, .invalidCenterBandProportion(1.25), "the rejected value is recorded")
        XCTAssertEqual(
            collaborators.log.entries,
            [.init(error: .invalidCenterBandProportion(1.25), detail: nil)],
            "the rejected value is logged once"
        )
        XCTAssertEqual(collaborators.renderer.profiles.count, 0, "nothing is drawn for values that are not valid")
        XCTAssertEqual(collaborators.installer.installations.count, 0, "nothing is installed for values that are not valid")
    }

    @MainActor
    func test_blurUIView_movedToAWindow_tellsTheInstallerTheScaleOfTheScreen() throws {
        let (sut, collaborators) = try makeSUT()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 400))

        window.addSubview(sut)
        sut.removeFromSuperview()

        XCTAssertEqual(
            collaborators.installer.scaleUpdates,
            [.init(scale: window.screen.scale, effectView: ObjectIdentifier(sut))]
        )
    }

    // MARK: - Helpers

    private var validConfiguration: VariableBlurConfiguration {
        VariableBlurConfiguration(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0)
    }

    @MainActor
    private func makeSUT(renderer: MaskImageRendererSpy? = nil) throws -> (DMVariableBlurUIView, Collaborators) {
        let collaborators = Collaborators(
            renderer: try renderer ?? MaskImageRendererSpy(result: .success(makeMaskImage())),
            installer: VariableBlurInstallerSpy(),
            log: FailureLogSpy()
        )
        let sut = DMVariableBlurUIView(
            maskRenderer: collaborators.renderer,
            installer: collaborators.installer,
            failureLog: collaborators.log
        )
        return (sut, collaborators)
    }
}
