import DMVariableBlurView
import XCTest

/// `onFailure(_:)`: when the handler is called, how often, with which reason, and which
/// handler receives it.
final class OnFailureTests: XCTestCase {
    @MainActor
    func test_onFailure_validConfiguration_reportsNothing() async throws {
        let recorder = FailureRecorder()
        let sut = try makeSUT(validView.onFailure(recorder.record))
        defer { sut.hide() }

        try await deliverPendingReports()

        XCTAssertEqual(recorder.reports, [])
    }

    @MainActor
    func test_onFailure_invalidConfiguration_reportsOnce() async throws {
        let recorder = FailureRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }

        try await deliverPendingReports()

        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5)])
    }

    /// The handler may change state: it never runs inside `makeUIView` or `updateUIView`.
    @MainActor
    func test_onFailure_duringMake_isNotCalledBeforeMakeReturns() async throws {
        let recorder = FailureRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }
        let reportsRightAfterMake = recorder.reports

        try await deliverPendingReports()

        XCTAssertEqual(reportsRightAfterMake, [], "nothing is reported while the view is made")
        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5)], "the report follows in a later turn")
    }

    @MainActor
    func test_onFailure_sameFailingConfigurationUpdatedAgain_reportsNothingNew() async throws {
        let recorder = FailureRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }

        _ = try sut.update(rejectedView(1.5).onFailure(recorder.record))
        try await deliverPendingReports()

        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5)])
    }

    /// The rejected value is compared through the reason, which is equal to itself also
    /// when the value is not a number.
    @MainActor
    func test_onFailure_nanConfigurationUpdatedAgain_reportsOnce() async throws {
        let recorder = FailureRecorder()
        let sut = try makeSUT(rejectedView(.nan).onFailure(recorder.record))
        defer { sut.hide() }

        _ = try sut.update(rejectedView(.nan).onFailure(recorder.record))
        try await deliverPendingReports()

        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(.nan)])
    }

    @MainActor
    func test_onFailure_failureRecoveryFailure_reportsTwice() async throws {
        let recorder = FailureRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }

        try await deliverPendingReports()
        _ = try sut.update(validView.onFailure(recorder.record))
        try await deliverPendingReports()
        _ = try sut.update(rejectedView(1.5).onFailure(recorder.record))
        try await deliverPendingReports()

        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5), .invalidCenterBandProportion(1.5)])
    }

    @MainActor
    func test_onFailure_twoDifferentFailures_reportsBothInOrder() async throws {
        let recorder = FailureRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }

        _ = try sut.update(rejectedView(-0.5).onFailure(recorder.record))
        try await deliverPendingReports()

        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5), .invalidCenterBandProportion(-0.5)])
    }

    @MainActor
    func test_onFailure_handlerReplaced_nextFailureGoesToTheNewHandler() async throws {
        let first = FailureRecorder()
        let second = FailureRecorder()
        let sut = try makeSUT(validView.onFailure(first.record))
        defer { sut.hide() }

        _ = try sut.update(rejectedView(1.5).onFailure(second.record))
        try await deliverPendingReports()

        XCTAssertEqual(first.reports, [], "the replaced handler hears nothing")
        XCTAssertEqual(second.reports, [.invalidCenterBandProportion(1.5)], "the new handler receives the failure")
    }

    /// A failure goes to the handler that was set when it happened.
    @MainActor
    func test_onFailure_handlerReplacedBeforeDelivery_failureGoesToTheHandlerSetWhenItHappened() async throws {
        let first = FailureRecorder()
        let second = FailureRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(first.record))
        defer { sut.hide() }

        _ = try sut.update(rejectedView(1.5).onFailure(second.record))
        try await deliverPendingReports()

        XCTAssertEqual(first.reports, [.invalidCenterBandProportion(1.5)], "the handler of the failure receives it")
        XCTAssertEqual(second.reports, [], "the later handler hears nothing, nothing new failed")
    }

    @MainActor
    func test_onFailure_viewLeavesTheHierarchyBeforeDelivery_handlerIsStillCalledOnce() async throws {
        let recorder = FailureRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }
        let blurView = sut.blurView

        sut.removeFromWindow()
        let leftTheHierarchy = blurView.window == nil
        try await deliverPendingReports()

        XCTAssertTrue(leftTheHierarchy, "precondition: the blur view left the window before the delivery")
        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5)], "the handler is called once")
    }

    @MainActor
    func test_onFailure_viewDeallocatedBeforeDelivery_handlerIsStillCalledOnce() async throws {
        let recorder = FailureRecorder()
        weak var blurView: DMVariableBlurUIView?
        try autoreleasepool {
            let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
            blurView = sut.blurView
            sut.removeFromWindow()
            sut.hide()
        }
        let deallocated = blurView == nil

        try await deliverPendingReports()

        XCTAssertTrue(deallocated, "precondition: the view is gone before the delivery")
        XCTAssertEqual(recorder.reports, [.invalidCenterBandProportion(1.5)], "the handler is called once")
    }

    @MainActor
    func test_onFailure_handlerSet_writesNoLineToTheLog() async throws {
        let log = UnifiedLogReader()
        let recorder = FailureRecorder()
        let sut = try makeSUT(rejectedView(1.5).onFailure(recorder.record))
        defer { sut.hide() }

        try await deliverPendingReports()

        XCTAssertEqual(recorder.reports.count, 1, "the handler receives the failure")
        XCTAssertEqual(try log.libraryLines().count, 0, "the log stays silent")
    }

    // MARK: - Helpers

    @MainActor
    private func makeSUT(_ view: DMVariableBlurView) throws -> HostedBlurView {
        try HostedBlurView(view)
    }

    @MainActor
    private final class FailureRecorder {
        private(set) var reports: [DMVariableBlurError] = []

        func record(_ error: DMVariableBlurError) {
            reports.append(error)
        }
    }

    @MainActor
    private var validView: DMVariableBlurView {
        DMVariableBlurView(maxBlurRadius: 5, direction: .blurredTopClearBottom)
    }

    @MainActor
    private func rejectedView(_ centerBandProportion: CGFloat) -> DMVariableBlurView {
        DMVariableBlurView(direction: .blurredCenterClearTopBottom(centerBandProportion: centerBandProportion))
    }

    /// Lets the main actor run the reports that were scheduled for a later turn.
    @MainActor
    private func deliverPendingReports() async throws {
        try await Task.sleep(for: .milliseconds(50))
    }
}
