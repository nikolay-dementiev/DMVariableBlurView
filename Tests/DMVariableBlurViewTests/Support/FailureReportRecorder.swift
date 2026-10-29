import DMVariableBlurView
import XCTest

/// The failure handler of a test. It records the reports and lets a test wait for them without
/// a fixed delay: the library hands a report over in a later turn of the main actor, and the
/// wait ends when that turn has come, not after a guessed time.
@MainActor
final class FailureReportRecorder {
    private(set) var reports: [DMVariableBlurError] = []
    private var waitedFor: XCTestExpectation?

    func record(_ error: DMVariableBlurError) {
        reports.append(error)
        waitedFor?.fulfill()
    }

    /// Waits until the recorder holds `count` reports, in total. A report beyond `count` that
    /// arrives during the wait over-fulfils the expectation and fails the test.
    func waitForReports(
        count: Int,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let missing = count - reports.count
        guard missing > 0 else {
            XCTAssertEqual(reports.count, count, "reports already recorded before the wait", file: file, line: line)
            return
        }
        let expectation = XCTestExpectation(description: "\(count) failure reports")
        expectation.expectedFulfillmentCount = missing
        expectation.assertForOverFulfill = true
        waitedFor = expectation
        defer { waitedFor = nil }

        let result = await XCTWaiter().fulfillment(of: [expectation], timeout: timeout)

        XCTAssertTrue(result == .completed, "\(reports.count) of \(count) reports arrived in \(timeout) s", file: file, line: line)
    }

    /// Fails when a report arrives within `interval`. For a contract of absence only: an
    /// inverted expectation always costs the whole interval.
    func waitForNoReport(
        within interval: TimeInterval = 0.1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let expectation = XCTestExpectation(description: "no failure report")
        expectation.isInverted = true
        waitedFor = expectation
        defer { waitedFor = nil }

        let result = await XCTWaiter().fulfillment(of: [expectation], timeout: interval)

        XCTAssertFalse(result == .invertedFulfillment, "a report arrived within \(interval) s: \(reports)", file: file, line: line)
    }
}
