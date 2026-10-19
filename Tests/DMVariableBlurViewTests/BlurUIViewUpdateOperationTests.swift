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
        let reduceTransparency: ReduceTransparencySettingSpy
    }

    /// The option turned on and off again, with the values unchanged: each change shows its
    /// state once, and the kept mask is used.
    @MainActor
    func test_update_onlyTheOptionChanges_presentsOnce() throws {
        let (sut, collaborators) = try makeSUT(reduceTransparencyEnabled: true)
        sut.apply(configuration(radius: 7), respectsReduceTransparency: false, failureHandler: nil)
        XCTAssertEqual(collaborators.installer.installations.count, 1, "precondition: the blur is installed")

        sut.apply(configuration(radius: 7), respectsReduceTransparency: true, failureHandler: nil)
        let installationsWhileFollowing = collaborators.installer.installations.count
        sut.apply(configuration(radius: 7), respectsReduceTransparency: false, failureHandler: nil)

        XCTAssertEqual(installationsWhileFollowing, 1, "the option turned on shows the plain blur and installs nothing")
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
        var reports: [DMVariableBlurError] = []

        sut.apply(configuration(radius: 9), respectsReduceTransparency: false, failureHandler: { reports.append($0) })
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(reports, [], "the handler hears nothing about the request that was never shown")
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
