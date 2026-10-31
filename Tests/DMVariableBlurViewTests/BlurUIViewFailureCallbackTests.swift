import DMVariableBlurView
import UIKit
import XCTest

/// The handler of `DMVariableBlurUIView(...onFailure:)` follows the rules of `onFailure(_:)` in
/// SwiftUI: a report per failing configuration, none for an equal one, a new one after a valid
/// configuration in between, none to the log while the handler exists. The views are made with
/// the initializer that takes the handler, so what the tests see is the handler it installs.
final class BlurUIViewFailureCallbackTests: XCTestCase {
    private struct Spies {
        let installer: VariableBlurInstallerSpy
        let log: FailureLogSpy
    }

    // MARK: - The first values

    @MainActor
    func test_init_validConfiguration_reportsNothing() async throws {
        let recorder = FailureReportRecorder()
        _ = try makeSUT(recorder: recorder)

        await recorder.waitForNoReport()

        XCTAssertEqual(recorder.reports, [], "a view that shows the blur has nothing to report")
    }

    @MainActor
    func test_init_effectUnavailableAtTheFirstApply_deliversTheReasonAndLogsNothing() async throws {
        let recorder = FailureReportRecorder()
        let installer = VariableBlurInstallerSpy()
        installer.outcome = .unavailable(.filterTypeMissing)
        let (_, spies) = try makeSUT(installer: installer, recorder: recorder)

        await recorder.waitForReports(count: 1)

        XCTAssertEqual(recorder.reports, [.effectUnavailable], "the handler receives the reason")
        XCTAssertEqual(spies.log.entries, [], "the log stays silent")
    }

    @MainActor
    func test_init_rejectedConfigurationWithAHandler_writesNoLineToTheLog() async throws {
        let recorder = FailureReportRecorder()
        let (sut, spies) = try makeSUT(direction: rejectedDirection, recorder: recorder)

        await recorder.waitForReports(count: 1)

        XCTAssertEqual(sut.failure, .invalidCenterBandProportion(1.25), "failure holds the reason")
        XCTAssertEqual(spies.log.entries, [], "the log stays silent while the handler exists")
    }

    // MARK: - Later failures

    @MainActor
    func test_layout_installingAgainFailsAfterTheInitializer_reportsToTheHandlerOnce() async throws {
        let recorder = FailureReportRecorder()
        let (sut, spies) = try makeSUT(recorder: recorder)
        spies.installer.blurIsStillInstalled = false
        spies.installer.outcome = .unavailable(.notApplied)

        layOut(sut)
        layOut(sut)
        await recorder.waitForReports(count: 1)
        await recorder.waitForNoReport()

        XCTAssertEqual(recorder.reports, [.effectUnavailable], "the failure of the re-application is reported once")
        XCTAssertEqual(spies.log.entries, [], "the log stays silent")
    }

    /// The appearance changes, UIKit puts the standard filters back, and the system refuses the
    /// blur: the view and the layout pass are real, only the installer can be told to refuse.
    @MainActor
    func test_layout_appearanceChangesAndTheSystemRefusesTheBlur_reportsToTheHandlerOfTheInitializer() async throws {
        let recorder = FailureReportRecorder()
        let installer = ForwardingInstallerSpy()
        let collaborators = VariableBlurCollaborators(
            maskRenderer: CoreGraphicsMaskImageRenderer(),
            installer: installer,
            failureLog: SystemFailureLog(),
            reduceTransparency: SystemReduceTransparencySetting()
        )
        let view = DMVariableBlurUIView(
            collaborators,
            maxBlurRadius: 7,
            direction: .blurredTopClearBottom,
            startOffset: 0,
            onFailure: recorder.record
        )
        let hosted = HostedBlurView(placing: view)
        defer { hosted.hide() }
        hosted.window.overrideUserInterfaceStyle = .light
        hosted.window.layoutIfNeeded()
        installer.refuseInstallations(because: .notApplied)
        let installationsBeforeTheChange = installer.installCount

        hosted.window.overrideUserInterfaceStyle = .dark
        hosted.window.layoutIfNeeded()
        await recorder.waitForReports(count: 1)

        XCTAssertEqual(recorder.reports, [.effectUnavailable], "the handler of the initializer hears the failure")
        XCTAssertEqual(view.failure, .effectUnavailable, "failure holds the reason as well")
        XCTAssertEqual(installer.installCount, installationsBeforeTheChange + 1, "the change brought one attempt")
    }

    /// A failure that an update brings is not reported inside `update`, so a host may change
    /// state in the handler.
    @MainActor
    func test_update_rejectedValuesWithAHandler_isNotReportedBeforeUpdateReturns() async throws {
        let recorder = FailureReportRecorder()
        let (sut, _) = try makeSUT(recorder: recorder)

        sut.update(maxBlurRadius: 7, direction: rejectedDirection, startOffset: 0)
        let reportsRightAfterTheUpdate = recorder.reports
        await recorder.waitForReports(count: 1)

        XCTAssertEqual(reportsRightAfterTheUpdate, [], "nothing is reported while the update runs")
        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.25)], "the report follows in a later turn")
    }

    /// The task that delivers a report holds the handler of the moment and not the view.
    @MainActor
    func test_init_viewDeallocatedBeforeDelivery_handlerIsStillCalledOnce() async throws {
        let recorder = FailureReportRecorder()
        weak var blurView: DMVariableBlurUIView?
        try autoreleasepool {
            let (sut, _) = try makeSUT(direction: rejectedDirection, recorder: recorder)
            blurView = sut
        }
        let deallocated = blurView == nil

        await recorder.waitForReports(count: 1)
        await recorder.waitForNoReport()

        XCTAssertTrue(deallocated, "precondition: the view is gone before the delivery")
        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.25)], "the handler is called once")
    }

    // MARK: - Equal failures and recovery

    @MainActor
    func test_update_equalRejectionAgain_reportsOnce() async throws {
        let recorder = FailureReportRecorder()
        let (sut, _) = try makeSUT(direction: rejectedDirection, recorder: recorder)

        sut.update(maxBlurRadius: 7, direction: rejectedDirection, startOffset: 0)
        sut.update(maxBlurRadius: 9, direction: rejectedDirection, startOffset: 0.2)
        await recorder.waitForReports(count: 1)
        await recorder.waitForNoReport()

        XCTAssertEqual(
            recorder.reports,
            [.invalidCenterBandProportion(1.25)],
            "an equal rejection is the same failure, also when the other values differ"
        )
    }

    @MainActor
    func test_update_rejectedValidRejected_reportsTwice() async throws {
        let recorder = FailureReportRecorder()
        let (sut, _) = try makeSUT(direction: rejectedDirection, recorder: recorder)
        await recorder.waitForReports(count: 1)

        sut.update(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0)
        sut.update(maxBlurRadius: 7, direction: rejectedDirection, startOffset: 0)
        await recorder.waitForReports(count: 2)
        await recorder.waitForNoReport()

        XCTAssertEqual(
            recorder.reports,
            [.invalidCenterBandProportion(1.25), .invalidCenterBandProportion(1.25)],
            "a failure that returns after a valid configuration is reported again"
        )
    }

    // MARK: - Helpers

    private var rejectedDirection: DMVariableBlurDirection {
        .blurredCenterClearTopBottom(centerBandProportion: 1.25)
    }

    @MainActor
    private func layOut(_ sut: DMVariableBlurUIView) {
        sut.setNeedsLayout()
        sut.layoutIfNeeded()
    }

    /// A view made by the initializer that takes the handler, with spies for the collaborators.
    @MainActor
    private func makeSUT(
        direction: DMVariableBlurDirection = .blurredTopClearBottom,
        installer: VariableBlurInstallerSpy = VariableBlurInstallerSpy(),
        recorder: FailureReportRecorder
    ) throws -> (DMVariableBlurUIView, Spies) {
        let log = FailureLogSpy()
        let collaborators = VariableBlurCollaborators(
            maskRenderer: MaskImageRendererSpy(result: .success(try makeMaskImage())),
            installer: installer,
            failureLog: log,
            reduceTransparency: ReduceTransparencySettingSpy(isEnabled: false)
        )
        let sut = DMVariableBlurUIView(
            collaborators,
            maxBlurRadius: 7,
            direction: direction,
            startOffset: 0,
            onFailure: recorder.record
        )
        return (sut, Spies(installer: installer, log: log))
    }
}
