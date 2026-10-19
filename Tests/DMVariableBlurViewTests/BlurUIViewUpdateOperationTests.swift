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

    // MARK: - Helpers

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
