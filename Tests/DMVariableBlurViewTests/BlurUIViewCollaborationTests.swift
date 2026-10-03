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
        let reduceTransparency: ReduceTransparencySettingSpy
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

    // MARK: - Updates

    @MainActor
    func test_apply_sameConfigurationAgain_drawsAndInstallsNothing() throws {
        let (sut, collaborators) = try makeSUT()
        sut.apply(validConfiguration)

        sut.apply(validConfiguration)

        XCTAssertEqual(collaborators.renderer.profiles.count, 1, "the mask is drawn once")
        XCTAssertEqual(collaborators.installer.installations.count, 1, "the blur is installed once")
    }

    /// The public `update` with the values the view already has does nothing: no mask is
    /// drawn and nothing is installed again.
    @MainActor
    func test_blurUIView_update_sameValues_doesNotRenderAgain() throws {
        let (sut, collaborators) = try makeSUT()
        sut.update(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0)

        sut.update(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0)

        XCTAssertEqual(collaborators.renderer.profiles.count, 1, "the mask is drawn once")
        XCTAssertEqual(collaborators.installer.installations.count, 1, "the blur is installed once")
    }

    @MainActor
    func test_apply_newValidConfiguration_installsItsMaskWithItsRadius() throws {
        let (sut, collaborators) = try makeSUT()
        sut.apply(validConfiguration)

        sut.apply(VariableBlurConfiguration(maxBlurRadius: 9, direction: .blurredBottomClearTop, startOffset: 0))

        XCTAssertEqual(
            collaborators.renderer.profiles.last,
            BlurMaskProfile(ramps: [.init(start: 1, end: 0, startAlpha: 1, endAlpha: 0)]),
            "the profile of the new direction is drawn"
        )
        XCTAssertEqual(collaborators.installer.installations.count, 2, "the new blur is installed")
        XCTAssertEqual(collaborators.installer.installations.last?.maxBlurRadius, 9, "with the new radius")
    }

    @MainActor
    func test_apply_sameRejectedConfigurationAgain_logsNothingNew() throws {
        let (sut, collaborators) = try makeSUT()

        sut.apply(rejectedConfiguration(centerBandProportion: 1.25))
        sut.apply(rejectedConfiguration(centerBandProportion: 1.25))

        XCTAssertEqual(collaborators.log.entries.count, 1)
    }

    /// An unchanged configuration is decided on the reason it was rejected for, and that
    /// reason is equal to itself also when the value is not a number.
    @MainActor
    func test_apply_rejectedValueThatIsNotANumberAgain_logsOnce() throws {
        let (sut, collaborators) = try makeSUT()

        sut.apply(rejectedConfiguration(centerBandProportion: .nan))
        sut.apply(rejectedConfiguration(centerBandProportion: .nan))

        XCTAssertEqual(collaborators.log.entries.count, 1)
    }

    @MainActor
    func test_apply_twoDifferentRejectedValues_logsBothInOrder() throws {
        let (sut, collaborators) = try makeSUT()

        sut.apply(rejectedConfiguration(centerBandProportion: 1.25))
        sut.apply(rejectedConfiguration(centerBandProportion: -0.5))

        XCTAssertEqual(
            collaborators.log.entries.map(\.error),
            [.invalidCenterBandProportion(1.25), .invalidCenterBandProportion(-0.5)]
        )
    }

    /// Failure, recovery, the same failure again: the failure that returns is a new one.
    @MainActor
    func test_apply_rejectedThenValidThenRejectedAgain_clearsTheFailureAndLogsTwice() throws {
        let (sut, collaborators) = try makeSUT()

        sut.apply(rejectedConfiguration(centerBandProportion: 1.25))
        sut.apply(validConfiguration)
        let failureWhileValid = sut.failure
        sut.apply(rejectedConfiguration(centerBandProportion: 1.25))

        XCTAssertNil(failureWhileValid, "a configuration that is shown clears the failure")
        XCTAssertEqual(sut.failure, .invalidCenterBandProportion(1.25), "the returning failure is recorded")
        XCTAssertEqual(collaborators.log.entries.count, 2, "the returning failure is logged again")
    }

    @MainActor
    func test_apply_newConfigurationCannotBeDrawn_stopsPuttingTheOldBlurBack() throws {
        let (sut, collaborators) = try makeSUT()
        sut.apply(validConfiguration)
        collaborators.renderer.result = .failure(RenderingFailure())

        sut.apply(VariableBlurConfiguration(maxBlurRadius: 9, direction: .blurredBottomClearTop, startOffset: 0))
        collaborators.installer.blurIsStillInstalled = false
        layOut(sut)

        XCTAssertEqual(sut.failure, .maskCreationFailed, "the failure of the new configuration is recorded")
        XCTAssertEqual(collaborators.installer.installations.count, 1, "the blur of the old configuration stays off")
    }

    @MainActor
    func test_apply_newConfigurationCannotBeInstalled_stopsPuttingTheOldBlurBack() throws {
        let (sut, collaborators) = try makeSUT()
        sut.apply(validConfiguration)
        collaborators.installer.outcome = .unavailable(.notApplied)

        sut.apply(VariableBlurConfiguration(maxBlurRadius: 9, direction: .blurredBottomClearTop, startOffset: 0))
        collaborators.installer.blurIsStillInstalled = false
        layOut(sut)

        XCTAssertEqual(sut.failure, .effectUnavailable, "the failure of the new configuration is recorded")
        XCTAssertEqual(collaborators.installer.installations.count, 2, "the blur of the old configuration stays off")
    }

    // MARK: - Reduce Transparency

    /// The view follows the setting: the standard effect of the system, which the system
    /// draws without transparency, and no failure, because nothing failed.
    @MainActor
    func test_apply_optionOnAndSettingOn_installsNothingAndRecordsNoFailure() throws {
        let (sut, collaborators) = try makeSUT(reduceTransparencyEnabled: true)
        sut.respectsReduceTransparency = true

        sut.apply(validConfiguration)
        collaborators.installer.blurIsStillInstalled = false
        layOut(sut)

        XCTAssertEqual(collaborators.installer.installations.count, 0, "no variable blur, not even in a layout pass")
        XCTAssertNil(sut.failure, "following the setting is not a failure")
        XCTAssertEqual(collaborators.log.entries, [], "nothing is logged")
    }

    @MainActor
    func test_apply_optionOffAndSettingOn_installsTheVariableBlur() throws {
        let (sut, collaborators) = try makeSUT(reduceTransparencyEnabled: true)

        sut.apply(validConfiguration)

        XCTAssertEqual(collaborators.installer.installations.count, 1)
    }

    @MainActor
    func test_apply_optionOnAndSettingOff_installsTheVariableBlur() throws {
        let (sut, collaborators) = try makeSUT(reduceTransparencyEnabled: false)
        sut.respectsReduceTransparency = true

        sut.apply(validConfiguration)

        XCTAssertEqual(collaborators.installer.installations.count, 1)
    }

    @MainActor
    func test_settingTurnsOnAndOff_followsBothChanges() throws {
        let (sut, collaborators) = try makeSUT()
        sut.respectsReduceTransparency = true
        sut.apply(validConfiguration)

        collaborators.reduceTransparency.simulateChange(to: true)
        collaborators.installer.blurIsStillInstalled = false
        layOut(sut)
        let installationsWhileOn = collaborators.installer.installations.count
        collaborators.reduceTransparency.simulateChange(to: false)

        XCTAssertEqual(installationsWhileOn, 1, "while the setting is on, the blur is not put back")
        XCTAssertEqual(collaborators.installer.installations.count, 2, "when it goes off, the blur comes back")
        XCTAssertEqual(collaborators.renderer.profiles.count, 1, "the kept mask is used, nothing is drawn again")
    }

    @MainActor
    func test_apply_validConfigurationWhileFollowingReduceTransparency_clearsAnEarlierFailure() throws {
        let (sut, _) = try makeSUT(reduceTransparencyEnabled: true)
        sut.respectsReduceTransparency = true
        sut.apply(rejectedConfiguration(centerBandProportion: 1.25))

        sut.apply(validConfiguration)

        XCTAssertNil(sut.failure)
    }

    @MainActor
    func test_respectsReduceTransparency_setToTheSameValueAgain_installsNothingAgain() throws {
        let (sut, collaborators) = try makeSUT()
        sut.respectsReduceTransparency = true
        sut.apply(validConfiguration)

        sut.respectsReduceTransparency = true

        XCTAssertEqual(collaborators.installer.installations.count, 1)
    }

    /// With the option off the view ignores the setting, also its change notifications.
    @MainActor
    func test_settingChanges_withTheOptionOff_installsNothingAgain() throws {
        let (sut, collaborators) = try makeSUT()
        sut.apply(validConfiguration)

        collaborators.reduceTransparency.simulateChange(to: true)
        collaborators.reduceTransparency.simulateChange(to: false)

        XCTAssertEqual(collaborators.installer.installations.count, 1)
    }

    @MainActor
    func test_respectsReduceTransparency_setWhileTheSettingIsOn_takesEffectAtOnce() throws {
        let (sut, collaborators) = try makeSUT(reduceTransparencyEnabled: true)
        sut.apply(validConfiguration)

        sut.respectsReduceTransparency = true
        collaborators.installer.blurIsStillInstalled = false
        layOut(sut)
        let installationsWithTheOptionOn = collaborators.installer.installations.count
        sut.respectsReduceTransparency = false

        XCTAssertEqual(installationsWithTheOptionOn, 1, "with the option on, the blur is not put back")
        XCTAssertEqual(collaborators.installer.installations.count, 2, "with the option off again, the blur at once")
    }

    /// A configuration the system did not take stays failed: the setting does not bring it
    /// back, and the failure is not reported twice.
    @MainActor
    func test_settingChanges_afterAnInstallationThatFailed_reportsNothingNew() throws {
        let (sut, collaborators) = try makeSUT()
        sut.respectsReduceTransparency = true
        collaborators.installer.outcome = .unavailable(.notApplied)
        sut.apply(validConfiguration)

        collaborators.reduceTransparency.simulateChange(to: true)
        collaborators.reduceTransparency.simulateChange(to: false)

        XCTAssertEqual(sut.failure, .effectUnavailable, "the failure stays")
        XCTAssertEqual(collaborators.log.entries.count, 1, "it is logged once")
        XCTAssertEqual(collaborators.installer.installations.count, 1, "no second attempt")
    }

    @MainActor
    func test_settingChanges_afterARejectedConfiguration_logsNothingNew() throws {
        let (sut, collaborators) = try makeSUT()
        sut.respectsReduceTransparency = true
        sut.apply(rejectedConfiguration(centerBandProportion: 1.25))

        collaborators.reduceTransparency.simulateChange(to: true)
        collaborators.reduceTransparency.simulateChange(to: false)

        XCTAssertEqual(collaborators.log.entries.count, 1, "the rejection is logged once")
        XCTAssertEqual(collaborators.installer.installations.count, 0, "nothing is installed")
    }

    // MARK: - Failures with a handler

    @MainActor
    func test_apply_effectUnavailableWithAHandler_reportsToTheHandlerAndLogsNothing() async throws {
        let (sut, collaborators) = try makeSUT()
        var reports: [DMVariableBlurError] = []
        sut.failureHandler = { reports.append($0) }
        collaborators.installer.outcome = .unavailable(.filterTypeMissing)

        sut.apply(validConfiguration)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(reports, [.effectUnavailable], "the handler receives the reason")
        XCTAssertEqual(collaborators.log.entries, [], "the log stays silent")
    }

    @MainActor
    func test_layout_installingAgainFailsWithAHandler_reportsToTheHandlerOnce() async throws {
        let (sut, collaborators) = try makeSUT()
        var reports: [DMVariableBlurError] = []
        sut.failureHandler = { reports.append($0) }
        sut.apply(validConfiguration)
        collaborators.installer.blurIsStillInstalled = false
        collaborators.installer.outcome = .unavailable(.notApplied)

        layOut(sut)
        layOut(sut)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(reports, [.effectUnavailable], "the failure of the re-application is reported once")
        XCTAssertEqual(collaborators.log.entries, [], "the log stays silent")
    }

    // MARK: - Layout passes

    @MainActor
    func test_layout_blurStillInstalled_installsNothingAgain() throws {
        let (sut, collaborators) = try makeSUT()
        sut.apply(validConfiguration)

        layOut(sut)

        XCTAssertEqual(collaborators.installer.installations.count, 1)
    }

    @MainActor
    func test_layout_blurGone_installsTheSameMaskWithTheSameRadiusAgain() throws {
        let mask = try makeMaskImage()
        let (sut, collaborators) = try makeSUT(renderer: MaskImageRendererSpy(result: .success(mask)))
        sut.apply(validConfiguration)
        collaborators.installer.blurIsStillInstalled = false

        layOut(sut)

        let installations = collaborators.installer.installations
        XCTAssertEqual(installations.count, 2, "the blur is installed again")
        XCTAssertEqual(installations.last?.maxBlurRadius, 7, "with the radius of the configuration")
        XCTAssertTrue(installations.last?.mask === mask, "with the mask that was drawn for it")
        XCTAssertEqual(collaborators.renderer.profiles.count, 1, "the mask is not drawn again")
        XCTAssertEqual(collaborators.log.entries, [], "a successful installation logs nothing")
    }

    /// A configuration that was shown and then cannot be installed again is a new failure.
    @MainActor
    func test_layout_installingAgainFails_recordsTheFailureLogsItOnceAndStopsTrying() throws {
        let (sut, collaborators) = try makeSUT()
        sut.apply(validConfiguration)
        collaborators.installer.blurIsStillInstalled = false
        collaborators.installer.outcome = .unavailable(.notApplied)

        layOut(sut)
        layOut(sut)

        XCTAssertEqual(sut.failure, .effectUnavailable, "the failure is recorded")
        XCTAssertEqual(
            collaborators.log.entries,
            [.init(error: .effectUnavailable, detail: "notApplied")],
            "the failure is logged once, although the view was laid out twice"
        )
        XCTAssertEqual(collaborators.installer.installations.count, 2, "one installation, one attempt, no third")
    }

    @MainActor
    func test_layout_afterARejectedConfiguration_installsNothing() throws {
        let (sut, collaborators) = try makeSUT()
        sut.apply(VariableBlurConfiguration(
            maxBlurRadius: 7,
            direction: .blurredCenterClearTopBottom(centerBandProportion: 1.25),
            startOffset: 0
        ))
        collaborators.installer.blurIsStillInstalled = false

        layOut(sut)

        XCTAssertEqual(collaborators.installer.installations.count, 0)
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

    // MARK: - Window

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
        let (sut, collaborators) = try makeSUT()

        container.addSubview(sut)

        XCTAssertEqual(
            collaborators.installer.scaleUpdates.map(\.scale),
            [overriddenScale],
            "the installer receives the display scale of the traits, not \(window.screen.scale) of the screen"
        )
    }

    // MARK: - Helpers

    @MainActor
    private func layOut(_ sut: DMVariableBlurUIView) {
        sut.setNeedsLayout()
        sut.layoutIfNeeded()
    }

    private func rejectedConfiguration(centerBandProportion: CGFloat) -> VariableBlurConfiguration {
        VariableBlurConfiguration(
            maxBlurRadius: 7,
            direction: .blurredCenterClearTopBottom(centerBandProportion: centerBandProportion),
            startOffset: 0
        )
    }

    private var validConfiguration: VariableBlurConfiguration {
        VariableBlurConfiguration(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0)
    }

    @MainActor
    private func makeSUT(
        renderer: MaskImageRendererSpy? = nil,
        reduceTransparencyEnabled: Bool = false
    ) throws -> (DMVariableBlurUIView, Collaborators) {
        let collaborators = Collaborators(
            renderer: try renderer ?? MaskImageRendererSpy(result: .success(makeMaskImage())),
            installer: VariableBlurInstallerSpy(),
            log: FailureLogSpy(),
            reduceTransparency: ReduceTransparencySettingSpy(isEnabled: reduceTransparencyEnabled)
        )
        let sut = DMVariableBlurUIView(
            maskRenderer: collaborators.renderer,
            installer: collaborators.installer,
            failureLog: collaborators.log,
            reduceTransparency: collaborators.reduceTransparency
        )
        return (sut, collaborators)
    }
}
