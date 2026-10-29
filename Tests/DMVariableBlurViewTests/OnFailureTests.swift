import DMVariableBlurView
import XCTest

/// `onFailure(_:)`: when the handler is called, how often, with which reason, and which
/// handler receives it.
final class OnFailureTests: XCTestCase {
    @MainActor
    func test_onFailure_validConfiguration_reportsNothing() async throws {
        let recorder = FailureReportRecorder()
        let sut = try makeSUT(validView.onFailure(recorder.record))
        defer { sut.hide() }

        await recorder.waitForNoReport()

        XCTAssertEqual(recorder.reports, [])
    }

    @MainActor
    func test_onFailure_invalidConfiguration_reportsOnce() async throws {
        let recorder = FailureReportRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }

        await recorder.waitForReports(count: 1)
        await recorder.waitForNoReport()

        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5)])
    }

    /// The handler may change state: it never runs inside `makeUIView` or `updateUIView`.
    @MainActor
    func test_onFailure_duringMake_isNotCalledBeforeMakeReturns() async throws {
        let recorder = FailureReportRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }
        let reportsRightAfterMake = recorder.reports

        await recorder.waitForReports(count: 1)

        XCTAssertEqual(reportsRightAfterMake, [], "nothing is reported while the view is made")
        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5)], "the report follows in a later turn")
    }

    /// A failure that an update brings is not reported inside `updateUIView` either, so a
    /// host may change state in the handler.
    @MainActor
    func test_onFailure_duringAnUpdate_isNotCalledBeforeTheUpdateReturns() async throws {
        let recorder = FailureReportRecorder()
        let sut = try makeSUT(DMVariableBlurView(direction: .blurredTopClearBottom).onFailure(recorder.record))
        defer { sut.hide() }
        await recorder.waitForNoReport()

        _ = try sut.update(rejectedView(1.5).onFailure(recorder.record))
        let reportsRightAfterTheUpdate = recorder.reports
        await recorder.waitForReports(count: 1)

        XCTAssertEqual(reportsRightAfterTheUpdate, [], "nothing is reported while the view is updated")
        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5)], "the report follows in a later turn")
    }

    @MainActor
    func test_onFailure_sameFailingConfigurationUpdatedAgain_reportsNothingNew() async throws {
        let recorder = FailureReportRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }

        _ = try sut.update(rejectedView(1.5).onFailure(recorder.record))
        await recorder.waitForReports(count: 1)
        await recorder.waitForNoReport()

        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5)])
    }

    /// The rejected value is compared through the reason, which is equal to itself also
    /// when the value is not a number.
    @MainActor
    func test_onFailure_nanConfigurationUpdatedAgain_reportsOnce() async throws {
        let recorder = FailureReportRecorder()
        let sut = try makeSUT(rejectedView(.nan).onFailure(recorder.record))
        defer { sut.hide() }

        _ = try sut.update(rejectedView(.nan).onFailure(recorder.record))
        await recorder.waitForReports(count: 1)
        await recorder.waitForNoReport()

        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(.nan)])
    }

    @MainActor
    func test_onFailure_failureRecoveryFailure_reportsTwice() async throws {
        let recorder = FailureReportRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }

        await recorder.waitForReports(count: 1)
        _ = try sut.update(validView.onFailure(recorder.record))
        await recorder.waitForNoReport()
        _ = try sut.update(rejectedView(1.5).onFailure(recorder.record))
        await recorder.waitForReports(count: 2)

        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5), .invalidCenterBandProportion(1.5)])
    }

    @MainActor
    func test_onFailure_twoDifferentFailures_reportsBothInOrder() async throws {
        let recorder = FailureReportRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }

        _ = try sut.update(rejectedView(-0.5).onFailure(recorder.record))
        await recorder.waitForReports(count: 2)

        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5), .invalidCenterBandProportion(-0.5)])
    }

    @MainActor
    func test_onFailure_handlerReplaced_nextFailureGoesToTheNewHandler() async throws {
        let first = FailureReportRecorder()
        let second = FailureReportRecorder()
        let sut = try makeSUT(validView.onFailure(first.record))
        defer { sut.hide() }

        _ = try sut.update(rejectedView(1.5).onFailure(second.record))
        await second.waitForReports(count: 1)
        await first.waitForNoReport()

        XCTAssertEqual(first.reports, [], "the replaced handler hears nothing")
        XCTAssertEqual(second.reports, [.invalidCenterBandProportion(1.5)], "the new handler receives the failure")
    }

    /// A failure goes to the handler that was set when it happened.
    @MainActor
    func test_onFailure_handlerReplacedBeforeDelivery_failureGoesToTheHandlerSetWhenItHappened() async throws {
        let first = FailureReportRecorder()
        let second = FailureReportRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(first.record))
        defer { sut.hide() }

        _ = try sut.update(rejectedView(1.5).onFailure(second.record))
        await first.waitForReports(count: 1)
        await second.waitForNoReport()

        XCTAssertEqual(first.reports, [.invalidCenterBandProportion(1.5)], "the handler of the failure receives it")
        XCTAssertEqual(second.reports, [], "the later handler hears nothing, nothing new failed")
    }

    @MainActor
    func test_onFailure_viewLeavesTheHierarchyBeforeDelivery_handlerIsStillCalledOnce() async throws {
        let recorder = FailureReportRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }
        let blurView = sut.blurView

        sut.removeFromWindow()
        let leftTheHierarchy = blurView.window == nil
        await recorder.waitForReports(count: 1)
        await recorder.waitForNoReport()

        XCTAssertTrue(leftTheHierarchy, "precondition: the blur view left the window before the delivery")
        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5)], "the handler is called once")
    }

    @MainActor
    func test_onFailure_viewDeallocatedBeforeDelivery_handlerIsStillCalledOnce() async throws {
        let recorder = FailureReportRecorder()
        weak var blurView: DMVariableBlurUIView?
        try autoreleasepool {
            let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
            blurView = sut.blurView
            sut.removeFromWindow()
            sut.hide()
        }
        let deallocated = blurView == nil

        await recorder.waitForReports(count: 1)
        await recorder.waitForNoReport()

        XCTAssertTrue(deallocated, "precondition: the view is gone before the delivery")
        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5)], "the handler is called once")
    }

    @MainActor
    func test_onFailure_handlerSet_writesNoLineToTheLog() async throws {
        let log = UnifiedLogReader()
        let recorder = FailureReportRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }

        await recorder.waitForReports(count: 1)

        XCTAssertEqual(recorder.reports.count, 1, "the handler receives the failure")
        XCTAssertEqual(try log.libraryLines().count, 0, "the log stays silent")
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT(_ view: DMVariableBlurView) throws -> HostedBlurView {
        try HostedBlurView(view)
    }

    @MainActor
    private var validView: DMVariableBlurView {
        DMVariableBlurView(maxBlurRadius: 5, direction: .blurredTopClearBottom)
    }

    @MainActor
    private func rejectedView(_ centerBandProportion: CGFloat) -> DMVariableBlurView {
        DMVariableBlurView(direction: .blurredCenterClearTopBottom(centerBandProportion: centerBandProportion))
    }
}
