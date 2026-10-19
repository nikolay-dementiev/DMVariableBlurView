import DMVariableBlurView
import UIKit
import XCTest

/// A layout pass that finds the blur gone and cannot install it again leaves the plain blur of
/// the system, with its tint, and reports the failure once. The tests run on the real system: the
/// installer is the real one, except that it refuses to install once a test says so.
final class BlurViewFailedReinstallationTests: XCTestCase {
    @MainActor
    func test_layout_reinstallationUnavailable_restoresPlainBlurAndReportsOnce() async throws {
        let sut = makeSUT()
        defer { sut.hosted.hide() }
        var reports: [DMVariableBlurError] = []
        sut.view.failureHandler = { reports.append($0) }

        refuseReinstallation(of: sut)
        let installationsBeforeTheFailure = sut.installer.installCount
        sut.view.setNeedsLayout()
        sut.hosted.window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(sut.view.failure, .effectUnavailable, "the failure is recorded")
        XCTAssertEqual(sut.hosted.tintAlphas, [1], "the tint that the installation hid is back")
        XCTAssertFalse(sut.hosted.filterTypes.isEmpty, "the backdrop carries the standard filters")
        XCTAssertFalse(sut.hosted.filterTypes.contains("variableBlur"), "the variable blur is gone")
        XCTAssertEqual(reports, [.effectUnavailable], "the failure is reported once")

        sut.view.setNeedsLayout()
        sut.hosted.window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(
            sut.installer.installCount,
            installationsBeforeTheFailure + 1,
            "one attempt at the failure and none on the next pass"
        )
        XCTAssertEqual(reports, [.effectUnavailable], "the next pass reports nothing new")
    }

    /// The plain blur is the state the view leaves, so a host that removes the effect and gives one
    /// back finds nothing to put back: the view installs nothing.
    @MainActor
    func test_layout_afterTheRestoredPlainBlur_effectRemovedAndGivenBack_installsNothing() throws {
        let sut = makeSUT()
        defer { sut.hosted.hide() }
        refuseReinstallation(of: sut)
        sut.view.setNeedsLayout()
        sut.hosted.window.layoutIfNeeded()
        let installationsAtTheFailure = sut.installer.installCount

        sut.view.effect = nil
        sut.view.layoutIfNeeded()
        let effectWhileRemoved = sut.view.effect
        sut.view.effect = UIBlurEffect(style: .dark)
        sut.view.layoutIfNeeded()

        XCTAssertNil(effectWhileRemoved, "the view leaves a removed effect to the host")
        XCTAssertEqual(sut.installer.installCount, installationsAtTheFailure, "nothing is installed when the effect returns")
        XCTAssertEqual(sut.hosted.tintAlphas, [1], "the effect that returned shows its tint")
        XCTAssertFalse(sut.hosted.filterTypes.contains("variableBlur"), "the effect that returned is the plain blur")
    }

    // MARK: - Helpers

    private struct SUT {
        let hosted: HostedBlurView
        let view: DMVariableBlurUIView
        let installer: ForwardingInstallerSpy
        /// The filters of the backdrop before the blur was installed: the standard ones.
        let standardFilters: [Any]?
    }

    /// A view in a window that has installed its blur once, with the real collaborators and an
    /// installer that can be told to refuse.
    @MainActor
    private func makeSUT() -> SUT {
        let installer = ForwardingInstallerSpy()
        let view = DMVariableBlurUIView(
            maskRenderer: CoreGraphicsMaskImageRenderer(),
            installer: installer,
            failureLog: SystemFailureLog(),
            reduceTransparency: SystemReduceTransparencySetting()
        )
        let hosted = HostedBlurView(placing: view)
        hosted.window.overrideUserInterfaceStyle = .light
        hosted.window.layoutIfNeeded()
        let standardFilters = view.subviews.first?.layer.filters
        view.apply(VariableBlurConfiguration(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0))
        hosted.window.layoutIfNeeded()
        return SUT(hosted: hosted, view: view, installer: installer, standardFilters: standardFilters)
    }

    /// The standard filters come back on the backdrop while the tint stays hidden, and the system
    /// refuses the blur from now on: the state in which a re-installation fails.
    @MainActor
    private func refuseReinstallation(of sut: SUT) {
        sut.view.subviews.first?.layer.filters = sut.standardFilters
        sut.installer.refuseInstallations(with: .unavailable(.notApplied))
    }
}
