import Foundation
import OSLog

/// Reads the lines this test process wrote to the unified log.
///
/// `OSLogStore(scope: .currentProcessIdentifier)` gives a process its own entries
/// (iOS 15 and later, https://developer.apple.com/documentation/oslog/oslogstore).
/// Entries reach the store with a delay that grows when many lines are written. So the
/// reader writes a marker line of its own and reads until the marker is there: every line
/// written before the marker is in the store by then.
struct UnifiedLogReader {
    enum ReaderError: Error {
        case markerNotFound(String)
    }

    /// The subsystem under which the library writes.
    static let librarySubsystem = "DMVariableBlurView"

    private static let markerCategory = "test-marker"
    private static let timeout: TimeInterval = 10

    private let start: Date

    /// Starts reading from now on: lines written before this call are not returned.
    init() {
        start = Date()
    }

    /// The lines of the library written since the reader was created.
    ///
    /// A position taken from a date can lie before that date, so the entries are also
    /// filtered by their own date: lines of earlier tests in the process stay out.
    func libraryLines() throws -> [OSLogEntryLog] {
        let marker = UUID().uuidString
        Logger(subsystem: Self.librarySubsystem, category: Self.markerCategory).notice("\(marker, privacy: .public)")
        let deadline = Date().addingTimeInterval(Self.timeout)
        repeat {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let lines = try store.getEntries(at: store.position(date: start))
                .compactMap { $0 as? OSLogEntryLog }
                .filter { $0.subsystem == Self.librarySubsystem && $0.date >= start }
            if lines.contains(where: { $0.category == Self.markerCategory && $0.composedMessage == marker }) {
                return lines.filter { $0.category != Self.markerCategory }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        throw ReaderError.markerNotFound(marker)
    }
}
