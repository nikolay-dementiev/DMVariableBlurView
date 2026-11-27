import DMCore
import DMCoreTesting
import DMVariableBlurView
import UIKit
import XCTest

/// What a blur view tells a performance tool about its work: the names, the details and the
/// order of its signposts, read from a spy on the tracing port.
@MainActor
final class BlurUIViewTracingTests: XCTestCase {
    func test_apply_acceptedConfiguration_tracesTheApplyTheMaskRenderAndTheInstall() throws {
        let sut = try makeSUT()

        sut.view.apply(validConfiguration)

        XCTAssertEqual(sut.tracing.calls, [applyAccepted, maskBegan, maskEnded, installed])
    }

    func test_apply_rejectedConfiguration_tracesTheRejectionAndTheFailure() throws {
        let sut = try makeSUT()

        sut.view.apply(rejectedConfiguration)

        XCTAssertEqual(sut.tracing.calls, [applyRejected, failed])
    }

    func test_apply_sameConfigurationAgain_tracesNothingMore() throws {
        let sut = try makeSUT()
        sut.view.apply(validConfiguration)

        sut.view.apply(validConfiguration)

        XCTAssertEqual(sut.tracing.calls, [applyAccepted, maskBegan, maskEnded, installed])
    }

    func test_apply_rejectedConfigurationAgain_tracesNothingMore() throws {
        let sut = try makeSUT()
        sut.view.apply(rejectedConfiguration)

        sut.view.apply(rejectedConfiguration)

        XCTAssertEqual(sut.tracing.calls, [applyRejected, failed])
    }

    func test_apply_maskRenderFails_endsTheIntervalAndTracesTheFailureWithoutAnInstall() throws {
        let sut = try makeSUT(renderer: MaskImageRendererSpy(result: .failure(RendererRefusal())))

        sut.view.apply(validConfiguration)

        XCTAssertEqual(sut.tracing.calls, [applyAccepted, maskBegan, maskEnded, failed])
    }

    func test_apply_installUnavailable_tracesTheReasonAsTheDetail() throws {
        let reasons: [(VariableBlurInstallation.Reason, StaticString)] = [
            (.filterClassMissing, "filterClassMissing"),
            (.filterFactoryMissing, "filterFactoryMissing"),
            (.filterTypeMissing, "filterTypeMissing"),
            (.filterCreationFailed, "filterCreationFailed"),
            (.backdropMissing, "backdropMissing"),
            (.notApplied, "notApplied"),
        ]
        for (reason, label) in reasons {
            let sut = try makeSUT()
            sut.installer.outcome = .unavailable(reason)

            sut.view.apply(validConfiguration)

            XCTAssertEqual(
                sut.tracing.calls,
                [applyAccepted, maskBegan, maskEnded, .event("install", .label(label)), failed],
                "the install event of \(reason) carries its name, and the failure follows"
            )
        }
    }

    func test_apply_viewThatFollowsReduceTransparency_tracesNoRenderAndNoInstall() throws {
        let sut = try makeSUT(reduceTransparencyEnabled: true)
        sut.view.respectsReduceTransparency = true

        sut.view.apply(validConfiguration)

        XCTAssertEqual(sut.tracing.calls, [applyAccepted])
    }

    func test_apply_viewWithAFailureHandler_tracesTheFailure() throws {
        let sut = try makeSUT()
        sut.view.failureHandler = { _ in }

        sut.view.apply(rejectedConfiguration)

        XCTAssertEqual(sut.tracing.calls, [applyRejected, failed])
    }

    func test_layout_blurStillInstalled_tracesNothingMore() throws {
        let sut = try makeSUT()
        sut.view.apply(validConfiguration)

        layOut(sut.view)

        XCTAssertEqual(sut.tracing.calls, [applyAccepted, maskBegan, maskEnded, installed])
    }

    func test_layout_blurReplaced_tracesAReinstall() throws {
        let sut = try makeSUT()
        sut.view.apply(validConfiguration)
        sut.installer.blurIsStillInstalled = false

        layOut(sut.view)

        XCTAssertEqual(sut.tracing.calls, [applyAccepted, maskBegan, maskEnded, installed, reinstalled])
    }

    func test_layout_reinstallUnavailable_tracesTheReinstallAndTheFailureOnce() throws {
        let sut = try makeSUT()
        sut.view.apply(validConfiguration)
        sut.installer.blurIsStillInstalled = false
        sut.installer.outcome = .unavailable(.notApplied)

        layOut(sut.view)
        layOut(sut.view)

        XCTAssertEqual(sut.tracing.calls, [applyAccepted, maskBegan, maskEnded, installed, reinstalled, failed])
    }

    func test_init_withCollaborators_tracesToTheirTracing() throws {
        let tracing = TracingSpy()
        let view = DMVariableBlurUIView(
            VariableBlurCollaborators(
                maskRenderer: MaskImageRendererSpy(result: .success(try makeMaskImage())),
                installer: VariableBlurInstallerSpy(),
                failureLog: FailureLogSpy(),
                reduceTransparency: ReduceTransparencySettingSpy(),
                tracing: tracing
            )
        )

        view.apply(validConfiguration)

        XCTAssertEqual(tracing.calls, [applyAccepted, maskBegan, maskEnded, installed])
    }

    func test_systemCollaborators_traceToTheSystem() {
        XCTAssertTrue(VariableBlurCollaborators.system.tracing is SystemTracing)
    }

    // MARK: - Helpers

    private struct SUT {
        let view: DMVariableBlurUIView
        let installer: VariableBlurInstallerSpy
        let tracing: TracingSpy
    }

    private struct RendererRefusal: Error {}

    private func makeSUT(
        renderer: MaskImageRendererSpy? = nil,
        reduceTransparencyEnabled: Bool = false
    ) throws -> SUT {
        let installer = VariableBlurInstallerSpy()
        let tracing = TracingSpy()
        let view = DMVariableBlurUIView(
            maskRenderer: try renderer ?? MaskImageRendererSpy(result: .success(makeMaskImage())),
            installer: installer,
            failureLog: FailureLogSpy(),
            reduceTransparency: ReduceTransparencySettingSpy(isEnabled: reduceTransparencyEnabled),
            tracing: tracing
        )
        return SUT(view: view, installer: installer, tracing: tracing)
    }

    private func layOut(_ view: DMVariableBlurUIView) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private var validConfiguration: VariableBlurConfiguration {
        VariableBlurConfiguration(maxBlurRadius: 7, direction: .blurredTopClearBottom, startOffset: 0)
    }

    private var rejectedConfiguration: VariableBlurConfiguration {
        VariableBlurConfiguration(maxBlurRadius: -1, direction: .blurredTopClearBottom, startOffset: 0)
    }

    private var applyAccepted: TracingSpy.Call { .event("apply", .label("accepted")) }
    private var applyRejected: TracingSpy.Call { .event("apply", .label("rejected")) }
    private var maskBegan: TracingSpy.Call { .begin("maskRender", .none, interval: 0) }
    private var maskEnded: TracingSpy.Call { .end("maskRender", .none, interval: 0) }
    private var installed: TracingSpy.Call { .event("install", .label("installed")) }
    private var reinstalled: TracingSpy.Call { .event("reinstall", .none) }
    private var failed: TracingSpy.Call { .event("failure", .none) }
}
