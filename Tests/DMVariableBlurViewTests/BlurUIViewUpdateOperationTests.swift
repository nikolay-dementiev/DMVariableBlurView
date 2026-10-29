import DMVariableBlurView
import UIKit
import XCTest

/// One update of the SwiftUI wrapper reaches the UIKit view as one request: the failure handler,
/// the Reduce Transparency option and the values arrive together and the view presents the final
/// request once. The tests call the operation the wrapper calls, with spies for the collaborators.
final class BlurUIViewUpdateOperationTests: XCTestCase {
    private struct Collaborators {
        let renderer: MaskImageRendererSpy
        let installer: VariableBlurInstallerSpy
        let log: FailureLogSpy
    }

    /// The option turned on and off again, with the values unchanged: each change shows its
    /// state once, and the kept mask is used.
    @MainActor
    func test_update_onlyTheOptionChanges_presentsOnce() throws {
        let (sut, collaborators) = try makeSUT(reduceTransparencyEnabled: true)
        sut.apply(configuration(radius: 7), respectsReduceTransparency: false, failureHandler: nil)
        XCTAssertEqual(collaborators.installer.installations.count, 1, "precondition: the blur is installed")

        let assignments = EffectAssignments()
        let observation = sut.observe(\.effect) { _, _ in
            MainActor.assumeIsolated { assignments.record() }
        }
        sut.apply(configuration(radius: 7), respectsReduceTransparency: true, failureHandler: nil)
        let installationsWhileFollowing = collaborators.installer.installations.count
        let assignmentsWhileFollowing = assignments.count
        sut.apply(configuration(radius: 7), respectsReduceTransparency: false, failureHandler: nil)
        withExtendedLifetime(observation) {}

        XCTAssertEqual(installationsWhileFollowing, 1, "the option turned on shows the plain blur and installs nothing")
        XCTAssertEqual(assignmentsWhileFollowing, 2, "the option turned on rebuilds the plain blur once")
        XCTAssertEqual(collaborators.installer.installations.count, 2, "the option turned off installs the blur once")
        XCTAssertEqual(collaborators.renderer.profiles.count, 1, "the mask is drawn once and kept")
        XCTAssertNil(sut.failure, "following the setting is not a failure")
    }

    /// The previous values were never shown, because the view followed the setting. An update that
    /// turns the option off and changes the values must not show them on the way.
    @MainActor
    func test_update_configurationAndOptionChange_appliesOnlyTheFinalRequest() throws {
        let (sut, collaborators) = try makeSUT(reduceTransparencyEnabled: true)
        sut.apply(configuration(radius: 7), respectsReduceTransparency: true, failureHandler: nil)
        XCTAssertEqual(collaborators.installer.installations.count, 0, "precondition: the setting is on, so nothing is installed")

        sut.apply(configuration(radius: 9), respectsReduceTransparency: false, failureHandler: nil)

        XCTAssertEqual(collaborators.installer.installations.map(\.maxBlurRadius), [9], "only the final request is installed")
        XCTAssertEqual(collaborators.renderer.profiles.count, 1, "the mask of the first request is never drawn")
    }

    /// The first request would be rejected by the system. It was never shown, so its failure must
    /// not reach the handler of the update that replaces it.
    @MainActor
    func test_update_previousRequestWouldFail_reportsOnlyTheNewRequestOutcome() async throws {
        let (sut, collaborators) = try makeSUT(reduceTransparencyEnabled: true)
        collaborators.installer.outcomeForRadius[7] = .unavailable(.notApplied)
        sut.apply(configuration(radius: 7), respectsReduceTransparency: true, failureHandler: nil)
        XCTAssertNil(sut.failure, "precondition: the first request was never presented, so nothing failed")
        let recorder = FailureReportRecorder()

        sut.apply(configuration(radius: 9), respectsReduceTransparency: false, failureHandler: recorder.record)
        await recorder.waitForNoReport()

        XCTAssertEqual(recorder.reports, [], "the handler hears nothing about the request that was never shown")
        XCTAssertNil(sut.failure, "the view shows the final request, which the system took")
        XCTAssertEqual(collaborators.installer.installations.map(\.maxBlurRadius), [9], "only the final request is installed")
        XCTAssertEqual(collaborators.log.entries, [], "nothing is logged")
    }

    /// The plain blur is rebuilt by assigning the effect through `nil`. One update rebuilds it once.
    @MainActor
    func test_update_optionTurnedOnWithANewConfiguration_showsThePlainBlurOnce() throws {
        let (sut, _) = try makeSUT(reduceTransparencyEnabled: true)
        sut.apply(configuration(radius: 7), respectsReduceTransparency: false, failureHandler: nil)
        let assignments = EffectAssignments()
        let observation = sut.observe(\.effect) { _, _ in
            MainActor.assumeIsolated { assignments.record() }
        }

        sut.apply(configuration(radius: 9), respectsReduceTransparency: true, failureHandler: nil)

        XCTAssertEqual(assignments.count, 2, "the effect goes through nil to a new one, once")
        withExtendedLifetime(observation) {}
    }

    /// New values the system would take are no help when they are rejected by value: the option
    /// changes, the values are not valid, and the view shows the plain blur and records the reason.
    @MainActor
    func test_update_optionChangesAndTheNewValuesAreRejected_installsNothingAndRecordsOnce() throws {
        let (sut, collaborators) = try makeSUT(reduceTransparencyEnabled: false)
        sut.apply(configuration(radius: 7), respectsReduceTransparency: false, failureHandler: nil)
        XCTAssertEqual(collaborators.installer.installations.count, 1, "precondition: the blur is installed")
        let rejected = VariableBlurConfiguration(
            maxBlurRadius: 7,
            direction: .blurredCenterClearTopBottom(centerBandProportion: 1.25),
            startOffset: 0
        )

        sut.apply(rejected, respectsReduceTransparency: true, failureHandler: nil)

        XCTAssertEqual(collaborators.installer.installations.count, 1, "the rejected values install nothing")
        XCTAssertEqual(sut.failure, .invalidCenterBandProportion(1.25), "the reason of the rejection is recorded")
        XCTAssertEqual(collaborators.log.entries.count, 1, "the rejection is logged once")
    }

    /// The new values are the ones the system refuses: the handler of the update hears of them
    /// once, and of nothing else.
    @MainActor
    func test_update_optionAndValuesChangeAndTheNewValuesFail_reportsTheFailureOnce() async throws {
        let (sut, collaborators) = try makeSUT(reduceTransparencyEnabled: true)
        collaborators.installer.outcomeForRadius[9] = .unavailable(.notApplied)
        sut.apply(configuration(radius: 7), respectsReduceTransparency: true, failureHandler: nil)
        let recorder = FailureReportRecorder()

        sut.apply(configuration(radius: 9), respectsReduceTransparency: false, failureHandler: recorder.record)
        await recorder.waitForReports(count: 1)

        XCTAssertEqual(recorder.reports, [.effectUnavailable], "the handler hears of the failure of the new values once")
        XCTAssertEqual(sut.failure, .effectUnavailable, "the failure is recorded")
        XCTAssertEqual(collaborators.installer.installations.map(\.maxBlurRadius), [9], "only the new values were tried")
    }

    /// A configuration that failed stays failed: the option does not bring it back, and the
    /// failure is not reported again.
    @MainActor
    func test_update_optionChangesWhileTheFailureIsRecorded_reportsNothingNew() async throws {
        let (sut, collaborators) = try makeSUT(reduceTransparencyEnabled: false)
        collaborators.installer.outcome = .unavailable(.notApplied)
        let recorder = FailureReportRecorder()
        let handler: @MainActor (DMVariableBlurError) -> Void = recorder.record
        sut.apply(configuration(radius: 7), respectsReduceTransparency: false, failureHandler: handler)
        await recorder.waitForReports(count: 1)

        sut.apply(configuration(radius: 7), respectsReduceTransparency: true, failureHandler: handler)
        sut.apply(configuration(radius: 7), respectsReduceTransparency: false, failureHandler: handler)
        await recorder.waitForNoReport()

        XCTAssertEqual(recorder.reports, [.effectUnavailable], "the failure is reported once")
        XCTAssertEqual(collaborators.installer.installations.count, 1, "no second attempt")
    }

    // MARK: - Helpers

    @MainActor
    private final class EffectAssignments {
        private(set) var count = 0

        func record() {
            count += 1
        }
    }

    private func configuration(radius: CGFloat) -> VariableBlurConfiguration {
        VariableBlurConfiguration(maxBlurRadius: radius, direction: .blurredTopClearBottom, startOffset: 0)
    }

    @MainActor
    private func makeSUT(reduceTransparencyEnabled: Bool) throws -> (DMVariableBlurUIView, Collaborators) {
        let collaborators = Collaborators(
            renderer: MaskImageRendererSpy(result: .success(try makeMaskImage())),
            installer: VariableBlurInstallerSpy(),
            log: FailureLogSpy()
        )
        let sut = DMVariableBlurUIView(
            maskRenderer: collaborators.renderer,
            installer: collaborators.installer,
            failureLog: collaborators.log,
            reduceTransparency: ReduceTransparencySettingSpy(isEnabled: reduceTransparencyEnabled)
        )
        return (sut, collaborators)
    }
}
